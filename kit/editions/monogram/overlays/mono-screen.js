/* AD FINEM - MONOGRAM look: live Starting Soon / BRB / Ending scene (same motion as the brand video).
   screen.js hands over here when edition.css says --edition: monogram. Texts come from window.AF
   (settings.js / Customize overlays): kicker, title, countdown, sub, callout, socials. */
(function (C) {
  const W = 1920, H = 1080;
  const css = `
  html,body{background:#0B0D12!important}
  body::before{display:none!important}
  #mo{position:absolute;inset:0;overflow:hidden;font-family:"AFM",sans-serif;color:#F2F2F0}
  #mo .a{position:absolute}
  #mo .em{-webkit-mask:url(img/adfinem-emblem-coral.svg) center/contain no-repeat;mask:url(img/adfinem-emblem-coral.svg) center/contain no-repeat}
  #mo .band{white-space:nowrap;font-weight:900;font-stretch:62%;font-size:300px;line-height:1;color:transparent;-webkit-text-stroke:2px #232A3A;filter:blur(1.2px)}
  #mo .hud{font-weight:700;font-stretch:125%;font-size:15px;letter-spacing:.38em;color:#5B6273;white-space:nowrap}
  #mo .micro{font-weight:700;font-stretch:125%;font-size:12px;letter-spacing:.32em;color:#3E4556;white-space:nowrap}
  #mo .corner{width:44px;height:44px;border-color:#3A4152;border-style:solid;border-width:0}
  #mo .dg{display:block;height:96px;line-height:96px}
  #mo-grain{mix-blend-mode:overlay;opacity:.22}`;
  const st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);
  const esc = s => String(s == null ? "" : s);
  const title = (C.title || []).map(esc).join(" ").trim();
  const hasCd = !!(C.target || C.minutes > 0);
  const root = document.createElement("div"); root.id = "mo";
  root.innerHTML = `
  <div id="l2" class="a" style="inset:0;background:radial-gradient(ellipse 1100px 800px at 380px 560px,rgba(70,90,130,.10),rgba(0,0,0,0) 70%)"></div>
  <div id="b1" class="a band" style="top:40px"></div><div id="b2" class="a band" style="top:720px"></div>
  <div id="mono" class="a em" style="left:-420px;top:-330px;width:1750px;height:1750px;background:#151A24"></div>
  <div id="monoE" class="a em" style="left:-420px;top:-330px;width:1750px;height:1750px;background:linear-gradient(105deg,rgba(0,0,0,0) 42%,rgba(232,120,90,.20) 50%,rgba(0,0,0,0) 58%);background-size:300% 100%"></div>
  <canvas id="stk" class="a" width="1920" height="1080" style="left:0;top:0"></canvas>
  <div id="lt" class="a" style="inset:0;background:radial-gradient(ellipse 680px 520px at 1450px 470px,rgba(232,120,90,.17),rgba(232,120,90,0) 70%)"></div>
  <svg id="cr" class="a" width="1920" height="1080" style="left:0;top:0"><defs>
   <linearGradient id="gl" x1="0" x2="1"><stop offset="0" stop-color="#E8785A" stop-opacity="0"/><stop offset="1" stop-color="#E8785A" stop-opacity=".9"/></linearGradient>
   <linearGradient id="gr" x1="0" x2="1"><stop offset="0" stop-color="#E8785A" stop-opacity=".9"/><stop offset="1" stop-color="#E8785A" stop-opacity="0"/></linearGradient></defs>
   <rect id="xl" height="1.5" fill="url(#gl)"/><rect id="xr" height="1.5" fill="url(#gr)"/></svg>
  <div id="c1" class="a corner" style="left:48px;top:48px;border-left-width:2px;border-top-width:2px"></div>
  <div id="c2" class="a corner" style="right:48px;top:48px;border-right-width:2px;border-top-width:2px"></div>
  <div id="c3" class="a corner" style="left:48px;bottom:48px;border-left-width:2px;border-bottom-width:2px"></div>
  <div id="c4" class="a corner" style="right:48px;bottom:48px;border-right-width:2px;border-bottom-width:2px"></div>
  <div id="rail" class="a" style="left:1830px;top:250px;width:18px;height:580px;overflow:hidden"><svg id="rsv" width="18" height="2400"></svg></div>
  <div id="railL" class="a micro" style="left:1878px;top:250px;transform-origin:0 0;transform:rotate(90deg)">AD-FINEM.EU — TO THE END</div>
  <div id="ru" class="a" style="left:96px;top:948px;width:1080px;height:18px;overflow:hidden"><svg id="rusv" width="2600" height="18"><line x1="0" y1="17" x2="2600" y2="17" stroke="#5B6273" stroke-width="2"/></svg></div>
  <div id="h1" class="a hud" style="left:96px;top:988px"></div>
  <div id="h2" class="a hud" style="left:1176px;top:988px;transform:translateX(-100%)">TO THE END</div>
  <div id="kick" class="a hud" style="left:96px;top:96px;color:#E8785A"><span style="display:inline-block;width:34px;height:3px;background:#E8785A;vertical-align:5px;margin-right:18px"></span><span id="kickT"></span></div>
  <div id="left" class="a" style="left:96px;bottom:200px;width:820px"></div>
  <div id="lock" class="a" style="left:1090px;top:${hasCd ? 205 : 240}px;width:720px;text-align:center">
   <div id="eb" style="position:relative;margin:0 auto;width:290px;height:290px">
    <svg id="dash" class="a" width="290" height="290" style="left:0;top:0;overflow:visible"></svg>
    <div id="rp" class="a" style="left:0;top:0;width:290px;height:290px;border-radius:50%;border:3px solid #E8785A"></div>
    <div id="rev" class="a" style="left:0;top:0;width:290px;height:290px"><div class="em" style="width:100%;height:100%;background:#E8785A;position:relative;overflow:hidden">
     <div id="sh" style="position:absolute;top:-20%;width:40%;height:140%;background:linear-gradient(90deg,rgba(255,255,255,0),rgba(255,238,228,.9),rgba(255,255,255,0));transform:skewX(-20deg)"></div></div></div>
   </div>
   <div id="wm" style="display:flex;justify-content:center;overflow:hidden;font-weight:900;font-stretch:62%;font-size:156px;height:150px;line-height:150px;margin-top:46px"></div>
   <div id="bar" style="height:3px;background:#E8785A;margin:24px auto 0;width:0"></div>
   <div id="tag" style="margin-top:24px;font-weight:700;font-stretch:125%;font-size:28px;color:#E8785A;white-space:nowrap"></div>
   <div id="cdw" style="margin-top:34px;height:96px;overflow:hidden;font-weight:900;font-stretch:62%;font-size:96px;letter-spacing:.03em;font-variant-numeric:tabular-nums"><div id="cdi"><span id="cdA" class="dg"></span><span id="cdB" class="dg"></span></div></div>
   <div id="cdl" class="micro" style="margin-top:12px;letter-spacing:.5em;color:#5B6273"></div>
  </div>
  <div id="blk" class="a" style="inset:0;background:#07090D"></div>
  <div id="cut" class="a" style="inset:0;display:flex;align-items:center;justify-content:center;font-weight:900;font-stretch:62%;font-size:560px;line-height:1"></div>
  <div id="ln" class="a" style="left:0;top:538px;width:1920px;height:4px;background:#E8785A"></div>
  <div id="s1" class="a" style="top:-300px;height:1700px;width:210px;background:#E8785A"></div>
  <div id="s2" class="a" style="top:-300px;height:1700px;width:30px;background:#E8785A"></div>
  <div id="s3" class="a" style="top:-300px;height:1700px;width:8px;background:#F2F2F0"></div>
  <div class="a" style="inset:0;background:radial-gradient(ellipse 78% 78% at 55% 50%,rgba(0,0,0,0) 55%,rgba(0,0,0,.55) 100%)"></div>
  <canvas id="mo-grain" class="a" width="960" height="540" style="left:0;top:0;width:1920px;height:1080px"></canvas>
  <div id="fl" class="a" style="inset:0;background:#FFF;opacity:0"></div>`;
  document.body.appendChild(root);
  const $ = id => document.getElementById(id), S = (id, k, v) => { $(id).style[k] = v; };

  // ---- texts
  $("kickT").textContent = esc(C.kicker);
  $("tag").textContent = title || "TO THE END";
  $("cdl").textContent = hasCd ? esc(C.countdownLabel) : "";
  if (!hasCd) { S("cdw", "display", "none"); S("cdl", "display", "none"); }
  const socials = (C.socials || []).map(esc);
  $("h1").textContent = socials.join("   ·   ") || "AD-FINEM.EU";
  const left = [];
  if (C.callout) left.push(`<div style="border-left:3px solid #E8785A;background:rgba(16,20,28,.86);padding:16px 22px;margin-bottom:22px;display:inline-block">
     <div style="font-weight:700;font-stretch:125%;font-size:14px;letter-spacing:.42em;color:#E8785A;margin-bottom:10px">${esc(C.callout.label)}</div>
     <div style="font-weight:600;font-size:24px">${esc(C.callout.text)} <span style="color:#E8785A">${esc(C.callout.accent)}</span></div></div>`);
  if (C.sub) left.push(`<div style="font-weight:500;font-size:24px;line-height:1.45;color:rgba(242,242,240,.74);max-width:780px">${esc(C.sub)}</div>`);
  $("left").innerHTML = left.join("");
  const WM = "AD FINEM"; $("wm").innerHTML = [...WM].map(c => `<span style="display:inline-block">${c === " " ? "&nbsp;" : c}</span>`).join("");
  const L = [...$("wm").children];
  const UNIT = "AD FINEM&nbsp;&nbsp;·&nbsp;&nbsp;TO THE END&nbsp;&nbsp;·&nbsp;&nbsp;"; $("b1").innerHTML = UNIT.repeat(6); $("b2").innerHTML = UNIT.repeat(6);
  let s = ""; for (let i = 0; i <= 104; i++) { const x = i * 25, m = i % 6 === 0; s += `<line x1="${x}" y1="${m ? 2 : 9}" x2="${x}" y2="17" stroke="${m ? "#E8785A" : "#5B6273"}" stroke-width="2"/>`; } $("rusv").insertAdjacentHTML("beforeend", s);
  s = ""; for (let i = 0; i <= 96; i++) { const y = i * 25, m = i % 4 === 0; s += `<line x1="${m ? 0 : 8}" y1="${y}" x2="18" y2="${y}" stroke="${m ? "#E8785A" : "#3E4556"}" stroke-width="2"/>`; } $("rsv").innerHTML = s;
  const R0 = 145, TAU = Math.PI * 2;
  $("dash").innerHTML = `<g id="dg" style="transform-origin:${R0}px ${R0}px"><circle cx="${R0}" cy="${R0}" r="${R0 * 1.22}" fill="none" stroke="#3A4152" stroke-width="1.5" stroke-dasharray="2 9"/>
   <circle cx="${R0}" cy="${R0}" r="${R0 * 1.22}" fill="none" stroke="#E8785A" stroke-width="2" stroke-dasharray="${R0 * 1.22 * TAU * .12} ${R0 * 1.22 * TAU}"/></g>
   ${[0, 90, 180, 270].map(a => `<line x1="${R0}" y1="${R0 - R0 * 1.30}" x2="${R0}" y2="${R0 - R0 * 1.40}" stroke="#E8785A" stroke-width="2" transform="rotate(${a} ${R0} ${R0})"/>`).join("")}`;
  let sd = 7; const RN = () => (sd = (sd * 16807) % 2147483647) / 2147483647;
  const ST = [...Array(80)].map(() => ({ x: RN() * W, y: RN() * 1400, l: 40 + RN() * 240, k: 1 + Math.floor(RN() * 3), w: RN() < .15 ? 2 : 1, c: RN() < .22, b: RN() < .3 }));
  const sc = $("stk").getContext("2d"), gc = $("mo-grain").getContext("2d");
  const tiles = [...Array(6)].map(() => { const im = gc.createImageData(960, 540); for (let i = 0; i < im.data.length; i += 4) { const v = Math.random() * 255; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = 255; } return im; });

  // ---- countdown
  let end = null;
  if (C.target) { const [h, m] = C.target.split(":").map(Number); end = new Date(); end.setHours(h, m || 0, 0, 0); if (end < new Date()) end.setDate(end.getDate() + 1); }
  else if (C.minutes > 0) end = new Date(Date.now() + C.minutes * 60000);
  const fmt = sec => { if (sec <= 0) return esc(C.doneText); const hh = Math.floor(sec / 3600), mm = Math.floor(sec % 3600 / 60), ss = sec % 60;
    return (hh ? hh + ":" + String(mm).padStart(2, "0") : String(mm).padStart(2, "0")) + ":" + String(ss).padStart(2, "0"); };
  let lastSec = null, rollAt = -9;

  // ---- motion (same timeline as the brand video)
  const cl = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x)), P = (t, a, b) => cl((t - a) / (b - a));
  const eo = x => 1 - Math.pow(1 - x, 4), e5 = x => 1 - Math.pow(1 - x, 5), eio = x => x < .5 ? 8 * x ** 4 : 1 - Math.pow(-2 * x + 2, 4) / 2;
  const eb = (x, c = 1.6) => 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2);
  const spring = x => x <= 0 ? 0 : x >= 1 ? 1 : 1 - Math.exp(-6 * x) * Math.cos(9 * x);
  const CUTS = ["TO", "THE", "END"], O = 1.0, E0 = O + .45, W0 = O + 1.0, H0 = O + .9;
  const PERIOD = 12, pulseAt = t => { if (t < 5.2) return -99; return 5.2 + Math.floor((t - 5.2) / PERIOD) * PERIOD; };
  const t0 = performance.now();
  function frame(now) {
    const t = (now - t0) / 1000, fr = Math.floor(t * 30);
    const pl = pulseAt(t), dp = t - pl;
    // intro: hairline, typographic cuts, sash reveal
    S("ln", "transform", `scaleX(${eio(P(t, 0, .32))}) scaleY(${1 - P(t, .34, .42)})`); S("ln", "opacity", t < .42 ? 1 : 0);
    let c = ""; if (t >= .42 && t < .98) c = CUTS[Math.min(2, Math.floor((t - .42) / .18))];
    if ($("cut").textContent !== c) $("cut").textContent = c;
    S("cut", "opacity", c ? 1 : 0); S("cut", "transform", `scale(${1.08 - .08 * eo(cl(((t - .42) % .18) / .18))})`);
    const vis = eo(P(t, O, O + .6)); S("blk", "opacity", 1 - vis);
    let sp = -1; if (t >= O - .1 && t < O + .7) sp = eio(P(t, O - .1, O + .7)); else if (pl > 0 && dp >= 0 && dp < .8) sp = eio(dp / .8);
    [["s1", 0], ["s2", 150], ["s3", 230]].forEach(([id, off], j) => { if (sp < 0) { S(id, "opacity", 0); return; }
      const q = eio(cl(sp * 1.08 - j * .04)); S(id, "opacity", 1); S(id, "transform", `translateX(${-1000 + q * 3500 + off}px) skewX(-32deg)`); });
    // background
    const mi = e5(P(t, O + .1, O + 2.0)), drift = Math.sin(t * .25) * 18;
    const mt = `translate(${(1 - mi) * -140}px,${drift}px) scale(${1.25 - .25 * mi}) rotate(${(1 - mi) * -7}deg)`;
    S("mono", "transform", mt); S("monoE", "transform", mt); S("mono", "opacity", mi); S("monoE", "opacity", mi);
    S("monoE", "backgroundPosition", `${130 - ((t * .08) % 1) * 160}% 0`);
    const UW = 4148, bi = eo(P(t, O + .3, O + 1.6));
    S("b1", "transform", `translateX(${-UW * .4 - ((t * 38) % UW)}px) rotate(-6deg)`); S("b2", "transform", `translateX(${-UW * 1.7 + ((t * 38) % UW)}px) rotate(-6deg)`);
    S("b1", "opacity", bi * .9); S("b2", "opacity", bi * .9);
    const hit = [E0 + .85, pl].filter(x => x > 0);
    let boost = 0; for (const e of hit) boost = Math.max(boost, Math.exp(-(((t - e - .35) / .28) ** 2)));
    S("lt", "opacity", vis * (.78 + .22 * Math.sin(t * 1.3)) + boost * .8); S("l2", "opacity", vis);
    sc.clearRect(0, 0, W, H); const si = P(t, O + .4, O + 1.6);
    for (const q of ST) { const y = ((q.y - t * q.k * 110 - boost * 90 * q.k) % 1400 + 1400) % 1400 - 200;
      const g = sc.createLinearGradient(0, y, 0, y + q.l), col = q.c ? "232,120,90" : "150,165,195", a = (q.b ? .28 : .55) * si;
      g.addColorStop(0, `rgba(${col},${a})`); g.addColorStop(1, `rgba(${col},0)`); sc.fillStyle = g; sc.fillRect(q.x, y, q.w, q.l); }
    // emblem
    const er = eio(P(t, E0, E0 + .85)), ang = er * 360, m = er >= 1 ? "none" : `conic-gradient(from 0deg,#000 ${ang}deg,transparent ${ang + .01}deg)`;
    S("rev", "webkitMask", m); S("rev", "mask", m);
    S("rev", "transform", `scale(${.8 + .2 * eb(P(t, E0, E0 + 1.0))}) rotate(${(1 - e5(P(t, E0, E0 + 1.1))) * -50}deg)`);
    let sh = -1, rp = -1; for (const e of hit) { const d = t - e; if (d >= 0 && d < .9) sh = eio(d / .9); if (d >= 0 && d < 1) rp = d; }
    S("sh", "left", (sh < 0 ? -80 : -60 + sh * 180) + "%");
    S("rp", "opacity", rp < 0 ? 0 : (1 - rp) * .85); S("rp", "transform", `scale(${1 + (rp < 0 ? 0 : eo(rp)) * .6})`);
    const di = eo(P(t, E0 + .3, E0 + 1.3)); $("dg").style.transform = `rotate(${t * 14 + (1 - di) * -120}deg)`; S("dash", "opacity", di);
    const lk = $("lock"), cy = lk.offsetTop + 145, cr = eio(P(t, E0 + .6, E0 + 1.3)), cxL = 1450 - 191, cxR = 1450 + 191;
    $("xl").setAttribute("y", cy); $("xr").setAttribute("y", cy); $("xl").setAttribute("x", cxL - cxL * cr); $("xl").setAttribute("width", cxL * cr);
    $("xr").setAttribute("x", cxR); $("xr").setAttribute("width", (W - cxR) * cr); S("cr", "opacity", (1 - .75 * P(t, E0 + 1.6, E0 + 2.4)) * vis);
    // wordmark + title + countdown
    L.forEach((el, i) => { const p = P(t, W0 + i * .04, W0 + .75 + i * .04); let gx = 0, shd = "none";
      if (pl > 0 && dp > .05 && dp < .17) { gx = ((i * 37 + fr * 13) % 3 - 1) * 16; shd = "-5px 0 rgba(232,120,90,.85), 5px 0 rgba(110,170,255,.65)"; }
      el.style.transform = `translate(${gx}px,${(1 - spring(p)) * 156}px)`; el.style.textShadow = shd; });
    S("wm", "letterSpacing", `${(1 - e5(P(t, W0, W0 + 1.4))) * .2 + .01}em`);
    S("bar", "width", eio(P(t, W0 + .45, W0 + 1.1)) * 380 + "px");
    const tg = P(t, W0 + .6, W0 + 1.6); S("tag", "letterSpacing", `${.9 - .48 * e5(tg)}em`); S("tag", "opacity", eo(tg)); S("tag", "clipPath", `inset(0 ${100 - eo(tg) * 100}% 0 0)`);
    if (end) { const sec = Math.max(0, Math.round((end - Date.now()) / 1000));
      if (sec !== lastSec) { $("cdA").textContent = lastSec === null ? fmt(sec) : fmt(lastSec); $("cdB").textContent = fmt(sec); rollAt = lastSec === null ? -9 : t; lastSec = sec;
        $("cdw").style.color = sec === 0 ? "#E8785A" : "#F2F2F0"; }
      S("cdi", "transform", `translateY(${-96 * (rollAt < 0 ? 1 : eo(cl((t - rollAt) / .28)))}px)`);
      const ci = eo(P(t, W0 + .9, W0 + 1.5)); S("cdw", "opacity", ci); S("cdl", "opacity", ci); S("cdw", "transform", `translateY(${(1 - ci) * 24}px)`); }
    // HUD + left copy
    const hi = eo(P(t, H0, H0 + .9));
    S("ru", "clipPath", `inset(0 ${100 - hi * 100}% 0 0)`); S("rusv", "transform", `translateX(${-((t * 60) % 150)}px)`);
    S("rail", "clipPath", `inset(0 0 ${100 - hi * 100}% 0)`); S("rsv", "transform", `translateY(${-((t * 40) % 100)}px)`);
    ["h1", "h2", "railL"].forEach(id => S(id, "opacity", hi));
    S("kick", "clipPath", `inset(0 ${100 - eo(P(t, H0, H0 + .8)) * 100}% 0 0)`);
    const li = eo(P(t, W0 + 1.1, W0 + 1.9)); S("left", "opacity", li); S("left", "transform", `translateY(${(1 - li) * 18}px)`);
    ["c1", "c2", "c3", "c4"].forEach((id, i) => { const p = e5(P(t, H0 + i * .06, H0 + .6 + i * .06)); S(id, "opacity", p); S(id, "transform", `scale(${1.6 - .6 * p})`); });
    // flash + camera shake on hits
    let f = 0; if (t > E0 + .85 && t < E0 + .92) f = .2; if (pl > 0 && dp > .08 && dp < .12) f = .045; S("fl", "opacity", f);
    let shk = 0; for (const e of hit) shk = Math.max(shk, t > e ? Math.exp(-(t - e) * 8) : 0);
    root.style.transform = `translate(${Math.sin(fr * 2.3) * 7 * shk}px,${Math.cos(fr * 1.7) * 7 * shk}px) scale(${1.012 + .008 * Math.sin(t * .2)})`;
    gc.putImageData(tiles[fr % 6], 0, 0);
    requestAnimationFrame(frame);
  }
  (document.fonts ? document.fonts.ready : Promise.resolve()).then(() => requestAnimationFrame(frame));
})(window.AF_MONO);
