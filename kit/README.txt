AD FINEM STREAM KIT
=====================================================================

INSTALL (2 minutes)
  1. Run AD-FINEM-Stream-Kit-Setup.exe (or INSTALL.bat in this folder).
  2. Pick your webcam and microphone, and which mic clean-up to use:
     noise suppression, noise gate, compressor and limiter (all on by
     default). The setup puts everything into OBS for you.
  3. Pick your game: Retail (the coral look), WoW Forever (gold and
     sapphire, with the Forever emblem, intro, outro and stinger), or
     Both - then OBS gets two scene collections, "AD FINEM" and
     "AD FINEM Forever"; switch with the Scene Collection menu.
     With Both, Customize overlays has a Retail / WoW Forever switch at
     the top: each look has its own texts, pill and sponsors.
     Change it any time by running the setup again.
  4. Open OBS > menu Scene Collection > AD FINEM.
  5. Settings > Video: Base and Output resolution = 1920x1080.
  Your webcam shows the AD FINEM picture until the camera is on.
  Fine-tune the mic later: Audio Mixer > three dots next to Mic/Aux > Filters.


CHANGE THE TEXTS
  Double-click "AD FINEM - Customize overlays" on your desktop
  (or "Customize overlays.bat" in the kit folder).
  Edit, click SAVE. OBS updates by itself within a few seconds.
  Save always writes to settings.js in the kit folder - there is no
  folder to pick. A small window opens minimized while you edit;
  close it when you're done (it also stops by itself after 45 minutes).
  You can change the countdown, titles, socials, recruiting box,
  webcam position, the live raider.io progress pill, sponsors and alerts.


THE SCENES
  AF - Starting Soon   Animated background + countdown
  AF - In-Game         WoW + webcam frame + live raid progress (raider.io)
                       Switching TO this scene plays the intro (with sound)
                       as the transition - just click In-Game when you go live.
  AF - BRB             Animated background + optional break timer
  AF - Ending          Animated background + thanks + recruiting
                       Switching TO this scene plays the outro (with sound)
                       as the transition, then lands on the thanks screen.


TRANSITIONS
  AF Intro     Plays automatically when you switch to AF - In-Game.
  AF Outro     Plays automatically when you switch to AF - Ending.
  AF Stinger   Short logo wipe, used for every other scene change.
  Don't want the intro (e.g. coming back from BRB)? Right-click
  AF - In-Game > Transition override > AF Stinger, then set it back.


ALERTS (follows, subs, gift subs, bits, raids)
  Already in your scenes as "AF Alerts". Set them up in
  Customize overlays > Alerts. Two ways:

  Built-in (easiest)
    Click "Connect Twitch", log in on twitch.tv/activate and type the
    code shown. Done - alerts play in OBS with the AD FINEM animation.
    Change texts, sound volume and which events show. "Send to OBS"
    plays a test alert in OBS. Only needed once (if you don't stream
    for 30+ days, connect again). The connection is saved in
    _system\twitch_auth.js - don't share that file.

  StreamElements / Streamlabs (if you use their tips/donations)
    Choose "StreamElements / Streamlabs" and paste your alert URL.
    In their alert settings use videos\alert_1x1_alpha.webm
    (transparent, 4 s, video above text). Text: Archivo 800, ~40px,
    colour #EEF1F6, name/highlight #F0B05C.
    If nothing shows in OBS, add your alert URL as its own Browser
    source (1920x1080) instead.


SPONSORS
  Customize overlays > Sponsors. Add each sponsor with a logo (Upload),
  name, a line of text and a code or link. Tick "Show sponsors on stream".
  Choose the look (card, wide banner or logo only), position, size,
  which scenes show them, and either always on (rotating) or popping up
  every few minutes. Logos are saved in the kit's "sponsors" folder.


STREAM DECK
  INSTALL.bat makes "AD FINEM.streamDeckProfile" in the kit folder.
  Double-click it to add the AD FINEM page (15-key Stream Deck):
    Row 1  Starting Soon | In-Game | BRB | Ending | Outro
           (Ending and Outro both play the outro, then show the thanks screen)
    Row 2  Mic | Desktop audio | Webcam | Sponsors | Alerts   (on/off)
    Row 3  Back | Customize overlays | Screenshot | Record | GO LIVE
  The buttons press OBS hotkeys (Ctrl+Alt+Shift+F13...F24, GO LIVE =
  Ctrl+Shift+F13) that the installer sets up in OBS - nothing else to
  install. Change them in OBS > Settings > Hotkeys (search "AD FINEM").
  Keyboard only? The same hotkeys work without a Stream Deck.


TWITCH PROFILE (twitch_uploads folder)
  Profile picture   avatar.png
  Profile banner    twitch_banner.png        (1200x480)
  Offline banner    twitch_offline.png       (1920x1080)
  Panels            panels\panel_*.png       (About > Edit panels)
  Sub badges        badges\sub_<months>_<18|36|72>.png
                    (Creator Dashboard > Viewer Rewards > Subscriptions > Badges)


STREAMLABS DESKTOP
  1. Run INSTALL.bat (say N if it offers to install OBS).
  2. Streamlabs Desktop: Scene Collections (top left) > Manage Scene
     Collections > Import > choose "AD FINEM" from OBS Studio.
  3. Transitions: add a Stinger with videos\stinger_16x9_alpha.webm
     (transition point 500 ms) as the default, and one with
     videos\intro_stinger_16x9_alpha.webm (point 4300 ms) and one with
     videos\outro_stinger_16x9_alpha.webm (point 9000 ms). Under
     Connections, set "AF - Starting Soon" > "AF - In-Game" to the intro
     and "AF - In-Game" > "AF - Ending" to the outro.
  4. Customize overlays and alerts work the same way as with OBS.


LINUX
  Needs OBS Studio (native, Flatpak or Snap) and Python 3.
  Install:   open a terminal in the kit folder and run   bash install-linux.sh
             (WoW Forever look: bash install-linux.sh --forever,
              both as two scene collections: --both, Retail: --retail)
  Edit text: "AD FINEM - Customize overlays" in your app menu,
             or   bash customize-overlays-linux.sh
  Remove:    bash uninstall-linux.sh
  Game capture uses PipeWire on Wayland (OBS asks you to pick the WoW
  window) or window capture on X11. Webcam: Video Capture Device (V4L2).


PROBLEMS?
  Game Capture is black   Open "Game Capture - World of Warcraft" in OBS and
                          pick the WoW window from the list.
  Changes don't show      Wait a few seconds, or right-click the overlay > Refresh.
  Moved the kit folder    Run INSTALL.bat again from the new place.
  No alerts in OBS        Customize overlays > Alerts: is Twitch connected?
                          Click "Send to OBS" while a scene with alerts is on.
  Remove from OBS         UNINSTALL.bat (your kit folder is kept).

Fonts: Archivo + Onest (SIL Open Font License, see overlays\fonts).
