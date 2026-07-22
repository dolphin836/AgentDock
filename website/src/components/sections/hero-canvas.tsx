"use client";

import { useEffect, useRef } from "react";
import * as THREE from "three";
import { gsap } from "gsap";

import styles from "./hero-canvas.module.css";

type HeroCanvasProps = {
  className?: string;
  id?: string;
};

/**
 * Particle budget. Desktop shows the full field; coarse-pointer / low-power
 * devices fall back to a lighter count so the hero stays smooth on phones.
 */
const DESKTOP_PARTICLES = 2200;
const MOBILE_PARTICLES = 1200;
const MAX_DPR = 1.5;

/** Convergence timing driven by GSAP (scatter -> AgentDock silhouette). */
const CONVERGE_DURATION = 1.9;

/** Outline / status-dot split. Roughly a fifth of the field forms the dots. */
const DOT_RATIO = 0.22;

/** Notch geometry in the orthographic frame (top = 1, bottom = -1). */
const NOTCH = {
  cx: 0,
  cy: 0.34,
  halfWidth: 0.46,
  halfHeight: 0.13,
  radius: 0.1,
} as const;

/** The three agent "status" dots that live inside the notch. */
const STATUS_DOTS: ReadonlyArray<{
  x: number;
  y: number;
  color: readonly [number, number, number];
}> = [
  { x: -0.22, y: 0.34, color: [0.204, 0.827, 0.6] }, // running · emerald
  { x: 0.0, y: 0.34, color: [0.984, 0.749, 0.141] }, // awaiting · amber
  { x: 0.22, y: 0.34, color: [0.376, 0.647, 0.98] }, // done · sky
];

const OUTLINE_COLOR: readonly [number, number, number] = [0.42, 0.42, 0.45];

function prefersReducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

function supportsFinePointer(): boolean {
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(hover: hover) and (pointer: fine)").matches
  );
}

/** Coarse pointer or modest hardware -> the lighter particle budget. */
function shouldUseMobileBudget(): boolean {
  if (typeof window === "undefined") {
    return false;
  }
  if (
    typeof window.matchMedia === "function" &&
    window.matchMedia("(pointer: coarse)").matches
  ) {
    return true;
  }
  if (typeof navigator !== "undefined") {
    const cores = navigator.hardwareConcurrency;
    if (typeof cores === "number" && cores > 0 && cores <= 4) {
      return true;
    }
    const memory = (navigator as Navigator & { deviceMemory?: number })
      .deviceMemory;
    if (typeof memory === "number" && memory > 0 && memory <= 4) {
      return true;
    }
  }
  return false;
}

type Segment = {
  length: number;
  at: (u: number) => [number, number];
};

/**
 * Builds an arc-length parametrisation of the notch outline (four straight
 * edges + four rounded corners) so particles can be spread evenly along the
 * perimeter regardless of segment size. This is an original sampler for the
 * AgentDock silhouette, not derived from any reference implementation.
 */
function buildNotchSegments(): { segments: Segment[]; total: number } {
  const { cx, cy, halfWidth, halfHeight, radius } = NOTCH;
  const top = cy + halfHeight;
  const bottom = cy - halfHeight;
  const left = cx - halfWidth;
  const right = cx + halfWidth;

  const line = (
    ax: number,
    ay: number,
    bx: number,
    by: number,
  ): Segment => ({
    length: Math.hypot(bx - ax, by - ay),
    at: (u) => [ax + (bx - ax) * u, ay + (by - ay) * u],
  });

  const arc = (
    centerX: number,
    centerY: number,
    startAngle: number,
    endAngle: number,
  ): Segment => ({
    length: Math.abs(endAngle - startAngle) * radius,
    at: (u) => {
      const angle = startAngle + (endAngle - startAngle) * u;
      return [
        centerX + Math.cos(angle) * radius,
        centerY + Math.sin(angle) * radius,
      ];
    },
  });

  const segments: Segment[] = [
    line(left + radius, top, right - radius, top),
    arc(right - radius, top - radius, Math.PI / 2, 0),
    line(right, top - radius, right, bottom + radius),
    arc(right - radius, bottom + radius, 0, -Math.PI / 2),
    line(right - radius, bottom, left + radius, bottom),
    arc(left + radius, bottom + radius, -Math.PI / 2, -Math.PI),
    line(left, bottom + radius, left, top - radius),
    arc(left + radius, top - radius, Math.PI, Math.PI / 2),
  ];

  const total = segments.reduce((sum, seg) => sum + seg.length, 0);
  return { segments, total };
}

function sampleOutlineAt(
  segments: Segment[],
  total: number,
  distance: number,
): [number, number] {
  let remaining = ((distance % total) + total) % total;
  for (const segment of segments) {
    if (remaining <= segment.length || segment === segments[segments.length - 1]) {
      const u = segment.length > 0 ? remaining / segment.length : 0;
      return segment.at(Math.min(u, 1));
    }
    remaining -= segment.length;
  }
  return segments[0].at(0);
}

