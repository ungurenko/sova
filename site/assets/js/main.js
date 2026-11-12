(() => {
  "use strict";
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Появление при прокрутке
  const items = document.querySelectorAll(".reveal");
  if (reduce || !("IntersectionObserver" in window)) {
    items.forEach((el) => el.classList.add("is-in"));
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) { e.target.classList.add("is-in"); io.unobserve(e.target); }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.05 });
    items.forEach((el) => io.observe(el));
  }

  // Обратный отсчёт, как в меню Sova
  const clocks = document.querySelectorAll("[data-countdown]");
  let left = 2 * 3600 + 41 * 60 + 5;
  const fmt = (s) => `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
  if (clocks.length) {
    setInterval(() => {
      left = left > 0 ? left - 1 : 24 * 3600;
      const t = fmt(left);
      clocks.forEach((c) => { c.textContent = t; });
    }, 1000);
  }

  // Наклон совы за курсором, до 6°
  const owl = document.querySelector("[data-tilt]");
  const hero = document.querySelector(".hero");
  if (owl && hero && !reduce && window.matchMedia("(pointer: fine)").matches) {
    hero.addEventListener("pointermove", (e) => {
      const r = hero.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      owl.style.setProperty("--ry", `${(x * 12).toFixed(2)}deg`);
      owl.style.setProperty("--rx", `${(-y * 8).toFixed(2)}deg`);
    });
    hero.addEventListener("pointerleave", () => {
      owl.style.setProperty("--ry", "0deg");
      owl.style.setProperty("--rx", "0deg");
    });
  }

  // Копирование команды установки
  document.querySelectorAll("[data-copy]").forEach((btn) => {
    const label = btn.querySelector(".btn__label");
    const initial = label.textContent;
    let timer;
    const show = (cls, text) => {
      btn.classList.remove("is-done", "is-error");
      btn.classList.add(cls);
      label.textContent = text;
      clearTimeout(timer);
      timer = setTimeout(() => { btn.classList.remove(cls); label.textContent = initial; }, 2200);
    };
    const selectText = (el) => {
      const range = document.createRange();
      range.selectNodeContents(el);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
    };
    btn.addEventListener("click", async () => {
      const src = document.querySelector(btn.dataset.copy);
      if (!src) return;
      const text = src.textContent.trim();
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          selectText(src);
          if (!document.execCommand("copy")) throw new Error("copy failed");
        }
        show("is-done", "Скопировано");
      } catch (err) {
        selectText(src);
        show("is-error", "Выделено, нажмите ⌘C");
      }
    });
  });
})();
