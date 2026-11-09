/* =====================================================================
   AD FINEM STREAM KIT - ALL TEXT IN ONE PLACE
   Easiest: double-click "Customize overlays.bat" and click Save.
   Or edit the text between the quotes below in Notepad and save.
   OBS picks up the changes by itself within a few seconds.
   ===================================================================== */
window.AF_SETTINGS = {
  "general": {
    "streamerName": "",
    "socials": ["AD-FINEM.EU"],
    "schedule": "Mon, Wed & Sun · 21:00 CET"
  },
  "starting": {
    "kicker": "AD FINEM · LIVE SHORTLY",
    "title": ["STARTING", "SOON"],
    "countdownLabel": "STREAM STARTS IN",
    "countdownMinutes": 5,
    "countdownTo": "",
    "doneText": "ANY MOMENT NOW",
    "subtitle": "Mythic raid night · Mon, Wed & Sun · 21:00 CET"
  },
  "brb": {
    "kicker": "AD FINEM · INTERMISSION",
    "title": ["BE RIGHT", "BACK"],
    "countdownLabel": "BACK IN",
    "countdownMinutes": 0,
    "doneText": "BACK ANY SECOND",
    "subtitle": "Grab a drink — we'll be right back."
  },
  "ending": {
    "kicker": "TO THE END",
    "title": ["THANKS FOR", "WATCHING"],
    "subtitle": "Next raid: Mon, Wed & Sun · 21:00 CET",
    "showRecruiting": true,
    "recruitingLabel": "WE'RE RECRUITING",
    "recruitingText": "Mythic raiders — apply at",
    "recruitingLink": "AD-FINEM.EU"
  },
  "ingame": {
    "showCamFrame": true,
    "camX": 32, "camY": 805, "camWidth": 432, "camHeight": 243,
    "showProgress": true,
    "progressPosition": "top-center",
    "raiderio": true,
    "region": "eu", "realm": "dentarg", "guild": "Ad Finem",
    "raid": "the-venomous-abyss",
    "rank": "realm",
    "fallbackLabel": "MYTHIC", "fallbackValue": "6/8", "fallbackRaid": "THE VENOMOUS ABYSS"
  },
  "alerts": {
    "mode": "twitch",
    "url": "",
    "follows": true, "subs": true, "gifts": true, "bits": true, "raids": true,
    "minBits": 1, "minRaid": 1,
    "followText": "NEW FOLLOWER",
    "subText": "JUST SUBSCRIBED",
    "resubText": "SUBSCRIBED · {months} MONTHS",
    "giftText": "GIFTED {amount} SUBS",
    "bitsText": "CHEERED {amount} BITS",
    "raidText": "RAIDING WITH {amount}",
    "duration": 7, "volume": 70, "sound": true, "position": "center"
  },
  "sponsors": {
    "enabled": false,
    "heading": "PARTNERED WITH", "showHeading": true,
    "style": "card", "position": "bottom-right", "scale": 100, "margin": 32,
    "mode": "rotate", "seconds": 12, "everyMinutes": 10, "showSeconds": 30, "showTimer": true,
    "scenes": { "starting": true, "ingame": true, "brb": true, "ending": true },
    "items": []
  }
};
