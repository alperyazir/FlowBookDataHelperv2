"""Report / install the Python runtime dependencies the FlowBook scripts need.

Usage:
  deps.py check               -> prints "DEPS_JSON: {...}" then "OK"
  deps.py install <pkg>...    -> pip-installs each package, then "OK"

The dependency list is reused from _bootstrap so there is one source of truth.
ffmpeg is reported too (whisperx needs it). It isn't a normal pip package, but
passing the pseudo-name "ffmpeg" to install pulls the "imageio-ffmpeg" wheel
(a bundled static build) and places its binary as a plain `ffmpeg` on PATH.

tesseract is reported as well, and is the one entry here that is OPTIONAL: it is
only ever run for a passage the PDF draws as a picture instead of text (see
passage_ocr), which across the six books measured so far was one page in a
hundred. Everything works without it; the dialog says so rather than showing a
red cross, and "Install missing" leaves it alone — there is no wheel to install,
it is a program the machine has to have.
"""
import sys
import os
import json
import shutil
import subprocess
import tempfile
import importlib.util

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import _DEPS, _ALIGN_DEPS
# tessdata_dir()/installed_langs() are asked of passage_ocr rather than repeated
# here, so the dialog that installs a language pack and the aligner that reads
# it can never disagree about where it went.
import passage_ocr

# The languages the editor offers when a project is created (NewProjectDialog),
# in tesseract's codes. Only these are offered for download -- a list of all 133
# would be a worse dialog, and a book cannot be in a language the editor cannot
# be told about.
EDITOR_LANGS = {"en": "eng", "tr": "tur", "de": "deu", "es": "spa"}

TESSDATA_URL = ("https://raw.githubusercontent.com/tesseract-ocr/"
                "tessdata_fast/main/{code}.traineddata")