export function HeroCanvas({ className, id }: HeroCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) {
      return;
    }

    let renderer: THREE.WebGLRenderer | null = null;
    try {
      renderer = new THREE.WebGLRenderer({
        canvas,
        antialias: false,
        alpha: true,
        powerPreference: "low-power",
      });
    } catch {
      // WebGL unavailable — the CSS #111 fill stays as the hero backdrop.
      return;
    }

    const reducedMotion = prefersReducedMotion();
    const finePointer = supportsFinePointer();
    const particleCount = shouldUseMobileBudget()
      ? MOBILE_PARTICLES
      : DESKTOP_PARTICLES;

    renderer.setClearColor(0x000000, 0);

    const scene = new THREE.Scene();
    const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -10, 10);
    camera.position.z = 1;

    const { segments, total } = buildNotchSegments();
    const dotCount = Math.round(particleCount * DOT_RATIO);
    const outlineCount = particleCount - dotCount;

    const origins = new Float32Array(particleCount * 2);
    const targets = new Float32Array(particleCount * 2);
    const normals = new Float32Array(particleCount * 2); // radial breathing dir
    const stagger = new Float32Array(particleCount);
    const phase = new Float32Array(particleCount);
    const positions = new Float32Array(particleCount * 3);
    const colors = new Float32Array(particleCount * 3);

    for (let i = 0; i < particleCount; i += 1) {
      let tx: number;
      let ty: number;
      let cr: number;
      let cg: number;
      let cb: number;

      if (i < outlineCount) {
        const jitter = (Math.random() - 0.5) * 0.01;
        const [px, py] = sampleOutlineAt(
          segments,
          total,
          (i / outlineCount) * total + jitter,
        );
        tx = px + (Math.random() - 0.5) * 0.006;
        ty = py + (Math.random() - 0.5) * 0.006;
        [cr, cg, cb] = OUTLINE_COLOR;
      } else {
        const dot = STATUS_DOTS[(i - outlineCount) % STATUS_DOTS.length];
        // Gaussian-ish cluster so each dot reads as a soft glowing point.
        const angle = Math.random() * Math.PI * 2;
        const r = Math.sqrt(Math.random()) * 0.03;
        tx = dot.x + Math.cos(angle) * r;
        ty = dot.y + Math.sin(angle) * r;
        [cr, cg, cb] = dot.color;
      }

      // Scatter origin across (and slightly beyond) the frame.
      const ox = (Math.random() - 0.5) * 2.6;
      const oy = (Math.random() - 0.5) * 2.6;

      origins[i * 2] = ox;
      origins[i * 2 + 1] = oy;
      targets[i * 2] = tx;
      targets[i * 2 + 1] = ty;

      const ndx = tx - NOTCH.cx;
      const ndy = ty - NOTCH.cy;
      const nlen = Math.hypot(ndx, ndy) || 1;
      normals[i * 2] = ndx / nlen;
      normals[i * 2 + 1] = ndy / nlen;

      stagger[i] = Math.random() * 0.28;
      phase[i] = Math.random() * Math.PI * 2;

      colors[i * 3] = cr;
      colors[i * 3 + 1] = cg;
      colors[i * 3 + 2] = cb;
    }

    const geometry = new THREE.BufferGeometry();
    const positionAttribute = new THREE.BufferAttribute(positions, 3);
    positionAttribute.setUsage(THREE.DynamicDrawUsage);
    geometry.setAttribute("position", positionAttribute);
    geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));

    const material = new THREE.PointsMaterial({
      size: 2,
      sizeAttenuation: false,
      vertexColors: true,
      transparent: true,
      opacity: 0.68,
      depthTest: false,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });

    const points = new THREE.Points(geometry, material);
    scene.add(points);

    let aspect = 1;
    let pointerX = 0;
    let pointerY = 0;
    let pointerStrength = 0;

    const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);

    const writePositions = (progressValue: number, elapsed: number) => {
      const breathe = Math.min(progressValue, 1);
      for (let i = 0; i < particleCount; i += 1) {
        const s = stagger[i];
        const local = easeOut(
          Math.min(Math.max((progressValue - s) / (1 - s), 0), 1),
        );

        const ox = origins[i * 2];
        const oy = origins[i * 2 + 1];
        const tx = targets[i * 2];
        const ty = targets[i * 2 + 1];

        let x = ox + (tx - ox) * local;
        let y = oy + (ty - oy) * local;

        // Subtle radial breathing once (mostly) converged.
        const breath =
          Math.sin(elapsed * 1.1 + phase[i]) * 0.012 * breathe * local;
        x += normals[i * 2] * breath;
        y += normals[i * 2 + 1] * breath;

        // Gentle pointer repulsion (fine pointers only).
        if (pointerStrength > 0.001) {
          const dx = x - pointerX;
          const dy = y - pointerY;
          const dist = Math.hypot(dx, dy);
          const radius = 0.22;
          if (dist < radius && dist > 0.0001) {
            const force = (1 - dist / radius) * pointerStrength * 0.12;
            x += (dx / dist) * force;
            y += (dy / dist) * force;
          }
        }

        positions[i * 3] = x;
        positions[i * 3 + 1] = y;
        positions[i * 3 + 2] = 0;
      }
      positionAttribute.needsUpdate = true;
    };

    const applyViewport = () => {
      if (!renderer) {
        return;
      }
      const width = canvas.clientWidth || window.innerWidth;
      const height = canvas.clientHeight || window.innerHeight;
      aspect = height > 0 ? width / height : 1;
      camera.left = -aspect;
      camera.right = aspect;
      camera.top = 1;
      camera.bottom = -1;
      camera.updateProjectionMatrix();
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, MAX_DPR));
      renderer.setSize(width, height, false);
    };

    const state = { progress: reducedMotion ? 1 : 0 };
    let rafId = 0;
    let running = false;
    let isIntersecting = true;
    let contextLost = false;
    let startTime =
      typeof performance !== "undefined" ? performance.now() : Date.now();

    let convergeTween: gsap.core.Tween | null = null;

    const renderFrame = (elapsed: number) => {
      if (!renderer || contextLost) {
        return;
      }
      writePositions(state.progress, elapsed);
      renderer.render(scene, camera);
    };

    const tick = () => {
      if (!running) {
        return;
      }
      const now =
        typeof performance !== "undefined" ? performance.now() : Date.now();
      const elapsed = (now - startTime) / 1000;
      pointerStrength *= 0.94;
      renderFrame(elapsed);
      rafId = window.requestAnimationFrame(tick);
    };

    const start = () => {
      if (running || contextLost || reducedMotion) {
        return;
      }
      if (!isIntersecting || document.hidden) {
        return;
      }
      running = true;
      convergeTween?.resume();
      rafId = window.requestAnimationFrame(tick);
    };

    const stop = () => {
      running = false;
      convergeTween?.pause();
      if (rafId) {
        window.cancelAnimationFrame(rafId);
        rafId = 0;
      }
    };

    const handleContextLost = (event: Event) => {
      event.preventDefault();
      contextLost = true;
      stop();
    };

    const handleVisibility = () => {
      if (document.hidden) {
        stop();
      } else {
        start();
      }
    };

    const handlePointerMove = (event: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) {
        return;
      }
      const nx = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      const ny = -(((event.clientY - rect.top) / rect.height) * 2 - 1);
      pointerX = nx * aspect;
      pointerY = ny;
      pointerStrength = 1;
    };

    const resizeObserver =
      typeof ResizeObserver !== "undefined"
        ? new ResizeObserver(() => {
            applyViewport();
            if (!running) {
              const now =
                typeof performance !== "undefined"
                  ? performance.now()
                  : Date.now();
              renderFrame((now - startTime) / 1000);
            }
          })
        : null;

    const intersectionObserver =
      typeof IntersectionObserver !== "undefined"
        ? new IntersectionObserver(
            (entries) => {
              for (const entry of entries) {
                isIntersecting = entry.isIntersecting;
              }
              if (isIntersecting) {
                start();
              } else {
                stop();
              }
            },
            { threshold: 0 },
          )
        : null;

    canvas.addEventListener("webglcontextlost", handleContextLost, false);
    document.addEventListener("visibilitychange", handleVisibility);
    if (finePointer) {
      window.addEventListener("pointermove", handlePointerMove, {
        passive: true,
      });
    }
    resizeObserver?.observe(canvas);
    intersectionObserver?.observe(canvas);

    applyViewport();

    if (reducedMotion) {
      // Reduced motion: paint a single, fully-converged static frame.
      renderFrame(0);
    } else {
      startTime =
        typeof performance !== "undefined" ? performance.now() : Date.now();
      try {
        convergeTween = gsap.to(state, {
          progress: 1,
          duration: CONVERGE_DURATION,
          ease: "power3.out",
        });
      } catch {
        // GSAP failed — snap to the converged silhouette without animation.
        state.progress = 1;
      }
      start();
    }

    return () => {
      stop();
      convergeTween?.kill();
      canvas.removeEventListener("webglcontextlost", handleContextLost, false);
      document.removeEventListener("visibilitychange", handleVisibility);
      if (finePointer) {
        window.removeEventListener("pointermove", handlePointerMove);
      }
      resizeObserver?.disconnect();
      intersectionObserver?.disconnect();
      geometry.dispose();
      material.dispose();
      renderer?.dispose();
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className={className ?? styles.canvas}
      id={id}
      aria-hidden="true"
    />
  );
}

export default HeroCanvas;
