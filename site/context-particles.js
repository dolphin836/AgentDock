// [skill: go-team-standards · dev-dna] Vokie 1:1 Task 4 — second (context) particle field.
// An original AgentDock composition: three streams of points flow from the edges
// and converge into a single entrance node, echoing "three kinds of agent, one
// place to look". It is dynamically imported by motion.js (lazy), device-tiered,
// paused when offscreen/hidden, static under reduced motion, and degrades to the
// masked paper background if WebGL is unavailable or the context is lost. No
// Vokie shapes, assets, or code are reproduced.
import * as THREE from "./vendor/three.module.min.js";

const section = document.getElementById("context");
const canvas = document.getElementById("contextCanvas");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const coarsePointer = window.matchMedia("(pointer: coarse)");
const CAPABLE_COUNT = 4000;
const CONSTRAINED_COUNT = 1600;
const POINT_SIZE = 5.0;
const ALPHA_BASE = 0.3;
const ALPHA_PEAK = 0.95;

// --- Device tier: fewer points on save-data / low-memory / low-cpu / touch ---
function chooseCount() {
  const saveData = !!(navigator.connection && navigator.connection.saveData);
  const lowMemory =
    typeof navigator.deviceMemory === "number" && navigator.deviceMemory <= 4;
  const lowCpu =
    typeof navigator.hardwareConcurrency === "number" &&
    navigator.hardwareConcurrency <= 4;
  const constrained = saveData || lowMemory || lowCpu || coarsePointer.matches;
  return constrained ? CONSTRAINED_COUNT : CAPABLE_COUNT;
}

// Three edge sources feeding one central entrance node (design §3.5 / §5.2).
const SOURCES = [
  [-1.15, 0.62],
  [1.15, 0.62],
  [0.0, -0.95],
];
const CONTROLS = [
  [-0.55, 0.05],
  [0.55, 0.05],
  [0.0, -0.28],
];

function buildField(count) {
  const start = new Float32Array(count * 2);
  const ctrl = new Float32Array(count * 2);
  const phase = new Float32Array(count);
  const tone = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    const s = i % SOURCES.length;
    const spread = 0.55;
    // Fan each source into a soft band so streams read as flows, not lines.
    const angle = Math.random() * Math.PI * 2;
    const radius = Math.sqrt(Math.random()) * spread;
    start[i * 2] = SOURCES[s][0] + Math.cos(angle) * radius;
    start[i * 2 + 1] = SOURCES[s][1] + Math.sin(angle) * radius * 0.7;
    ctrl[i * 2] = CONTROLS[s][0] + (Math.random() - 0.5) * 0.5;
    ctrl[i * 2 + 1] = CONTROLS[s][1] + (Math.random() - 0.5) * 0.5;
    phase[i] = Math.random();
    tone[i] = Math.random(); // 0 => stream tone, 1 => warm core tone (near center)
  }
  return { start, ctrl, phase, tone };
}

function markFallback() {
  if (section) section.classList.add("context-failed");
  window.AgentDockContext = {
    ready: true,
    mode: "fallback",
    config: {
      count: chooseCount(),
      pointSize: POINT_SIZE,
      alphaBase: ALPHA_BASE,
      alphaPeak: ALPHA_PEAK,
    },
    uniforms: { uProgress: { value: 0 } },
    frameCount: 0,
    pixelRatio: 1,
  };
}

