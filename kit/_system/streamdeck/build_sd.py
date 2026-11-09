"""Builds the AD FINEM Stream Deck page (15-key Stream Deck / MK.2 layout).
   python build_sd.py page <icons_dir> <out_page_dir> <editor_path>  -> writes manifest.json + Images/
   python build_sd.py profile <icons_dir> <out.streamDeckProfile> <editor_path>
"""
import json, os, shutil, sys, uuid, zipfile

QT_F = {n: 16777264 + n - 1 for n in range(1, 36)}        # Qt::Key_F1 = 0x01000030
VK_F = {n: 111 + n for n in range(1, 25)}                 # VK_F1 = 0x70
EMPTY = {"KeyCmd": False, "KeyCtrl": False, "KeyModifiers": 0, "KeyOption": False, "KeyShift": False,
         "NativeCode": 0, "QTKeyCode": 33554431, "VKeyCode": -1}

def hotkey(fn, ctrl=True, alt=True, shift=True):
    mods = (1 if shift else 0) | (2 if ctrl else 0) | (4 if alt else 0)
    k = {"KeyCmd": False, "KeyCtrl": ctrl, "KeyModifiers": mods, "KeyOption": alt, "KeyShift": shift,
         "NativeCode": VK_F[fn], "QTKeyCode": QT_F[fn], "VKeyCode": VK_F[fn]}
    return {"Coalesce": True, "Hotkeys": [k, dict(EMPTY), dict(EMPTY), dict(EMPTY)]}

def state(img):
    return {"FontFamily": "", "FontSize": 12, "FontStyle": "", "FontUnderline": False, "Image": "Images/" + img,
            "OutlineThickness": 2, "ShowTitle": False, "Title": "", "TitleAlignment": "bottom", "TitleColor": "#FFFFFF"}

def action(name, uid, plugin, settings, img):
    return {"ActionID": str(uuid.uuid4()), "LinkedTitle": False, "Name": name,
            "Plugin": {"Name": plugin, "UUID": uid if not uid.startswith("com.elgato.streamdeck.page") else "com.elgato.streamdeck.page", "Version": "1.0"},
            "Settings": settings, "State": 0, "States": [state(img)], "UUID": uid}

HK = "com.elgato.streamdeck.system.hotkey"
def hk(name, img, fn, **m): return action(name, HK, "Activate a Key Command", hotkey(fn, **m), img)

def layout(editor_path):
    return {  # "column,row" on a 5x3 Stream Deck
        "0,0": hk("Scene: Starting Soon", "scene_starting.png", 13),
        "1,0": hk("Scene: In-Game", "scene_ingame.png", 14),
        "2,0": hk("Scene: BRB", "scene_brb.png", 15),
        "3,0": hk("Scene: Ending", "scene_ending.png", 16),
        "4,0": hk("Scene: Outro", "scene_outro.png", 17),
        "0,1": hk("Mute / unmute mic", "mic.png", 18),
        "1,1": hk("Mute / unmute desktop audio", "desktop.png", 19),
        "2,1": hk("Show / hide webcam", "cam.png", 20),
        "3,1": hk("Show / hide sponsors", "sponsors.png", 21),
        "4,1": hk("Show / hide alerts", "alerts.png", 22),
        "0,2": action("Previous page", "com.elgato.streamdeck.page.previous", "Pages", {}, "back.png"),
        "1,2": action("Customize overlays", "com.elgato.streamdeck.system.open", "Open", {"openInBrowser": False, "path": editor_path}, "editor.png"),
        "2,2": hk("Screenshot", "screenshot.png", 23),
        "3,2": hk("Start / stop recording", "record.png", 24),
        "4,2": hk("Start / stop stream", "live.png", 13, alt=False),
    }

def write_page(icons, out, editor_path):
    os.makedirs(os.path.join(out, "Images"), exist_ok=True)
    acts = layout(editor_path)
    for a in acts.values():
        img = a["States"][0]["Image"].split("/")[1]
        shutil.copy(os.path.join(icons, img), os.path.join(out, "Images", img))
    m = {"Controllers": [{"Actions": acts, "Type": "Keypad"}], "Icon": "", "Name": "AD FINEM"}
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False)
    return m

ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTVW"   # Stream Deck's folder names: base32 of the page UUID (no U), then "Z"
def page_folder(page_uuid):
    n = int.from_bytes(uuid.UUID(page_uuid).bytes, "big") << 2      # 128 bits -> 26 x 5 bits
    s = "".join(ALPHA[(n >> (5 * (25 - i))) & 31] for i in range(26))
    return s + "Z"

if __name__ == "__main__":
    mode, icons, out, editor = sys.argv[1:5]
    if mode == "page":
        write_page(icons, out, editor); print("page written", out)
    else:
        import tempfile
        prof, page = str(uuid.uuid4()).upper(), str(uuid.uuid4())
        tmp = tempfile.mkdtemp(); root = os.path.join(tmp, prof + ".sdProfile")
        write_page(icons, os.path.join(root, "Profiles", page_folder(page)), editor)
        os.makedirs(os.path.join(root, "Images"), exist_ok=True)
        json.dump({"Device": {"Model": "20GBD9901", "UUID": ""}, "Name": "AD FINEM",
                   "Pages": {"Current": page, "Default": page, "Pages": [page]}, "Version": "2.0"},
                  open(os.path.join(root, "manifest.json"), "w"))
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
            for r, d, fs in os.walk(tmp):
                for f in fs:
                    p = os.path.join(r, f); z.write(p, os.path.relpath(p, tmp))
        print("profile written", out)
