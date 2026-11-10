#!/usr/bin/env python3
"""AD FINEM Stream Kit - installer for Linux and macOS.

Started by install-linux.sh (Linux) or INSTALL-mac.command (macOS). Safe to run again: your settings.js is kept.
  1. checks for OBS Studio (Linux: native, Flatpak or Snap - macOS: OBS.app)
  2. copies the kit to ~/Documents/AD FINEM Stream Kit
  3. adds the "AD FINEM" scene collection to OBS, using Linux / macOS capture sources
  4. adds an "AD FINEM - Customize overlays" launcher (Linux: app menu, macOS: Desktop)
"""
import datetime
import uuid
import json
import os
import shutil
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
MAC = sys.platform == "darwin"
SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORANGE, GREEN, YELLOW, RED, DIM, END = "\033[38;5;208m", "\033[32m", "\033[33m", "\033[31m", "\033[90m", "\033[0m"
if not sys.stdout.isatty():
    ORANGE = GREEN = YELLOW = RED = DIM = END = ""

# Where OBS keeps its settings: native, Flatpak, Snap.
OBS_CONFIGS = [
    os.path.join((os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")), "obs-studio"),
    os.path.join(HOME, ".var", "app", "com.obsproject.Studio", "config", "obs-studio"),
    os.path.join(HOME, "snap", "obs-studio", "current", ".config", "obs-studio"),
]
if MAC:
    OBS_CONFIGS = [os.path.join(HOME, "Library", "Application Support", "obs-studio")]


def say(text, color=""):
    print(f"{color}{text}{END}")


def step(n, text):
    print(f"\n{ORANGE}[{n}] {text}{END}")


def ask(question):
    if not sys.stdin.isatty():
        return False
    try:
        return input(f"    {question} (y/n) ").strip().lower().startswith(("y", "j"))
    except EOFError:
        return False


def documents_dir():
    if MAC:
        return os.path.join(HOME, "Documents")
    try:
        d = subprocess.run(["xdg-user-dir", "DOCUMENTS"], capture_output=True, text=True, timeout=5).stdout.strip()
        if d and d != HOME and os.path.isdir(d):
            return d
    except Exception:
        pass
    d = os.path.join(HOME, "Documents")
    return d if os.path.isdir(d) else HOME


def have(cmd):
    return shutil.which(cmd) is not None


def flatpak_has_obs():
    if not have("flatpak"):
        return False
    r = subprocess.run(["flatpak", "info", "com.obsproject.Studio"], capture_output=True)
    return r.returncode == 0


def obs_running():
    if not have("pgrep"):
        return False
    if MAC:   # the app's process is called "OBS"
        return subprocess.run(["pgrep", "-ix", "obs"], capture_output=True).returncode == 0
    return subprocess.run(["pgrep", "-x", "obs"], capture_output=True).returncode == 0


def mac_obs_app():
    for p in ("/Applications/OBS.app", os.path.join(HOME, "Applications", "OBS.app")):
        if os.path.isdir(p):
            return p
    return None


# ------------------------------------------------------------------ Linux sources
def linux_session():
    return "wayland" if (os.environ.get("XDG_SESSION_TYPE") == "wayland" or os.environ.get("WAYLAND_DISPLAY")) else "x11"


def to_mac(collection):
    """macOS sources: ScreenCaptureKit window capture, Video Capture Device, Core Audio mic, SCK desktop audio."""
    for s in collection["sources"]:
        if s["id"] == "game_capture":      # pick the WoW window in the source's properties
            s["id"] = s["versioned_id"] = "screen_capture"
            s["settings"] = {"type": 1, "show_cursor": True}
        elif s["id"] == "dshow_input":
            s["id"] = s["versioned_id"] = "macos-avcapture"
            s["settings"] = {}
    for key, sid, st in (("DesktopAudioDevice1", "sck_audio_capture", {"type": 0}),
                         ("AuxAudioDevice1", "coreaudio_input_capture", {"device_id": "default"})):
        if key in collection:
            collection[key]["id"] = collection[key]["versioned_id"] = sid
            collection[key]["settings"] = st
    return collection


def to_linux(collection, kit):
    """Turn the Windows template into a Linux (or macOS) scene collection."""
    text = json.dumps(collection)
    collection = json.loads(text.replace("__KIT__", kit.replace("\\", "/").replace('"', '\\"')))
    if MAC:
        return to_mac(collection)
    wayland = linux_session() == "wayland"
    for s in collection["sources"]:
        if s["id"] == "game_capture":
            if wayland:      # Wayland: OBS asks you to pick the WoW window the first time
                s["id"] = s["versioned_id"] = "pipewire-screen-capture-source"
                s["settings"] = {"ShowCursor": True}
            else:            # X11: window capture, pick WoW in the source's properties
                s["id"] = s["versioned_id"] = "xcomposite_input"
                s["settings"] = {"capture_window": "", "show_cursor": True}
        elif s["id"] == "dshow_input":
            s["id"] = s["versioned_id"] = "v4l2_input"
            s["settings"] = {}
    for key, sid in (("DesktopAudioDevice1", "pulse_output_capture"), ("AuxAudioDevice1", "pulse_input_capture")):
        if key in collection:
            collection[key]["id"] = collection[key]["versioned_id"] = sid
            collection[key]["settings"] = {"device_id": "default"}
    return collection


USER_IDS = {"dshow_input", "game_capture", "window_capture", "monitor_capture", "wasapi_input_capture", "wasapi_output_capture",
            "wasapi_process_output_capture", "v4l2_input", "xcomposite_input", "pipewire-screen-capture-source",
            "pipewire-desktop-capture-source", "pipewire-window-capture-source", "pipewire-camera-source",
            "pulse_input_capture", "pulse_output_capture", "av_capture_input", "screen_capture",
            "macos-avcapture", "macos-avcapture-fast", "coreaudio_input_capture", "coreaudio_output_capture", "sck_audio_capture"}


def merge(new, old):
    """Update = new kit scenes, but keep the camera/game/audio the streamer picked, where they put them,
    their own scenes/sources, their hotkeys for the kit's script and their other scripts."""
    old_by = {s["name"]: s for s in old.get("sources", [])}
    for s in new["sources"]:
        o = old_by.get(s["name"])
        if o and o.get("id") == s["id"] and o["id"] in USER_IDS:
            for k in ("settings", "volume", "muted", "filters", "monitoring_type", "mixers", "sync", "balance"):
                if k in o:
                    s[k] = o[k]
    for k, v in old.items():
        if k.startswith(("DesktopAudioDevice", "AuxAudioDevice")):
            new[k] = v
    old_scenes = {s["name"]: s for s in old.get("sources", []) if s.get("id") == "scene"}
    for s in new["sources"]:
        if s["id"] != "scene" or s["name"] not in old_scenes:
            continue
        old_items = {i["name"]: i for i in old_scenes[s["name"]]["settings"].get("items", [])}
        for it in s["settings"].get("items", []):
            src = old_by.get(it["name"])
            if src and src.get("id") in USER_IDS and it["name"] in old_items:
                for k in ("pos", "scale", "rot", "bounds", "bounds_type", "bounds_align", "align",
                          "crop_left", "crop_top", "crop_right", "crop_bottom", "visible"):
                    if k in old_items[it["name"]]:
                        it[k] = old_items[it["name"]][k]
    names = {s["name"] for s in new["sources"]}
    extra = [s for s in old.get("sources", []) if s["name"] not in names and not s["name"].startswith("AF ")]
    new["sources"] += extra
    order = {o["name"] for o in new["scene_order"]}
    new["scene_order"] += [o for o in old.get("scene_order", []) if o["name"] not in order and any(e["name"] == o["name"] and e["id"] == "scene" for e in extra)]
    gnames = {g["name"] for g in new.get("groups", [])}
    new["groups"] = new.get("groups", []) + [g for g in old.get("groups", []) if g["name"] not in gnames]
    old_mods = old.get("modules", {}) or {}
    old_scripts = old_mods.get("scripts-tool", []) or []
    mine = next((x for x in old_scripts if x.get("path", "").endswith("adfinem-hotkeys.lua")), None)
    for ns in new.get("modules", {}).get("scripts-tool", []):
        if mine and ns["path"].endswith("adfinem-hotkeys.lua"):
            ns["settings"] = mine.get("settings", {})
    new.setdefault("modules", {})["scripts-tool"] = new["modules"].get("scripts-tool", []) + \
        [x for x in old_scripts if not x.get("path", "").endswith("adfinem-hotkeys.lua")]
    for k, v in old_mods.items():
        new["modules"].setdefault(k, v)
    return new


def kit_filters():
    """Noise suppression, gate, compressor and limiter for a new mic (same as the Windows setup)."""
    def f(name, fid, vid, settings):
        return {"name": name, "uuid": str(uuid.uuid4()), "id": fid, "versioned_id": vid, "settings": settings,
                "mixers": 0, "sync": 0, "flags": 0, "volume": 1.0, "balance": 0.5, "enabled": True, "muted": False,
                "push-to-mute": False, "push-to-mute-delay": 0, "push-to-talk": False, "push-to-talk-delay": 0,
                "hotkeys": {}, "deinterlace_mode": 0, "deinterlace_field_order": 0, "monitoring_type": 0, "private_settings": {}}
    return [f("Noise Suppression", "noise_suppress_filter", "noise_suppress_filter_v2", {"method": "rnnoise", "suppress_level": -30}),
            f("Noise Gate", "noise_gate_filter", "noise_gate_filter", {"open_threshold": -26.0, "close_threshold": -32.0, "attack_time": 25, "hold_time": 200, "release_time": 150}),
            f("Compressor", "compressor_filter", "compressor_filter", {"ratio": 4.0, "threshold": -18.0, "attack_time": 6, "release_time": 60, "output_gain": 0.0}),
            f("Limiter", "limiter_filter", "limiter_filter", {"threshold": -3.0, "release_time": 60})]


def sync_placeholder(c):
    """The webcam placeholder picture sits exactly where the webcam is."""
    cams = {s["name"] for s in c["sources"] if s.get("id") in ("dshow_input", "v4l2_input", "pipewire-camera-source", "av_capture_input", "macos-avcapture", "macos-avcapture-fast")}
    for s in c["sources"]:
        if s.get("id") != "scene":
            continue
        items = s["settings"].get("items", [])
        ph = next((i for i in items if i["name"] == "AF Webcam Placeholder"), None)
        wc = next((i for i in items if i["name"] in cams), None)
        if ph and wc:
            for k in ("pos", "scale", "rot", "bounds", "bounds_type", "bounds_align", "align"):
                if k in wc:
                    ph[k] = wc[k]
    return c


def pick_edition(dest):
    """'retail', 'forever' or 'both': --retail / --forever / --both, else the one installed, else ask."""
    if "--both" in sys.argv:
        return "both"
    if "--forever" in sys.argv:
        return "forever"
    if "--retail" in sys.argv:
        return "retail"
    try:
        with open(os.path.join(dest, "_system", "edition.txt"), encoding="utf-8") as f:
            v = f.read().strip().lower()
            return v if v in ("forever", "both") else "retail"
    except OSError:
        pass
    if sys.stdin.isatty():
        a = input("    Which game do you stream? r = Retail, f = WoW Forever, b = both (two scene collections) ").strip().lower()
        return {"f": "forever", "b": "both"}.get(a[:1], "retail")
    return "retail"


def set_edition_texts(dest, ed, sf=None):
    """Swaps the shipped Mythic-raiding texts for neutral ones with WoW Forever (only texts nobody changed)."""
    import re
    mp, sf = os.path.join(dest, "editions", "forever", "texts.json"), sf or os.path.join(dest, "settings.js")
    if not (os.path.exists(mp) and os.path.exists(sf)):
        return
    with open(mp, encoding="utf-8") as f:
        pairs = json.load(f)
    with open(sf, encoding="utf-8") as f:
        txt = orig = f.read()
    for e in pairs:
        if ed == "forever":
            frm, to = e["retail"], e["forever"]
        elif e.get("back"):
            frm, to = e["forever"], e["retail"]
        else:
            continue
        pat = r'("' + re.escape(e["key"]) + r'"\s*:\s*)"' + re.escape(frm) + '"'
        txt = re.sub(pat, lambda m: m.group(1) + '"' + to + '"', txt)
    if txt != orig:
        with open(sf, "w", encoding="utf-8") as f:
            f.write(txt)
        say("    Standard texts set for this game (your own texts were kept).")


FOREVER_PAGES = ("starting", "brb", "ending", "ingame", "alerts", "sponsors")


def make_forever_overlays(dest):
    """Retail + Forever side by side: "<overlay>-forever.html" copies with the Forever colours, emblem and alert."""
    ov = os.path.join(dest, "overlays")
    for n in FOREVER_PAGES:
        src = os.path.join(ov, n + ".html")
        if not os.path.exists(src):
            continue
        with open(src, encoding="utf-8") as f:
            t = f.read()
        t = t.replace('<script src="../settings.js"></script>',
                      '<script>window.AF_SETTINGS_SRC = "../settings-forever.js";</script><script src="../settings-forever.js"></script>')
        t = t.replace('<link rel="stylesheet" href="edition.css">',
                      '<link rel="stylesheet" href="edition.css"><link rel="stylesheet" href="../editions/forever/overlays/edition.css">')
        t = t.replace('"img/adfinem-emblem-gradient.svg"', '"../editions/forever/overlays/img/adfinem-emblem-gradient.svg"')
        t = t.replace('"img/webcam_placeholder.jpg"', '"../editions/forever/overlays/img/webcam_placeholder.jpg"')
        t = t.replace('"../videos/alert_1x1_alpha.webm"', '"../editions/forever/videos/alert_1x1_alpha.webm"')
        with open(os.path.join(ov, n + "-forever.html"), "w", encoding="utf-8") as f:
            f.write(t)


def forever_collection(collection, dest):
    """The "AD FINEM Forever" scene collection: same scenes, Forever videos, overlays and webcam picture."""
    kit = dest.replace("\\", "/")
    txt = json.dumps(collection, ensure_ascii=False)
    txt = txt.replace(kit + "/videos/", kit + "/editions/forever/videos/")
    txt = txt.replace(kit + "/overlays/img/webcam_placeholder.jpg", kit + "/editions/forever/overlays/img/webcam_placeholder.jpg")
    for n in FOREVER_PAGES:
        txt = txt.replace(kit + "/overlays/" + n + ".html", kit + "/overlays/" + n + "-forever.html")
    c = json.loads(txt)
    c["name"] = "AD FINEM Forever"
    return c


def apply_edition(dest):
    """Lays editions/forever over the kit (videos, colours, emblem) or puts the Retail files back.
    'both' keeps the kit Retail and makes Forever copies of the overlays for a second scene collection."""
    choice = pick_edition(dest)
    ed = "retail" if choice == "both" else choice
    ed_src = os.path.join(SRC, "editions", "forever")
    if not os.path.isdir(ed_src):
        ed_src = os.path.join(dest, "editions", "forever")
    bk = os.path.join(dest, "_system", "edition_backup")
    for root, dirs, files in os.walk(ed_src):
        rel_root = os.path.relpath(root, ed_src)
        if rel_root.split(os.sep)[0] == "streamdeck_icons":
            continue
        for f in files:
            if rel_root == "." and f == "texts.json":
                continue
            rel = os.path.normpath(os.path.join(rel_root, f))
            fs, d, b = os.path.join(root, f), os.path.join(dest, rel), os.path.join(bk, rel)
            is_forever = os.path.exists(d) and os.path.getsize(d) == os.path.getsize(fs)
            if ed == "forever" and not is_forever:
                if os.path.exists(d):
                    os.makedirs(os.path.dirname(b), exist_ok=True)
                    shutil.copy2(d, b)
                os.makedirs(os.path.dirname(d), exist_ok=True)
                shutil.copy2(fs, d)
            elif ed == "retail" and is_forever:
                r = os.path.join(SRC, rel)
                if os.path.exists(r) and os.path.getsize(r) != os.path.getsize(fs):
                    shutil.copy2(r, d)
                elif os.path.exists(b):
                    shutil.copy2(b, d)
    if choice == "both":   # each collection gets its own settings: settings.js (Retail), settings-forever.js (Forever)
        sf, sff = os.path.join(dest, "settings.js"), os.path.join(dest, "settings-forever.js")
        if not os.path.exists(sff) and os.path.exists(sf):
            shutil.copy2(sf, sff)
        set_edition_texts(dest, "forever", sff)
        set_edition_texts(dest, "retail")
        make_forever_overlays(dest)
    else:
        set_edition_texts(dest, choice)
    with open(os.path.join(dest, "_system", "edition.js"), "w", encoding="utf-8") as f:
        f.write(f'window.AF_EDITION = "{choice}";\n')
    ed = choice
    with open(os.path.join(dest, "_system", "edition.txt"), "w", encoding="utf-8") as f:
        f.write(ed + "\n")
    say("    Look: " + {"forever": "WoW Forever (gold + sapphire)", "both": "Retail AND WoW Forever (two scene collections)"}.get(ed, "Retail"), GREEN)
    return ed


def main():
    docs = documents_dir()
    dest = os.path.join(docs, "AD FINEM Stream Kit")
    say(f"\n  {ORANGE}==============================================={END}")
    say(f"     AD FINEM  -  STREAM KIT INSTALLER ({'macOS' if MAC else 'Linux'})")
    say(f"  {ORANGE}==============================================={END}")
    say(f"  Installs to: {dest}")

    # ---------------------------------------------------------------- 1. OBS
    step(1, "Checking for OBS Studio")
    if MAC:
        native, flat, snap = bool(mac_obs_app()), False, False
        if not native:
            say("    OBS Studio was not found.", YELLOW)
            if have("brew") and ask("Install OBS Studio with Homebrew now?"):
                subprocess.run(["brew", "install", "--cask", "obs"])
                native = bool(mac_obs_app())
            if not native:
                say("    Download OBS from https://obsproject.com, then run INSTALL-mac.command again.", YELLOW)
                say("    Continuing so the files are ready.", YELLOW)
        else:
            say(f"    Found: {mac_obs_app()}", GREEN)
    else:
        native, flat = have("obs"), flatpak_has_obs()
        snap = os.path.isdir(os.path.join(HOME, "snap", "obs-studio"))
    if MAC:
        pass
    elif native or flat or snap:
        say("    Found: " + ", ".join(n for n, ok in (("OBS", native), ("OBS (Flatpak)", flat), ("OBS (Snap)", snap)) if ok), GREEN)
    else:
        say("    OBS Studio was not found.", YELLOW)
        if have("flatpak") and ask("Install OBS Studio from Flathub now?"):
            subprocess.run(["flatpak", "install", "-y", "--user", "flathub", "com.obsproject.Studio"])
            flat = flatpak_has_obs()
        if not flat:
            say("    Install OBS first (Flathub: com.obsproject.Studio, or your package manager),", YELLOW)
            say("    then run install-linux.sh again. Continuing so the files are ready.", YELLOW)

    # ---------------------------------------------------------------- 2. close OBS
    step(2, "Making sure OBS is closed")
    if obs_running():
        say("    OBS is open. Please close it - waiting...", YELLOW)
        while obs_running():
            time.sleep(1)
    say("    OK", GREEN)

    # ---------------------------------------------------------------- 3. copy the kit
    step(3, "Copying the kit")
    if os.path.realpath(SRC) == os.path.realpath(dest):
        say("    Already running from the installed folder - nothing to copy.", GREEN)
    else:
        keep = os.path.exists(os.path.join(dest, "settings.js"))
        os.makedirs(dest, exist_ok=True)
        for root, dirs, files in os.walk(SRC):
            dirs[:] = [d for d in dirs if d != "backup"]
            rel = os.path.relpath(root, SRC)
            os.makedirs(os.path.join(dest, rel), exist_ok=True)
            for f in files:
                if rel == "." and f == "settings.js" and keep:
                    continue
                if rel == "_system" and f == "twitch_auth.js":
                    continue
                shutil.copy2(os.path.join(root, f), os.path.join(dest, rel, f))
        for sh in ("install-linux.sh", "uninstall-linux.sh", "customize-overlays-linux.sh",
                   "INSTALL-mac.command", "UNINSTALL-mac.command", "Customize overlays-mac.command"):
            p = os.path.join(dest, sh)
            if os.path.exists(p):
                os.chmod(p, 0o755)
        say("    Updated the kit. Your own settings.js was kept." if keep else "    Copied.", GREEN)

    edition = apply_edition(dest)

    # ---------------------------------------------------------------- 4. OBS scene collection
    step(4, 'Adding the "AD FINEM" scene collection to OBS')
    with open(os.path.join(dest, "_system", "obs_template.json"), encoding="utf-8") as f:
        collection = to_linux(json.load(f), dest)
    targets = [c for c in OBS_CONFIGS if os.path.isdir(c)]
    if not targets:   # OBS never started yet: use the right place for how it's installed
        if flat and not native:
            targets = [OBS_CONFIGS[1]]
        elif snap and not native:
            targets = [OBS_CONFIGS[2]]
        else:
            targets = [OBS_CONFIGS[0]]
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    jobs = [("AD_FINEM.json", collection)]
    if edition == "both":
        jobs.append(("AD_FINEM_Forever.json", forever_collection(collection, dest)))
    for cfg, (fname, coll) in [(c, j) for c in targets for j in jobs]:
        scenes = os.path.join(cfg, "basic", "scenes")
        os.makedirs(scenes, exist_ok=True)
        target = os.path.join(scenes, fname)
        collection = coll
        out = collection
        if os.path.exists(target):
            bk = os.path.join(dest, "_system", "backup")
            os.makedirs(bk, exist_ok=True)
            shutil.copy2(target, os.path.join(bk, f"{fname[:-5]}_{stamp}.json"))
            say("    Replaced an earlier AD FINEM collection (backup in _system/backup).", DIM)
            try:
                with open(target, encoding="utf-8-sig") as f:
                    out = merge(json.loads(json.dumps(collection)), json.load(f))
                say("    Kept your webcam, game capture, audio devices and your own scenes.", GREEN)
            except Exception as e:
                say(f"    (Could not keep your old OBS picks: {e} - set webcam/game again.)", YELLOW)
                out = collection
        else:
            out["AuxAudioDevice1"]["filters"] = kit_filters()
            say("    Mic: noise suppression, noise gate, compressor and limiter added.", GREEN)
        out = sync_placeholder(out)
        with open(target, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=2, ensure_ascii=False)
        say(f"    Written: {target}", GREEN)
    if edition == "both":
        say('    In OBS: Scene Collection > "AD FINEM" (Retail) or "AD FINEM Forever".', GREEN)
    else:   # switched away from "both": put the Forever collection away
        for cfg in targets:
            ft = os.path.join(cfg, "basic", "scenes", "AD_FINEM_Forever.json")
            if os.path.exists(ft):
                os.replace(ft, ft + ".removed")
                say("    Removed the \"AD FINEM Forever\" collection (kept as .removed).", DIM)
    if MAC:
        say("    Game capture: macOS Screen Capture (window). OBS asks for Screen Recording permission the first time.", DIM)
    else:
        say(f"    Game capture: {'PipeWire (Wayland)' if linux_session() == 'wayland' else 'Window capture (X11)'}", DIM)

    missing = []
    for s in collection["sources"]:
        p = s.get("settings", {}).get("local_file")
        if p and not os.path.exists(p):
            missing.append(p)
    for t in collection.get("transitions", []):
        p = t.get("settings", {}).get("path")
        if p and not os.path.exists(p):
            missing.append(p)
    if missing:
        say("    Note - these files are missing (those scenes will be empty until you add them):", YELLOW)
        for m in missing:
            say(f"      {m}", YELLOW)

    # ---------------------------------------------------------------- 5. launcher
    if MAC:
        step(5, "Adding the editor to your Desktop")
        try:
            cmd = os.path.join(dest, "Customize overlays-mac.command")
            if os.path.exists(cmd):
                os.chmod(cmd, 0o755)
                link = os.path.join(HOME, "Desktop", "AD FINEM - Customize overlays.command")
                if os.path.lexists(link):
                    os.remove(link)
                os.symlink(cmd, link)
                say('    Desktop: "AD FINEM - Customize overlays"', GREEN)
            # the downloaded kit is quarantined by macOS; clear it so the .command files open with a double-click
            if have("xattr"):
                subprocess.run(["xattr", "-dr", "com.apple.quarantine", dest], capture_output=True)
        except Exception as e:
            say(f"    Couldn't add the Desktop shortcut ({e}). Use \"Customize overlays-mac.command\" in the kit folder.", YELLOW)
    else:
        step(5, "Adding the editor to your app menu")
        try:
            apps = os.path.join((os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share")), "applications")
            os.makedirs(apps, exist_ok=True)
            icon = os.path.join(dest, "overlays", "img", "adfinem-emblem-gradient.svg")
            entry = (
                "[Desktop Entry]\nType=Application\nName=AD FINEM - Customize overlays\n"
                "Comment=Change the text on your AD FINEM stream overlays\n"
                f'Exec=python3 "{os.path.join(dest, "_system", "editor.py")}"\n'
                f"Icon={icon}\nTerminal=false\nCategories=AudioVideo;\n"
            )
            path = os.path.join(apps, "adfinem-customize-overlays.desktop")
            with open(path, "w", encoding="utf-8") as f:
                f.write(entry)
            os.chmod(path, 0o755)
            say('    App menu: "AD FINEM - Customize overlays"', GREEN)
        except Exception as e:
            say(f"    Couldn't add the launcher ({e}). Use customize-overlays-linux.sh in the kit folder.", YELLOW)

    say(f"\n  {GREEN}Done!{END}")
    if edition == "both":
        say('  1. Open OBS > Scene Collection > "AD FINEM" (Retail) or "AD FINEM Forever"')
    else:
        say("  1. Open OBS > Scene Collection > AD FINEM")
    say('  2. In "AF - In-Game": open "Game Capture - World of Warcraft" and pick the WoW window,')
    say('     and open "Webcam (pick your camera)" and pick your camera')
    if MAC:
        say('  3. Change your text, connect Twitch and set up alerts: "AD FINEM - Customize overlays" on your Desktop')
        say('     (or "Customize overlays-mac.command" in the kit folder)')
        say("")
    else:
        say('  3. Change your text, connect Twitch and set up alerts: "AD FINEM - Customize overlays" in your app menu')
        say("     (or run customize-overlays-linux.sh in the kit folder)\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        sys.exit(1)
    except Exception as e:
        say(f"\n  Something went wrong: {e}", RED)
        sys.exit(1)