function init() {
  if (!section || !canvas) {
    markFallback();
    return;
  }

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: false,
      powerPreference: "low-power",
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

  const field = buildField(count);
  const geometry = new THREE.BufferGeometry();
  // A dummy position attribute keeps three.js happy; real positions are computed
  // in the vertex shader from the stream start/control/phase attributes.
  geometry.setAttribute("position", new THREE.BufferAttribute(new Float32Array(count * 3), 3));
  geometry.setAttribute("aStart", new THREE.BufferAttribute(field.start, 2));
  geometry.setAttribute("aCtrl", new THREE.BufferAttribute(field.ctrl, 2));
  geometry.setAttribute("aPhase", new THREE.BufferAttribute(field.phase, 1));
  geometry.setAttribute("aTone", new THREE.BufferAttribute(field.tone, 1));

  const uniforms = {
    uProgress: { value: 0 },
    uTime: { value: 0 },
    uPixelRatio: { value: pixelRatio },
    uSize: { value: POINT_SIZE },
    uColorStream: { value: new THREE.Color(0.56, 0.46, 0.42) },
    uColorCore: { value: new THREE.Color(0.86, 0.42, 0.32) },
  };

  const material = new THREE.ShaderMaterial({
    uniforms,
    transparent: true,
    depthTest: false,
    depthWrite: false,
    blending: THREE.NormalBlending,
    vertexShader: `
      attribute vec2 aStart;
      attribute vec2 aCtrl;
      attribute float aPhase;
      attribute float aTone;
      uniform float uProgress;
      uniform float uTime;
      uniform float uPixelRatio;
      uniform float uSize;
      varying float vAlpha;
      varying float vTone;
      void main() {
        // Flow parameter loops the particle from its source into the center.
        float p = fract(aPhase + uTime * 0.05);
        vec2 center = vec2(0.0, 0.0);
        // Quadratic bezier: start -> control -> center.
        vec2 a = mix(aStart, aCtrl, p);
        vec2 b = mix(aCtrl, center, p);
        vec2 pos = mix(a, b, p);
        vec3 world = vec3(pos, 0.0);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(world, 1.0);
        // Brightest as particles near the entrance node, then fade out.
        float nearCenter = smoothstep(0.35, 0.95, p);
        float arrive = 1.0 - smoothstep(0.9, 1.0, p);
        gl_PointSize = uSize * uPixelRatio * (0.6 + nearCenter * 0.9);
        vAlpha = (${ALPHA_BASE.toFixed(2)} + nearCenter * ${(ALPHA_PEAK - ALPHA_BASE).toFixed(2)}) * arrive * uProgress;
        vTone = clamp(aTone * 0.4 + nearCenter * 0.8, 0.0, 1.0);
      }
    `,
    fragmentShader: `
      precision mediump float;
      uniform vec3 uColorStream;
      uniform vec3 uColorCore;
      varying float vAlpha;
      varying float vTone;
      void main() {
        vec2 uv = gl_PointCoord - 0.5;
        float d = length(uv);
        float a = smoothstep(0.5, 0.1, d);
        if (a < 0.02) discard;
        vec3 col = mix(uColorStream, uColorCore, vTone);
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
  }
  resize();

  const api = {
    ready: true,
    mode: "webgl",
    config: {
      count,
      pointSize: POINT_SIZE,
      alphaBase: ALPHA_BASE,
      alphaPeak: ALPHA_PEAK,
    },
    uniforms,
    frameCount: 0,
    pixelRatio,
  };
  window.AgentDockContext = api;

  let rafId = null;
  let visible = false;
  let runtimeReduced = reducedMotion.matches;
  let lastTime = null;
  let introStart = null;
  const introDuration = 900;

  function canRun() {
    return api.mode === "webgl" && visible && !document.hidden && !runtimeReduced;
  }

  function renderFrame() {
    renderer.render(scene, camera);
    api.frameCount++;
  }

  function loop(now) {
    rafId = null;
    if (!canRun()) return;
    if (introStart === null) introStart = now;
    uniforms.uProgress.value = Math.min(1, (now - introStart) / introDuration);
    uniforms.uTime.value = now * 0.001;
    lastTime = now;
    renderFrame();
    rafId = requestAnimationFrame(loop);
  }

  function start() {
    if (rafId === null && canRun()) {
      rafId = requestAnimationFrame(loop);
    }
  }
  function stop() {
    if (rafId !== null) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
    lastTime = null;
  }

  function renderStaticFrame() {
    // A single representative frame for reduced motion / one-shot paints.
    uniforms.uProgress.value = 1;
    uniforms.uTime.value = 6.2831;
    renderFrame();
  }

  function switchToFallback() {
    if (api.mode === "fallback") return;
    stop();
    api.mode = "fallback";
    section.classList.add("context-failed");
  }

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) stop();
    else start();
  });

  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        visible = entries[0].isIntersecting;
        if (visible) {
          if (runtimeReduced) renderStaticFrame();
          else start();
        } else {
          stop();
        }
      },
      { threshold: 0 }
    );
    io.observe(canvas);
  } else {
    visible = true;
    if (runtimeReduced) renderStaticFrame();
    else start();
  }

  window.addEventListener(
    "resize",
    () => {
      resize();
      if (runtimeReduced && api.mode === "webgl" && visible) renderStaticFrame();
    },
    { passive: true }
  );

  reducedMotion.addEventListener("change", () => {
    runtimeReduced = reducedMotion.matches;
    if (runtimeReduced) {
      stop();
      if (api.mode === "webgl" && visible) renderStaticFrame();
    } else {
      introStart = null;
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

  // Paint an initial static frame so the scene is present even before it scrolls
  // fully into view (and this is the only frame under reduced motion).
  renderStaticFrame();
}

init();
