"use client";

import { useEffect, useRef } from "react";
import * as THREE from "three";

type ContextFocusCanvasProps = {
  className?: string;
  id?: string;
};

const DESKTOP_PARTICLES = 2200;
const LOW_PERF_PARTICLES = 1200;
const MAX_DPR = 1.5;

const PARTICLE_COLOR = 0x111111;

// Three source lanes ("agent streams") that flow up into the notch outline.
const STREAM_ORIGINS: ReadonlyArray<readonly [number, number]> = [
  [-0.85, -1.25],
  [0.0, -1.4],
  [0.85, -1.25],
];

function prefersReducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

function isLowPerfDevice(): boolean {
  if (typeof navigator === "undefined") {
    return false;
  }
  const cores = navigator.hardwareConcurrency;
  if (typeof cores === "number" && cores > 0 && cores <= 4) {
    return true;
  }
  const memory = (navigator as Navigator & { deviceMemory?: number })
    .deviceMemory;
  if (typeof memory === "number" && memory > 0 && memory <= 4) {
    return true;
  }
  return false;
}

/**
 * Samples an evenly-distributed outline of a rounded rectangle shaped like the
 * macOS notch (the "刘海" silhouette) in world coordinates.
 */
function buildNotchOutline(
  cx: number,
  cy: number,
  halfWidth: number,
  halfHeight: number,
  radius: number,
): THREE.Vector2[] {
  const points: THREE.Vector2[] = [];
  const density = 90; // samples per world unit of perimeter

  const pushLine = (ax: number, ay: number, bx: number, by: number) => {
    const length = Math.hypot(bx - ax, by - ay);
    const steps = Math.max(2, Math.round(length * density));
    for (let i = 0; i < steps; i += 1) {
      const t = i / steps;
      points.push(new THREE.Vector2(ax + (bx - ax) * t, ay + (by - ay) * t));
    }
  };

  const pushArc = (
    centerX: number,
    centerY: number,
    startAngle: number,
    endAngle: number,
  ) => {
    const length = Math.abs(endAngle - startAngle) * radius;
    const steps = Math.max(2, Math.round(length * density));
    for (let i = 0; i < steps; i += 1) {
      const t = i / steps;
      const angle = startAngle + (endAngle - startAngle) * t;
      points.push(
        new THREE.Vector2(
          centerX + Math.cos(angle) * radius,
          centerY + Math.sin(angle) * radius,
        ),
      );
    }
  };

  const top = cy + halfHeight;
  const bottom = cy - halfHeight;
  const left = cx - halfWidth;
  const right = cx + halfWidth;

  pushLine(left + radius, top, right - radius, top);
  pushArc(right - radius, top - radius, Math.PI / 2, 0);
  pushLine(right, top - radius, right, bottom + radius);
  pushArc(right - radius, bottom + radius, 0, -Math.PI / 2);
  pushLine(right - radius, bottom, left + radius, bottom);
  pushArc(left + radius, bottom + radius, -Math.PI / 2, -Math.PI);
  pushLine(left, bottom + radius, left, top - radius);
  pushArc(left + radius, top - radius, Math.PI, Math.PI / 2);

  return points;
}

