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
import zipfile
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

        # Get script directory and go one level up
        script_dir = os.path.dirname(os.path.abspath(__file__))
        parent_dir = os.path.dirname(script_dir)
        config_location = os.path.join(parent_dir, "temp_config.json")

        try:
            shutil.copy2(temp_path, config_location)
            log(f"Copied configuration to {config_location}")
        except Exception as e:
            log(f"Could not copy to {config_location}: {e}")
            return None

        # For debugging purposes
        log(f"Current working directory: {os.getcwd()}")
        log(f"Script directory: {script_dir}")
        log(f"Parent directory: {parent_dir}")

        # Don't remove the temporary file
        return config_location

    except URLError as e:
        log(f"Error downloading remote configuration: {e}")
        return None
    except Exception as e:
        log(f"Unexpected error during remote configuration download: {e}")
        return None


def download_file(url, target_path):
    """Download a file from URL."""
    log(f"Downloading from {url} to {target_path}")
    try:
        with urllib.request.urlopen(url) as response, open(
            target_path, "wb"
        ) as out_file:
            total_size = int(response.info().get("Content-Length", 0))
            downloaded = 0
            block_size = 8192

            while True:
                buffer = response.read(block_size)
                if not buffer:
                    break

                downloaded += len(buffer)
                out_file.write(buffer)

                # Calculate and log progress
                if total_size > 0:
                    percent = downloaded * 100 / total_size
                    log(
                        f"Download progress: {percent:.1f}% ({downloaded}/{total_size} bytes)"
                    )
                else:
                    log(f"Downloaded {downloaded} bytes")

        log(f"Download completed: {target_path}")
        return True
    except Exception as e:
        log(f"Download error: {str(e)}")
        return False


def extract_zip(zip_path, extract_path):
    """Extract zip file to specified path."""
    log(f"Extracting {zip_path} to {extract_path}")
    try:
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            total_files = len(zip_ref.namelist())
            log(f"Zip contains {total_files} files")

            for i, file in enumerate(zip_ref.namelist(), 1):
                if i % 5 == 0 or i == total_files:  # Log every 5 files or the last file
                    log(f"Extracting file {i}/{total_files}: {file}")

            zip_ref.extractall(extract_path)

        log(f"Successfully extracted {zip_path} to {extract_path}")
        return True
    except Exception as e:
        log(f"Extraction error: {str(e)}")
        return False


def update_component(component, app_dir, is_main_app=False):
    """Update a component."""
    name = component.get("name", "Unknown")
    version = component.get("version", "Unknown")
    download_url = component.get("downloadUrl", "")
    file_name = component.get("fileName", f"{name}.zip")
    target_path = component.get("targetPath", "")

    log(f"Updating component: {name} to version {version}")

    # Determine download and extraction paths
    download_path = os.path.join(app_dir, file_name)

    # Special case for FlowBookTest - extract to test folder
    if name == "FlowBookTest":
        extract_path = os.path.join(app_dir, "test")
        if not os.path.exists(extract_path):
            os.makedirs(extract_path, exist_ok=True)
    else:
        extract_path = os.path.join(app_dir, target_path) if target_path else app_dir

    # Download the file
    if not download_file(download_url, download_path):
        log(f"Failed to download {name}")
        return False

    # For main application, just return the path to the zip
    if is_main_app:
        log(f"Main application zip downloaded to {download_path}")
        return download_path

    # For other components, extract them now
    if not os.path.exists(extract_path):
        os.makedirs(extract_path, exist_ok=True)

    if not extract_zip(download_path, extract_path):
        log(f"Failed to extract {name}")
        return False

    # Remove downloaded zip
    try:
        os.remove(download_path)
        log(f"Removed downloaded zip: {download_path}")
    except Exception as e:
        log(f"Could not remove zip file: {str(e)}")

    log(f"Component {name} updated successfully")
    return True


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


