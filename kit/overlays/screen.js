/* AD FINEM — Starting Soon / BRB / Ending screen builder.
   Each screen HTML sets window.AF = {...} and loads this file. */
(function () {
  const C = Object.assign({
    kicker: "AD FINEM",
    title: ["STARTING", "SOON"],
    countdownLabel: "STREAM STARTS IN",
    minutes: 0,            // countdown length in minutes (0 = no countdown) ...
    target: "",            // ... or count down to a clock time, e.g. "21:00" (local time). Wins over minutes.
    doneText: "ANY MOMENT NOW",
    sub: "",
    callout: null,         // { label: "WE'RE RECRUITING", text: "Mythic raiders - apply at" , accent: "AD-FINEM.EU" }
    socials: ["AD-FINEM.EU"],
  }, window.AF || {});

  // URL overrides: screen.html?minutes=10&target=21:00
  const q = new URLSearchParams(location.search);
  if (q.get("minutes")) C.minutes = parseFloat(q.get("minutes"));
  if (q.get("target")) C.target = q.get("target");

  const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
  const root = el("main", "screen");
  let d = 0.3; const step = () => (d += 0.22).toFixed(2) + "s";

  const k = el("div", "kicker fade", C.kicker); k.style.setProperty("--d", "0.2s"); root.append(k);

  const t = el("h1", "title");
  C.title.forEach(line => {
    const w = el("span", "wipe"); w.style.setProperty("--d", step());
    w.append(el("span", "in", line)); t.append(w, el("br"));
  });
  root.append(t);

  const r = el("div", "rule fade"); r.style.setProperty("--d", step()); root.append(r);

  if (C.target || C.minutes > 0) {
    const box = el("div", "countdown fade"); box.style.setProperty("--d", step());
    box.append(el("div", "cd-label", C.countdownLabel));
    const v = el("div", "cd-value mono", "--:--"); box.append(v); root.append(box);
    let end;
    if (C.target) {
      const [h, m] = C.target.split(":").map(Number); end = new Date(); end.setHours(h, m || 0, 0, 0);
      if (end < new Date()) end.setDate(end.getDate() + 1);
    } else end = new Date(Date.now() + C.minutes * 60000);
    const tick = () => {
      const s = Math.max(0, Math.round((end - Date.now()) / 1000));
      if (s === 0) { v.textContent = C.doneText; v.classList.add("done"); return; }
      const hh = Math.floor(s / 3600), mm = Math.floor(s % 3600 / 60), ss = s % 60;
      v.textContent = (hh ? hh + ":" + String(mm).padStart(2, "0") : String(mm).padStart(2, "0")) + ":" + String(ss).padStart(2, "0");
      setTimeout(tick, 250);
    };
    tick();
  }

  if (C.sub) { const s = el("p", "sub fade", C.sub); s.style.setProperty("--d", step()); root.append(s); }

  if (C.callout) {
    const c = el("div", "callout fade"); c.style.setProperty("--d", step());
    c.append(el("div", "callout-label", C.callout.label));
    c.append(el("div", "callout-text", `${C.callout.text} <span class="accent">${C.callout.accent || ""}</span>`));
    root.append(c);
  }

  const foot = el("footer", "foot fade"); foot.style.setProperty("--d", step());
  C.socials.forEach((s, i) => { foot.append(el("span", i === 0 ? "chip url" : "chip", (i === 0 ? '<i class="dot"></i>' : "") + s)); });
  root.append(foot);

  document.body.append(root);

  // shrink the title so its widest line stays clear of the emblem (max ~760 px)
  const fit = () => {
    const MAX = 760, BASE = 118;
    t.style.fontSize = BASE + "px";
    const widest = Math.max(...[...t.querySelectorAll(".in")].map(s => s.scrollWidth));
    if (widest > MAX) t.style.fontSize = Math.floor(BASE * MAX / widest) + "px";
  };
  (document.fonts ? document.fonts.ready : Promise.resolve()).then(fit);
})();
