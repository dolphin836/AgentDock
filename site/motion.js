// [skill: go-team-standards · dev-dna] Vokie 1:1 Task 3 — GSAP hero choreography.
// Drives the 1.9s particle convergence and the clip-path title entrance with a
// staggered bottom row. Task 4 extends this module with the reveal bands,
// pinned journey and chapter scroll orchestration. Content is only gated behind
// motion once GSAP is present and reduced motion is not requested, so a missing
// library or reduced-motion preference always leaves the hero fully visible.
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const gsap = window.gsap;
const ScrollTrigger = window.ScrollTrigger;
if (gsap && ScrollTrigger && typeof gsap.registerPlugin === "function") {
  try {
    gsap.registerPlugin(ScrollTrigger);
  } catch {
    /* leave chapters un-animated; content stays fully visible */
  }
}
const root = document.documentElement;
const lines = Array.from(document.querySelectorAll(".hero-title .line"));
const bottom = Array.from(document.querySelectorAll(".hero-bottom > *"));
let timeline = null;
let particleTween = null;
let motionStarted = false;

function showHeroFinalState() {
  root.classList.remove("motion-ready");
  lines.forEach((node) => {
    node.style.clipPath = "none";
    node.style.transform = "none";
  });
  bottom.forEach((node) => {
    node.style.opacity = "1";
    node.style.transform = "none";
  });
}

function rollbackHeroMotion() {
  if (timeline && typeof timeline.kill === "function") timeline.kill();
  if (particleTween && typeof particleTween.kill === "function") particleTween.kill();
  timeline = null;
  particleTween = null;
  showHeroFinalState();
  const hero = window.AgentDockHero;
  if (hero && typeof hero.beginFallbackConvergence === "function") {
    hero._driven = false;
    hero.beginFallbackConvergence();
  }
}

function initHeroMotion() {
  if (motionStarted || reducedMotion.matches) return;
  motionStarted = true;

  if (!gsap) {
    rollbackHeroMotion();
    return;
  }

  try {
    // Build every animation successfully before adding `.motion-ready`.
    // If GSAP throws anywhere, catch/rollback leaves default content visible.
    timeline = gsap.timeline({ paused: true, delay: 0.15 });
    timeline.to(lines, {
      clipPath: "inset(0 0 0% 0)",
      y: 0,
      duration: 1.0,
      stagger: 0.12,
      ease: "power3.out",
    });
    timeline.to(
      bottom,
      {
        opacity: 1,
        y: 0,
        duration: 0.8,
        stagger: 0.14,
        ease: "power2.out",
      },
      "-=0.5"
    );

    const hero = window.AgentDockHero;
    if (hero && hero.mode === "webgl" && hero.uniforms && hero.uniforms.uProgress) {
      particleTween = gsap.to(hero.uniforms.uProgress, {
        value: 1,
        duration: 1.9,
        ease: "power2.inOut",
        paused: true,
      });
    }

    root.classList.add("motion-ready");
    requestAnimationFrame(() => {
      if (reducedMotion.matches) {
        rollbackHeroMotion();
        return;
      }
      try {
        timeline.play();
        if (particleTween) {
          particleTween.play();
          if (hero) hero._driven = true;
        }
      } catch {
        rollbackHeroMotion();
      }
    });
  } catch {
    rollbackHeroMotion();
  }
}

// --- Task 4: chapter choreography (reveal band, pinned journey, lines) ---
// Every scroll-bound animation is additive: it only sets initial hidden/clipped
// states through GSAP itself, so a missing library, a thrown error, or
// reduced-motion always leaves the underlying content fully visible.
let chapterTriggers = [];
let chaptersStarted = false;

function initChapters() {
  if (chaptersStarted) return;
  chaptersStarted = true;
  if (!gsap || !ScrollTrigger || reducedMotion.matches) return;

  try {
    // First light chapter reveals from the right via clip-path (design §6).
    const bandInner = document.querySelector("#value .reveal-band-inner");
    const bandSection = document.getElementById("value");
    if (bandInner && bandSection) {
      const revealTween = gsap.fromTo(
        bandInner,
        { clipPath: "inset(0 100% 0 0)" },
        {
          clipPath: "inset(0 0% 0 0)",
          ease: "none",
          scrollTrigger: {
            trigger: bandSection,
            start: "top bottom",
            end: "top 42%",
            scrub: 1,
          },
        }
      );
      if (revealTween.scrollTrigger) chapterTriggers.push(revealTween.scrollTrigger);
    }

    // Integrations background: five vertical lines grow from scaleY(.2) (§5.3).
    const lineSpans = Array.from(document.querySelectorAll("#integrations .context-lines span"));
    const integrations = document.getElementById("integrations");
    if (lineSpans.length && integrations) {
      const linesTween = gsap.fromTo(
        lineSpans,
        { scaleY: 0.2 },
        {
          scaleY: 1,
          ease: "none",
          stagger: 0.04,
          scrollTrigger: {
            trigger: integrations,
            start: "top bottom",
            end: "top 45%",
            scrub: 1,
          },
        }
      );
      if (linesTween.scrollTrigger) chapterTriggers.push(linesTween.scrollTrigger);
    }

    // Workflow journey: pin + horizontal track only when there is room (§6).
    initJourney();

    ScrollTrigger.refresh();
  } catch {
    teardownChapters();
  }
}