def create_update_script(main_app_zip, app_dir):
    """Create a batch/shell script to finish the update after app exit."""
    if platform.system() == "Windows":
        script_path = os.path.join(app_dir, "_update_helper.bat")

        # Get the executable name - assuming it's the only .exe in the app_dir
        exe_files = [f for f in os.listdir(app_dir) if f.endswith(".exe")]
        if not exe_files:
            log("No .exe file found in app directory")
            return None

        exe_name = exe_files[0]
        log(f"Found executable: {exe_name}")

        with open(script_path, "w") as f:
            f.write("@echo off\n")
            f.write("echo Updating application...\n")
            f.write("timeout /t 2 >nul\n")  # Give time for the app to fully close
            f.write(f'del "{os.path.join(app_dir, exe_name)}"\n')
            f.write(f"echo Extracting update...\n")
            # Use PowerShell to extract the zip (more reliable than batch)
            f.write(
                f"powershell -command \"Expand-Archive -Path '{main_app_zip}' -DestinationPath '{app_dir}' -Force\"\n"
            )
            f.write(f'del "{main_app_zip}"\n')
            f.write(f"echo Starting updated application...\n")
            f.write(f'start "" "{os.path.join(app_dir, exe_name)}"\n')
            f.write("exit\n")
    else:
        # For macOS or Linux
        script_path = os.path.join(app_dir, "_update_helper.sh")
        with open(script_path, "w") as f:
            f.write("#!/bin/bash\n")
            f.write('echo "Updating application..."\n')
            f.write("sleep 2\n")  # Give time for the app to fully close
            f.write(f"rm -f \"{os.path.join(app_dir, 'FlowBookDataHelper2')}\"\n")
            f.write(f'echo "Extracting update..."\n')
            f.write(f'unzip -o "{main_app_zip}" -d "{app_dir}"\n')
            f.write(f'rm -f "{main_app_zip}"\n')
            f.write(f'echo "Starting updated application..."\n')
            f.write(f"\"{os.path.join(app_dir, 'FlowBookDataHelper2')}\" &\n")
            f.write("exit 0\n")
        os.chmod(script_path, 0o755)  # Make executable

    log(f"Created update helper script: {script_path}")
    return script_path


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
    main_app_update_needed = False
    components_to_update = []

    # Application update check
    main_app_component = None
    if "application" in local_config and "application" in remote_config:
        local_app = local_config["application"]
        remote_app = remote_config["application"]

        if compare_versions(
            local_app.get("version", "0"), remote_app.get("version", "0")
        ):
            main_app_update_needed = True
            main_app_component = remote_app
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
                    components_to_update.append(remote_component)
                    log(
                        f"Component '{name}' update available: {local_component.get('version', 'unknown')} -> {remote_component.get('version', 'unknown')}"
                    )
            else:
                components_to_update.append(remote_component)
                log(
                    f"New component available: {name} ({remote_component.get('version', 'unknown')})"
                )

    # If only checking for updates, return information
    if mode == "check":
        if main_app_update_needed or components_to_update:
            log("Updates are available")
            return EXIT_CODE_SUCCESS
        else:
            log("No updates available")
            return EXIT_CODE_SUCCESS

    # If applying updates
    if mode == "apply":
        # First update components
        for component in components_to_update:
            if component["name"] != "FlowBookDataHelper":  # Don't update main app yet
                log(f"Updating component: {component['name']}")
                success = update_component(component, app_dir)
                if not success:
                    log(f"Failed to update component: {component['name']}")

        # Update local configuration with component versions
        if components_to_update:
            try:
                updated_config = local_config.copy()

                # Update component versions
                if "components" in updated_config:
                    for i, component in enumerate(updated_config["components"]):
                        for remote_component in components_to_update:
                            if component["name"] == remote_component["name"]:
                                updated_config["components"][i]["version"] = (
                                    remote_component["version"]
                                )
                                if "releaseNotes" in remote_component:
                                    updated_config["components"][i]["releaseNotes"] = (
                                        remote_component["releaseNotes"]
                                    )

                # Write updated config
                with open(local_config_path, "w") as f:
                    json.dump(updated_config, f, indent=4)

                log("Updated local configuration with new component versions")
            except Exception as e:
                log(f"Error updating local configuration: {str(e)}")

        # Finally, if main app needs update
        if main_app_update_needed and main_app_component:
            log("Preparing to update main application...")
            main_app_zip = update_component(
                main_app_component, app_dir, is_main_app=True
            )

            if main_app_zip and os.path.exists(main_app_zip):
                # Create helper script to complete update after app exits
                update_script = create_update_script(main_app_zip, app_dir)

                if update_script:
                    log("Main application update prepared, restart required.")

                    # On Windows, start the update script
                    if platform.system() == "Windows":
                        try:
                            subprocess.Popen(f'start "" "{update_script}"', shell=True)
                            log("Update helper script launched")
                        except Exception as e:
                            log(f"Failed to launch update helper: {str(e)}")

                    return EXIT_CODE_RESTART_REQUIRED
                else:
                    log("Failed to create update script")
                    return EXIT_CODE_ERROR
            else:
                log("Failed to download main application update")
                return EXIT_CODE_ERROR

        log("Update process completed successfully")
        return EXIT_CODE_SUCCESS

    log("Unknown mode specified")
    return EXIT_CODE_ERROR


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
