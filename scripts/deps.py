"""Report / install the Python runtime dependencies the FlowBook scripts need.

Usage:
  deps.py check               -> prints "DEPS_JSON: {...}" then "OK"
  deps.py install <pkg>...    -> pip-installs each package, then "OK"

The dependency list is reused from _bootstrap so there is one source of truth.
ffmpeg is reported too (whisperx needs it). It isn't a normal pip package, but
passing the pseudo-name "ffmpeg" to install pulls the "imageio-ffmpeg" wheel
(a bundled static build) and places its binary as a plain `ffmpeg` on PATH.
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


def _install_ffmpeg():
    """Install a usable `ffmpeg` binary via the imageio-ffmpeg wheel.

    ffmpeg isn't on PyPI itself, but imageio-ffmpeg ships a self-contained
    static build. We install the wheel, ask it for the binary path, then copy
    that binary under the plain name `ffmpeg`(.exe) into a directory that is on
    PATH for our scripts (next to the interpreter, which _augment_path adds, or
    a standard bin dir on Unix) so whisperx and shutil.which() can find it.
    """
    print("Installing ffmpeg (imageio-ffmpeg static build) ...", flush=True)
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "imageio-ffmpeg"])
        import imageio_ffmpeg
        src = imageio_ffmpeg.get_ffmpeg_exe()
    except Exception as e:
        print("ERROR: failed to install ffmpeg: %s" % e, flush=True)
        sys.exit(1)

    is_win = os.name == "nt"
    dest_name = "ffmpeg.exe" if is_win else "ffmpeg"
    if is_win:
        candidates = [os.path.dirname(sys.executable)]
    else:
        candidates = ["/usr/local/bin", "/opt/homebrew/bin",
                      os.path.dirname(sys.executable)]

    placed = None
    for d in candidates:
        try:
            os.makedirs(d, exist_ok=True)
            dest = os.path.join(d, dest_name)
            shutil.copy2(src, dest)
            if not is_win:
                os.chmod(dest, 0o755)
            placed = dest
            break
        except Exception:
            continue

    if not placed:
        print("ERROR: installed imageio-ffmpeg but could not place ffmpeg on "
              "PATH (binary is at %s)" % src, flush=True)
        sys.exit(1)
    print("ffmpeg ready at %s" % placed, flush=True)


def install(pkgs):
    if not pkgs:
        print("OK", flush=True)
        return
    for pkg in pkgs:
        if pkg == "ffmpeg":
            _install_ffmpeg()
            continue
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
