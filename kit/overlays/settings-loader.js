/* Reads ../settings.js (or a live preview from the Customize page via #s=...) and exposes AF_GET(section). */
(function () {
  function fromHash() {
    const m = location.hash.match(/[#&]s=([^&]+)/);
    if (!m) return null;
    try { return JSON.parse(decodeURIComponent(escape(atob(decodeURIComponent(m[1]))))); } catch (e) { return null; }
  }
  const preview = fromHash();
  const S = preview || window.AF_SETTINGS || {};

  // Live updates in OBS: re-read ../settings.js every 3 s (script tag = works from disk too)
  // and reload this overlay when the saved settings changed. Not used in the editor preview.
  if (!preview) {
    const current = JSON.stringify(window.AF_SETTINGS || null);
    const check = () => {
      const tag = document.createElement("script");
      const keep = window.AF_SETTINGS;
      tag.src = "../settings.js?v=" + Date.now();
      tag.onload = () => {
        const fresh = JSON.stringify(window.AF_SETTINGS || null);
        tag.remove();
        if (window.AF_SETTINGS && fresh !== current) location.reload();
        else window.AF_SETTINGS = keep;
      };
      tag.onerror = () => tag.remove();
      document.head.appendChild(tag);
    };
    setInterval(check, 3000);
  }
  const esc = v => String(v == null ? "" : v).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  window.AF_ESC = esc;
  window.AF_GET = function (section) {
    if (!S.general && !S[section]) {           // settings.js missing or broken: use the built-in defaults
      console.warn("[AF] settings.js not found or has an error - using defaults");
      return {};
    }
    const g = S.general || {}, s = S[section] || {};
    if (section === "ingame") return Object.assign({ streamerName: g.streamerName }, s);
    if (section === "alerts" || section === "sponsors") return Object.assign({}, s);
    const cfg = {
      kicker: esc(s.kicker), title: (s.title || []).filter(Boolean).map(esc),
      countdownLabel: esc(s.countdownLabel), minutes: Number(s.countdownMinutes) || 0,
      target: s.countdownTo || "", doneText: esc(s.doneText), sub: esc(s.subtitle),
      socials: (g.socials || []).filter(Boolean).map(esc),
    };
    if (section === "ending" && s.showRecruiting)
      cfg.callout = { label: esc(s.recruitingLabel), text: esc(s.recruitingText), accent: esc(s.recruitingLink) };
    return cfg;
  };
})();
