"""Builds the AD FINEM Stream Deck profiles (15-key Stream Deck / MK.2 layout).

   python build_sd.py templates            -> writes templates/<edition>-<mode>/ for every combination

   edition: one or more looks joined with "+" (retail, monogram, forever), e.g. retail+monogram+forever.
            One page per look: the first look is the "AD FINEM" collection, the others
            "AD FINEM Monogram" / "AD FINEM Forever". The bottom-left key flips to the next look's page
            (a middle page also gets a "previous" key, as the Stream Deck app requires).
   mode:    obs  - Elgato's "OBS Studio" plugin: keys show what OBS is doing (two icon states)
            keys - plain key commands (no plugin needed, one icon state)

   install.ps1 / make-profile.ps1 zips one template into "AD FINEM.streamDeckProfile",
   replacing __EDITOR__ with the path to "Customize overlays.bat".
   Icons: icons/ (Retail) and ../../editions/forever/streamdeck_icons/ - the second states
   (*_off, *_active, *_on) are made by tools/make_states.py.
"""
import json, os, shutil, sys, uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = {"retail": os.path.join(HERE, "icons"),
         "forever": os.path.join(HERE, "..", "..", "editions", "forever", "streamdeck_icons"),
         "monogram": os.path.join(HERE, "..", "..", "editions", "monogram", "streamdeck_icons")}
OUT = os.path.join(HERE, "templates")
PROFILE_UUID = "A7D0F1E2-5C3B-4E6A-9F80-AD0F1E2E5C3B"       # same as before: importing again updates the profile
NS = uuid.UUID("ad0f1e2e-5c3b-4e6a-9f80-a7d0f1e25c3b")

QT_F = {n: 16777264 + n - 1 for n in range(1, 36)}        # Qt::Key_F1 = 0x01000030
VK_F = {n: 111 + n for n in range(1, 25)}                 # VK_F1 = 0x70
EMPTY = {"KeyCmd": False, "KeyCtrl": False, "KeyModifiers": 0, "KeyOption": False, "KeyShift": False,
         "NativeCode": 0, "QTKeyCode": 33554431, "VKeyCode": -1}

OBS = {"Name": "OBS Studio", "UUID": "com.elgato.obsstudio", "Version": "3.0.3.31"}
# Elgato's OBS actions: state 0 = "on" (scene on screen, audio live, source shown, recording/streaming),
#                       state 1 = "off"
SCENES = [("0,0", "AF - Starting Soon", "scene_starting"), ("1,0", "AF - In-Game", "scene_ingame"),
          ("2,0", "AF - BRB", "scene_brb"), ("3,0", "AF - Ending", "scene_ending")]
# items in "AF - In-Game" (ids from obs_template.json); the kit's OBS script copies their
# visibility to the same source in every other AD FINEM scene
ITEMS = [("2,1", "Show / hide webcam", "Webcam (pick your camera)", 2, "cam"),
         ("3,1", "Show / hide sponsors", "AF Sponsors", 5, "sponsors"),
         ("4,1", "Show / hide alerts", "AF Alerts", 4, "alerts"),
         # the switch for music in your headphones (the stream always has it) - read by the kit's OBS script
         ("2,2", "Music in my headphones on / off", "AF Music - in my headphones", 7, "music")]


def hotkey(fn, ctrl=True, alt=True, shift=True):
    mods = (1 if shift else 0) | (2 if ctrl else 0) | (4 if alt else 0)
    k = {"KeyCmd": False, "KeyCtrl": ctrl, "KeyModifiers": mods, "KeyOption": alt, "KeyShift": shift,
         "NativeCode": VK_F[fn], "QTKeyCode": QT_F[fn], "VKeyCode": VK_F[fn]}
    return {"Coalesce": True, "Hotkeys": [k, dict(EMPTY), dict(EMPTY), dict(EMPTY)]}


def state(img):
    return {"FontFamily": "", "FontSize": 12, "FontStyle": "", "FontUnderline": False, "Image": "Images/" + img,
            "OutlineThickness": 2, "ShowTitle": False, "Title": "", "TitleAlignment": "bottom", "TitleColor": "#FFFFFF"}


def action(name, uid, plugin, settings, imgs, start=0):
    imgs = [imgs] if isinstance(imgs, str) else imgs
    if isinstance(plugin, str):
        plugin = {"Name": plugin, "UUID": "com.elgato.streamdeck.page" if uid.startswith("com.elgato.streamdeck.page") else uid, "Version": "1.0"}
    return {"ActionID": str(uuid.uuid4()), "LinkedTitle": False, "Name": name, "Plugin": plugin,
            "Settings": settings, "State": start, "States": [state(i) for i in imgs], "UUID": uid}


HK = "com.elgato.streamdeck.system.hotkey"
def hk(name, img, fn, **m): return action(name, HK, "Activate a Key Command", hotkey(fn, **m), img)


