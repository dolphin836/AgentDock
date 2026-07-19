// [skill: go-team-standards · dev-dna] Vokie 1:1 Task 3 — GSAP hero choreography.
// Drives the 1.9s particle convergence and the clip-path title entrance with a
// staggered bottom row. Task 4 extends this module with the reveal bands,
// pinned journey and chapter scroll orchestration. Content is only gated behind
// motion once GSAP is present and reduced motion is not requested, so a missing
// library or reduced-motion preference always leaves the hero fully visible.
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const gsap = window.gsap;
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

function startAfterCurtain() {
  initHeroMotion();
}

const curtainState = window.AgentDockCurtain && window.AgentDockCurtain.state;
if (curtainState === "skipped" || curtainState === "exiting" || curtainState === "complete") {
  startAfterCurtain();
} else {
  document.addEventListener("agentdock:curtain-exit-start", startAfterCurtain, { once: true });
  document.addEventListener("agentdock:curtain-skipped", startAfterCurtain, { once: true });
}

reducedMotion.addEventListener("change", () => {
  if (reducedMotion.matches) rollbackHeroMotion();
});
