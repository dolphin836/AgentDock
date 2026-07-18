(() => {
  "use strict";

  const translations = {
    en: {
      skip: "Skip to content",
      downloadShort: "Download",
      download: "Download for Mac",
      heroEyebrow: "Every agent, at a glance",
      heroLine1: "Your agents are working.",
      heroLine2: "You stay in flow.",
      heroDescription: "Live status, approvals, and usage in your macOS notch.",
      running: "Running",
      needsYou: "Needs you",
      usage: "Usage",
      panelHint: "Click to pin",
      stageNote: "Hover, click, or focus the notch to open the live panel.",
    },
    zh: {
      skip: "跳到主要内容",
      downloadShort: "下载",
      download: "下载 Mac 版",
      heroEyebrow: "所有 Agent，一眼看清",
      heroLine1: "Agent 在工作。",
      heroLine2: "你保持专注。",
      heroDescription: "实时状态、审批与用量，都在 macOS 刘海里。",
      running: "运行中",
      needsYou: "需要你",
      usage: "用量",
      panelHint: "点击固定",
      stageNote: "悬停、点击或聚焦刘海，展开实时面板。",
    },
  };

  let language = "en";
  try {
    language = localStorage.getItem("agentdock-language") ||
      (navigator.language.startsWith("zh") ? "zh" : "en");
  } catch (_) {
    language = navigator.language.startsWith("zh") ? "zh" : "en";
  }

  const langButtons = document.querySelectorAll("[data-lang]");
  const i18nNodes = document.querySelectorAll("[data-i18n]");

  function setLanguage(next) {
    language = next === "zh" ? "zh" : "en";
    const dict = translations[language];
    document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
    i18nNodes.forEach((node) => {
      const value = dict[node.dataset.i18n];
      if (value) node.textContent = value;
    });
    langButtons.forEach((button) =>
      button.setAttribute("aria-pressed", String(button.dataset.lang === language))
    );
    try { localStorage.setItem("agentdock-language", language); } catch (_) {}
  }

  langButtons.forEach((button) =>
    button.addEventListener("click", () => setLanguage(button.dataset.lang))
  );

  const notchWrap = document.getElementById("notchWrap");
  const notchToggle = document.getElementById("notchToggle");
  let notchPinned = false;

  function setNotch(open) {
    if (!notchWrap || !notchToggle) return;
    notchWrap.classList.toggle("is-open", open);
    notchToggle.setAttribute("aria-expanded", String(open));
  }

  if (notchWrap && notchToggle) {
    notchToggle.addEventListener("click", () => {
      notchPinned = !notchPinned;
      setNotch(notchPinned);
    });
    notchWrap.addEventListener("mouseenter", () => setNotch(true));
    notchWrap.addEventListener("mouseleave", () => { if (!notchPinned) setNotch(false); });
    notchWrap.addEventListener("focusout", (event) => {
      if (!notchWrap.contains(event.relatedTarget) && !notchPinned) setNotch(false);
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && (notchPinned || notchWrap.classList.contains("is-open"))) {
        notchPinned = false;
        setNotch(false);
        notchToggle.focus();
      }
    });
  }

  const revealNodes = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && revealNodes.length) {
    const observer = new IntersectionObserver((entries, obs) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          obs.unobserve(entry.target);
        }
      });
    }, { rootMargin: "0px 0px -10% 0px", threshold: 0.05 });
    revealNodes.forEach((node) => observer.observe(node));
  } else {
    revealNodes.forEach((node) => node.classList.add("is-visible"));
  }

  const AgentDockSite = {
    setLanguage,
    setNotch,
    setApproval() {},
  };

  window.AgentDockSite = AgentDockSite;

  setLanguage(language);
})();