def layout(mode, collection, nav):
    """nav: set of page moves this page needs: {} (single page), {'next'}, {'previous'} or both"""
    a = {}
    if mode == "obs":
        for key, scene, img in SCENES:
            a[key] = action("Scene: " + scene[5:], "com.elgato.obsstudio.scene", OBS,
                            {"scene": scene, "target": "program"}, [img + "_active.png", img + ".png"], 1)
        for key, name, src, img in (("0,1", "Mute / unmute mic", "Mic/Aux", "mic"),
                                    ("1,1", "Mute / unmute desktop audio", "Desktop Audio", "desktop")):
            a[key] = action(name, "com.elgato.obsstudio.mixeraudio", OBS,
                            {"type": "mute", "mode": "toggle", "style": "static", "source": src, "step": 1.0, "volume": 0.5},
                            [img + ".png", img + "_off.png"])
        for key, name, src, iid, img in ITEMS:
            a[key] = action(name, "com.elgato.obsstudio.source", OBS,
                            {"collection": collection, "scene": "AF - In-Game", "sceneitemscene": "AF - In-Game",
                             "sceneitemid": iid, "sceneitemname": src},
                            [img + ".png", img + "_off.png"])
        a["3,2"] = action("Start / stop recording", "com.elgato.obsstudio.record", OBS, {"longpress": False},
                          ["record_on.png", "record.png"], 1)
        a["4,2"] = action("Start / stop stream", "com.elgato.obsstudio.stream", OBS, {"longpress": False},
                          ["live_on.png", "live.png"], 1)
    else:
        for (key, _, img), fn in zip(SCENES, (13, 14, 15, 16)):
            a[key] = hk("Scene: " + _[5:], img + ".png", fn)
        a["0,1"] = hk("Mute / unmute mic", "mic.png", 18)
        a["1,1"] = hk("Mute / unmute desktop audio", "desktop.png", 19)
        a["2,1"] = hk("Show / hide webcam", "cam.png", 20)
        a["3,1"] = hk("Show / hide sponsors", "sponsors.png", 21)
        a["2,2"] = hk("Music in my headphones on / off", "music.png", 12)
        a["4,1"] = hk("Show / hide alerts", "alerts.png", 22)
        a["3,2"] = hk("Start / stop recording", "record.png", 24)
        a["4,2"] = hk("Start / stop stream", "live.png", 13, alt=False)
    a["4,0"] = hk("Scene: Ending + outro", "scene_outro.png", 17)        # plays the outro, then Ending
    a["1,2"] = action("Customize overlays", "com.elgato.streamdeck.system.open", "Open",
                      {"openInBrowser": False, "path": "__EDITOR__"}, "editor.png")
    if not nav:
        a["0,2"] = hk("Screenshot", "screenshot.png", 23)
    else:   # bottom-left: next look (or back, on the last page); a middle page gives up Customize for "previous"
        a["0,2"] = action("Switch look", "com.elgato.streamdeck.page." + ("next" if "next" in nav else "previous"), "Pages", {},
                          "page_next.png" if "next" in nav else "page_prev.png")
        if "next" in nav and "previous" in nav:
            a["1,2"] = action("Previous look", "com.elgato.streamdeck.page.previous", "Pages", {}, "page_prev.png")
    return a


def write_page(folder, icons, actions, next_icons=None, prev_icons=None):
    img_dir = os.path.join(folder, "Images"); os.makedirs(img_dir, exist_ok=True)
    for act in actions.values():
        for st in act["States"]:
            n = st["Image"].split("/")[1]
            src = (os.path.join(next_icons, "page.png") if n == "page_next.png" else
                   os.path.join(prev_icons, "page.png") if n == "page_prev.png" else os.path.join(icons, n))
            shutil.copy(src, os.path.join(img_dir, n))
    m = {"Controllers": [{"Actions": actions, "Type": "Keypad"}], "Icon": "", "Name": "AD FINEM"}
    with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=1)


ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTVW"   # Stream Deck's folder names: base32 of the page UUID (no U), then "Z"
def page_folder(page_uuid):
    n = int.from_bytes(uuid.UUID(page_uuid).bytes, "big") << 2      # 128 bits -> 26 x 5 bits
    return "".join(ALPHA[(n >> (5 * (25 - i))) & 31] for i in range(26)) + "Z"


def build(edition, mode):
    out = os.path.join(OUT, f"{edition}-{mode}")
    shutil.rmtree(out, ignore_errors=True)
    root = os.path.join(out, PROFILE_UUID + ".sdProfile")
    looks = edition.split("+")
    ids = []
    for i, look in enumerate(looks):
        coll = "AD FINEM" if i == 0 else {"monogram": "AD FINEM Monogram", "forever": "AD FINEM Forever"}[look]
        nav = set() if len(looks) == 1 else ({"next"} if i == 0 else {"previous"} if i == len(looks) - 1 else {"next", "previous"})
        pid = str(uuid.uuid5(NS, f"{edition}-{mode}-{look}"))
        ids.append(pid)
        nxt = ICONS[looks[i + 1]] if i + 1 < len(looks) else None
        prv = ICONS[looks[i - 1]] if i > 0 else None
        write_page(os.path.join(root, "Profiles", page_folder(pid)), ICONS[look], layout(mode, coll, nav), nxt, prv)
    with open(os.path.join(root, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"Device": {"Model": "20GAA9902", "UUID": ""}, "Name": "AD FINEM",
                   "Pages": {"Current": ids[0], "Default": ids[0], "Pages": ids}, "Version": "2.0"}, f)
    return out


if __name__ == "__main__":
    if sys.argv[1:2] != ["templates"]:
        sys.exit(__doc__)
    import itertools
    LOOKS = ("retail", "monogram", "forever")
    combos = ["+".join(c) for n in (1, 2, 3) for c in itertools.combinations(LOOKS, n)]
    keep = ("retail", "forever")   # the single Retail / Forever templates are unchanged - don't rewrite them
    for old in ("both", "both-monogram"):
        for mode in ("obs", "keys"):
            shutil.rmtree(os.path.join(OUT, f"{old}-{mode}"), ignore_errors=True)
    for ed in combos:
        if ed in keep and "--all" not in sys.argv:
            continue
        for mode in ("obs", "keys"):
            print("written", build(ed, mode))
