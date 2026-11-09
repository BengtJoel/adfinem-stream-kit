#!/usr/bin/env python3
"""AD FINEM Stream Kit - overlay editor helper (Linux / macOS).

Same job as editor.ps1 on Windows: serves the kit to your browser on this computer
only (127.0.0.1) so the editor's Save button writes straight to settings.js - no
file dialog. Always edits the kit OBS actually uses. Stops by itself after 45 minutes
without use, or when you click Close in the editor.
"""
import datetime
import glob
import json
import mimetypes
import os
import re
import secrets
import shutil
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlsplit

HOME = os.path.expanduser("~")
SELF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT, IDLE_MINUTES = 47821, 45
NO_BROWSER = "--no-browser" in sys.argv
TOKEN = secrets.token_hex(16)

OBS_SCENES = [
    os.path.join((os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")), "obs-studio", "basic", "scenes"),
    os.path.join(HOME, ".var", "app", "com.obsproject.Studio", "config", "obs-studio", "basic", "scenes"),
    os.path.join(HOME, "snap", "obs-studio", "current", ".config", "obs-studio", "basic", "scenes"),
    os.path.join(HOME, "Library", "Application Support", "obs-studio", "basic", "scenes"),   # macOS
]
OVERLAY_RE = re.compile(r'"local_file"\s*:\s*"([^"]+?)/overlays/(?:ingame|starting|brb|ending)\.html"')


def find_obs_kit():
    """The kit folder OBS loads its overlays from (newest scene file first)."""
    files = []
    for d in OBS_SCENES:
        files += glob.glob(os.path.join(d, "*.json")) + glob.glob(os.path.join(d, "*.json.bak"))
    for f in sorted(files, key=os.path.getmtime, reverse=True):
        try:
            text = open(f, encoding="utf-8-sig").read()
        except Exception:
            continue
        for m in OVERLAY_RE.finditer(text):
            cand = m.group(1).replace("\\\\", "/").rstrip("/")
            if os.path.isfile(os.path.join(cand, "settings.js")) and os.path.isdir(os.path.join(cand, "overlays")):
                return cand
    return None


obs_kit = find_obs_kit()
if not obs_kit:
    guess = os.path.join(HOME, "Documents", "AD FINEM Stream Kit")
    if os.path.isfile(os.path.join(guess, "settings.js")):
        obs_kit = guess
ROOT = os.path.realpath(obs_kit or SELF)
SETTINGS = os.path.join(ROOT, "settings.js")
last_use = time.time()


class Handler(BaseHTTPRequestHandler):
    server_version = "AFEditor"

    def log_message(self, *a):
        pass

    def send(self, code, ctype, body=b"", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def json(self, code, obj):
        self.send(code, "application/json", json.dumps(obj).encode())

    def version_info(self):
        sysd = os.path.join(ROOT, "_system")
        try:
            current = open(os.path.join(sysd, "version.txt")).read().strip() or "0.0.0"
            cfg = json.load(open(os.path.join(sysd, "update.json")))
        except Exception:
            return {"ok": False}
        try:
            import urllib.request
            req = urllib.request.Request(f"https://api.github.com/repos/{cfg['repo']}/releases/latest",
                                         headers={"User-Agent": "ADFINEM-StreamKit-Updater", "Accept": "application/vnd.github+json"})
            rel = json.load(urllib.request.urlopen(req, timeout=10))
        except Exception:
            return {"ok": False, "current": current}
        ver = lambda v: tuple(int(x) for x in re.findall(r"\d+", v)[:3]) or (0,)
        latest = rel.get("tag_name", "").lstrip("vV")
        return {"ok": True, "current": current, "latest": latest, "available": ver(latest) > ver(current),
                "notes": (rel.get("body") or "")[:600], "page": rel.get("html_url", cfg.get("page", "")), "canInstall": False}

    def do_POST(self):
        global last_use
        last_use = time.time()
        path = urlsplit(self.path).path
        ok_token = secrets.compare_digest(self.headers.get("X-AF-Token", ""), TOKEN)
        if path == "/api/save":
            if not ok_token:
                return self.json(403, {"ok": False, "error": "not allowed"})
            n = int(self.headers.get("Content-Length") or 0)
            if n <= 0 or n > 500000:
                return self.json(400, {"ok": False, "error": "not a settings file"})
            text = self.rfile.read(n).decode("utf-8", "replace")
            if not re.search(r"window\.AF_SETTINGS\s*=", text):
                return self.json(400, {"ok": False, "error": "not a settings file"})
            if os.path.exists(SETTINGS):
                bk = os.path.join(ROOT, "_system", "backup")
                os.makedirs(bk, exist_ok=True)
                shutil.copy2(SETTINGS, os.path.join(bk, "settings_previous.js"))
            with open(SETTINGS, "w", encoding="utf-8", newline="") as f:
                f.write(text)
            print("  Saved", datetime.datetime.now().strftime("%H:%M:%S"), flush=True)
            return self.json(200, {"ok": True, "path": SETTINGS})
        if path == "/api/upload":   # sponsor logos, saved in the kit's "sponsors" folder
            if not ok_token:
                return self.json(403, {"ok": False, "error": "not allowed"})
            orig = os.path.basename(parse_qs(urlsplit(self.path).query).get("name", ["logo.png"])[0].replace("\\", "/"))
            base, ext = os.path.splitext(orig)
            ext = ext.lower()
            if ext not in (".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif"):
                return self.json(400, {"ok": False, "error": "use a PNG, JPG, WEBP, SVG or GIF image"})
            n = int(self.headers.get("Content-Length") or 0)
            if n <= 0 or n > 8 * 1024 * 1024:
                return self.json(400, {"ok": False, "error": "image is empty or too big (max 8 MB)"})
            data = self.rfile.read(n)
            base = re.sub(r"[^A-Za-z0-9_-]+", "-", base).strip("-") or "logo"
            folder = os.path.join(ROOT, "sponsors")
            os.makedirs(folder, exist_ok=True)
            name, i = base + ext, 2
            while os.path.exists(os.path.join(folder, name)):
                name, i = f"{base}-{i}{ext}", i + 1
            with open(os.path.join(folder, name), "wb") as f:
                f.write(data)
            return self.json(200, {"ok": True, "path": "sponsors/" + name})
        if path == "/api/file":   # small data files the overlays read: Twitch connection, test alert
            names = {"twitch_auth": "AF_TWITCH_AUTH", "alert_test": "AF_ALERT_TEST"}
            name = parse_qs(urlsplit(self.path).query).get("name", [""])[0]
            if not ok_token:
                return self.json(403, {"ok": False, "error": "not allowed"})
            n = int(self.headers.get("Content-Length") or 0)
            if name not in names or n > 20000:
                return self.json(400, {"ok": False, "error": "bad request"})
            try:
                data = json.loads(self.rfile.read(n).decode("utf-8") or "null")
            except ValueError:
                return self.json(400, {"ok": False, "error": "not json"})
            with open(os.path.join(ROOT, "_system", name + ".js"), "w", encoding="utf-8") as f:
                f.write(f"window.{names[name]} = {json.dumps(data)};\n")
            return self.json(200, {"ok": True})
        if path == "/api/close":
            if not ok_token:
                return self.json(403, {"ok": False})
            self.json(200, {"ok": True})
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return
        self.send(405, "text/plain", b"method not allowed")

    def do_GET(self):
        global last_use
        last_use = time.time()
        path = urlsplit(self.path).path
        if path in ("", "/"):
            return self.send(302, "text/plain", extra={"Location": "/_system/editor.html"})
        if path == "/api/version":
            if not secrets.compare_digest(self.headers.get("X-AF-Token", ""), TOKEN):
                return self.json(403, {"ok": False})
            return self.json(200, self.version_info())
        rel = unquote(path).lstrip("/")
        base = os.path.realpath(SELF if rel == "_system/editor.html" else ROOT)
        full = os.path.realpath(os.path.join(base, rel))
        if not full.startswith(base + os.sep) or not os.path.isfile(full):
            return self.send(404, "text/plain", b"not found")
        ctype = mimetypes.guess_type(full)[0] or "application/octet-stream"
        if ctype.startswith("text/") or ctype in ("application/javascript", "application/json"):
            ctype += "; charset=utf-8"
        if rel == "_system/editor.html":
            html = open(full, encoding="utf-8").read()
            html = html.replace("__AF_TOKEN__", TOKEN).replace("__AF_SAVE_PATH__", json.dumps(SETTINGS)[1:-1])
            return self.send(200, ctype, html.encode("utf-8"))
        with open(full, "rb") as f:
            self.send(200, ctype, f.read())


def main():
    mimetypes.add_type("text/javascript", ".js")
    mimetypes.add_type("font/woff2", ".woff2")
    mimetypes.add_type("image/svg+xml", ".svg")
    mimetypes.add_type("video/webm", ".webm")
    mimetypes.add_type("image/webp", ".webp")
    server = None
    for p in range(PORT, PORT + 30):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", p), Handler)
            break
        except OSError:
            continue
    if not server:
        print("Could not start the editor helper (no free port).")
        sys.exit(1)
    url = f"http://127.0.0.1:{server.server_address[1]}/_system/editor.html"
    print("\n  AD FINEM - overlay editor is running.")
    print(f"  Saving goes straight to: {SETTINGS}")
    if ROOT != os.path.realpath(SELF):
        print("  (This is the kit OBS uses - not the copy you started the editor from.)")
    elif not obs_kit:
        print("  Note: OBS is not set up with this kit yet - run install-linux.sh first.")
    print(f"  Editor: {url}\n", flush=True)

    def idle_watch():
        while True:
            time.sleep(20)
            if time.time() - last_use > IDLE_MINUTES * 60:
                server.shutdown()
                return

    threading.Thread(target=idle_watch, daemon=True).start()
    if not NO_BROWSER:
        threading.Timer(0.3, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    print("  Editor helper stopped.")


if __name__ == "__main__":
    main()
