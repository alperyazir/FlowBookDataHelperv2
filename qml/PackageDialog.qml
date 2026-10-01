import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: packageDialog
    property string currentProject
    title: "Let's Package"
    modal: true
    closePolicy: Popup.NoAutoClose
    // Big enough for a book's checks and their file lists, never past the window.
    width: Math.min(820, (parent ? parent.width : 900) - 40)
    height: Math.min(900, (parent ? parent.height : 960) - 40)

    anchors.centerIn: parent

    // Three-step flow: 1 = pick books, 2 = title and publisher per book (with a
    // read-only pre-flight check), 3 = pick platforms.
    property int step: 1

    // Bumped while the book list and the book details show, so each re-queries
    // the PDF optimize status: compression runs detached, and its end is only
    // seen on disk. Book Details won't go on until both PDFs are optimized.
    property int statusTick: 0
    Timer {
        running: packageDialog.visible && packageDialog.step <= 2
        interval: 1500
        repeat: true
        onTriggered: packageDialog.statusTick++
    }

    // Books selected for this package — they all go under data/books/ together
    // (e.g. a paired Student Book + Workbook). Defaults to the open project.
    property var selectedBooks: []

    // Per-book details, keyed by project folder name:
    //   { check, title, publisherIndex, configPublisher, folder, titleError,
    //     titleWarnings, answered }
    // Packaging normalizes each book into book_export/<folder>/ and builds the
    // package from there. The folder comes from the title, so title and
    // publisher are required and set here, never read off the cover.
    // publisherIndex: into `publishers`, -1 until chosen.
    // answered: "" | "original" (no answer key) | path of a chosen PDF.
    property var bookInfo: ({})
    property bool checking: false

    // Project ▸ Export Book opens this dialog with exportOnly: books and
    // details only — normalize into book_export/ and stop, no platforms.
    property bool exportOnly: false

    // What publisher_name may be; "None" writes it empty. Spelled the way the
    // published books spell them (73 "Edulink" to 3 "EduLink").
    readonly property var publishers: ["Universal ELT", "Edulink", "None"]

    property var selectedOS: ({
                                  windows: false,
                                  linux: false,
                                  macos: false
                              })

    onOpened: {
        step = 1;
        selectedBooks = currentProject ? [currentProject] : [];
        bookInfo = ({});
        pendingChecks = [];
        checking = false;
    }

    // Book Details ▸ Optimize videos runs on the window's videoOptimizer
    // (main.qml): in the background, one book at a time, and it carries on if
    // this dialog closes. These mirror it for the cards below.
    readonly property string videoBook: videoOptimizer.book
    readonly property var videoProgress: videoOptimizer.progress
    readonly property bool videoStopping: videoOptimizer.stopping

    // The book's videos in one state ("sorunlu": won't play on Windows,
    // "okunamayan": can't be read), from its check.
    function videosIn(book, durum) {
        var all = (((info(book).check || {}).video || {}).videolar) || [];
        var out = [];
        for (var i = 0; i < all.length; i++)
            if (all[i].durum === durum)
                out.push(all[i]);
        return out;
    }

    function videoPending(book) {
        return videosIn(book, "sorunlu");
    }

    function videosReady(book) {
        var v = (info(book).check || {}).video;
        if (!v)
            return true;
        return !v.ffmpeg_yok && !v.okunamayan && !v.sorunlu && videoBook !== book;
    }

    function startVideoOptimize(book) {
        if (videoOptimizer.start(book))
            setInfo(book, { videoError: "" });
    }

    function stopVideoOptimize() {
        videoOptimizer.stop();
    }

    Connections {
        target: videoOptimizer
        function onFinished(book, r) {
            if (!packageDialog.visible || !packageDialog.bookInfo[book])
                return;
            var msgs = [];
            if (r.hata)
                msgs.push(r.hata);
            var failed = r.basarisiz || [];
            for (var i = 0; i < failed.length; i++)
                msgs.push(failed[i].dosya + ": " + failed[i].hata);
            // What is left to do comes from checking again, not from this run.
            packageDialog.setInfo(book, { videoError: msgs.join("\n"), rechecking: true, recheckKey: "video" });
            recheckTimer.book = book;
            recheckTimer.restart();
        }
    }

    // Book Details ▸ Optimize images: the book being worked on, "" when idle.
    // Fast (seconds), so no progress — just the button's text.
    property string imageBook: ""

    // The book's game/fill images in one state ("buyuk": over 750 px and
    // 1 MB, "okunamayan": can't be read), from its check.
    function imagesIn(book, durum) {
        var all = (((info(book).check || {}).gorsel || {}).gorseller) || [];
        var out = [];
        for (var i = 0; i < all.length; i++)
            if (all[i].durum === durum)
                out.push(all[i]);
        return out;
    }

    function startImageOptimize(book) {
        if (imageBook !== "")
            return;
        if (pdfProcess.optimizeImages(book)) {
            imageBook = book;
            setInfo(book, { imageError: "" });
        }
    }

    Connections {
        target: pdfProcess
        function onImagesOptimized(book, ok, json) {
            if (book !== packageDialog.imageBook)
                return;
            packageDialog.imageBook = "";
            var r;
            try {
                r = JSON.parse(json);
            } catch (e) {
                r = { hata: "" + e };
            }
            var msgs = [];
            if (r.hata)
                msgs.push(r.hata);
            var failed = r.basarisiz || [];
            for (var i = 0; i < failed.length; i++)
                msgs.push(failed[i].dosya + ": " + failed[i].hata);
            var done = r.kucultulen || [];
            var before = 0, after = 0;
            for (var j = 0; j < done.length; j++) {
                before += done[j].eski_mb;
                after += done[j].mb;
            }
            if (done.length)
                toast.show(done.length + " image(s) brought down to 750 px (" + book + "): "
                           + before.toFixed(1) + " MB → " + after.toFixed(1) + " MB");
            if (!packageDialog.bookInfo[book])
                return;
            // What is left comes from checking again, not from this run.
            packageDialog.setInfo(book, { imageError: msgs.join("\n"), rechecking: true, recheckKey: "images" });
            recheckTimer.book = book;
            recheckTimer.restart();
        }
    }

    // ---- PDFs: original.pdf and answered.pdf must be optimized first ----
    // "ready" | "inprogress" | "stale" | "none", re-read on every statusTick.
    function pdfState(book, kind) {
        statusTick;
        return kind === "answered" ? pdfProcess.answeredPdfStatus(book)
                                   : pdfProcess.originalPdfStatus(book);
    }

    function pdfsReady(book) {
        var o = pdfState(book, "original"), a = pdfState(book, "answered");
        return (o === "ready" || o === "none") && (a === "ready" || a === "none");
    }

    // ---- Audio: Book Details ▸ Optimize audio (scripts/audio_level.py) ----
    property string audioBook: ""        // "" when idle
    property var audioProgress: ({})     // {i, n, dosya}
    property bool audioStopping: false

    function audioIn(book, durum) {
        var all = (((info(book).check || {}).ses || {}).sesler) || [];
        var out = [];
        for (var i = 0; i < all.length; i++)
            if (all[i].durum === durum)
                out.push(all[i]);
        return out;
    }

    function startAudioOptimize(book) {
        if (audioBook !== "")
            return;
        // The open book lets go of a clip its audio panel may hold (Windows
        // won't replace an open file).
        if (book === currentProject && typeof sideBar !== "undefined")
            sideBar.audioVisible = false;
        if (pdfProcess.optimizeAudio(book)) {
            audioBook = book;
            audioProgress = ({});
            audioStopping = false;
            setInfo(book, { audioError: "" });
        }
    }

    Connections {
        target: pdfProcess
        function onAudioOptimizeProgress(book, json) {
            if (book !== packageDialog.audioBook)
                return;
            try {
                packageDialog.audioProgress = JSON.parse(json);
            } catch (e) {}
        }
        function onAudioOptimizeFinished(book, ok, json) {
            if (book !== packageDialog.audioBook)
                return;
            packageDialog.audioBook = "";
            packageDialog.audioProgress = ({});
            packageDialog.audioStopping = false;
            var r;
            try {
                r = JSON.parse(json);
            } catch (e) {
                r = { hata: "" + e };
            }
            var msgs = [];
            if (r.hata)
                msgs.push(r.hata);
            var failed = r.basarisiz || [];
            for (var i = 0; i < failed.length; i++)
                msgs.push(failed[i].dosya + ": " + failed[i].hata);
            var skipped = r.hizali_atlanan || [];
            for (var k = 0; k < skipped.length; k++)
                msgs.push(skipped[k] + ": left as it is — re-encoding would move its karaoke timings");
            var done = (r.normalize_edilen || []).length;
            if (done)
                toast.show(done + " audio file(s) brought to -16 LUFS (" + book + ")"
                           + (r.iptal ? " — stopped" : ""));
            if (!packageDialog.bookInfo[book])
                return;
            packageDialog.setInfo(book, { audioError: msgs.join("\n"), rechecking: true, recheckKey: "audio" });
            recheckTimer.book = book;
            recheckTimer.restart();
        }
    }

    function toggleBook(name) {
        var arr = selectedBooks.slice();
        var p = arr.indexOf(name);
        if (p === -1)
            arr.push(name);
        else
            arr.splice(p, 1);
        selectedBooks = arr;
    }

    function info(book) {
        return bookInfo[book] || ({});
    }

    function setInfo(book, patch) {
        var all = Object.assign({}, bookInfo);
        all[book] = Object.assign({}, all[book] || {}, patch);
        bookInfo = all;
    }

    // Runs the pre-flight check (nothing is written) for each selected book
    // not checked yet, and pre-fills title and publisher.
    // Books whose first check is still running (checkBookForPackageAsync):
    // the check measures every MP3 and probes every video, so it runs on a
    // worker thread and the dialog stays live meanwhile.
    property var pendingChecks: []

    function loadDetails() {
        var pending = [], ask = [];
        for (var i = 0; i < selectedBooks.length; i++) {
            var book = "" + selectedBooks[i];
            if (info(book).check)
                continue;                  // keep what was already typed
            pending.push(book);
            // Back and Next again while a check is out: wait for that one.
            if (pendingChecks.indexOf(book) === -1)
                ask.push(book);
        }
        pendingChecks = pending;
        checking = pending.length > 0;
        for (var j = 0; j < ask.length; j++)
            pdfProcess.checkBookForPackageAsync(ask[j]);
    }

    function applyCheck(book, json) {
        var check;
        try {
            check = JSON.parse(json);
        } catch (e) {
            check = { hata: "Could not check " + book + ": " + e };
        }
        var p = pendingChecks.indexOf(book);
        if (p === -1) {
            // A re-check after an Optimize: only the findings change.
            if (info(book).rechecking)
                setInfo(book, { check: check, rechecking: false });
            return;
        }
        // The open project may hold edits not saved yet; prefer those.
        var open = book === currentProject && config;
        var pub = (open && config.publisherName) ? config.publisherName : (check.publisher_name || "");
        setInfo(book, {
            check: check,
            title: (open && config.bookTitle) ? config.bookTitle : (check.book_title || ""),
            publisherIndex: publisherIndexOf(pub),
            configPublisher: pub,
            answered: ""
        });
        refreshFolder(book);
        var rest = pendingChecks.slice();
        rest.splice(p, 1);
        pendingChecks = rest;
        if (rest.length === 0)
            checking = false;
    }

    Connections {
        target: pdfProcess
        function onBookChecked(book, json) {
            if (packageDialog.visible)
                packageDialog.applyCheck(book, json);
        }
    }

    // The option a config value matches, ignoring case ("EduLink" is Edulink);
    // -1 for empty or anything else, so the author picks. Never "None": an
    // empty publisher_name is as likely unset as deliberate.
    function publisherIndexOf(name) {
        var n = ("" + name).trim().toLowerCase();
        for (var i = 0; i < publishers.length - 1; i++)
            if (publishers[i].toLowerCase() === n)
                return i;
        return -1;
    }

    function publisherValue(book) {
        var i = info(book).publisherIndex;
        return (i === undefined || i < 0 || i === publishers.length - 1) ? "" : publishers[i];
    }

    function fileUrl(path) {
        if (!path)
            return "";
        return "file://" + (path.charAt(0) === "/" ? "" : "/") + path;
    }

    function refreshFolder(book) {
        var d = info(book);
        if (!(d.title || "").trim()) {
            setInfo(book, { folder: "", titleError: "", titleWarnings: [] });
            return;
        }
        var r;
        try {
            r = JSON.parse(pdfProcess.packageFolderPreview(d.title, publisherValue(book)));
        } catch (e) {
            r = { hata: "" + e };
        }
        setInfo(book, { folder: r.klasor || "", titleError: r.hata || "",
                        titleWarnings: r.baslik_uyari || [] });
    }

    function bookReady(book) {
        var d = info(book);
        var c = d.check || {};
        return !!(d.check && !c.hata
                  && (d.title || "").trim() && d.publisherIndex >= 0
                  && d.folder && !d.titleError
                  && !(c.ref_kayip > 0) && !((c.kirik_detay || []).length > 0)
                  && c.original !== "yok" && !c.pypdf_uyari
                  && (c.answered !== "yok" || d.answered)
                  && videosReady(book) && !d.rechecking && imageBook !== book
                  && audioBook !== book && pdfsReady(book));
    }

    function duplicateFolder() {
        var seen = {};
        for (var i = 0; i < selectedBooks.length; i++) {
            var f = info("" + selectedBooks[i]).folder;
            if (!f)
                continue;
            if (seen[f])
                return f;
            seen[f] = true;
        }
        return "";
    }

    readonly property bool detailsReady: {
        bookInfo;
        videoBook;
        imageBook;
        audioBook;
        statusTick;
        if (checking || selectedBooks.length === 0)
            return false;
        for (var i = 0; i < selectedBooks.length; i++)
            if (!bookReady("" + selectedBooks[i]))
                return false;
        return duplicateFolder() === "";
    }

    // What the author should see before packaging: errors block, warnings and
    // notes don't.
    function notesFor(book) {
        var d = info(book);
        var c = d.check || {};
        var out = [];
        if (!d.check)
            return out;
        if (c.hata)
            out.push({ level: "error", text: c.hata });
        if (!(d.title || "").trim())
            out.push({ level: "error", text: "Book title is required." });
        if (!(d.publisherIndex >= 0))
            out.push({ level: "error", text: "Choose a publisher." });
        if (d.configPublisher && publisherIndexOf(d.configPublisher) < 0)
            out.push({ level: "info", text: "config.json has publisher \"" + d.configPublisher + "\"" });
        if (d.titleError)
            out.push({ level: "error", text: d.titleError });
        var tw = d.titleWarnings || [];
        for (var i = 0; i < tw.length; i++)
            out.push({ level: "warn", text: "Title: " + tw[i] });
        // Every broken path on its own line, with module and page.
        var broken = c.kirik_detay || [];
        if (c.ref_kayip > 0 || broken.length > 0) {
            out.push({ level: "error", text: (broken.length || c.ref_kayip)
                       + " path(s) in config.json point at files that don't exist — fix them before packaging:" });
            for (var b = 0; b < broken.length; b++)
                out.push({ level: "error", detail: true, text: broken[b].metin });
        }
        if (c.ref_onarilabilir > 0)
            out.push({ level: "info", text: c.ref_onarilabilir + " broken path(s) will be repaired" });
        if (c.original === "yok")
            out.push({ level: "error", text: "raw/ has no original PDF" });
        if (c.pypdf_uyari)
            out.push({ level: "error", text: c.pypdf_uyari });
        if (c.referanssiz_gorsel > 0)
            out.push({ level: "info", text: c.referanssiz_gorsel + " image(s) in images/ that nothing uses will be left out"
                                            + ((c.referanssiz_ornek || []).length ? " (e.g. " + c.referanssiz_ornek[0] + ")" : "") });
        if ((c.pdf_kopya || []).length)
            out.push({ level: "info", text: "Duplicate PDF(s) removed from the export: " + c.pdf_kopya.join(", ") });
        if (c.sayfa_uyari)
            out.push({ level: "warn", text: c.sayfa_uyari });
        if (c.bozuk_metin > 0)
            out.push({ level: "warn", text: c.bozuk_metin + " corrupt text value(s) in config.json will be cleaned" });
        if (c.logo_uyari)
            out.push({ level: "warn", text: c.logo_uyari });
        return out;
    }

    // ---- Checks: one row per topic (PDFs, audio, images, videos) ----
    // Which rows are open, by "<book>/<key>": kept here, not in the row,
    // because the rows are rebuilt on every progress tick.
    property var openChecks: ({})
    function toggleCheck(book, key) {
        var o = Object.assign({}, openChecks);
        o[book + "/" + key] = !o[book + "/" + key];
        openChecks = o;
    }

    function mb(bytes) {
        return (bytes / 1048576).toFixed(1) + " MB";
    }

    // Each row: {key, title, state ("ok" | "warn" | "error" | "running"),
    // summary, details: [{text, level}], action ("" for none), stoppable,
    // progress (0-1, or -1 for none), error}. State "error" holds Next back.
    function mediaChecks(book) {
        var d = info(book);
        var c = d.check || {};
        var rows = [];
        if (!d.check || c.hata)
            return rows;
        var again = d.rechecking ? d.recheckKey : "";

        // PDFs — a must.
        var po = pdfState(book, "original"), pa = pdfState(book, "answered");
        var pdf = { key: "pdf", title: "PDFs", details: [], action: "", stoppable: false,
                    progress: -1, error: "" };
        var oi = pdfProcess.originalPdfInfo(book);
        var kinds = [["original.pdf", po], ["answered.pdf", pa]];
        for (var k = 0; k < kinds.length; k++) {
            if (kinds[k][1] === "none")
                continue;
            var label = kinds[k][1] === "ready" ? "optimized" : kinds[k][1] === "inprogress"
                        ? "optimizing…" : "not optimized";
            if (k === 0 && po === "ready" && oi.original > 0 && oi.compressed > 0)
                label += " (" + mb(oi.original) + " → " + mb(oi.compressed) + ")";
            pdf.details.push({ text: kinds[k][0] + " — " + label,
                               level: kinds[k][1] === "stale" ? "error" : "info" });
        }
        if (po === "inprogress" || pa === "inprogress") {
            pdf.state = "running";
            pdf.summary = "Optimizing… a minute or two on a big book";
        } else if (po === "stale" || pa === "stale") {
            pdf.state = "error";
            pdf.summary = "Must be optimized before packaging";
            pdf.action = "Optimize";
        } else {
            pdf.state = "ok";
            pdf.summary = (pa === "none" ? "original.pdf" : "original.pdf and answered.pdf") + " optimized";
        }
        rows.push(pdf);

        // Audio — -16 LUFS; a warning.
        var s = c.ses;
        if (s && s.toplam) {
            var au = { key: "audio", title: "Audio", details: [], action: "", stoppable: false,
                       progress: -1, error: d.audioError || "" };
            var quiet = audioIn(book, "duzeltilecek"), badAu = audioIn(book, "okunamayan");
            for (var q = 0; q < quiet.length; q++)
                au.details.push({ level: "warn", text: quiet[q].dosya + " — " + quiet[q].i + " LUFS, peak "
                                  + quiet[q].tp + " dBTP → " + (quiet[q].gain > 0 ? "+" : "") + quiet[q].gain + " dB" });
            for (var ba = 0; ba < badAu.length; ba++)
                au.details.push({ level: "warn", text: badAu[ba].dosya + " — can't be read: " + badAu[ba].hata });
            if (audioBook === book) {
                var ap = audioProgress;
                au.state = "running";
                au.summary = ap.n > 0 ? "Leveling " + (ap.i + 1) + " of " + ap.n + " · " + (ap.dosya || "")
                                      : "Measuring…";
                au.progress = ap.n > 0 ? ap.i / ap.n : 0;
                au.stoppable = true;
            } else if (again === "audio") {
                au.state = "running";
                au.summary = "Checking again…";
            } else if (s.ffmpeg_yok) {
                au.state = "warn";
                au.summary = "Can't check " + s.toplam + " file(s): ffmpeg isn't installed (Help ▸ Dependencies)";
            } else if (quiet.length) {
                au.state = "warn";
                au.summary = quiet.length + " of " + s.toplam + " file(s) too quiet — off " + s.hedef + " LUFS";
                au.action = "Optimize";
            } else if (badAu.length) {
                au.state = "warn";
                au.summary = badAu.length + " file(s) can't be read";
            } else {
                au.state = "ok";
                au.summary = s.toplam + " file(s) at " + s.hedef + " LUFS";
            }
            rows.push(au);
        }

        // Game/fill images — a warning.
        var g = c.gorsel;
        if (g && g.toplam) {
            var im = { key: "images", title: "Images", details: [], action: "", stoppable: false,
                       progress: -1, error: d.imageError || "" };
            var big = imagesIn(book, "buyuk"), badImg = imagesIn(book, "okunamayan");
            for (var gi = 0; gi < big.length; gi++)
                im.details.push({ level: "warn", text: big[gi].dosya + " — " + big[gi].w + "×" + big[gi].h
                                  + ", " + big[gi].mb + " MB" });
            for (var bi = 0; bi < badImg.length; bi++)
                im.details.push({ level: "warn", text: badImg[bi].dosya + " — can't be read: " + badImg[bi].hata });
            if (imageBook === book) {
                im.state = "running";
                im.summary = "Resizing to " + g.limit + " px…";
            } else if (again === "images") {
                im.state = "running";
                im.summary = "Checking again…";
            } else if (g.pillow_yok) {
                im.state = "warn";
                im.summary = "Can't check: Pillow isn't installed (Help ▸ Dependencies)";
            } else if (big.length) {
                im.state = "warn";
                im.summary = big.length + " of " + g.toplam + " game/fill image(s) far bigger than "
                             + g.limit + " px";
                im.action = "Optimize";
            } else if (badImg.length) {
                im.state = "warn";
                im.summary = badImg.length + " image(s) can't be read";
            } else {
                im.state = "ok";
                im.summary = g.toplam + " game/fill image(s) sized for the reader";
            }
            rows.push(im);
        }

        // Videos — must play on Windows.
        var v = c.video;
        if (v && v.toplam) {
            var vi = { key: "video", title: "Videos", details: [], action: "", stoppable: false,
                       progress: -1, error: d.videoError || "" };
            var pend = videoPending(book), badV = videosIn(book, "okunamayan");
            for (var p = 0; p < pend.length; p++)
                vi.details.push({ level: "error", text: pend[p].dosya + " — " + pend[p].sorun });
            for (var u = 0; u < badV.length; u++)
                vi.details.push({ level: "error", text: badV[u].dosya + " — can't be read: " + badV[u].hata });
            if (videoBook === book) {
                var vp = videoProgress;
                vi.state = "running";
                vi.progress = vp.n > 0 ? (vp.i + vp.pct / 100) / vp.n : 0;
                vi.summary = vp.n > 0 ? "Converting " + (vp.i + 1) + " of " + vp.n + " · "
                                        + (vp.dosya || "") + " " + (vp.pct || 0) + "%"
                                      : "Checking the videos…";
                vi.stoppable = true;
            } else if (again === "video") {
                vi.state = "running";
                vi.summary = "Checking again…";
            } else if (v.ffmpeg_yok) {
                vi.state = "error";
                vi.summary = "Can't check " + v.toplam + " video(s): ffmpeg isn't installed (Help ▸ Dependencies)";
            } else if (badV.length) {
                vi.state = "error";
                vi.summary = badV.length + " video(s) can't be read — replace them";
            } else if (pend.length) {
                vi.state = "error";
                vi.summary = pend.length + " of " + v.toplam + " video(s) won't play on Windows";
                vi.action = "Optimize";
            } else {
                vi.state = "ok";
                vi.summary = v.toplam + " video(s) play on Windows";
            }
            rows.push(vi);
        }
        return rows;
    }

    function runCheck(book, key) {
        if (key === "pdf") {
            pdfProcess.ensurePdfsCompressed(book);
            statusTick++;
        } else if (key === "audio") {
            startAudioOptimize(book);
        } else if (key === "images") {
            startImageOptimize(book);
        } else if (key === "video") {
            startVideoOptimize(book);
        }
    }

    function stopCheck(key) {
        if (key === "audio") {
            audioStopping = true;
            pdfProcess.cancelAudioOptimize();
        } else if (key === "video") {
            stopVideoOptimize();
        }
    }

    function folderList() {
        var out = [];
        for (var i = 0; i < selectedBooks.length; i++)
            out.push(info("" + selectedBooks[i]).folder || selectedBooks[i]);
        return out;
    }

    function doPackage() {
        var platforms = [];
        if (selectedOS.windows)
            platforms.push("windows");
        if (selectedOS.linux)
            platforms.push("linux");
        if (selectedOS.macos)
            platforms.push("macos");

        if (packageDialog.selectedBooks.length === 0 || platforms.length === 0)
            return;

        pdfProcess.packageForPlatforms(platforms, collectBooks());
        flowProgress.reset();
        flowProgress.statusText = "Packaging is Processing...";
        flowProgress.addLogMessage("Packaging: " + folderList().join(" + "));
        flowProgress.open();
        packageDialog.close();
    }

    function doExport() {
        if (packageDialog.selectedBooks.length === 0)
            return;

        pdfProcess.exportBooks(collectBooks());
        flowProgress.reset();
        flowProgress.statusText = "Exporting…";
        flowProgress.addLogMessage("Export: " + folderList().join(" + "));
        flowProgress.open();
        packageDialog.close();
    }

    // The books as plain objects of strings (a `var` property holding a JS
    // array can marshal oddly). An empty publisher is "None".
    function collectBooks() {
        var books = [];
        for (var i = 0; i < packageDialog.selectedBooks.length; i++) {
            var name = "" + packageDialog.selectedBooks[i];
            var d = info(name);
            var title = d.title.trim();
            var publisher = publisherValue(name);
            books.push({ book: name, title: title, publisher: publisher,
                         answered: "" + (d.answered || "") });
            // Both write these back to the project's config.json; keep the
            // open project's in-memory copy in step so the next save doesn't
            // put the old values back.
            if (name === currentProject && config) {
                config.bookTitle = title;
                config.publisherName = publisher;
            }
        }
        return books;
    }

    // Gives "Checking books…" a frame to show before the checks start.
    Timer {
        id: checkTimer
        interval: 50
        onTriggered: packageDialog.loadDetails()
    }

    // After an Optimize: the book's check again (in the background), so its
    // rows show what is left.
    Timer {
        id: recheckTimer
        property string book
        interval: 50
        onTriggered: pdfProcess.checkBookForPackageAsync(book)
    }

    // Title/publisher edits re-derive the folder preview once typing pauses.
    Timer {
        id: folderTimer
        interval: 400
        onTriggered: {
            for (var i = 0; i < packageDialog.selectedBooks.length; i++)
                packageDialog.refreshFolder("" + packageDialog.selectedBooks[i]);
        }
    }

    FileDialog {
        id: answeredDialog
        property string targetBook
        title: "Choose the answered PDF"
        nameFilters: ["PDF files (*.pdf)"]
        onAccepted: {
            // file:///Users/x -> /Users/x, file:///C:/x -> C:/x
            var p = decodeURIComponent(selectedFile.toString().replace(/^file:\/\/\/?/, ""));
            if (!/^[A-Za-z]:/.test(p))
                p = "/" + p;
            packageDialog.setInfo(targetBook, { answered: p });
        }
    }

    // main.qml's Escape shortcut steps aside while the cover is open.
    readonly property bool coverOpen: coverPopup.visible

    // The cover at full size, over everything; × or Escape closes it.
    Popup {
        id: coverPopup
        property url source
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: parent ? parent.width * 0.8 : 600
        height: parent ? parent.height * 0.9 : 800
        modal: true
        // Not CloseOnEscape: the modal dialog behind holds the focus, and a
        // window Shortcut gets the key first anyway — the Shortcut below closes it.
        closePolicy: Popup.CloseOnPressOutside
        padding: 8
        background: Rectangle {
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1
            radius: 4
        }
        contentItem: Item {
            Image {
                anchors.fill: parent
                source: coverPopup.visible ? coverPopup.source : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Rectangle {
                width: 38; height: 38
                radius: 19
                color: coverCloseMouse.containsMouse ? "#ff3b6b" : "#1A2327"
                border.color: "#00e6e6"
                border.width: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                }

                MouseArea {
                    id: coverCloseMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: coverPopup.close()
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: coverPopup.visible
                onActivated: coverPopup.close()
            }
        }
    }

    header: Rectangle {
        color: "#1A2327"
        height: 40
        border.color: "#009ca6"
        border.width: 1
        Label {
            text: (packageDialog.exportOnly ? "Export" : "Package") + " · Step "
                  + packageDialog.step + ": "
                  + (packageDialog.step === 1 ? "Books"
                     : packageDialog.step === 2 ? "Book Details" : "Platforms")
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            font.pixelSize: 16
            font.bold: true
        }
    }

    footer: Rectangle {
        color: "#1A2327"
        height: 60
        border.color: "#009ca6"
        border.width: 1
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Button {
                text: "Cancel"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: packageDialog.reject()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Back"
                visible: packageDialog.step > 1
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: packageDialog.step = packageDialog.step - 1
            }

            Button {
                text: "Next"
                visible: packageDialog.step < (packageDialog.exportOnly ? 2 : 3)
                enabled: packageDialog.step === 1 ? packageDialog.selectedBooks.length > 0
                                                  : packageDialog.detailsReady
                Layout.preferredWidth: 100
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: !parent.enabled ? "#2a3338" : (parent.hovered ? "#00b3be" : "#009ca6")
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : "#6b7a80"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (packageDialog.step === 1) {
                        packageDialog.step = 2;
                        packageDialog.checking = true;
                        checkTimer.restart();
                    } else {
                        packageDialog.step = 3;
                    }
                }
            }

            Button {
                text: packageDialog.exportOnly ? "Export" : "Package"
                visible: packageDialog.step === (packageDialog.exportOnly ? 2 : 3)
                enabled: !packageDialog.exportOnly || packageDialog.detailsReady
                Layout.preferredWidth: 100
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: !parent.enabled ? "#2a3338" : (parent.hovered ? "#00b3be" : "#009ca6")
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text; color: parent.enabled ? "white" : "#6b7a80"; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (packageDialog.exportOnly)
                        packageDialog.doExport();
                    else
                        packageDialog.doPackage();
                }
            }
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 4
    }

    // ---------- Step 1: books ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        visible: packageDialog.step === 1

        Label {
            text: "Select Books"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "white"
        }
        Text {
            Layout.fillWidth: true
            text: packageDialog.exportOnly
                  ? "Pick the book(s) to export into book_export/."
                  : "Pick one book for a single package, or two for a paired set "
                    + "(both go under books/ together)."
            color: "#8aa0a8"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.width: 1
            border.color: "#009ca6"
            radius: 4

            ListView {
                id: bookList
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 2
                model: config ? config.recentProject : []
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: bookRow
                    required property var modelData
                    readonly property bool sel: packageDialog.selectedBooks.indexOf(modelData) !== -1
                    // Optimize status; statusTick forces a refresh.
                    readonly property string pdfStatus: {
                        packageDialog.statusTick;
                        return pdfProcess.originalPdfStatus(bookRow.modelData);
                    }
                    width: ListView.view ? ListView.view.width : 0
                    height: 34
                    radius: 4
                    color: bookRow.sel ? "#15323a" : (bookMouse.containsMouse ? "#1c2a31" : "transparent")

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        width: parent.width - pkgBadge.width - 24
                        spacing: 10
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: bookRow.sel ? "#00e6e6" : "#232f34"
                            border.color: "#009ca6"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#10343a"
                                font.pixelSize: 12
                                font.bold: true
                                visible: bookRow.sel
                            }
                        }
                        Text {
                            text: bookRow.modelData
                            color: "white"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: bookMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: packageDialog.toggleBook(bookRow.modelData)
                    }

                    // Informational: warns when this book's original.pdf hasn't
                    // been optimized (Project ▸ Optimize). Empty when ready/none.
                    Text {
                        id: pkgBadge
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 11
                        text: bookRow.pdfStatus === "stale" ? "⚠ not optimized"
                            : bookRow.pdfStatus === "inprogress" ? "optimizing…"
                            : ""
                        color: bookRow.pdfStatus === "inprogress" ? "#e0a32e" : "#d08770"
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: packageDialog.selectedBooks.length > 0
                  ? (packageDialog.exportOnly ? "Export: " : "Package: ")
                    + packageDialog.selectedBooks.join(" + ")
                  : "No books selected"
            color: packageDialog.selectedBooks.length > 0 ? "#4fd2dc" : "#5e7178"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    // ---------- Step 2: book details ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        visible: packageDialog.step === 2

        Label {
            text: "Book Details"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "white"
        }
        // While the checks run (on a worker thread): a turning ring in the
        // middle of the space the cards will take.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: packageDialog.checking
            Column {
                anchors.centerIn: parent
                spacing: 14
                Canvas {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34
                    height: 34
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.lineWidth = 3;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = "#2c3c44";
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2 - 3, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.strokeStyle = "#4fd2dc";
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2 - 3, 0, Math.PI * 0.6);
                        ctx.stroke();
                    }
                    RotationAnimator on rotation {
                        running: packageDialog.checking && packageDialog.visible
                        from: 0; to: 360; duration: 900
                        loops: Animation.Infinite
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Checking " + (packageDialog.pendingChecks.length > 1
                                         ? packageDialog.pendingChecks.length + " books" : "the book") + "…"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Measuring the audio and probing the videos — a few seconds the first time"
                    color: "#8aa0a8"
                    font.pixelSize: 12
                }
            }
        }

        // A plain Flickable sized by the laid-out column: the ScrollView here
        // never picked up the cards' height, so a tall card just got cut off.
        Flickable {
            id: detailsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: detailsColumn.height
            boundsBehavior: Flickable.StopAtBounds
            visible: !packageDialog.checking
            // Not interactive: a mouse drag selects text in the notes instead of
            // dragging the list. The wheel/trackpad (below) and the bar scroll it.
            interactive: false

            ScrollBar.vertical: ScrollBar {
                id: detailsBar
                // Shown the whole time there is more to see, in the theme's
                // colour: Fusion's own bar is a faint grey that only turns up
                // while scrolling.
                policy: detailsScroll.contentHeight > detailsScroll.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                width: 10
                padding: 1
                contentItem: Rectangle {
                    implicitWidth: 8
                    implicitHeight: 40
                    radius: 4
                    color: detailsBar.pressed ? "#00e6e6"
                         : (detailsBar.hovered ? "#00b3be" : "#009ca6")
                }
                background: Rectangle {
                    implicitWidth: 10
                    radius: 5
                    color: "#1c2a31"
                }
            }

            // The wheel, the way GamesDialog's lists take it: a MouseArea over
            // the content that accepts no buttons, so clicks and text selection
            // still reach the fields underneath. A WheelHandler here never saw
            // a real wheel on macOS.
            MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    var dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 3;
                    detailsScroll.contentY = Math.max(0, Math.min(
                        detailsScroll.contentHeight - detailsScroll.height,
                        detailsScroll.contentY - dy));
                }
            }

            ColumnLayout {
                id: detailsColumn
                width: detailsScroll.width - 12     // room for the scroll bar
                spacing: 10

                Repeater {
                    model: packageDialog.step === 2 ? packageDialog.selectedBooks : []

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property string book: "" + modelData
                        readonly property var d: {
                            packageDialog.bookInfo;
                            return packageDialog.info(card.book);
                        }
                        readonly property var c: card.d.check || ({})
                        readonly property bool ready: {
                            packageDialog.bookInfo;
                            packageDialog.videoBook;
                            return packageDialog.bookReady(card.book);
                        }
                        Layout.fillWidth: true
                        implicitHeight: cardCol.implicitHeight + 24
                        color: "#1c2a31"
                        radius: 4
                        border.width: 1
                        border.color: card.ready ? "#009ca6" : "#d08770"

                        ColumnLayout {
                            id: cardCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 6

                            // The cover the book uses, on top; click for a full-size look.
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 200
                                color: "#232f34"
                                radius: 3
                                border.width: 1
                                border.color: coverMouse.containsMouse ? "#00e6e6" : "#33505b"

                                Image {
                                    id: coverThumb
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: packageDialog.fileUrl(card.c.kapak_yolu)
                                    sourceSize.height: 400
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: coverThumb.status !== Image.Ready
                                    text: coverThumb.status === Image.Loading ? "…" : "No cover"
                                    color: "#5e7178"
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    id: coverMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: coverThumb.status === Image.Ready
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        coverPopup.source = packageDialog.fileUrl(card.c.kapak_yolu);
                                        coverPopup.open();
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.book
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text { text: "Book title *"; color: "#8aa0a8"; font.pixelSize: 11 }
                            TextField {
                                id: titleField
                                Layout.fillWidth: true
                                text: card.d.title || ""
                                placeholderText: "e.g. My English Path 1 Student's Book"
                                placeholderTextColor: "#5e7178"
                                color: "white"
                                selectByMouse: true
                                background: Rectangle {
                                    color: "#232f34"
                                    radius: 2
                                    border.width: 1
                                    border.color: titleField.activeFocus ? "#00e6e6" : "#009ca6"
                                }
                                onTextEdited: {
                                    packageDialog.setInfo(card.book, { title: text });
                                    folderTimer.restart();
                                }
                            }

                            Text { text: "Publisher *"; color: "#8aa0a8"; font.pixelSize: 11 }
                            ComboBox {
                                id: publisherBox
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                model: packageDialog.publishers
                                currentIndex: card.d.publisherIndex === undefined ? -1 : card.d.publisherIndex
                                displayText: currentIndex < 0 ? "Choose a publisher…" : currentText
                                onActivated: function(index) {
                                    packageDialog.setInfo(card.book, { publisherIndex: index });
                                    folderTimer.restart();
                                }

                                background: Rectangle {
                                    color: "#232f34"
                                    border.color: publisherBox.activeFocus ? "#00e6e6" : "#009ca6"
                                    border.width: 1
                                    radius: 2
                                }

                                contentItem: Text {
                                    text: publisherBox.displayText
                                    color: publisherBox.currentIndex < 0 ? "#5e7178" : "white"
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 10
                                    elide: Text.ElideRight
                                }

                                popup: Popup {
                                    y: publisherBox.height
                                    width: publisherBox.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: publisherBox.popup.visible ? publisherBox.delegateModel : null

                                        ScrollIndicator.vertical: ScrollIndicator {}
                                    }

                                    background: Rectangle {
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 1
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: publisherBox.width
                                    contentItem: Text {
                                        // textAt, not modelData: the card's own
                                        // required modelData is in scope here.
                                        text: publisherBox.textAt(index)
                                        color: "white"
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    highlighted: publisherBox.highlightedIndex === index
                                    background: Rectangle {
                                        color: highlighted ? "#2A3337" : "#1A2327"
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: !!card.d.folder
                                text: "Folder:  book_export/" + (card.d.folder || "")
                                color: "#4fd2dc"
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                            }

                            Repeater {
                                model: {
                                    packageDialog.bookInfo;
                                    return packageDialog.notesFor(card.book);
                                }
                                // Selectable, so a path can be copied straight
                                // out of the dialog.
                                delegate: TextEdit {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    readOnly: true
                                    selectByMouse: true
                                    selectionColor: "#00707a"
                                    selectedTextColor: "white"
                                    textFormat: TextEdit.PlainText
                                    wrapMode: TextEdit.Wrap
                                    font.pixelSize: 12
                                    leftPadding: modelData.detail ? 22 : 0
                                    text: (modelData.detail ? "" : modelData.level === "error" ? "✖  "
                                           : modelData.level === "warn" ? "⚠  " : "•  ") + modelData.text
                                    color: modelData.level === "error" ? "#e06c75"
                                         : modelData.level === "warn" ? "#e0a32e" : "#8aa0a8"
                                }
                            }

                            // Checks: one row per topic, a click opens its files.
                            Text {
                                Layout.topMargin: 6
                                visible: checksCol.count > 0
                                text: "CHECKS"
                                color: "#5e7178"
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1
                            }
                            ColumnLayout {
                                id: checksBox
                                Layout.fillWidth: true
                                spacing: 4
                                // The rows themselves, re-read on every tick and progress
                                // line. The Repeater's model is only the list of topics
                                // (a string, so an unchanged list is no change): rows
                                // are built once and update in place, keeping an open
                                // file list, its selection and the hover.
                                readonly property var checks: {
                                    packageDialog.bookInfo;
                                    packageDialog.statusTick;
                                    packageDialog.audioProgress;
                                    packageDialog.videoProgress;
                                    packageDialog.audioBook;
                                    packageDialog.imageBook;
                                    packageDialog.videoBook;
                                    return packageDialog.mediaChecks(card.book);
                                }
                                readonly property string checkKeys: checks.map(function(r) { return r.key; }).join(",")
                                Repeater {
                                    id: checksCol
                                    model: checksBox.checkKeys ? checksBox.checkKeys.split(",") : []
                                    delegate: Rectangle {
                                        id: checkRow
                                        required property int index
                                        readonly property var r: checksBox.checks[index]
                                            || ({ key: "", title: "", state: "ok", summary: "", details: [],
                                                  action: "", stoppable: false, progress: -1, error: "" })
                                        readonly property bool expanded: !!packageDialog.openChecks[card.book + "/" + r.key]
                                        readonly property bool hasDetails: r.details.length > 0 || !!r.error
                                        readonly property color tone: r.state === "ok" ? "#4fbf8a"
                                                                    : r.state === "warn" ? "#e0a32e"
                                                                    : r.state === "error" ? "#e06c75" : "#4fd2dc"
                                        Layout.fillWidth: true
                                        implicitHeight: rowCol.implicitHeight
                                        radius: 4
                                        color: rowMouse.containsMouse && checkRow.hasDetails ? "#253740" : "#212f36"
                                        border.width: 1
                                        border.color: r.state === "error" ? "#5a3236" : "#2c3c44"

                                        // A thin bar in the row's own colour, on the left.
                                        Rectangle {
                                            width: 3
                                            height: parent.height - 8
                                            anchors.left: parent.left
                                            anchors.leftMargin: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: 1.5
                                            color: checkRow.tone
                                        }

                                        ColumnLayout {
                                            id: rowCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            spacing: 0

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 40
                                                MouseArea {
                                                    id: rowMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: checkRow.hasDetails ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: if (checkRow.hasDetails)
                                                                   packageDialog.toggleCheck(card.book, checkRow.r.key)
                                                }
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 16
                                                    anchors.rightMargin: 8
                                                    spacing: 10
                                                    Item {
                                                        Layout.preferredWidth: 16
                                                        Layout.preferredHeight: 16
                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: checkRow.r.state !== "running"
                                                            text: checkRow.r.state === "ok" ? "✓"
                                                                : checkRow.r.state === "warn" ? "!" : "✖"
                                                            color: checkRow.tone
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                        }
                                                        // Running: a three-quarter ring turning.
                                                        Canvas {
                                                            anchors.fill: parent
                                                            visible: checkRow.r.state === "running"
                                                            onPaint: {
                                                                var ctx = getContext("2d");
                                                                ctx.reset();
                                                                ctx.lineWidth = 2;
                                                                ctx.strokeStyle = "#4fd2dc";
                                                                ctx.beginPath();
                                                                ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 1.5);
                                                                ctx.stroke();
                                                            }
                                                            RotationAnimator on rotation {
                                                                running: checkRow.r.state === "running"
                                                                from: 0; to: 360; duration: 900
                                                                loops: Animation.Infinite
                                                            }
                                                        }
                                                    }
                                                    Text {
                                                        text: checkRow.r.title
                                                        color: "white"
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        Layout.preferredWidth: 58
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: checkRow.r.summary
                                                        color: checkRow.r.state === "ok" ? "#8aa0a8" : checkRow.tone
                                                        font.pixelSize: 12
                                                        elide: Text.ElideMiddle
                                                    }
                                                    Text {
                                                        visible: checkRow.hasDetails
                                                        text: "›"
                                                        color: rowMouse.containsMouse ? "white" : "#8aa0a8"
                                                        font.pixelSize: 20
                                                        Layout.preferredWidth: 14
                                                        horizontalAlignment: Text.AlignHCenter
                                                        rotation: checkRow.expanded ? 90 : 0
                                                        Behavior on rotation { NumberAnimation { duration: 120 } }
                                                    }
                                                    Button {
                                                        id: checkBtn
                                                        visible: checkRow.r.action !== "" || checkRow.r.stoppable
                                                        readonly property bool stop: checkRow.r.stoppable
                                                        enabled: stop ? !(checkRow.r.key === "audio" ? packageDialog.audioStopping
                                                                                                    : packageDialog.videoStopping)
                                                                      : !card.d.rechecking
                                                        text: stop ? "Stop" : checkRow.r.action
                                                        Layout.preferredHeight: 28
                                                        Layout.preferredWidth: 84
                                                        background: Rectangle {
                                                            radius: 3
                                                            color: checkBtn.stop ? (checkBtn.hovered ? "#2A3337" : "#1A2327")
                                                                 : !checkBtn.enabled ? "#2a3338"
                                                                 : (checkBtn.hovered ? "#00b3be" : "#009ca6")
                                                            border.width: checkBtn.stop ? 1 : 0
                                                            border.color: "#009ca6"
                                                        }
                                                        contentItem: Text {
                                                            text: checkBtn.text
                                                            font.pixelSize: 12
                                                            font.bold: !checkBtn.stop
                                                            color: checkBtn.enabled ? "white" : "#6b7a80"
                                                            horizontalAlignment: Text.AlignHCenter
                                                            verticalAlignment: Text.AlignVCenter
                                                        }
                                                        onClicked: checkBtn.stop ? packageDialog.stopCheck(checkRow.r.key)
                                                                                 : packageDialog.runCheck(card.book, checkRow.r.key)
                                                    }
                                                }
                                            }

                                            // Progress, flush with the row's bottom edge.
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 16
                                                Layout.rightMargin: 8
                                                Layout.bottomMargin: 6
                                                Layout.preferredHeight: 3
                                                visible: checkRow.r.progress >= 0
                                                radius: 1.5
                                                color: "#1A2327"
                                                Rectangle {
                                                    width: parent.width * Math.max(0, Math.min(1, checkRow.r.progress))
                                                    height: parent.height
                                                    radius: 1.5
                                                    color: "#009ca6"
                                                }
                                            }

                                            // The files, selectable so a path can be copied.
                                            TextEdit {
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 40
                                                Layout.rightMargin: 10
                                                Layout.bottomMargin: 8
                                                visible: checkRow.expanded && checkRow.hasDetails
                                                readOnly: true
                                                selectByMouse: true
                                                selectionColor: "#00707a"
                                                selectedTextColor: "white"
                                                textFormat: TextEdit.RichText
                                                wrapMode: TextEdit.Wrap
                                                font.pixelSize: 12
                                                text: {
                                                    function esc(t) {
                                                        return ("" + t).replace(/&/g, "&amp;").replace(/</g, "&lt;");
                                                    }
                                                    var lines = [];
                                                    if (checkRow.r.error)
                                                        lines.push("<span style='color:#e06c75'>✖ " + esc(checkRow.r.error).replace(/\n/g, "<br>✖ ") + "</span>");
                                                    for (var i = 0; i < checkRow.r.details.length; i++) {
                                                        var dl = checkRow.r.details[i];
                                                        var col = dl.level === "error" ? "#e06c75" : dl.level === "warn" ? "#c9a25a" : "#8aa0a8";
                                                        // "file — what": the file quiet, the finding in the row's colour.
                                                        var cut = dl.text.indexOf(" — ");
                                                        lines.push(cut < 0 ? "<span style='color:" + col + "'>" + esc(dl.text) + "</span>"
                                                                   : "<span style='color:#b8c7cc'>" + esc(dl.text.slice(0, cut))
                                                                     + "</span><span style='color:#5e7178'>  ·  </span><span style='color:"
                                                                     + col + "'>" + esc(dl.text.slice(cut + 3)) + "</span>");
                                                    }
                                                    return lines.join("<br>");
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Every package ships an answered.pdf; a book without
                            // one needs the author to say where it comes from.
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: card.c.answered === "yok"
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 12
                                    color: card.d.answered ? "#8aa0a8" : "#e0a32e"
                                    text: "raw/ has no answered PDF. Choose it, or confirm this book has no answer key:"
                                }
                                RowLayout {
                                    spacing: 8
                                    Button {
                                        id: pickBtn
                                        readonly property bool selected: !!card.d.answered && card.d.answered !== "original"
                                        text: "Choose answered PDF…"
                                        Layout.preferredHeight: 30
                                        background: Rectangle {
                                            radius: 2
                                            color: pickBtn.selected ? "#15323a" : (pickBtn.hovered ? "#2A3337" : "#1A2327")
                                            border.width: 1
                                            border.color: pickBtn.selected ? "#00e6e6" : "#009ca6"
                                        }
                                        contentItem: Text {
                                            text: pickBtn.text; color: "white"; font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: {
                                            answeredDialog.targetBook = card.book;
                                            answeredDialog.open();
                                        }
                                    }
                                    Button {
                                        id: noKeyBtn
                                        readonly property bool selected: card.d.answered === "original"
                                        text: "No answer key — copy original"
                                        Layout.preferredHeight: 30
                                        background: Rectangle {
                                            radius: 2
                                            color: noKeyBtn.selected ? "#15323a" : (noKeyBtn.hovered ? "#2A3337" : "#1A2327")
                                            border.width: 1
                                            border.color: noKeyBtn.selected ? "#00e6e6" : "#009ca6"
                                        }
                                        contentItem: Text {
                                            text: noKeyBtn.text; color: "white"; font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: packageDialog.setInfo(card.book, { answered: "original" })
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: pickBtn.selected
                                    text: "answered.pdf ← " + (card.d.answered || "")
                                    color: "#4fd2dc"
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    readonly property string dup: {
                        packageDialog.bookInfo;
                        return packageDialog.duplicateFolder();
                    }
                    visible: dup !== ""
                    text: "✖  Two books would both export to book_export/" + dup
                          + " — give them different titles."
                    color: "#e06c75"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // ---------- Step 3: platforms ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        visible: packageDialog.step === 3

        Label {
            text: "Select Platforms"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "white"
        }
        Text {
            Layout.fillWidth: true
            text: {
                packageDialog.bookInfo;
                return "Package: " + packageDialog.folderList().join(" + ");
            }
            color: "#4fd2dc"
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.width: 1
            border.color: "#009ca6"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                CheckBox {
                    id: windowsCheck
                    text: "Windows"
                    checked: selectedOS.windows
                    onCheckedChanged: selectedOS.windows = checked
                    indicator: Rectangle {
                        width: 18; height: 18; radius: 4
                        color: windowsCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 5
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right; anchors.leftMargin: 10
                    }
                }
                CheckBox {
                    id: linuxCheck
                    text: "Linux"
                    checked: selectedOS.linux
                    onCheckedChanged: selectedOS.linux = checked
                    indicator: Rectangle {
                        width: 18; height: 18; radius: 4
                        color: linuxCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 5
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right; anchors.leftMargin: 10
                    }
                }
                CheckBox {
                    id: macosCheck
                    text: "MacOS"
                    checked: selectedOS.macos
                    onCheckedChanged: selectedOS.macos = checked
                    indicator: Rectangle {
                        width: 18; height: 18; radius: 4
                        color: macosCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 5
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right; anchors.leftMargin: 10
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
