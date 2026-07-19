// [skill: go-team-standards · dev-dna] Vokie 1:1 Task 3 — one-viewport particle hero.
// A Three.js point cloud interpolates each particle between a scattered
// position and an original AgentDock structured shape (a rounded macOS notch
// flanked by two status bands) through a shader `uProgress` uniform. GSAP in
// motion.js drives the 1.9s convergence; this module owns the scene, breathing,
// mouse perturbation, DPR cap, visibility/offscreen pausing and the WebGL
// failure fallback. No Vokie shapes or assets are reproduced.
import * as THREE from "./vendor/three.module.min.js";

const heroSection = document.getElementById("top");
const canvas = document.getElementById("heroCanvas");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const coarsePointer = window.matchMedia("(pointer: coarse)");

// --- Device tier: 2200 particles on capable desktops, 1200 otherwise ---
function chooseCount() {
  const narrow = window.innerWidth <= 900;
  const saveData = !!(navigator.connection && navigator.connection.saveData);
  const lowMemory =
    typeof navigator.deviceMemory === "number" && navigator.deviceMemory <= 4;
  const lowCpu =
    typeof navigator.hardwareConcurrency === "number" &&
    navigator.hardwareConcurrency <= 4;
  const lowPerf =
    narrow || coarsePointer.matches || saveData || lowMemory || lowCpu;
  return lowPerf ? 1200 : 2200;
}

// --- Structured shape: original AgentDock notch + two status bands ---
// Composition lives in shape space roughly x∈[-1.35,1.35], y∈[-0.2,0.3].
function buildStructured(target, count) {
  const cx = 0;
  const cy = 0.06;
  const hw = 0.6; // notch half width
  const hh = 0.23; // notch half height
  const r = 0.14; // corner radius

  // Rounded-rectangle perimeter, walked by arc length.
  const straightX = 2 * (hw - r);
  const straightY = 2 * (hh - r);
  const arc = (Math.PI / 2) * r;
  const segLen = [straightX, arc, straightY, arc, straightX, arc, straightY, arc];
  const perimeter = segLen.reduce((a, b) => a + b, 0);

  function perimeterPoint(u, out) {
    let d = u * perimeter;
    let i = 0;
    while (d > segLen[i]) {
      d -= segLen[i];
      i++;
    }
    const f = segLen[i] > 0 ? d / segLen[i] : 0;
    switch (i) {
      case 0: // top edge, left→right
        out[0] = cx - hw + r + f * straightX;
        out[1] = cy + hh;
        break;
      case 1: { // top-right arc 90°→0°
        const a = (Math.PI / 2) * (1 - f);
        out[0] = cx + hw - r + Math.cos(a) * r;
        out[1] = cy + hh - r + Math.sin(a) * r;
        break;
      }
      case 2: // right edge, top→bottom
        out[0] = cx + hw;
        out[1] = cy + hh - r - f * straightY;
        break;
      case 3: { // bottom-right arc 0°→-90°
        const a = -(Math.PI / 2) * f;
        out[0] = cx + hw - r + Math.cos(a) * r;
        out[1] = cy - hh + r + Math.sin(a) * r;
        break;
      }
      case 4: // bottom edge, right→left
        out[0] = cx + hw - r - f * straightX;
        out[1] = cy - hh;
        break;
      case 5: { // bottom-left arc -90°→-180°
        const a = -(Math.PI / 2) * (1 + f);
        out[0] = cx - hw + r + Math.cos(a) * r;
        out[1] = cy - hh + r + Math.sin(a) * r;
        break;
      }
      case 6: // left edge, bottom→top
        out[0] = cx - hw;
        out[1] = cy - hh + r + f * straightY;
        break;
      default: { // top-left arc 180°→90°
        const a = Math.PI - (Math.PI / 2) * f;
        out[0] = cx - hw + r + Math.cos(a) * r;
        out[1] = cy + hh - r + Math.sin(a) * r;
      }
    }
  }

  const dotCenters = [-0.26, 0, 0.26]; // three agent-state dots inside the notch
  const tone = new Float32Array(count);
  const pt = [0, 0];

  const nPerimeter = Math.round(count * 0.44);
  const nDots = Math.round(count * 0.16);
  const nBands = count - nPerimeter - nDots;

  for (let i = 0; i < count; i++) {
    let x;
    let y;
    let toneValue;
    if (i < nPerimeter) {
      // Slight jitter off the outline so the border reads as a soft band.
      perimeterPoint((i + Math.random() * 0.6) / nPerimeter, pt);
      const j = (Math.random() - 0.5) * 0.02;
      x = pt[0] + j;
      y = pt[1] + j;
      toneValue = 0.15;
    } else if (i < nPerimeter + nDots) {
      const c = dotCenters[(i - nPerimeter) % dotCenters.length];
      const rad = Math.sqrt(Math.random()) * 0.045;
      const ang = Math.random() * Math.PI * 2;
      x = cx + c + Math.cos(ang) * rad;
      y = cy + Math.sin(ang) * rad;
      toneValue = 0.0; // brightest coral cores
    } else {
      // Two horizontal status bands flanking the notch.
      const right = Math.random() < 0.5;
      const inner = 0.74;
      const outer = 1.34;
      const bx = inner + Math.random() * (outer - inner);
      x = cx + (right ? bx : -bx);
      y = cy + (Math.random() - 0.5) * 0.11;
      toneValue = 0.85; // dim warm-light band particles
    }
    target[i * 3] = x;
    target[i * 3 + 1] = y;
    target[i * 3 + 2] = (Math.random() - 0.5) * 0.06;
    tone[i] = toneValue;
  }
  return tone;
}

