"""Report / install the Python runtime dependencies the FlowBook scripts need.

Usage:
  deps.py check               -> prints "DEPS_JSON: {...}" then "OK"
  deps.py install <pkg>...    -> pip-installs each package, then "OK"

The dependency list is reused from _bootstrap so there is one source of truth.
ffmpeg is reported too (whisperx needs it) but cannot be pip-installed.
"""
import sys
import os
import json
import shutil
import subprocess
import importlib.util

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import _DEPS, _ALIGN_DEPS


def _augment_path():
    if os.name == "nt":
        extra = [os.path.dirname(sys.executable),
                 os.path.join(os.path.dirname(sys.executable), "ffmpeg", "bin")]
    else:
        extra = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
    parts = os.environ.get("PATH", "").split(os.pathsep)
    for p in extra:
        if p and p not in parts:
            parts.append(p)
    os.environ["PATH"] = os.pathsep.join(parts)


def _is_installed(mod):
    try:
        return importlib.util.find_spec(mod) is not None
    except Exception:
        return False


def _version(pkg):
    try:
        from importlib.metadata import version
        return version(pkg)
    except Exception:
        return None


def check():
    _augment_path()
    deps = []
    for mod, pkg in (list(_DEPS) + list(_ALIGN_DEPS)):
        ok = _is_installed(mod)
        deps.append({
            "name": pkg,
            "module": mod,
            "pkg": pkg,
            "installed": ok,
            "version": _version(pkg) if ok else None,
            "heavy": pkg == "whisperx",   # pulls torch; large download
        })
    ff = shutil.which("ffmpeg")
    out = {
        "python": {"executable": sys.executable,
                   "version": sys.version.split()[0]},
        "deps": deps,
        "ffmpeg": {"name": "ffmpeg", "installed": bool(ff), "path": ff},
    }
    print("DEPS_JSON: " + json.dumps(out), flush=True)
    print("OK", flush=True)


def install(pkgs):
    if not pkgs:
        print("OK", flush=True)
        return
    for pkg in pkgs:
        print("Installing %s ..." % pkg, flush=True)
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", pkg])
        except Exception as e:
            print("ERROR: failed to install %s: %s" % (pkg, e), flush=True)
            sys.exit(1)
    print("OK", flush=True)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode == "install":
        install(sys.argv[2:])
    else:
        check()
