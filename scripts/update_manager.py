#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import json
import os
import platform
import random
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from datetime import datetime
from urllib.error import URLError

# Exit codes
EXIT_CODE_SUCCESS = 0
EXIT_CODE_ERROR = 1
EXIT_CODE_RESTART_REQUIRED = 10


def log(message):
    """Log a message with timestamp."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")


def get_platform():
    """Get the current platform."""
    system = platform.system().lower()
    if system == "darwin":
        return "mac"
    elif system == "windows":
        return "windows"
    elif system == "linux":
        return "linux"
    else:
        return "unknown"


def get_application_directory():
    """Get the application directory."""
    # When running from the application bundle
    app_dir = os.path.dirname(os.path.abspath(sys.argv[0]))

    # Find parent directory where configuration.json exists
    current_dir = app_dir
    max_iterations = 5  # Limit search depth to prevent infinite loop

    for _ in range(max_iterations):
        if os.path.exists(os.path.join(current_dir, "configuration.json")):
            return current_dir

        parent = os.path.dirname(current_dir)
        if parent == current_dir:  # We've reached the root
            break
        current_dir = parent

    # If not found, return the original app_dir
    return app_dir


def load_config(config_path):
    """Load a configuration file."""
    try:
        with open(config_path, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        log(f"Error loading configuration from {config_path}: {e}")
        return None


def get_remote_config_url():
    """Get the remote configuration URL from the local configuration."""
    app_dir = get_application_directory()
    config_path = os.path.join(app_dir, "configuration.json")

    config = load_config(config_path)
    if not config:
        log("Failed to load local configuration, cannot determine remote URL")
        return None

    if "application" in config and "downloadUrl" in config["application"]:
        remote_url = config["application"]["downloadUrl"]
        log(f"Using remote config URL from configuration: {remote_url}")
        return remote_url
    else:
        log("No remote URL found in configuration")
        return None


def download_remote_config():
    """Download the remote configuration file."""
    log("Downloading remote configuration...")

    # Get remote URL from configuration
    remote_url = get_remote_config_url()
    if not remote_url:
        log("Cannot download remote configuration: URL not available")
        return None

    try:
        # Create a temporary file to store the remote config
        with tempfile.NamedTemporaryFile(delete=False, suffix=".json") as temp_file:
            temp_path = temp_file.name

        # Download the configuration file
        with urllib.request.urlopen(remote_url) as response, open(
            temp_path, "wb"
        ) as out_file:
            shutil.copyfileobj(response, out_file)

        # For testing: Artificially delay to simulate download time
        time.sleep(random.uniform(0.5, 2.0))

        log(f"Remote configuration downloaded to {temp_path}")

        # Save to multiple possible locations to ensure it can be found
        app_dir = get_application_directory()
        possible_locations = [
            os.path.join(app_dir, "temp_config.json"),
            os.path.join(os.path.dirname(app_dir), "temp_config.json"),
            os.path.join(os.path.dirname(os.path.dirname(app_dir)), "temp_config.json"),
        ]

        for location in possible_locations:
            try:
                directory = os.path.dirname(location)
                if not os.path.exists(directory):
                    os.makedirs(directory, exist_ok=True)

                shutil.copy2(temp_path, location)
                log(f"Copied configuration to {location}")
            except Exception as e:
                log(f"Could not copy to {location}: {e}")

        # For debugging purposes
        log(f"Current working directory: {os.getcwd()}")
        log(f"Application directory: {app_dir}")
        log(f"Script location: {os.path.abspath(__file__)}")

        # Don't remove the temporary file
        return temp_path

    except URLError as e:
        log(f"Error downloading remote configuration: {e}")
        return None
    except Exception as e:
        log(f"Unexpected error during remote configuration download: {e}")
        return None


def compare_versions(local_version, remote_version):
    """Compare two version strings."""
    if local_version == remote_version:
        return False

    local_parts = [int(x) for x in local_version.split(".")]
    remote_parts = [int(x) for x in remote_version.split(".")]

    # Pad with zeros to make them the same length
    while len(local_parts) < len(remote_parts):
        local_parts.append(0)
    while len(remote_parts) < len(local_parts):
        remote_parts.append(0)

    for lp, rp in zip(local_parts, remote_parts):
        if rp > lp:
            return True
        elif lp > rp:
            return False

    return False  # They are equal


def check_for_updates(mode="check"):
    """Check for updates and optionally apply them."""
    log("Starting update check...")
    app_dir = get_application_directory()
    local_config_path = os.path.join(app_dir, "configuration.json")

    # Load local configuration
    local_config = load_config(local_config_path)
    if not local_config:
        log("Failed to load local configuration")
        return EXIT_CODE_ERROR

    # Download remote configuration
    remote_config_path = download_remote_config()
    if not remote_config_path:
        log("Failed to download remote configuration")
        return EXIT_CODE_ERROR

    remote_config = load_config(remote_config_path)
    if not remote_config:
        log("Failed to load remote configuration")
        return EXIT_CODE_ERROR

    # Check if the application needs an update
    application_update_needed = False
    components_update_needed = False

    # Application update check
    if "application" in local_config and "application" in remote_config:
        local_app = local_config["application"]
        remote_app = remote_config["application"]

        if compare_versions(
            local_app.get("version", "0"), remote_app.get("version", "0")
        ):
            application_update_needed = True
            log(
                f"Application update available: {local_app.get('version', 'unknown')} -> {remote_app.get('version', 'unknown')}"
            )
        else:
            log("Application is up to date")

    # Components update check
    if "components" in local_config and "components" in remote_config:
        local_components = {
            component["name"]: component
            for component in local_config.get("components", [])
        }
        remote_components = {
            component["name"]: component
            for component in remote_config.get("components", [])
        }

        for name, remote_component in remote_components.items():
            if name in local_components:
                local_component = local_components[name]
                if compare_versions(
                    local_component.get("version", "0"),
                    remote_component.get("version", "0"),
                ):
                    components_update_needed = True
                    log(
                        f"Component '{name}' update available: {local_component.get('version', 'unknown')} -> {remote_component.get('version', 'unknown')}"
                    )
            else:
                log(
                    f"New component available: {name} ({remote_component.get('version', 'unknown')})"
                )
                components_update_needed = True

    # If application needs update, it requires a restart
    if application_update_needed:
        if mode == "apply":
            # Apply application update (would typically download and install the new version)
            log(
                "Application update requires restart. Please download the latest version manually."
            )
            return EXIT_CODE_RESTART_REQUIRED
        else:
            log("Application update available but not applied (check-only mode)")
            return EXIT_CODE_RESTART_REQUIRED

    # If components need updates
    if components_update_needed:
        if mode == "apply":
            # Apply component updates
            log("Applying component updates...")

            # Simulate update process
            time.sleep(random.uniform(1.0, 3.0))

            # Here we would actually download and install component updates
            # For each component that needs an update:
            # 1. Download the component from its URL
            # 2. Extract/install it to the target path

            # Update local configuration
            with open(local_config_path, "w") as f:
                # Update the local config with the remote component versions
                if "components" in local_config and "components" in remote_config:
                    local_components = {
                        component["name"]: component
                        for component in local_config.get("components", [])
                    }
                    remote_components = {
                        component["name"]: component
                        for component in remote_config.get("components", [])
                    }

                    for component in local_config["components"]:
                        name = component["name"]
                        if name in remote_components:
                            # Update version and other fields
                            component["version"] = remote_components[name]["version"]
                            if "releaseNotes" in remote_components[name]:
                                component["releaseNotes"] = remote_components[name][
                                    "releaseNotes"
                                ]
                            if "downloadUrl" in remote_components[name]:
                                component["downloadUrl"] = remote_components[name][
                                    "downloadUrl"
                                ]

                json.dump(local_config, f, indent=4)

            log("Component updates completed successfully")
            return EXIT_CODE_SUCCESS
        else:
            log("Component updates available but not applied (check-only mode)")
            return EXIT_CODE_SUCCESS

    log("No updates available")
    return EXIT_CODE_SUCCESS


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Update manager for FlowBook applications"
    )
    parser.add_argument(
        "mode",
        nargs="?",
        default="check",
        choices=["check", "apply"],
        help="Mode: check for updates only or apply updates",
    )

    # Special handling for older Qt integration which passes the arguments directly
    if len(sys.argv) > 1 and sys.argv[1] in ["check", "apply"]:
        mode = sys.argv[1]
    else:
        args = parser.parse_args()
        mode = args.mode

    log(f"Running in {mode} mode")
    exit_code = check_for_updates(mode)

    log(f"Finished with exit code: {exit_code}")
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