function initJourney() {
  const section = document.getElementById("journey");
  const viewport = document.getElementById("journeyViewport");
  const track = document.getElementById("journeyTrack");
  const bar = document.querySelector("#journeyProgress .journey-progress-bar");
  if (!section || !viewport || !track) return;

  const wideEnough = window.matchMedia("(min-width: 901px)").matches;
  const tallEnough = window.innerHeight >= 700;
  if (!wideEnough || !tallEnough || reducedMotion.matches) return; // vertical degrade

  section.classList.add("is-pinned");
  // Measure after the row layout is applied.
  const overflow = Math.max(0, track.scrollWidth - viewport.clientWidth);
  const distance = Math.max(overflow, window.innerHeight);

  const journeyTween = gsap.to(track, {
    x: -overflow,
    ease: "none",
    scrollTrigger: {
      trigger: viewport,
      start: "top top",
      end: "+=" + distance,
      pin: true,
      scrub: 1,
      invalidateOnRefresh: true,
      onUpdate: (self) => {
        if (bar) bar.style.transform = "scaleX(" + self.progress + ")";
      },
    },
  });
  if (journeyTween.scrollTrigger) chapterTriggers.push(journeyTween.scrollTrigger);
}

function teardownChapters() {
  chapterTriggers.forEach((trigger) => {
    if (trigger && typeof trigger.kill === "function") trigger.kill(true);
  });
  chapterTriggers = [];
  const bandInner = document.querySelector("#value .reveal-band-inner");
  if (bandInner) bandInner.style.clipPath = "none";
  const journey = document.getElementById("journey");
  if (journey) journey.classList.remove("is-pinned");
  const track = document.getElementById("journeyTrack");
  if (track) track.style.transform = "none";
  document.querySelectorAll("#integrations .context-lines span").forEach((span) => {
    span.style.transform = "scaleY(1)";
  });
}

// --- Second particle field: lazy import with capable-device idle preload ---
let contextRequested = false;
function loadContextScene() {
  if (contextRequested) return;
  contextRequested = true;
  import("./context-particles.js").catch(() => {
    /* scene is optional: on failure the masked paper background remains */
  });
}

function armContextScene() {
  const section = document.getElementById("context");
  if (!section) return;
  const saveData = !!(navigator.connection && navigator.connection.saveData);
  const lowMemory =
    typeof navigator.deviceMemory === "number" && navigator.deviceMemory <= 4;
  const lowCpu =
    typeof navigator.hardwareConcurrency === "number" &&
    navigator.hardwareConcurrency <= 4;
  const constrained = saveData || lowMemory || lowCpu;

  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          io.disconnect();
          loadContextScene();
        }
      },
      { rootMargin: "300px 0px" }
    );
    io.observe(section);
  } else {
    loadContextScene();
  }

  // Capable devices warm the module during idle time; constrained devices wait
  // until the section approaches the viewport (design §5.2 tiering).
  if (!constrained) {
    if ("requestIdleCallback" in window) {
      requestIdleCallback(() => loadContextScene(), { timeout: 2500 });
    } else {
      setTimeout(loadContextScene, 1200);
    }
  }
}
armContextScene();

let chapterResizeTimer = null;
window.addEventListener(
  "resize",
  () => {
    if (!chaptersStarted || reducedMotion.matches || !ScrollTrigger) return;
    window.clearTimeout(chapterResizeTimer);
    chapterResizeTimer = window.setTimeout(() => {
      try {
        ScrollTrigger.refresh();
      } catch {
        /* ignore refresh failures */
      }
    }, 200);
  },
  { passive: true }
);

function startAfterCurtain() {
  initHeroMotion();
  initChapters();
}

const curtainState = window.AgentDockCurtain && window.AgentDockCurtain.state;
if (curtainState === "skipped" || curtainState === "exiting" || curtainState === "complete") {
  startAfterCurtain();
} else {
  document.addEventListener("agentdock:curtain-exit-start", startAfterCurtain, { once: true });
  document.addEventListener("agentdock:curtain-skipped", startAfterCurtain, { once: true });
}

reducedMotion.addEventListener("change", () => {
  if (reducedMotion.matches) {
    rollbackHeroMotion();
    teardownChapters();
  }
});
