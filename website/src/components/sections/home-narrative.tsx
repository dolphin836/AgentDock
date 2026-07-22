"use client";

import Image from "next/image";
import { ArrowDown, ArrowUpRight, Check, ShieldCheck } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { useLanguage } from "@/hooks/use-language";
import { DOWNLOAD_URL, RELEASE_VERSION } from "@/lib/release";

import styles from "./home-narrative.module.css";

const IMAGES = {
  overview: "/product/agent-overview.png",
  approval: "/product/approval.png",
  usage: "/product/usage.png",
  workspace: "/product/workspace.png",
} as const;

const COPY = {
  en: {
    label: "BUILT FOR PARALLEL AGENT WORK",
    mosaic: {
      title: "Stay in flow.\nYour agents stay in sight.",
      body: "AgentDock turns the Mac notch into a quiet command center for Claude Code, Codex, and Cursor — no window hunting, no lost approvals.",
      cards: [
        ["01", "Every session, one glance", "See what is running, waiting, or finished without leaving the work in front of you.", IMAGES.overview, "AgentDock overview showing Claude Code, Codex, and Cursor sessions", "carbon"],
        ["02", "Approve without context switching", "Review permission requests from the notch and keep the agent moving.", IMAGES.approval, "AgentDock approval prompt for a Codex command", "blue"],
        ["03", "Know your usage before it matters", "Track rolling limits across supported agents from one compact view.", IMAGES.usage, "AgentDock usage dashboard for supported coding agents", "coral"],
        ["04", "Return to the exact workspace", "One click takes you back to the terminal, editor, and task that needs you.", IMAGES.workspace, "AgentDock workspace return panel", "paper"],
      ],
    },
    convergence: {
      kicker: "ONE DOCK. THREE AGENTS.",
      title: "The small place where all your agent work comes together.",
      body: "Claude Code, Codex, and Cursor keep their own workflows. AgentDock gives them one shared surface on your Mac.",
      agents: ["Claude Code", "Codex", "Cursor"],
    },
    tabs: {
      kicker: "ALWAYS PRESENT, NEVER IN THE WAY",
      title: "The signal you need.\nNothing you don’t.",
      body: "A native surface that appears when there is something worth seeing, then gets out of your way.",
      items: [
        ["status", "Live status", "Read the room in one glance.", "Running, waiting, and completed sessions stay visible in a compact agent overview.", IMAGES.overview, "Live AgentDock status overview"],
        ["approval", "Approvals", "Unblock an agent from the notch.", "See the request, inspect the command, and decide without searching for the right window.", IMAGES.approval, "AgentDock approval request"],
        ["usage", "Usage", "Keep limits in view.", "Understand five-hour and seven-day usage before an active session hits a wall.", IMAGES.usage, "AgentDock usage metrics"],
        ["return", "One-click return", "Go straight back to the work.", "Reopen the exact editor or terminal context instead of retracing your steps.", IMAGES.workspace, "AgentDock workspace return actions"],
      ],
    },
    journey: {
      kicker: "FROM PROMPT TO DONE",
      title: "Your agents keep moving.\nYou keep your train of thought.",
      body: "AgentDock follows the moments that actually need attention and leaves the rest alone.",
      cards: [
        ["01 · MONITOR", "Start anywhere", "Claude Code, Codex, and Cursor appear automatically as their sessions become active.", IMAGES.overview, "AgentDock monitoring active sessions"],
        ["02 · REVIEW", "Catch the handoff", "When an agent pauses for permission, the notch changes from passive status to a clear decision.", IMAGES.approval, "AgentDock permission review"],
        ["03 · TRACK", "See the runway", "Usage stays close enough to check without becoming another dashboard to manage.", IMAGES.usage, "AgentDock agent usage tracking"],
        ["04 · RETURN", "Land where you left off", "Jump back into the workspace that changed, already knowing why it needs you.", IMAGES.workspace, "AgentDock returning to an active workspace"],
      ],
    },
    outcomes: {
      kicker: "A CALMER CONTROL LOOP",
      title: "Less checking.\nMore shipping.",
      body: "AgentDock compresses the repetitive parts of supervising agents into a few precise moments.",
      items: [
        ["Know what changed", "A single, readable status surface replaces the habit of reopening every terminal and editor.", IMAGES.overview, "AgentDock agent status summary"],
        ["Respond at the right moment", "Approval prompts arrive where your eyes already are, with enough context to make the call.", IMAGES.approval, "AgentDock approval controls"],
        ["Protect your focus", "After the decision, one click returns you to the right workspace instead of the search for it.", IMAGES.workspace, "AgentDock return-to-workspace controls"],
      ],
    },
    integrations: {
      kicker: "THE AGENTS YOU ALREADY USE",
      title: "Three workflows.\nOne native surface.",
      body: "AgentDock is deliberately focused on deep support for the tools it understands today.",
      agents: [
        ["Claude Code", "RUNNING", "Session activity, tool calls, approvals, and fast workspace return.", "green"],
        ["Codex", "WAITING", "Active tasks, command approvals, usage context, and direct return.", "amber"],
        ["Cursor", "READY", "Editor-aware activity and a clear path back to the project in progress.", "blue"],
      ],
    },
    memory: {
      kicker: "LIMITS WITHOUT THE GUESSWORK",
      title: "Know the runway before the agent stops.",
      body: "Five-hour and seven-day usage stay readable across your supported agents, so you can plan the next task with real context.",
      points: ["One view for Claude Code, Codex, and Cursor", "Clear reset windows and current utilization", "Native Swift performance with a compact footprint"],
    },
    privacy: {
      kicker: "LOCAL BY DEFAULT",
      title: "Your agent work stays on your Mac.",
      body: "Session content is processed locally. AgentDock does not require an account and does not send prompts, code, or approval details to an external service.",
      badge: "NO ACCOUNT · NO SESSION-CONTENT TELEMETRY",
    },
    final: {
      kicker: "AGENTDOCK FOR MACOS",
      title: "Keep every agent close.\nKeep your attention yours.",
      body: "A native command center for Claude Code, Codex, and Cursor — built into the place that is always in view.",
      action: "Download for Mac",
      note: "macOS · Apple silicon",
    },
  },
  zh: {
    label: "为多 AGENT 并行工作而生",
    mosaic: {
      title: "保持心流。\n所有 Agent 都在视野里。",
      body: "AgentDock 把 Mac 刘海变成 Claude Code、Codex 与 Cursor 的安静控制中心：不用找窗口，也不会错过审批。",
      cards: [
        ["01", "所有会话，一眼掌握", "无需离开当前工作，就能看到谁在运行、等待或已经完成。", IMAGES.overview, "AgentDock 同时展示 Claude Code、Codex 和 Cursor 会话", "carbon"],
        ["02", "不切换上下文，也能审批", "直接在刘海里查看权限请求，让 Agent 继续向前。", IMAGES.approval, "AgentDock 中的 Codex 命令审批", "blue"],
        ["03", "用量触顶前，提前知道", "在一个紧凑视图里查看已支持 Agent 的滚动用量限制。", IMAGES.usage, "AgentDock Agent 用量面板", "coral"],
        ["04", "回到准确的工作现场", "点击一次，直接回到需要你的终端、编辑器与任务。", IMAGES.workspace, "AgentDock 工作区返回面板", "paper"],
      ],
    },
    convergence: {
      kicker: "一个 DOCK，三个 AGENT",
      title: "所有 Agent 工作，在这个小小的地方汇合。",
      body: "Claude Code、Codex 和 Cursor 保留各自的工作流，AgentDock 为它们提供一个共享的 Mac 界面。",
      agents: ["Claude Code", "Codex", "Cursor"],
    },
    tabs: {
      kicker: "始终可见，从不碍事",
      title: "只给你必要的信号。\n没有多余打扰。",
      body: "只有值得关注时才出现，处理完后立刻退场的原生界面。",
      items: [
        ["status", "实时状态", "一眼看清全局。", "运行中、等待中与已完成的会话，都收进紧凑的 Agent 总览。", IMAGES.overview, "AgentDock 实时状态总览"],
        ["approval", "授权审批", "直接在刘海里解除阻塞。", "查看请求与命令，做出决定，不再满屏寻找正确的窗口。", IMAGES.approval, "AgentDock 审批请求"],
        ["usage", "用量", "让限制始终心中有数。", "在活跃会话触顶前，看清五小时和七天用量窗口。", IMAGES.usage, "AgentDock 用量指标"],
        ["return", "一键返回", "直接回到正在发生的工作。", "重新打开准确的编辑器或终端上下文，不必沿路寻找。", IMAGES.workspace, "AgentDock 工作区返回操作"],
      ],
    },
    journey: {
      kicker: "从提示词到完成",
      title: "Agent 持续前进。\n你的思路不被打断。",
      body: "AgentDock 只跟随真正需要关注的时刻，其余时间保持安静。",
      cards: [
        ["01 · 监控", "从任何地方开始", "Claude Code、Codex 和 Cursor 的会话活跃时，会自动出现在 AgentDock。", IMAGES.overview, "AgentDock 监控活跃会话"],
        ["02 · 审批", "接住需要你的时刻", "当 Agent 因权限而暂停，刘海会从被动状态变成清晰的决策界面。", IMAGES.approval, "AgentDock 权限审批"],
        ["03 · 用量", "看清剩余空间", "用量离你足够近，又不会变成另一个需要维护的仪表盘。", IMAGES.usage, "AgentDock Agent 用量追踪"],
        ["04 · 返回", "落回原来的现场", "直接跳回发生变化的工作区，而且已经知道它为什么需要你。", IMAGES.workspace, "AgentDock 返回活跃工作区"],
      ],
    },
    outcomes: {
      kicker: "更安静的控制回路",
      title: "少一点检查。\n多一点交付。",
      body: "AgentDock 把监督 Agent 的重复动作，压缩成几个准确的关键时刻。",
      items: [
        ["知道哪里发生了变化", "一个清晰的状态界面，取代反复打开每个终端与编辑器。", IMAGES.overview, "AgentDock Agent 状态摘要"],
        ["在正确的时刻回应", "审批请求出现在视线所在的位置，并提供足够上下文帮你做决定。", IMAGES.approval, "AgentDock 审批控制"],
        ["保护你的专注力", "做完决定后，一键回到正确的工作区，而不是继续寻找它。", IMAGES.workspace, "AgentDock 返回工作区控制"],
      ],
    },
    integrations: {
      kicker: "你已经在使用的 AGENT",
      title: "三种工作流。\n一个原生界面。",
      body: "AgentDock 专注于把今天真正理解的工具做深、做好。",
      agents: [
        ["Claude Code", "运行中", "会话活动、工具调用、授权审批与快速返回工作区。", "green"],
        ["Codex", "等待中", "活跃任务、命令审批、用量上下文与直接返回。", "amber"],
        ["Cursor", "已就绪", "感知编辑器活动，并清晰返回正在进行的项目。", "blue"],
      ],
    },
    memory: {
      kicker: "不用猜的用量限制",
      title: "在 Agent 停下前，看清还剩多少空间。",
      body: "五小时与七天用量集中展示，让你在安排下一个任务时真正有数。",
      points: ["Claude Code、Codex 与 Cursor 集中在一个视图", "清晰展示重置窗口与当前占用", "原生 Swift 性能与紧凑资源占用"],
    },
    privacy: {
      kicker: "默认本地运行",
      title: "你的 Agent 工作留在自己的 Mac 上。",
      body: "会话内容在本地处理。AgentDock 无需账号，也不会把提示词、代码或审批详情发送到外部服务。",
      badge: "无需账号 · 不采集会话内容",
    },
    final: {
      kicker: "适用于 MACOS 的 AGENTDOCK",
      title: "让所有 Agent 近在眼前。\n让注意力始终属于你。",
      body: "Claude Code、Codex 与 Cursor 的原生控制中心，就在你一直看得见的地方。",
      action: "下载 Mac 版",
      note: "macOS · Apple 芯片",
    },
  },
} as const;