export default function ContextFocusCanvas({
  className,
  id,
}: ContextFocusCanvasProps) {
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
      // WebGL unavailable — leave the paper background visible as fallback.
      return;
    }

    const reducedMotion = prefersReducedMotion();
    const particleCount = isLowPerfDevice()
      ? LOW_PERF_PARTICLES
      : DESKTOP_PARTICLES;

    renderer.setClearColor(0x000000, 0);

    const scene = new THREE.Scene();
    const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -10, 10);
    camera.position.z = 1;

    // Notch outline target near the top-center of the frame.
    const outline = buildNotchOutline(0, 0.62, 0.44, 0.11, 0.09);
    const outlineCount = outline.length;

    const origins = new Float32Array(particleCount * 2);
    const controls = new Float32Array(particleCount * 2);
    const targets = new Float32Array(particleCount * 2);
    const progress = new Float32Array(particleCount);
    const speed = new Float32Array(particleCount);
    const positions = new Float32Array(particleCount * 3);

    for (let i = 0; i < particleCount; i += 1) {
      const stream = i % STREAM_ORIGINS.length;
      const origin = STREAM_ORIGINS[stream];
      const target = outline[i % outlineCount];

      const jitterX = (Math.random() - 0.5) * 0.012;
      const jitterY = (Math.random() - 0.5) * 0.012;
      const tx = target.x + jitterX;
      const ty = target.y + jitterY;

      const ox = origin[0] + (Math.random() - 0.5) * 0.28;
      const oy = origin[1] + (Math.random() - 0.5) * 0.14;

      // Curve the flow with a control point biased toward the notch centre.
      const cxCtrl = (ox + tx) * 0.5 + (Math.random() - 0.5) * 0.5;
      const cyCtrl = (oy + ty) * 0.5 + Math.random() * 0.3;

      origins[i * 2] = ox;
      origins[i * 2 + 1] = oy;
      controls[i * 2] = cxCtrl;
      controls[i * 2 + 1] = cyCtrl;
      targets[i * 2] = tx;
      targets[i * 2 + 1] = ty;
      progress[i] = Math.random();
      speed[i] = 0.05 + Math.random() * 0.07;
    }

    const geometry = new THREE.BufferGeometry();
    const positionAttribute = new THREE.BufferAttribute(positions, 3);
    positionAttribute.setUsage(THREE.DynamicDrawUsage);
    geometry.setAttribute("position", positionAttribute);

    const material = new THREE.PointsMaterial({
      color: PARTICLE_COLOR,
      size: 1.8,
      sizeAttenuation: false,
      transparent: true,
      opacity: 0.55,
      depthTest: false,
      depthWrite: false,
    });

    const points = new THREE.Points(geometry, material);
    scene.add(points);

    const writePositions = () => {
      for (let i = 0; i < particleCount; i += 1) {
        const t = progress[i];
        const inv = 1 - t;
        const a = inv * inv;
        const b = 2 * inv * t;
        const c = t * t;

        const ox = origins[i * 2];
        const oy = origins[i * 2 + 1];
        const cxCtrl = controls[i * 2];
        const cyCtrl = controls[i * 2 + 1];
        const tx = targets[i * 2];
        const ty = targets[i * 2 + 1];

        positions[i * 3] = a * ox + b * cxCtrl + c * tx;
        positions[i * 3 + 1] = a * oy + b * cyCtrl + c * ty;
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
      const aspect = height > 0 ? width / height : 1;
      camera.left = -aspect;
      camera.right = aspect;
      camera.top = 1;
      camera.bottom = -1;
      camera.updateProjectionMatrix();
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, MAX_DPR));
      renderer.setSize(width, height, false);
    };

    let rafId = 0;
    let running = false;
    let isIntersecting = true;
    let contextLost = false;
    let lastTime =
      typeof performance !== "undefined" ? performance.now() : Date.now();

    const renderFrame = () => {
      if (renderer && !contextLost) {
        renderer.render(scene, camera);
      }
    };

    const tick = () => {
      if (!running) {
        return;
      }
      const now =
        typeof performance !== "undefined" ? performance.now() : Date.now();
      const dt = Math.min((now - lastTime) / 1000, 0.05);
      lastTime = now;

      for (let i = 0; i < particleCount; i += 1) {
        let t = progress[i] + speed[i] * dt;
        if (t >= 1) {
          t -= 1;
        }
        progress[i] = t;
      }
      writePositions();
      renderFrame();
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
      lastTime =
        typeof performance !== "undefined" ? performance.now() : Date.now();
      rafId = window.requestAnimationFrame(tick);
    };

    const stop = () => {
      running = false;
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

    const resizeObserver =
      typeof ResizeObserver !== "undefined"
        ? new ResizeObserver(() => {
            applyViewport();
            if (!running) {
              // Keep the static frame crisp after a resize.
              renderFrame();
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
    resizeObserver?.observe(canvas);
    intersectionObserver?.observe(canvas);

    applyViewport();
    writePositions();
    renderFrame();

    if (!reducedMotion) {
      start();
    }

    return () => {
      stop();
      canvas.removeEventListener("webglcontextlost", handleContextLost, false);
      document.removeEventListener("visibilitychange", handleVisibility);
      resizeObserver?.disconnect();
      intersectionObserver?.disconnect();
      geometry.dispose();
      material.dispose();
      renderer?.dispose();
    };
  }, []);

  return <canvas ref={canvasRef} className={className} id={id} aria-hidden="true" />;
}
