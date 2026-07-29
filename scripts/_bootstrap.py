"""Ensure the runtime Python packages the FlowBook scripts need are
installed, so a fresh machine self-bootstraps on first run (needs the
internet once). Call ensure_runtime_deps() at the top of every entry
script BEFORE importing fitz / PIL / cv2 / numpy.

Only a Python interpreter has to pre-exist on the target machine; these
four packages are installed on demand.

After an install the script re-execs itself (see _restart_after_install).
Installing into the live interpreter leaves it in a mixed state: modules
imported before the install (numpy, say) stay resident at the old version
while the new files are already on disk, and the next import blows up with
errors that look nothing like the real cause -- e.g. installing whisperx
pulled a newer numpy and the run died on "cannot import name
'GenerationMixin' from 'transformers.generation'". A restart is the only
reliable fix; the same command then runs against a clean interpreter.
"""

import importlib
import os
import subprocess
import sys

# Set once before re-execing, so a package that fails to import even after a
# successful install can't put us in a restart loop.
_REEXEC_FLAG = "FLOWBOOK_DEPS_RESTARTED"

# import name -> pip package name
_DEPS = (
    ("fitz", "PyMuPDF"),
    ("PIL", "Pillow"),
    ("numpy", "numpy"),
    ("cv2", "opencv-python"),
)


def _install(pkg):
    """pip-install pkg. True if it succeeded (so the caller can restart)."""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", pkg])
        return True
    except Exception as e:
        print(f"  WARNING: could not install {pkg}: {e}", flush=True)
        return False


def _restart_after_install(progress=False):
    """Re-run this script from scratch so the fresh packages are the only
    ones loaded. Either way stdout/stderr stay the inherited pipes, so the
    caller keeps streaming our output and reads the same exit code."""
    if os.environ.get(_REEXEC_FLAG):
        return
    os.environ[_REEXEC_FLAG] = "1"
    prefix = "PROGRESS: " if progress else ""
    print(f"{prefix}Restarting with the new packages…", flush=True)
    # -u to keep stdout unbuffered, matching how the app launches us.
    argv = [sys.executable, "-u"] + sys.argv
    if os.name == "nt":
        # Windows execv would end this process and start a new one under a
        # different PID, which the app reads as "the script exited". Run the
        # restart as a child and mirror its exit code instead.
        sys.exit(subprocess.call(argv))
    # POSIX: same PID, so the app's cancel (which kills the process) still
    # reaches us after the restart.
    os.execv(sys.executable, argv)


def ensure_runtime_deps():
    installed = False
    for mod, pkg in _DEPS:
        try:
            importlib.import_module(mod)
        except ImportError:
            print(f"Installing {pkg} ...", flush=True)
            installed |= _install(pkg)
    if installed:
        _restart_after_install()


# Heavy, optional deps used only by the audio karaoke aligner. Kept out of
# ensure_runtime_deps() so plain crop/PDF scripts never pull torch.
_ALIGN_DEPS = (
    ("whisperx", "whisperx"),
)


def ensure_align_deps():
    installed = False
    for mod, pkg in _ALIGN_DEPS:
        try:
            importlib.import_module(mod)
        except ImportError:
            # PROGRESS: so the editor's karaoke status shows the install
            # instead of sitting on "Starting…" for the minutes pip takes
            # (it pulls torch, ~300MB).
            print(f"PROGRESS: Installing {pkg} — first run only, "
                  f"several minutes…", flush=True)
            print(f"Installing {pkg} (this is large, first run only) ...",
                  flush=True)
            installed |= _install(pkg)
    if installed:
        _restart_after_install(progress=True)
