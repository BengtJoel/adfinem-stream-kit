"""AD FINEM page for OpenDeck (Linux). Elgato's Stream Deck app does not run on Linux; OpenDeck does,
and it runs Elgato's "OBS Studio" plugin (2.x, the HTML one), so the keys show what OBS is doing.

Same 15-key layout as build_sd.py (Windows). Writes, for every 15-key deck OpenDeck knows:
  <opendeck>/profiles/<device>/AD FINEM.json           (+ "AD FINEM Forever.json" with both looks)
  <opendeck>/images/<device>/<profile>/Keypad.N.0/<state>-user.png
The page shows up in OpenDeck's profile list. Running it again updates it.
"""
import glob
import json
import os
import shutil
import subprocess
import time

HOME = os.path.expanduser("~")
CONFIGS = [os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config"), "opendeck"),
           os.path.join(HOME, ".var", "app", "me.amankhanna.opendeck", "config", "opendeck")]
OBS = "com.elgato.obsstudio.sdPlugin"
# the OBS side of the plugin (the OpenDeck plugin talks to it, not to obs-websocket)
OBS_SIDE = ["/usr/lib*/obs-plugins/libStreamDeckPlugin.so", "/usr/lib/*/obs-plugins/libStreamDeckPlugin.so",
            os.path.join(HOME, ".config", "obs-studio", "plugins", "*", "bin", "*", "libStreamDeckPlugin.so")]
STARTER = "com.amansprojects.starterpack.sdPlugin"
SCENES = [(0, "AF - Starting Soon", "scene_starting"), (1, "AF - In-Game", "scene_ingame"),
          (2, "AF - BRB", "scene_brb"), (3, "AF - Ending", "scene_ending"),
          (4, "AF - Ending", "scene_outro")]   # Ending already plays the outro (transition override)
# items in "AF - In-Game" (ids from obs_template.json); the kit's OBS script copies them to every scene
ITEMS = [(7, "Webcam (pick your camera)", 2, "cam"), (8, "AF Sponsors", 5, "sponsors"),
         (9, "AF Alerts", 4, "alerts"), (12, "AF Music - in my headphones", 7, "music")]


def find_config():
    return next((c for c in CONFIGS if os.path.isdir(os.path.join(c, "plugins"))), None)


def img_path(cfg, plugin, rel):
    """OpenDeck stores plugin images as plugins/<id>/<path>[@2x].png, like its own UI does."""
    ext = next(e for e in ("@2x.png", ".png", "") if e == "" or os.path.exists(os.path.join(cfg, "plugins", plugin, rel + e)))
    return f"plugins/{plugin}/{rel}{ext}"


def state(image, override=None):
    return {"alignment": "bottom", "background_colour": "#000000", "colour": "#FFFFFF", "family": "Liberation Sans",
            "image": image, "image_override": override, "image_scale": 100, "name": "", "show": False, "size": 16,
            "stroke_colour": "#000000", "stroke_size": 3, "style": "Regular", "text": "", "text_override": "",
            "underline": False}


# OpenDeck's own Multi Action (no manifest; same fields as in its shared.rs)
MULTI = {"controllers": ["Keypad"], "disable_automatic_states": False, "encoder": None, "icon": "opendeck/multi-action.png",
         "name": "Multi Action", "plugin": "opendeck", "property_inspector": "", "states": [state("opendeck/multi-action.png")],
         "supported_in_multi_actions": False, "tooltip": "Execute multiple actions", "uuid": "opendeck.multiaction",
         "visible_in_action_list": True}