function SectionHeading({ body, kicker, title }: { body: string; kicker: string; title: string }) {
  return (
    <div className={styles.sectionHeading} data-reveal>
      <p className={styles.kicker}>{kicker}</p>
      <h2>{title.split("\n").map((line) => <span key={line}>{line}</span>)}</h2>
      <p className={styles.lead}>{body}</p>
    </div>
  );
}

export function HomeNarrative() {
  const language = useLanguage();
  const copy = COPY[language];
  const [activeTab, setActiveTab] = useState(0);
  const [activeOutcome, setActiveOutcome] = useState(0);
  const journeyRef = useRef<HTMLElement>(null);
  const journeyTrackRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let frame = 0;
    const update = () => {
      frame = 0;
      const section = journeyRef.current;
      const track = journeyTrackRef.current;
      if (!section || !track) return;
      if (window.innerWidth <= 900) {
        track.style.transform = "none";
        return;
      }
      const rect = section.getBoundingClientRect();
      const range = Math.max(section.offsetHeight - window.innerHeight, 1);
      const progress = Math.min(Math.max(-rect.top / range, 0), 1);
      const travel = Math.max(track.scrollWidth - window.innerWidth + 80, 0);
      track.style.transform = `translate3d(${-travel * progress}px, 0, 0)`;
    };
    const requestUpdate = () => {
      if (!frame) frame = window.requestAnimationFrame(update);
    };
    const observer = new ResizeObserver(requestUpdate);
    if (journeyRef.current) observer.observe(journeyRef.current);
    if (journeyTrackRef.current) observer.observe(journeyTrackRef.current);
    window.addEventListener("scroll", requestUpdate, { passive: true });
    window.addEventListener("resize", requestUpdate);
    update();
    return () => {
      if (frame) window.cancelAnimationFrame(frame);
      observer.disconnect();
      window.removeEventListener("scroll", requestUpdate);
      window.removeEventListener("resize", requestUpdate);
    };
  }, []);

  const tab = copy.tabs.items[activeTab];
  const outcome = copy.outcomes.items[activeOutcome];

  return (
    <>
      <section className={`${styles.lightSection} ${styles.mosaicSection}`} data-header="light" id="product">
        <div className={styles.container}>
          <SectionHeading body={copy.mosaic.body} kicker={copy.label} title={copy.mosaic.title} />
          <div className={styles.mosaic}>
            {copy.mosaic.cards.map(([index, title, body, image, alt, tone]) => (
              <article className={`${styles.mosaicCard} ${styles[`tone_${tone}`]}`} data-reveal key={index}>
                <div className={styles.mosaicCopy}>
                  <p className={styles.cardIndex}>{index}</p>
                  <h3>{title}</h3>
                  <p>{body}</p>
                </div>
                <div className={styles.mosaicImage}><Image alt={alt} fill loading="eager" sizes="(max-width: 900px) 92vw, 46vw" src={image} /></div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className={`${styles.lightSection} ${styles.convergenceSection}`} data-header="light" id="context-focus">
        <div className={styles.container}>
          <div className={styles.convergenceCopy} data-reveal>
            <p className={styles.kicker}>{copy.convergence.kicker}</p>
            <h2>{copy.convergence.title}</h2>
            <p>{copy.convergence.body}</p>
          </div>
          <div className={styles.convergenceStage} data-reveal>
            <div className={styles.agentRail}>
              {copy.convergence.agents.map((agent, index) => (
                <div className={styles.agentNode} key={agent}><span className={styles.agentDot} data-agent={index} /><span>{agent}</span></div>
              ))}
            </div>
            <div className={styles.dockMark}><span className={styles.dockLine} /><Image alt="AgentDock" height={92} src="/app-icon.png" width={92} /><span>AGENTDOCK</span></div>
          </div>
        </div>
      </section>

      <section className={`${styles.lightSection} ${styles.tabsSection}`} data-header="light" id="voice">
        <div className={styles.container}>
          <SectionHeading body={copy.tabs.body} kicker={copy.tabs.kicker} title={copy.tabs.title} />
          <div className={styles.productTabs}>
            <div className={styles.tabList} role="tablist" aria-label={copy.tabs.kicker}>
              {copy.tabs.items.map((item, index) => (
                <button aria-controls={`feature-panel-${item[0]}`} aria-selected={activeTab === index} className={styles.tabButton} id={`feature-tab-${item[0]}`} key={item[0]} onClick={() => setActiveTab(index)} role="tab" type="button">
                  <span>{item[1]}</span><span aria-hidden="true">0{index + 1}</span>
                </button>
              ))}
            </div>
            <div aria-labelledby={`feature-tab-${tab[0]}`} className={styles.tabPanel} id={`feature-panel-${tab[0]}`} role="tabpanel" tabIndex={0}>
              <div className={styles.tabPanelCopy}><p className={styles.kicker}>{tab[1]}</p><h3>{tab[2]}</h3><p>{tab[3]}</p></div>
              <div className={styles.tabPanelImage}><Image alt={tab[5]} fill key={tab[4]} loading="eager" sizes="(max-width: 900px) 94vw, 64vw" src={tab[4]} /></div>
            </div>
          </div>
        </div>
      </section>

      <section className={styles.journeySection} data-header="dark" id="meeting" ref={journeyRef}>
        <div className={styles.journeySticky}>
          <div className={styles.journeyHeader}>
            <p className={styles.kicker}>{copy.journey.kicker}</p>
            <h2>{copy.journey.title.split("\n").map((line) => <span key={line}>{line}</span>)}</h2>
            <p>{copy.journey.body}</p>
            <ArrowDown aria-hidden="true" size={22} strokeWidth={1.5} />
          </div>
          <div className={styles.journeyTrack} ref={journeyTrackRef}>
            {copy.journey.cards.map(([step, title, body, image, alt]) => (
              <article className={styles.journeyCard} key={step}>
                <div className={styles.journeyCardCopy}><p className={styles.kicker}>{step}</p><h3>{title}</h3><p>{body}</p></div>
                <div className={styles.journeyImage}><Image alt={alt} fill loading="eager" sizes="(max-width: 900px) 92vw, 760px" src={image} /></div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className={`${styles.lightSection} ${styles.outcomesSection}`} data-header="light" id="context">
        <div className={styles.container}>
          <SectionHeading body={copy.outcomes.body} kicker={copy.outcomes.kicker} title={copy.outcomes.title} />
          <div className={styles.outcomesGrid}>
            <div className={styles.outcomesList}>
              {copy.outcomes.items.map((item, index) => {
                const active = activeOutcome === index;
                return (
                  <div className={styles.outcomeItem} data-active={active} key={item[0]}>
                    <button aria-expanded={active} className={styles.outcomeButton} onClick={() => setActiveOutcome(index)} type="button"><span>0{index + 1}</span><strong>{item[0]}</strong><span aria-hidden="true">{active ? "−" : "+"}</span></button>
                    <div className={styles.outcomeBody}><p>{item[1]}</p></div>
                  </div>
                );
              })}
            </div>
            <div className={styles.outcomeImage}><Image alt={outcome[3]} fill key={outcome[2]} loading="eager" sizes="(max-width: 900px) 94vw, 54vw" src={outcome[2]} /></div>
          </div>
        </div>
      </section>

      <section className={`${styles.darkSection} ${styles.integrationsSection}`} data-header="dark" id="integrations">
        <div className={styles.container}>
          <SectionHeading body={copy.integrations.body} kicker={copy.integrations.kicker} title={copy.integrations.title} />
          <div className={styles.agentCards}>
            {copy.integrations.agents.map(([name, status, detail, accent], index) => (
              <article className={styles.agentCard} data-reveal key={name}>
                <div className={styles.agentCardTop}><span className={styles.agentStatusDot} data-accent={accent} /><span>{status}</span><span>0{index + 1}</span></div>
                <div className={styles.agentCardCenter}><Image alt="" aria-hidden="true" height={72} src="/app-icon.png" width={72} /><h3>{name}</h3></div>
                <p>{detail}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className={`${styles.darkSection} ${styles.memorySection}`} data-header="dark" id="memory">
        <div className={styles.container}>
          <div className={styles.memoryGrid}>
            <div className={styles.memoryCopy} data-reveal>
              <p className={styles.kicker}>{copy.memory.kicker}</p><h2>{copy.memory.title}</h2><p>{copy.memory.body}</p>
              <ul>{copy.memory.points.map((point) => <li key={point}><Check aria-hidden="true" size={16} />{point}</li>)}</ul>
            </div>
            <div className={styles.memoryImage} data-reveal><Image alt="AgentDock usage dashboard" fill loading="eager" sizes="(max-width: 900px) 94vw, 62vw" src={IMAGES.usage} /></div>
          </div>
        </div>
      </section>

      <section className={`${styles.lightSection} ${styles.privacySection}`} data-header="light" id="privacy">
        <div className={styles.container}>
          <div className={styles.privacyMark} data-reveal><ShieldCheck aria-hidden="true" size={52} strokeWidth={1.2} /></div>
          <div className={styles.privacyCopy} data-reveal><p className={styles.kicker}>{copy.privacy.kicker}</p><h2>{copy.privacy.title}</h2><p>{copy.privacy.body}</p><span>{copy.privacy.badge}</span></div>
        </div>
      </section>

      <section className={styles.finalSection} data-header="dark" data-version={RELEASE_VERSION} id="download">
        <div className={styles.finalMedia}><Image alt="AgentDock ready to return to an active agent workspace" fill loading="eager" sizes="(max-width: 900px) 100vw, 50vw" src={IMAGES.workspace} /></div>
        <div className={styles.finalCopy}><p className={styles.kicker}>{copy.final.kicker}</p><h2 id="final-cta-heading">{copy.final.title.split("\n").map((line) => <span key={line}>{line}</span>)}</h2><p>{copy.final.body}</p><a href={DOWNLOAD_URL}>{copy.final.action}<ArrowUpRight aria-hidden="true" size={18} strokeWidth={1.5} /></a><span>v{RELEASE_VERSION} · {copy.final.note}</span></div>
      </section>
    </>
  );
}

export default HomeNarrative;
