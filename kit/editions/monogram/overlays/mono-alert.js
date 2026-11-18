/* AD FINEM - MONOGRAM look: alert panel (same as the alert in the brand video).
   alerts.html calls AF_MONO_ALERT(stage, {name, what, msg}, seconds, position, done). */
(function () {
  const st = document.createElement("style");
  st.textContent = `
  .mal{position:absolute;height:132px;font-family:"AFM",sans-serif;color:#F2F2F0}
  .mal.top{left:96px;top:96px} .mal.center{left:50%;top:420px}
  .mal .pn{position:absolute;inset:0;background:#10141C;border:1px solid #232A3A;overflow:hidden}
  .mal .em{position:absolute;left:30px;top:26px;width:80px;height:80px;background:#E8785A;
    -webkit-mask:url(img/adfinem-emblem-coral.svg) center/contain no-repeat;mask:url(img/adfinem-emblem-coral.svg) center/contain no-repeat}
  .mal .tx{position:absolute;left:136px;top:24px;right:30px;height:92px;overflow:hidden;white-space:nowrap}
  .mal .lb{text-transform:uppercase;font-weight:700;font-stretch:125%;font-size:14px;letter-spacing:.42em;color:#E8785A}
  .mal .nm{text-transform:uppercase;font-weight:900;font-stretch:62%;font-size:62px;line-height:68px;display:flex}
  .mal .nm span{display:inline-block}
  .mal .ms{position:absolute;left:0;top:140px;max-width:100%;padding:12px 18px;background:rgba(16,20,28,.92);border-left:3px solid #E8785A;
    font-weight:500;font-size:19px;line-height:1.35;color:rgba(242,242,240,.85);white-space:normal}
  .mal .tb{position:absolute;left:0;bottom:-1px;height:3px;background:#E8785A}
  .mal .bk{position:absolute;top:0;height:132px;background:#E8785A}
  .mal .sl{position:absolute;top:-60px;height:260px;width:26px;background:#F2F2F0}`;
  document.head.appendChild(st);
  const cl = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x)), P = (t, a, b) => cl((t - a) / (b - a));
  const eo = x => 1 - Math.pow(1 - x, 4), e5 = x => 1 - Math.pow(1 - x, 5), eio = x => x < .5 ? 8 * x ** 4 : 1 - Math.pow(-2 * x + 2, 4) / 2;
  const eb = (x, c = 1.6) => 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2);
  const spring = x => x <= 0 ? 0 : x >= 1 ? 1 : 1 - Math.exp(-6 * x) * Math.cos(9 * x);

  window.AF_MONO_ALERT = function (stage, ev, seconds, pos, done) {
    const el = document.createElement("div"); el.className = "mal " + (pos === "top" ? "top" : "center");
    el.innerHTML = `<div class="pn"></div><div class="em"></div>
      <div class="tx"><div class="lb">${ev.what}</div><div class="nm">${[...ev.name].map(c => `<span>${c === " " ? "&nbsp;" : c.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}</span>`).join("")}</div></div>
      ${ev.msg ? `<div class="ms">${ev.msg}</div>` : ""}<div class="tb"></div><div class="sl"></div><div class="bk"></div>`;
    stage.appendChild(el);
    const q = s => el.querySelector(s), N = [...el.querySelectorAll(".nm span")];
    const W = Math.min(1100, Math.max(600, 136 + q(".nm").scrollWidth + 50));
    el.style.width = W + "px"; if (pos !== "top") el.style.marginLeft = -W / 2 + "px";
    const D = Math.max(4, seconds), t0 = performance.now();
    function frame(now) {
      const t = (now - t0) / 1000;
      // coral block: wipes in, retracts to reveal the panel; at the end it closes over it and leaves to the right
      const inA = eio(P(t, 0, .32)), inB = eio(P(t, .32, .7)), outA = eio(P(t, D - .6, D - .3)), outB = eio(P(t, D - .3, D));
      let l = 0, r = 0;
      if (t < .32) { l = 0; r = inA; } else if (t < D - .6) { l = inB; r = 1; } else if (t < D - .3) { l = 1 - outA; r = 1; } else { l = outB; r = 1; }
      q(".bk").style.left = l * W + "px"; q(".bk").style.width = Math.max(0, (r - l) * W) + "px";
      const shown = t >= .32 && t < D - .3;
      ["pn", "em", "tx", "tb"].forEach(c => q("." + c).style.opacity = shown ? 1 : 0);
      if (q(".ms")) { const mi = eo(P(t, 1.0, 1.5)) * (t < D - .4 ? 1 : 0); q(".ms").style.opacity = mi; q(".ms").style.transform = `translateY(${(1 - mi) * 10}px)`; }
      // white slash crossing the panel as it opens
      const sp = P(t, .3, .75); q(".sl").style.opacity = sp > 0 && sp < 1 ? 1 : 0;
      q(".sl").style.transform = `translateX(${-60 + eio(sp) * (W + 120)}px) skewX(-32deg)`;
      const ae = e5(P(t, .35, 1.0)); q(".em").style.transform = `scale(${.5 + .5 * eb(P(t, .35, .9))}) rotate(${(1 - ae) * -90}deg)`;
      q(".lb").style.clipPath = `inset(0 ${100 - eo(P(t, .45, .9)) * 100}% 0 0)`;
      N.forEach((s, i) => { s.style.transform = `translateY(${(1 - spring(P(t, .5 + i * .025, 1.1 + i * .025))) * 70}px)`; });
      q(".tb").style.width = W * (1 - P(t, .7, D - .6)) + "px";
      if (t < D + .05) requestAnimationFrame(frame); else { el.remove(); done(); }
    }
    requestAnimationFrame(frame);
  };
})();