def action_def(cfg, plugin, uuid):
    if uuid == MULTI["uuid"]:
        return MULTI
    with open(os.path.join(cfg, "plugins", plugin, "manifest.json"), encoding="utf-8") as f:
        a = next(x for x in json.load(f)["Actions"] if x["UUID"] == uuid)
    icon = img_path(cfg, plugin, a["Icon"])
    sts = [state(icon if s.get("Image") in (None, "actionDefaultImage") else img_path(cfg, plugin, s["Image"]))
           for s in a["States"]]
    return {"controllers": a.get("Controllers", ["Keypad"]), "disable_automatic_states": a.get("DisableAutomaticStates", False),
            "encoder": None, "icon": icon, "name": a["Name"], "plugin": plugin,
            "property_inspector": f"plugins/{plugin}/{a['PropertyInspectorPath']}" if a.get("PropertyInspectorPath") else "",
            "states": sts, "supported_in_multi_actions": a.get("SupportedInMultiActions", True),
            "tooltip": a.get("Tooltip", ""), "uuid": uuid, "visible_in_action_list": a.get("VisibleInActionList", True)}


def layout(collection, editor_cmd, switch_to):
    """index -> (plugin, action uuid, settings, [icon per state], start state[, children]). Index = row * 5 + column.
    children: [(plugin, action uuid, settings)], run in order by OpenDeck's Multi Action."""
    k = {}
    for i, scene, img in SCENES:
        k[i] = (OBS, "com.elgato.obsstudio.scene", {"scene": scene, "target": "program"}, [img + "_active", img], 1)
    for i, src, img in ((5, "Mic/Aux", "mic"), (6, "Desktop Audio", "desktop")):
        k[i] = (OBS, "com.elgato.obsstudio.mixeraudio",
                {"type": "mute", "mode": "toggle", "style": "static", "source": src, "step": 1.0, "volume": 0.5},
                [img, img + "_off"], 0)
    for i, src, iid, img in ITEMS:
        k[i] = (OBS, "com.elgato.obsstudio.source",
                {"collection": collection, "scene": "AF - In-Game", "sceneitemscene": "AF - In-Game",
                 "sceneitemid": iid, "sceneitemname": src}, [img, img + "_off"], 0)
    k[11] = (STARTER, "com.amansprojects.starterpack.runcommand",
             {"down": editor_cmd, "up": "", "rotate": "", "file": "", "show": False}, ["editor"], 0)
    k[13] = (OBS, "com.elgato.obsstudio.record", {"longpress": False}, ["record_on", "record"], 1)
    k[14] = (OBS, "com.elgato.obsstudio.stream", {"longpress": False}, ["live_on", "live"], 1)
    if switch_to:
        # switch OBS to the other look's collection, then the deck to its page (both are named the same)
        k[10] = ("opendeck", "opendeck.multiaction", {}, ["page_other"], 0,
                 [(OBS, "com.elgato.obsstudio.scenecollection", {"collection": switch_to}),
                  (STARTER, "com.amansprojects.starterpack.switchprofile", {"profile": switch_to})])
    else:
        k[10] = (OBS, "com.elgato.obsstudio.screenshot", {}, ["screenshot"], 0)
    return k


def write_profile(cfg, device, name, keys, icons, other_icons):
    img_root = os.path.join(cfg, "images", device, name)
    shutil.rmtree(img_root, ignore_errors=True)
    out = [None] * 15
    for i, (plugin, uuid, settings, imgs, start, *kids) in keys.items():
        a = action_def(cfg, plugin, uuid)
        ctx = f"Keypad.{i}.0"
        os.makedirs(os.path.join(img_root, ctx), exist_ok=True)
        sts = []
        for n, base in enumerate(a["states"]):
            img = imgs[min(n, len(imgs) - 1)]
            src = os.path.join(other_icons, "page.png") if img == "page_other" else os.path.join(icons, img + ".png")
            shutil.copy(src, os.path.join(img_root, ctx, f"{n}-user.png"))
            sts.append(state(base["image"], f"{n}-user.png"))
        children = None
        if kids:
            children = []
            for n, (cp, cu, cs) in enumerate(kids[0], 1):
                ca = action_def(cfg, cp, cu)
                if cu.endswith("switchprofile"):
                    cs = dict(cs, device=device)
                children.append({"action": ca, "children": None, "context": f"Keypad.{i}.{n}", "current_state": 0,
                                 "settings": cs, "states": ca["states"]})
        out[i] = {"action": a, "children": children, "context": ctx, "current_state": start, "settings": settings, "states": sts}
    with open(os.path.join(cfg, "profiles", device, name + ".json"), "w", encoding="utf-8") as f:
        json.dump({"infobars": [], "keys": out, "sliders": []}, f, indent=2)


