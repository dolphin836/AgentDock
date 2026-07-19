(() => {
  "use strict";

  // [skill: go-team-standards · dev-dna] 双语状态交互与渐进增强
  document.documentElement.classList.add("has-js");

  const translations = {
    en: {
      skip: "Skip to content",
      downloadShort: "Download",
      download: "Download for Mac",
      navMenu: "Menu",
      mobileNavLabel: "Mobile navigation",
      navFocus: "Focus",
      navCapabilities: "Capabilities",
      navContext: "Agents",
      navJourney: "Journey",
      navIntegrations: "Integrations",
      navPrivacy: "Privacy",
      heroEyebrow: "For Claude Code · Codex · Cursor",
      heroLine1: "Every agent in view.",
      heroLine2: "Your focus stays intact.",
      heroDescription: "Live status, approvals, and usage in your macOS notch.",
      running: "Running",
      needsYou: "Needs you",
      usage: "Usage",
      panelHint: "Click to pin",
      notchToggleLabel: "Show AgentDock status",
      stageNote: "Hover, click, or focus the notch to open the live panel.",
      valueIndex: "01 / Focus",
      valueTitle: "Know what needs you, without checking every window.",
      valueOneTitle: "See every active agent",
      valueOneBody: "One quiet surface for Claude Code, Codex, and Cursor.",
      valueTwoTitle: "Notice the right moment",
      valueTwoBody: "Running, thinking, waiting, and usage stay distinct at a glance.",
      valueThreeTitle: "Return in one click",
      valueThreeBody: "Jump to the terminal or editor running that session.",
      capabilitiesIndex: "02 / Capabilities",
      capabilitiesTitle: "Four ways AgentDock keeps you oriented.",
      capabilitiesLede: "Hover a panel to expand it. Each capability has its own quiet surface, not a shared dashboard to babysit.",
      capStatusTitle: "Status",
      capStatusBody: "Running, thinking, waiting, and usage stay distinct across Claude Code, Codex, and Cursor.",
      capApprovalTitle: "Approval",
      capApprovalBody: "Answer permission requests from the notch and your choice returns to the session.",
      capUsageTitle: "Usage",
      capUsageBody: "A dedicated tab reads rate limits and account usage with text labels, never color alone.",
      capReturnTitle: "Return",
      capReturnBody: "Click a session to jump straight back to the terminal or editor that runs it.",
      statusClaude: "Hooks and a status line report each session as it moves.",
      statusCodex: "A notify hook and the local session log together infer progress.",
      statusCursor: "Hooks, the live transcript, and local storage keep status current.",
      approvalAsk: "Run the test suite in this workspace?",
      approvalWaiting: "Waiting for your decision",
      approvalAllow: "Allow",
      approvalReviewAction: "Review",
      approvalDeny: "Deny",
      approvalApproved: "Approved — sent to the session",
      approvalReview: "Opening the session to review",
      approvalDenied: "Denied — sent to the session",
      approvalScope: "Claude Code asks through a hook you answer. Assisted approval — pressing the shortcut for you — is available for Codex and Cursor only.",
      usageClaudeFigure: "Weekly · 62% used",
      usageCodexFigure: "Weekly · 41% used",
      usageCursorFigure: "Monthly · 38% used",
      usageFoot: "Figures shown are an example of the Usage tab layout.",
      returnTargetTerminals: "iTerm2 & Terminal",
      returnTargetTerminalsHow: "Matched by project window",
      returnTargetEditors: "VS Code & more editors",
      returnTargetEditorsHow: "Opened at the project path",
      returnTargetFallback: "Finder",
      returnTargetFallbackHow: "Reveals the folder as a fallback",
      contextIndex: "03 / Context",
      contextTitle: "Three kinds of agent, one place to look.",
      contextBody: "Claude Code, Codex, and Cursor each run their own way. AgentDock draws them into a single entrance in the notch, so your attention has one destination instead of many.",
      journeyIndex: "04 / Journey",
      journeyTitle: "A working session, start to finish.",
      journeyLede: "The same four surfaces from the notch, walked through once — running, waiting, usage, return — with the real panels you'd see.",
      journeyRunTitle: "Running",
      journeyRunBody: "See which agent is executing, thinking, or idle — read from where each tool already runs.",
      journeyWaitTitle: "Waiting",
      journeyWaitBody: "When an approval needs you, the notch surfaces it instead of stalling silently — decide without switching windows.",
      journeyUsageTitle: "Usage",
      journeyUsageBody: "Check remaining limits across all three agents from one tab — always with text labels, never color alone.",
      journeyReturnTitle: "Return",
      journeyReturnBody: "Click a session and land back in the exact terminal or editor that runs it.",
      integrationsIndex: "05 / Integrations",
      integrationsTitle: "Integrations that stay reversible.",
      integrationsBody: "Install or remove each agent from the settings panel. AgentDock backs up integration settings before installation. On uninstall, it removes AgentDock's own entries and restores prior settings where they can be recovered.",
      integrationsClaude: "Registers hooks and a status line in settings.json, passing your original status line through untouched. Your file is saved as settings.json.agentdock-backup.",
      integrationsCodex: "Adds a notify line to config.toml and follows the local session log to infer progress.",
      integrationsCursor: "Adds hooks, follows the live transcript, and reads local storage for status and usage.",
      privacyIndex: "06 / Privacy",
      privacyTitle: "Your work stays on your Mac.",
      privacyOneTerm: "Local by default",
      privacyOneDesc: "Session content, file paths, and token details stay on your Mac.",
      privacyTwoTerm: "Automation",
      privacyTwoDesc: "Automation (Apple Events) is used only to return you to the correct workspace.",
      privacyThreeTerm: "Accessibility",
      privacyThreeDesc: "Accessibility assists supported approvals — Codex and Cursor only.",
      privacyFourTerm: "Telemetry",
      privacyFourDesc: "Limited telemetry uses an installation-level identifier and includes launch, version, system, architecture, and crash metadata. It does not include session content or file paths.",
      downloadTitle: "Put your agents in the notch.",
      downloadMeta: "macOS 14+ · Universal · Free",
    },
    zh: {
      skip: "跳到主要内容",
      downloadShort: "下载",
      download: "下载 Mac 版",
      navMenu: "菜单",
      mobileNavLabel: "移动导航",
      navFocus: "专注",
      navCapabilities: "能力",
      navContext: "汇聚",
      navJourney: "旅程",
      navIntegrations: "集成",
      navPrivacy: "隐私",
      heroEyebrow: "支持 Claude Code · Codex · Cursor",
      heroLine1: "所有 Agent，都在眼前。",
      heroLine2: "你的专注，不被打断。",
      heroDescription: "实时状态、审批与用量，都在 macOS 刘海里。",
      running: "运行中",
      needsYou: "需要你",
      usage: "用量",
      panelHint: "点击固定",
      notchToggleLabel: "显示 AgentDock 状态",
      stageNote: "悬停、点击或聚焦刘海，展开实时面板。",
      valueIndex: "01 / 专注",
      valueTitle: "不用切遍每个窗口，也知道哪件事需要你。",
      valueOneTitle: "看清每个在跑的 Agent",
      valueOneBody: "Claude Code、Codex、Cursor，集中在一处安静的界面。",
      valueTwoTitle: "抓住该出手的时刻",
      valueTwoBody: "运行、思考、等待、用量，一眼就能分清。",
      valueThreeTitle: "一键回到现场",
      valueThreeBody: "跳回正在运行该会话的终端或编辑器。",
      capabilitiesIndex: "02 / 能力",
      capabilitiesTitle: "AgentDock 让你保持方向感的四种方式。",
      capabilitiesLede: "悬停任意面板即可展开。每项能力都有自己安静的界面，而不是一个要时刻盯着的共享面板。",
      capStatusTitle: "状态",
      capStatusBody: "运行、思考、等待与用量，在 Claude Code、Codex、Cursor 间始终分得清。",
      capApprovalTitle: "审批",
      capApprovalBody: "在刘海里答复权限请求，你的选择会回传给会话。",
      capUsageTitle: "用量",
      capUsageBody: "独立 tab 读取额度与账号用量，始终带文字标签，绝不只靠颜色。",
      capReturnTitle: "回到现场",
      capReturnBody: "点击会话，直接跳回运行它的终端或编辑器。",
      statusClaude: "通过 hooks 与状态栏实时上报每个会话。",
      statusCodex: "notify hook 加上本地会话日志推断进度。",
      statusCursor: "hooks、实时 transcript 与本地存储持续更新状态。",
      approvalAsk: "在该工作区运行测试套件？",
      approvalWaiting: "等待你的决定",
      approvalAllow: "允许",
      approvalReviewAction: "查看",
      approvalDeny: "拒绝",
      approvalApproved: "已批准——已发送到会话",
      approvalReview: "正在打开会话以便查看",
      approvalDenied: "已拒绝——已发送到会话",
      approvalScope: "Claude Code 通过 hook 请求，由你答复。辅助审批（替你按下快捷键）仅支持 Codex 与 Cursor。",
      usageClaudeFigure: "本周 · 已用 62%",
      usageCodexFigure: "本周 · 已用 41%",
      usageCursorFigure: "本月 · 已用 38%",
      usageFoot: "此处数字仅为用量 tab 布局示例。",
      returnTargetTerminals: "iTerm2 与 Terminal",
      returnTargetTerminalsHow: "按项目窗口匹配",
      returnTargetEditors: "VS Code 等编辑器",
      returnTargetEditorsHow: "按项目路径打开",
      returnTargetFallback: "访达",
      returnTargetFallbackHow: "兜底定位该文件夹",
      contextIndex: "03 / 汇聚",
      contextTitle: "三类 Agent，只看一处。",
      contextBody: "Claude Code、Codex 与 Cursor 各有各的运行方式。AgentDock 把它们汇入刘海里的同一个入口，让你的注意力只有一个去处，而不是许多个。",
      journeyIndex: "04 / 旅程",
      journeyTitle: "一次工作会话，从头到尾。",
      journeyLede: "把刘海里的四个界面走一遍——运行、等待、用量、回到现场——都是你真实会看到的面板。",
      journeyRunTitle: "运行",
      journeyRunBody: "不用打开窗口，就知道哪个 Agent 正在执行、思考或空闲——就地从每个工具读取。",
      journeyWaitTitle: "等待",
      journeyWaitBody: "当审批需要你时，刘海会主动提示，而不是无声地卡住——不切窗口就能决定。",
      journeyUsageTitle: "用量",
      journeyUsageBody: "在一个 tab 里查看三类 Agent 的剩余额度——始终带文字标签，绝不只靠颜色。",
      journeyReturnTitle: "回到现场",
      journeyReturnBody: "点击会话，回到运行它的那个终端或编辑器。",
      integrationsIndex: "05 / 集成",
      integrationsTitle: "可随时还原的集成。",
      integrationsBody: "在设置面板中逐个安装或卸载 Agent。AgentDock 会在安装前备份集成配置。卸载时只移除 AgentDock 自身写入的配置，并仅在原设置可恢复时还原。",
      integrationsClaude: "在 settings.json 中注册 hooks 与状态栏，并原样透传你原本的状态栏输出。你的文件会备份为 settings.json.agentdock-backup。",
      integrationsCodex: "向 config.toml 追加一行 notify，并跟随本地会话日志推断进度。",
      integrationsCursor: "添加 hooks、跟随实时 transcript，并读取本地存储获取状态与用量。",
      privacyIndex: "06 / 隐私",
      privacyTitle: "你的工作留在你的 Mac 上。",
      privacyOneTerm: "默认本地",
      privacyOneDesc: "会话内容、文件路径与 token 详情都留在你的 Mac 上。",
      privacyTwoTerm: "自动化",
      privacyTwoDesc: "自动化（Apple 事件）仅用于把你带回正确的工作区。",
      privacyThreeTerm: "辅助功能",
      privacyThreeDesc: "辅助功能仅用于协助受支持的审批——仅 Codex 与 Cursor。",
      privacyFourTerm: "遥测",
      privacyFourDesc: "有限遥测使用安装级标识，仅包含启动、版本、系统、架构与崩溃元数据，不包含会话内容或文件路径。",
      downloadTitle: "把你的 Agent 放进刘海。",
      downloadMeta: "macOS 14+ · 通用版 · 免费",
    },
  };

  function detectLanguage() {
    const browserLanguage = navigator.language.startsWith("zh") ? "zh" : "en";
    try {
      return localStorage.getItem("agentdock-language") || browserLanguage;
    } catch {
      return browserLanguage;
    }
  }

  let currentLanguage = detectLanguage();
  const langButtons = document.querySelectorAll("[data-lang]");
  const i18nNodes = document.querySelectorAll("[data-i18n]");

  function setLanguage(nextLanguage) {
    const language = nextLanguage === "zh" ? "zh" : "en";
    currentLanguage = language;
    const dict = translations[currentLanguage];
    document.documentElement.lang = currentLanguage === "zh" ? "zh-CN" : "en";
    i18nNodes.forEach((node) => {
      const value = dict[node.dataset.i18n];
      if (value) node.textContent = value;
    });
    langButtons.forEach((button) =>
      button.setAttribute("aria-pressed", String(button.dataset.lang === currentLanguage))
    );
    if (notchToggle) {
      notchToggle.setAttribute("aria-label", translations[currentLanguage].notchToggleLabel);
    }
    if (menuButton) {
      menuButton.setAttribute("aria-label", translations[currentLanguage].navMenu);
    }
    if (mobileNav) {
      mobileNav.setAttribute("aria-label", translations[currentLanguage].mobileNavLabel);
    }
    try {
      localStorage.setItem("agentdock-language", currentLanguage);
    } catch {}
  }

  langButtons.forEach((button) =>
    button.addEventListener("click", () => setLanguage(button.dataset.lang))
  );

  const notchWrap = document.getElementById("notchWrap");
  const notchToggle = document.getElementById("notchToggle");
  const menuButton = document.getElementById("menuButton");
  const mobileNav = document.querySelector(".mobile-nav");
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
    notchWrap.addEventListener("focusin", () => setNotch(true));
    notchWrap.addEventListener("focusout", (event) => {
      if (!notchWrap.contains(event.relatedTarget) && !notchPinned) setNotch(false);
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && (notchPinned || notchWrap.classList.contains("is-open"))) {
        notchPinned = false;
        setNotch(false);
      }
    });
  }

  const approvalPanel = document.getElementById("approvalPanel");
  const approvalStatus = document.getElementById("approvalStatus");
  const approvalButtons = document.querySelectorAll("#approvalPanel [data-action]");
  const approvalKeyByState = {
    waiting: "approvalWaiting",
    approved: "approvalApproved",
    review: "approvalReview",
    denied: "approvalDenied",
  };
  const approvalStateByAction = {
    allow: "approved",
    review: "review",
    deny: "denied",
  };

  function setApproval(state) {
    const nextState = approvalKeyByState[state] ? state : "waiting";
    const key = approvalKeyByState[nextState];
    if (approvalPanel) approvalPanel.dataset.state = nextState;
    if (!approvalStatus) return;
    approvalStatus.dataset.i18n = key;
    approvalStatus.textContent = translations[currentLanguage][key];
    approvalButtons.forEach((button) =>
      button.setAttribute(
        "aria-pressed",
        String(approvalStateByAction[button.dataset.action] === nextState)
      )
    );
  }

  approvalButtons.forEach((button) =>
    button.addEventListener("click", () =>
      setApproval(approvalStateByAction[button.dataset.action])
    )
  );

  // --- Capability panels: hover/focus expanding accordion (progressive) ---
  // Pure DOM enhancement so the panels still read as four equal cards without
  // JavaScript. Active panel grows (CSS flex-basis), the rest shrink.
  const capabilityPanels = Array.from(document.querySelectorAll(".capability-panel"));
  const capabilityWrap = document.querySelector(".capability-panels");
  function setActivePanel(panel) {
    capabilityPanels.forEach((node) => node.classList.toggle("is-active", node === panel));
  }
  function clearActivePanels() {
    capabilityPanels.forEach((node) => node.classList.remove("is-active"));
  }
  capabilityPanels.forEach((panel) => {
    panel.addEventListener("mouseenter", () => setActivePanel(panel));
    panel.addEventListener("focusin", () => setActivePanel(panel));
  });
  if (capabilityWrap) {
    capabilityWrap.addEventListener("mouseleave", clearActivePanels);
    capabilityWrap.addEventListener("focusout", (event) => {
      if (!capabilityWrap.contains(event.relatedTarget)) clearActivePanels();
    });
  }

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const demoStates = ["running", "waiting", "usage"];
  const demoStateNodes = document.querySelectorAll("[data-demo-state]");
  let demoStatusIndex = 0;
  let statusTimer = null;

  function advanceDemoStatus() {
    demoStatusIndex = (demoStatusIndex + 1) % demoStates.length;
    demoStateNodes.forEach((node) => {
      node.dataset.activeState = demoStates[demoStatusIndex];
    });
  }

  function syncStatusCycle() {
    window.clearInterval(statusTimer);
    statusTimer = null;
    if (document.hidden || reducedMotion.matches) return;
    statusTimer = window.setInterval(advanceDemoStatus, 4200);
  }

  document.addEventListener("visibilitychange", syncStatusCycle);
  reducedMotion.addEventListener("change", syncStatusCycle);
  syncStatusCycle();

  const revealNodes = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reducedMotion.matches) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.16 });
    revealNodes.forEach((node) => observer.observe(node));
  } else {
    revealNodes.forEach((node) => node.classList.add("is-visible"));
  }

  // --- Adaptive navigation: 22vh condense, direction hide, chapter theme, indicator ---
  const header = document.getElementById("siteHeader");
  const navLinks = Array.from(document.querySelectorAll(".nav-link"));
  const navIndicator = document.querySelector(".nav-indicator");
  const navCenter = document.querySelector(".nav-center");
  const themedSections = Array.from(document.querySelectorAll("section[data-header]"));
  const condenseRatio = 0.22;
  const scrollHideDelta = 12;
  let lastScrollY = window.scrollY;
  let headerHidden = false;
  let navTicking = false;

  function currentTheme() {
    const probe = 48;
    let theme = "dark";
    for (const section of themedSections) {
      const rect = section.getBoundingClientRect();
      if (rect.top <= probe && rect.bottom > probe) {
        theme = section.dataset.header === "light" ? "light" : "dark";
      }
    }
    return theme;
  }

  function showHeader() {
    if (!headerHidden) return;
    headerHidden = false;
    header.classList.remove("is-hidden");
  }

  function hideHeader() {
    if (headerHidden) return;
    headerHidden = true;
    header.classList.add("is-hidden");
  }

  function updateHeader() {
    navTicking = false;
    if (!header) return;
    const y = window.scrollY;
    const vh = window.innerHeight;
    header.classList.toggle("is-condensed", y > vh * condenseRatio);
    header.dataset.header = currentTheme();
    if (y <= vh) {
      showHeader();
      lastScrollY = y;
      return;
    }
    const delta = y - lastScrollY;
    if (delta > scrollHideDelta) {
      hideHeader();
      lastScrollY = y;
    } else if (delta < 0) {
      showHeader();
      lastScrollY = y;
    }
  }

  function requestHeaderUpdate() {
    if (navTicking) return;
    navTicking = true;
    window.requestAnimationFrame(updateHeader);
  }

  if (header) {
    window.addEventListener("scroll", requestHeaderUpdate, { passive: true });
    window.addEventListener("resize", requestHeaderUpdate, { passive: true });
    updateHeader();
  }

  function moveIndicator(target) {
    if (!navIndicator || !navCenter || !target) return;
    const linkRect = target.getBoundingClientRect();
    const navRect = navCenter.getBoundingClientRect();
    navIndicator.style.width = `${linkRect.width}px`;
    navIndicator.style.transform = `translateX(${linkRect.left - navRect.left}px)`;
    navIndicator.style.opacity = "1";
  }

  function hideIndicator() {
    if (navIndicator) navIndicator.style.opacity = "0";
  }

  navLinks.forEach((link) => {
    link.addEventListener("mouseenter", () => moveIndicator(link));
    link.addEventListener("focus", () => moveIndicator(link));
  });
  if (navCenter) {
    navCenter.addEventListener("mouseleave", hideIndicator);
    navCenter.addEventListener("focusout", (event) => {
      if (!navCenter.contains(event.relatedTarget)) hideIndicator();
    });
  }

  // --- Mobile full-screen menu: focus trap, inert, Escape ---
  const mobileMenu = document.getElementById("mobileMenu");
  const mainEl = document.getElementById("main");
  const footerEl = document.querySelector("footer");
  let menuOpen = false;

  function menuFocusables() {
    return mobileMenu
      ? Array.from(mobileMenu.querySelectorAll('a[href], button:not([disabled])'))
      : [];
  }

  function focusHashTarget(hash) {
    if (!hash || hash === "#") return false;
    let targetId;
    try {
      targetId = decodeURIComponent(hash.slice(1));
    } catch {
      return false;
    }
    const target = document.getElementById(targetId);
    if (!target) return false;
    const hadTabindex = target.hasAttribute("tabindex");
    if (!hadTabindex) {
      target.setAttribute("tabindex", "-1");
      target.addEventListener(
        "blur",
        () => target.removeAttribute("tabindex"),
        { once: true }
      );
    }
    target.focus({ preventScroll: true });
    target.scrollIntoView();
    return document.activeElement === target;
  }

  function setMenu(open, { restoreFocus = !open } = {}) {
    if (!mobileMenu || !menuButton) return;
    const wasOpen = menuOpen;
    menuOpen = open;
    mobileMenu.classList.toggle("is-open", open);
    mobileMenu.setAttribute("aria-hidden", String(!open));
    menuButton.setAttribute("aria-expanded", String(open));
    if (open) {
      mobileMenu.removeAttribute("inert");
      if (mainEl) mainEl.setAttribute("inert", "");
      if (footerEl) footerEl.setAttribute("inert", "");
      const focusables = menuFocusables();
      // Focus on the next frame so the menu is rendered visible and focusable.
      if (focusables[0]) {
        window.requestAnimationFrame(() => {
          if (menuOpen) focusables[0].focus();
        });
      }
    } else {
      mobileMenu.setAttribute("inert", "");
      if (mainEl) mainEl.removeAttribute("inert");
      if (footerEl) footerEl.removeAttribute("inert");
      if (wasOpen && restoreFocus) menuButton.focus();
    }
  }

  if (mobileMenu && menuButton) {
    menuButton.addEventListener("click", () => setMenu(!menuOpen));
    mobileMenu.querySelectorAll(".mobile-link").forEach((link) => {
      link.addEventListener("click", (event) => {
        setMenu(false, { restoreFocus: false });
        if (!link.hash) return;
        const target = document.getElementById(link.hash.slice(1));
        if (!target) return;
        event.preventDefault();
        window.history.pushState(null, "", link.hash);
        focusHashTarget(link.hash);
      });
    });
    mobileMenu.addEventListener("keydown", (event) => {
      if (event.key === "Tab") {
        const focusables = menuFocusables();
        if (focusables.length === 0) return;
        const first = focusables[0];
        const last = focusables[focusables.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && menuOpen) {
        setMenu(false);
      }
    });
  }

  // --- Intro curtain: 0→100 progress then clip upward; skip reduced motion / <=680 ---
  const curtain = document.getElementById("introCurtain");
  const curtainCount = document.getElementById("curtainCount");
  const rootEl = document.documentElement;
  const curtainLifecycle = { state: "pending" };
  window.AgentDockCurtain = curtainLifecycle;

  function publishCurtainState(state, eventName) {
    curtainLifecycle.state = state;
    document.dispatchEvent(new CustomEvent(eventName, { detail: { state } }));
  }

  function runCurtain() {
    if (!curtain || reducedMotion.matches || window.innerWidth <= 680) {
      publishCurtainState("skipped", "agentdock:curtain-skipped");
      return;
    }
    curtainLifecycle.state = "running";
    rootEl.classList.add("curtain-active");
    const start = performance.now();
    const duration = 1400;
    let finished = false;
    let completed = false;

    function finish() {
      if (finished) return;
      finished = true;
      publishCurtainState("exiting", "agentdock:curtain-exit-start");
      curtain.classList.add("is-done");
      const cleanup = () => {
        rootEl.classList.remove("curtain-active");
        if (completed) return;
        completed = true;
        publishCurtainState("complete", "agentdock:curtain-complete");
      };
      curtain.addEventListener("transitionend", cleanup, { once: true });
      setTimeout(cleanup, 900);
    }

    function tick(now) {
      const progress = Math.min(1, (now - start) / duration);
      if (curtainCount) curtainCount.textContent = String(Math.round(progress * 100));
      if (progress < 1) {
        window.requestAnimationFrame(tick);
      } else {
        finish();
      }
    }

    window.requestAnimationFrame(tick);
    // Resource timeout fallback so content is never trapped behind the curtain
    setTimeout(finish, 3500);
  }

  runCurtain();

  const AgentDockSite = {
    setLanguage,
    setNotch,
    setApproval,
    setMenu,
  };

  window.AgentDockSite = AgentDockSite;

  setLanguage(currentLanguage);
  setApproval("waiting");
})();