TESSERACT_RELEASES = "https://api.github.com/repos/UB-Mannheim/tesseract/releases/latest"
TESSERACT_PAGE = "https://github.com/UB-Mannheim/tesseract/wiki"


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
    # Asked of passage_ocr rather than looked up here, so the dialog and the
    # aligner can never disagree about whether this machine has tesseract. The
    # fallback that used to guard this import is gone: the two files ship in the
    # same resource, and a fallback that can only fire when one of them is
    # missing is a second answer nobody would ever get to compare.
    tess = passage_ocr._binary()
    hint = passage_ocr.INSTALL_HINT
    # Which of the editor's languages this machine can actually OCR. A tesseract
    # that is installed but has only English is the case that used to fail
    # silently -- the run returned no words at all and said nothing about why.
    have = passage_ocr.installed_langs() if tess else set()
    langs = [{"lang": lang, "code": code, "installed": code in have}
             for lang, code in sorted(EDITOR_LANGS.items())]
    out = {
        "python": {"executable": sys.executable,
                   "version": sys.version.split()[0]},
        "deps": deps,
        "ffmpeg": {"name": "ffmpeg", "installed": bool(ff), "path": ff},
        "tesseract": {"name": "tesseract", "installed": bool(tess),
                      "path": tess, "optional": True, "hint": hint,
                      "langs": langs, "tessdata_dir": passage_ocr.tessdata_dir()},
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


def _download(url, dest, label):
    """Stream a file down with progress lines. urllib, so no new dependency."""
    import urllib.request
    print(f"{label} indiriliyor…", flush=True)
    req = urllib.request.Request(url, headers={"User-Agent": "FlowBookDataHelper"})
    tmp = dest + ".part"
    with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        done = 0
        step = max(1, total // 20) if total else 1 << 20
        nxt = step
        while True:
            chunk = r.read(1 << 16)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if done >= nxt:
                nxt += step
                pct = f" ({done * 100 // total}%)" if total else ""
                print(f"  {done / 1e6:.1f} MB{pct}", flush=True)
    os.replace(tmp, dest)
    print(f"{label} indi ({os.path.getsize(dest) / 1e6:.1f} MB).", flush=True)


def _install_tessdata(code):
    """Put <code>.traineddata where passage_ocr will look for it.

    Deliberately NOT into the tesseract installation: on Windows that is under
    Program Files and writing there needs an elevation prompt. Our own directory
    needs none, and --tessdata-dir makes tesseract read from it."""
    d = passage_ocr.tessdata_dir()
    os.makedirs(d, exist_ok=True)
    dest = os.path.join(d, f"{code}.traineddata")
    try:
        _download(TESSDATA_URL.format(code=code), dest, f"{code} dil paketi")
    except Exception as e:
        print(f"ERROR: {code} dil paketi indirilemedi: {e}", flush=True)
        sys.exit(1)


# Starting the installer. subprocess -- i.e. CreateProcess -- cannot do it: the
# installer's manifest asks for "highestAvailable", and on a machine where this
# user is a local administrator that means the process has to be elevated.
# CreateProcess does not raise the consent dialog for that, it fails outright
# with ERROR_ELEVATION_REQUIRED (740). No installer window, no UAC prompt, and
# an install that reported itself failed a second after it was asked for.
# ShellExecuteEx is the call that reads the manifest and prompts, and
# SEE_MASK_NOCLOSEPROCESS makes it hand back a handle to the process it started,
# so the wait afterwards is on the installer itself.
_SEE_MASK_NOCLOSEPROCESS = 0x00000040
_SW_SHOWNORMAL = 1
_ERROR_CANCELLED = 1223
_WAIT_OBJECT_0 = 0


def _start_elevated(path):
    """Open `path` the way a double-click would, prompting if it needs to.

    Returns a process handle to wait on, or None after saying why not.

    No verb is passed rather than "runas": the manifest is what decides. Forcing
    "runas" would demand an administrator password on a machine where this user
    is not one, when that install could have gone into their own profile without
    anybody being asked."""
    import ctypes
    from ctypes import wintypes

    class SHELLEXECUTEINFOW(ctypes.Structure):
        _fields_ = [("cbSize", wintypes.DWORD),
                    ("fMask", ctypes.c_ulong),
                    ("hwnd", wintypes.HWND),
                    ("lpVerb", wintypes.LPCWSTR),
                    ("lpFile", wintypes.LPCWSTR),
                    ("lpParameters", wintypes.LPCWSTR),
                    ("lpDirectory", wintypes.LPCWSTR),
                    ("nShow", ctypes.c_int),
                    ("hInstApp", wintypes.HINSTANCE),
                    ("lpIDList", ctypes.c_void_p),
                    ("lpClass", wintypes.LPCWSTR),
                    ("hkeyClass", wintypes.HKEY),
                    ("dwHotKey", wintypes.DWORD),
                    ("hIcon", wintypes.HANDLE),
                    ("hProcess", wintypes.HANDLE)]

    info = SHELLEXECUTEINFOW()
    info.cbSize = ctypes.sizeof(info)
    info.fMask = _SEE_MASK_NOCLOSEPROCESS
    info.lpFile = path
    info.nShow = _SW_SHOWNORMAL

    shell32 = ctypes.WinDLL("shell32", use_last_error=True)
    shell32.ShellExecuteExW.argtypes = [ctypes.POINTER(SHELLEXECUTEINFOW)]
    shell32.ShellExecuteExW.restype = wintypes.BOOL
    if not shell32.ShellExecuteExW(ctypes.byref(info)):
        err = ctypes.get_last_error()
        if err == _ERROR_CANCELLED:
            print("ERROR: yonetici izni verilmedi — kurulum baslatilamadi. "
                  "Tekrar deneyip UAC penceresinde 'Evet' secin.", flush=True)
        else:
            print(f"ERROR: kurulum baslatilamadi (WinError {err}). "
                  f"Elle kurun: {TESSERACT_PAGE}", flush=True)
        return None
    if not info.hProcess:
        # SEE_MASK_NOCLOSEPROCESS always yields a handle for an .exe; if this
        # ever fires there is nothing to wait on, and hanging the dialog for ten
        # minutes on a running installer we cannot observe is worse than saying
        # so. The installer stays open either way.
        print("ERROR: kurulum baslatildi ama izlenemiyor. Kurulumu bitirip bu "
              "pencereyi kapatin ve tekrar acin.", flush=True)
        return None
    return info.hProcess


def _exited(handle):
    """Has the process behind this handle finished?"""
    import ctypes
    from ctypes import wintypes
    k32 = ctypes.windll.kernel32
    k32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    k32.WaitForSingleObject.restype = wintypes.DWORD
    return k32.WaitForSingleObject(wintypes.HANDLE(handle), 0) == _WAIT_OBJECT_0


def _close_handle(handle):
    import ctypes
    from ctypes import wintypes
    k32 = ctypes.windll.kernel32
    k32.CloseHandle.argtypes = [wintypes.HANDLE]
    k32.CloseHandle(wintypes.HANDLE(handle))


# How long to keep looking after the installer is gone. It writes the binary
# before it exits, so the usual case is answered on the same pass; this covers
# an antivirus holding the new file shut for a moment. Longer would only make a
# cancelled install sit on the dialog.
_GONE_GRACE = 10


def _await_binary(timeout_s, proc=None):
    """Wait until tesseract shows up, or until waiting stops making sense.

    _binary() caches its answer on the function, so the cache is dropped before
    every look — otherwise this would ask the same stale "no" over and over.

    `proc` is a handle to the installer. Once it has exited and the binary still
    is not there, the user closed or cancelled it and there is nothing left to
    wait for; without that check a cancelled install would hold the dialog for
    the whole timeout."""
    import time
    waited = 0
    gone_for = 0
    while waited < timeout_s:
        if hasattr(passage_ocr._binary, "_cached"):
            del passage_ocr._binary._cached
        found = passage_ocr._binary()
        if found:
            print(f"tesseract hazir: {found}", flush=True)
            return True
        if proc is not None and _exited(proc):
            gone_for += 2
            if gone_for >= _GONE_GRACE:
                return False
        if waited and waited % 30 == 0:
            print(f"  kurulum bekleniyor… ({waited // 60}:{waited % 60:02d})",
                  flush=True)
        time.sleep(2)
        waited += 2
    return False


def _install_tesseract():
    """Get the tesseract binary onto this machine, the way the platform does it.

    There is no pip route: the trick that installs ffmpeg -- a wheel with a
    static binary inside (imageio-ffmpeg) -- has no counterpart here. The PyPI
    package called "tesseract" is an astrophysics library, nothing to do with
    OCR. So each platform is handed to the thing that installs software on it.

    On Windows the installer is downloaded and RUN, not run silently: its
    language-selection page is the one the user actually needs (the default
    install is English only), it raises its own elevation prompt, and we are not
    betting on the silent flags of somebody else's installer."""
    if os.name == "nt":
        import json as _json
        import urllib.request
        print("En son tesseract surumu araniyor…", flush=True)
        try:
            req = urllib.request.Request(
                TESSERACT_RELEASES, headers={"User-Agent": "FlowBookDataHelper"})
            with urllib.request.urlopen(req, timeout=30) as r:
                rel = _json.load(r)
            asset = next(a for a in rel.get("assets", [])
                         if "w64-setup" in a["name"] and a["name"].endswith(".exe"))
        except Exception as e:
            print(f"ERROR: kurulum dosyasi bulunamadi ({e}). "
                  f"Elle kurun: {TESSERACT_PAGE}", flush=True)
            sys.exit(1)
        dest = os.path.join(tempfile.gettempdir(), asset["name"])
        # A 50MB download the machine already has is worth not doing again: a
        # failed install is retried from this dialog, and the retry used to
        # start by fetching the same bytes a second time.
        want = int(asset.get("size") or 0)
        if want and os.path.exists(dest) and os.path.getsize(dest) == want:
            print(f"{asset['name']} zaten indirilmis.", flush=True)
        else:
            try:
                _download(asset["browser_download_url"], dest, asset["name"])
            except Exception as e:
                print(f"ERROR: indirilemedi ({e}). Elle kurun: {TESSERACT_PAGE}",
                      flush=True)
                sys.exit(1)
        if os.path.getsize(dest) < 1 << 20:
            print("ERROR: indirilen dosya bozuk gorunuyor. "
                  f"Elle kurun: {TESSERACT_PAGE}", flush=True)
            sys.exit(1)
        print("Kurulum penceresi aciliyor — Windows yonetici izni soracak. "
              "'Additional language data' adiminda Almanca/Turkce/Ispanyolca'yi "
              "da secebilirsiniz.", flush=True)
        proc = _start_elevated(dest)
        if proc is None:
            sys.exit(1)          # _start_elevated already said why
        # Waiting is on the handle ShellExecuteEx handed back, which is the
        # elevated installer itself. The old code waited on subprocess.call and
        # then looked once: that call returns the moment the unelevated stub
        # exits, long before the user has seen the first page, so a successful
        # install read as "not installed" every time.
        try:
            if not _await_binary(600, proc=proc):
                print("Kurulum tamamlanmadi. Kurulumu bitirdiyseniz bu pencereyi "
                      "kapatip tekrar acin.", flush=True)
                sys.exit(1)
        finally:
            _close_handle(proc)
        return
    elif sys.platform == "darwin":
        if not shutil.which("brew"):
            print(f"ERROR: Homebrew yok. Kurun ya da tesseract'i elle kurun: "
                  f"{TESSERACT_PAGE}", flush=True)
            sys.exit(1)
        print("brew install tesseract …", flush=True)
        if subprocess.call(["brew", "install", "tesseract"]) != 0:
            print("ERROR: brew ile kurulamadi.", flush=True)
            sys.exit(1)
    else:
        print("ERROR: bu platformda paket yoneticinizden kurun "
              "(ornegin: sudo apt install tesseract-ocr)", flush=True)
        sys.exit(1)
    # brew and apt really are done when they exit, so a single look is enough.
    if not _await_binary(4):
        print("Kurulum bitti ama tesseract bulunamadi — pencereyi kapatip "
              "tekrar acin.", flush=True)
        sys.exit(1)


def install(pkgs):
    if not pkgs:
        print("OK", flush=True)
        return
    for pkg in pkgs:
        if pkg == "ffmpeg":
            _install_ffmpeg()
            continue
        if pkg == "tesseract":
            _install_tesseract()
            continue
        if pkg.startswith("tessdata:"):
            _install_tessdata(pkg.split(":", 1)[1])
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
