(() => {
  "use strict";

  const translations = {
    en: {
      downloadShort: "Download",
      download: "Download for Mac",
      heroEyebrow: "Every agent, at a glance",
      heroLine1: "Your agents are working.",
      heroLine2: "You stay in flow.",
      heroDescription: "Live status, approvals, and usage in your macOS notch.",
    },
    zh: {
      downloadShort: "下载",
      download: "下载 Mac 版",
      heroEyebrow: "所有 Agent，一眼看清",
      heroLine1: "Agent 在工作。",
      heroLine2: "你保持专注。",
      heroDescription: "实时状态、审批与用量，都在 macOS 刘海里。",
    },
  };

  const AgentDockSite = {
    setLanguage() {},
    setNotch() {},
    setApproval() {},
  };

  window.AgentDockSite = AgentDockSite;
})();