function markFallback() {
  if (heroSection) {
    heroSection.classList.remove("particles-active");
    heroSection.classList.add("webgl-failed");
  }
  window.AgentDockHero = {
    ready: true,
    mode: "fallback",
    config: { count: chooseCount() },
    uniforms: { uProgress: { value: 0 } },
    frameCount: 0,
    pixelRatio: 1,
    fallbackConvergenceActive: false,
    beginFallbackConvergence() {},
  };
}

function init() {
  if (!heroSection || !canvas) {
    markFallback();
    return;
  }

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: false,
      powerPreference: "high-performance",
    });
    if (!renderer.getContext()) throw new Error("no webgl context");
  } catch (err) {
    markFallback();
    return;
  }

  const count = chooseCount();
  const pixelRatio = Math.min(window.devicePixelRatio || 1, 1.5);
  renderer.setPixelRatio(pixelRatio);
  renderer.setClearColor(0x000000, 0);

  const scene = new THREE.Scene();
  let aspect = Math.max(canvas.clientWidth, 1) / Math.max(canvas.clientHeight, 1);
  const camera = new THREE.OrthographicCamera(-aspect, aspect, 1, -1, 0.1, 10);
  camera.position.z = 2;

  const scatter = new Float32Array(count * 3);
  const structured = new Float32Array(count * 3);
  const random = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    scatter[i * 3] = (Math.random() * 2 - 1) * 1.55;
    scatter[i * 3 + 1] = (Math.random() * 2 - 1) * 1.08;
    scatter[i * 3 + 2] = (Math.random() - 0.5) * 0.6;
    random[i] = Math.random();
  }
  const tone = buildStructured(structured, count);

  const geometry = new THREE.BufferGeometry();
  const scatterAttr = new THREE.BufferAttribute(scatter, 3);
  geometry.setAttribute("position", scatterAttr);
  geometry.setAttribute("aScatter", scatterAttr);
  geometry.setAttribute("aStructured", new THREE.BufferAttribute(structured, 3));
  geometry.setAttribute("aRandom", new THREE.BufferAttribute(random, 1));
  geometry.setAttribute("aTone", new THREE.BufferAttribute(tone, 1));

  const uniforms = {
    uProgress: { value: 0 },
    uTime: { value: 0 },
    uPixelRatio: { value: pixelRatio },
    uStructureScale: { value: 1 },
    uSize: { value: 2.6 },
    uMouse: { value: new THREE.Vector2(999, 999) },
    uMouseStrength: { value: 0 },
    uColorCoral: { value: new THREE.Color(0.98, 0.55, 0.42) },
    uColorLight: { value: new THREE.Color(0.92, 0.9, 0.86) },
  };

  const material = new THREE.ShaderMaterial({
    uniforms,
    transparent: true,
    depthTest: false,
    depthWrite: false,
    blending: THREE.NormalBlending,
    vertexShader: `
      attribute vec3 aScatter;
      attribute vec3 aStructured;
      attribute float aRandom;
      attribute float aTone;
      uniform float uProgress;
      uniform float uTime;
      uniform float uPixelRatio;
      uniform float uStructureScale;
      uniform float uSize;
      uniform vec2 uMouse;
      uniform float uMouseStrength;
      varying float vAlpha;
      varying float vTone;
      void main() {
        float t = clamp((uProgress - aRandom * 0.28) / 0.72, 0.0, 1.0);
        t = t * t * (3.0 - 2.0 * t);
        vec3 target = aStructured;
        target.xy *= uStructureScale;
        vec3 pos = mix(aScatter, target, t);
        float breathe = sin(uTime * 0.9 + aRandom * 6.2831) * 0.012 * t;
        pos.x += breathe * 0.6;
        pos.y += breathe;
        vec2 diff = pos.xy - uMouse;
        float d = length(diff);
        float infl = uMouseStrength * (1.0 - smoothstep(0.0, 0.42, d)) * t;
        pos.xy += normalize(diff + vec2(0.0001)) * infl * 0.14;
        vec4 mv = modelViewMatrix * vec4(pos, 1.0);
        gl_Position = projectionMatrix * mv;
        gl_PointSize = uSize * uPixelRatio * (0.55 + aRandom * 0.9);
        vAlpha = mix(0.26, 0.95, t);
        vTone = aTone;
      }
    `,
    fragmentShader: `
      precision mediump float;
      uniform vec3 uColorCoral;
      uniform vec3 uColorLight;
      varying float vAlpha;
      varying float vTone;
      void main() {
        vec2 uv = gl_PointCoord - 0.5;
        float d = length(uv);
        float a = smoothstep(0.5, 0.12, d);
        if (a < 0.02) discard;
        vec3 col = mix(uColorCoral, uColorLight, vTone);
        gl_FragColor = vec4(col, a * vAlpha);
      }
    `,
  });

  const points = new THREE.Points(geometry, material);
  points.frustumCulled = false;
  scene.add(points);

  function resize() {
    const w = Math.max(canvas.clientWidth, 1);
    const h = Math.max(canvas.clientHeight, 1);
    aspect = w / h;
    camera.left = -aspect;
    camera.right = aspect;
    camera.top = 1;
    camera.bottom = -1;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h, false);
    // Scale the notch composition down so its widest extent (~1.34) fits narrow
    // portrait viewports without overflowing the horizontal half-range (aspect).
    uniforms.uStructureScale.value = Math.min(1, (aspect * 0.9) / 1.34);
  }
  resize();

  heroSection.classList.add("particles-active");

  const hero = {
    ready: true,
    mode: "webgl",
    config: { count },
    uniforms,
    frameCount: 0,
    pixelRatio,
    _driven: false,
    fallbackConvergenceActive: false,
    beginFallbackConvergence,
  };
  window.AgentDockHero = hero;

  function renderFrame() {
    renderer.render(scene, camera);
    hero.frameCount++;
  }

  // --- One scheduler owns breathing and fallback convergence. ---
  // Time only advances on rendered visible frames, so fallback convergence
  // cannot progress while the canvas is offscreen or the document is hidden.
  let rafId = null;
  let visible = true;
  let runtimeReduced = reducedMotion.matches;
  let lastFrameTime = null;
  let fallbackElapsed = 0;
  const fallbackDuration = 1900;
  const allowInteraction = !coarsePointer.matches;
  const mouseTarget = new THREE.Vector2(999, 999);

  function canRun() {
    return hero.mode === "webgl" && visible && !document.hidden && !runtimeReduced;
  }

  function beginFallbackConvergence() {
    if (hero.mode !== "webgl" || uniforms.uProgress.value >= 1) return;
    hero._driven = false;
    hero.fallbackConvergenceActive = true;
    fallbackElapsed = uniforms.uProgress.value * fallbackDuration;
    lastFrameTime = null;
    start();
  }

  function loop(now) {
    rafId = null;
    if (!canRun()) return;
    const delta = lastFrameTime === null ? 0 : Math.min(50, now - lastFrameTime);
    lastFrameTime = now;
    if (hero.fallbackConvergenceActive) {
      fallbackElapsed = Math.min(fallbackDuration, fallbackElapsed + delta);
      const k = fallbackElapsed / fallbackDuration;
      uniforms.uProgress.value = k * k * (3 - 2 * k);
      if (k >= 1) hero.fallbackConvergenceActive = false;
    }
    uniforms.uTime.value = now * 0.001;
    if (allowInteraction && uniforms.uMouseStrength.value > 0.001) {
      uniforms.uMouse.value.lerp(mouseTarget, 0.12);
    }
    renderFrame();
    rafId = requestAnimationFrame(loop);
  }

  function start() {
    if (rafId === null && canRun()) {
      lastFrameTime = null;
      rafId = requestAnimationFrame(loop);
    }
  }
  function stop() {
    if (rafId !== null) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
    lastFrameTime = null;
  }

  function switchToFallback() {
    if (hero.mode === "fallback") return;
    stop();
    hero.mode = "fallback";
    hero.fallbackConvergenceActive = false;
    heroSection.classList.remove("particles-active");
    heroSection.classList.add("webgl-failed");
  }

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) stop();
    else start();
  });

  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        visible = entries[0].isIntersecting;
        if (visible) start();
        else stop();
      },
      { threshold: 0 }
    );
    io.observe(canvas);
  }

  window.addEventListener(
    "resize",
    () => {
      resize();
      if (runtimeReduced && hero.mode === "webgl") renderFrame();
    },
    { passive: true }
  );

  reducedMotion.addEventListener("change", () => {
    runtimeReduced = reducedMotion.matches;
    if (runtimeReduced) {
      stop();
      hero.fallbackConvergenceActive = false;
      uniforms.uProgress.value = 1;
      if (hero.mode === "webgl") renderFrame();
    } else {
      start();
    }
  });

  canvas.addEventListener(
    "webglcontextlost",
    (event) => {
      event.preventDefault();
      switchToFallback();
    },
    false
  );

  if (allowInteraction) {
    window.addEventListener(
      "pointermove",
      (event) => {
        if (event.pointerType === "touch") return;
        const rect = canvas.getBoundingClientRect();
        const nx = ((event.clientX - rect.left) / Math.max(rect.width, 1)) * 2 - 1;
        const ny = -(((event.clientY - rect.top) / Math.max(rect.height, 1)) * 2 - 1);
        mouseTarget.set(nx * aspect, ny);
        uniforms.uMouseStrength.value = 1;
      },
      { passive: true }
    );
    window.addEventListener("pointerout", () => {
      uniforms.uMouseStrength.value = 0;
    });
  }

  if (runtimeReduced) {
    uniforms.uProgress.value = 1;
    renderFrame();
  } else {
    start();
  }

  // Arm the no-GSAP safety net only after the curtain gate opens. It delegates
  // to the unified scheduler above; it never creates a second RAF chain.
  let safetyArmed = false;
  function armSafetyNet() {
    if (safetyArmed || runtimeReduced) return;
    safetyArmed = true;
    setTimeout(() => {
      if (!hero._driven && uniforms.uProgress.value < 1) {
        beginFallbackConvergence();
      }
    }, 500);
  }
  const curtainState = window.AgentDockCurtain && window.AgentDockCurtain.state;
  if (curtainState === "skipped" || curtainState === "exiting" || curtainState === "complete") {
    armSafetyNet();
  } else {
    document.addEventListener("agentdock:curtain-exit-start", armSafetyNet, { once: true });
    document.addEventListener("agentdock:curtain-skipped", armSafetyNet, { once: true });
  }
}

init();
