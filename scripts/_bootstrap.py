"""Ensure the runtime Python packages the FlowBook scripts need are
installed, so a fresh machine self-bootstraps on first run (needs the
internet once). Call ensure_runtime_deps() at the top of every entry
script BEFORE importing fitz / PIL / cv2 / numpy.

Only a Python interpreter has to pre-exist on the target machine; these
four packages are installed on demand.
"""

import importlib
import subprocess
import sys

# import name -> pip package name
_DEPS = (
    ("fitz", "PyMuPDF"),
    ("PIL", "Pillow"),
    ("numpy", "numpy"),
    ("cv2", "opencv-python"),
)


def ensure_runtime_deps():
    for mod, pkg in _DEPS:
        try:
            importlib.import_module(mod)
        except ImportError:
            print(f"Installing {pkg} ...", flush=True)
            try:
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", pkg])
            except Exception as e:
                print(f"  WARNING: could not install {pkg}: {e}", flush=True)
