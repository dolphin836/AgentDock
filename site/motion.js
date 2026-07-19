// [skill: go-team-standards · dev-dna] Vokie 1:1 Task 3 — GSAP hero choreography.
// Drives the 1.9s particle convergence and the clip-path title entrance with a
// staggered bottom row. Task 4 extends this module with the reveal bands,
// pinned journey and chapter scroll orchestration. Content is only gated behind
// motion once GSAP is present and reduced motion is not requested, so a missing
// library or reduced-motion preference always leaves the hero fully visible.
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const gsap = window.gsap;

function initHeroMotion() {
  if (!gsap || reducedMotion.matches) return;

  document.documentElement.classList.add("motion-ready");

  const hero = window.AgentDockHero;
  if (hero && hero.mode === "webgl" && hero.uniforms && hero.uniforms.uProgress) {
    hero._driven = true;
    gsap.to(hero.uniforms.uProgress, {
      value: 1,
      duration: 1.9,
      ease: "power2.inOut",
    });
  }

  const lines = document.querySelectorAll(".hero-title .line");
  const bottom = document.querySelectorAll(".hero-bottom > *");
  const timeline = gsap.timeline({ delay: 0.15 });
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
}

initHeroMotion();