def fifteen_key_devices(cfg):
    """Device folders whose pages have 15 keys (Stream Deck / MK.2), the layout the page is made for."""
    def keys(p):
        try:
            with open(p, encoding="utf-8") as f:
                return len(json.load(f).get("keys", []))
        except (OSError, ValueError):
            return 0
    return sorted({os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(cfg, "profiles", "*", "*.json")) if keys(p) == 15})


def opendeck_running():
    return subprocess.run(["pgrep", "-x", "opendeck"], capture_output=True).returncode == 0


def make(dest, edition):
    """Returns (ok, [lines to show])."""
    cfg = find_config()
    if not cfg:
        return False, ["OpenDeck not found. Using a Stream Deck? Install OpenDeck (github.com/nekename/OpenDeck),",
                       "plug in the deck once, then run install-linux.sh again."]
    if not os.path.isdir(os.path.join(cfg, "plugins", OBS)):
        return False, ['OpenDeck has no "OBS Studio" plugin yet. In OpenDeck: Plugins > OBS Studio > Install,',
                       "then run install-linux.sh again."]
    devs = fifteen_key_devices(cfg)
    if not devs:
        return False, ["No 15-key Stream Deck in OpenDeck yet. Plug it in, open OpenDeck once, then run install-linux.sh again."]
    was_running = opendeck_running()
    if was_running:   # OpenDeck keeps pages in memory and would write its old copy back
        subprocess.run(["pkill", "-x", "opendeck"])
        for _ in range(50):
            if not opendeck_running():
                break
            time.sleep(0.1)
    icons = {"retail": os.path.join(dest, "_system", "streamdeck", "icons"),
             "forever": os.path.join(dest, "editions", "forever", "streamdeck_icons"),
             "monogram": os.path.join(dest, "editions", "monogram", "streamdeck_icons")}
    # a .desktop launcher needs no quoting (the kit path has spaces); the installer writes it before this
    editor_cmd = "gtk-launch adfinem-customize-overlays" if shutil.which("gtk-launch") else f'python3 "{os.path.join(dest, "_system", "editor.py")}"'
    if edition.startswith("both"):
        first = "monogram" if edition == "both-monogram" else "retail"
        pages = [(first, "AD FINEM", "AD FINEM", "AD FINEM Forever"),
                 ("forever", "AD FINEM Forever", "AD FINEM Forever", "AD FINEM")]
    else:
        pages = [(edition, "AD FINEM", "AD FINEM", None)]
        for d in devs:   # switched away from "both": remove the second page
            shutil.rmtree(os.path.join(cfg, "images", d, "AD FINEM Forever"), ignore_errors=True)
            p = os.path.join(cfg, "profiles", d, "AD FINEM Forever.json")
            if os.path.exists(p):
                os.remove(p)
    try:
        for d in devs:
            for look, profile, collection, switch_to in pages:
                other = icons["forever" if look != "forever" else pages[0][0]]
                write_profile(cfg, d, profile, layout(collection, editor_cmd, switch_to), icons[look], other)
    finally:
        if was_running:
            subprocess.Popen(["opendeck", "--hide"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    lines = ["OpenDeck: added " + " and ".join(f'"{p[1]}"' for p in pages) + ". Pick it in OpenDeck's profile list."]
    if not any(glob.glob(g) for g in OBS_SIDE):
        lines.append("OBS also needs Elgato's Stream Deck plugin built for Linux (libStreamDeckPlugin.so); without it the keys stay grey.")
    return True, lines


if __name__ == "__main__":   # quick check on this machine: python3 make_opendeck.py <kit folder> [retail|forever|both]
    import sys
    ok, lines = make(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "retail")
    print("\n".join(lines))
    sys.exit(0 if ok else 1)
