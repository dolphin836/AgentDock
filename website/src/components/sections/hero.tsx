import { RELEASE_VERSION } from "@/lib/release";

import { HeroCanvas } from "./hero-canvas";
import { HeroContent } from "./hero-content";

import styles from "./hero.module.css";

export default function Hero() {
  return (
    <section
      id="top"
      className={styles.section}
      data-header="dark"
    >
      <div aria-hidden="true" className={styles.dotTexture} />
      <HeroCanvas />
      <HeroContent />

      <div className={styles.navTargets}>
        <span id="voice" tabIndex={-1} />
        <span id="meeting" tabIndex={-1} />
        <span id="integrations" tabIndex={-1} />
        <span id="privacy" tabIndex={-1} />
      </div>

      <div
        className={styles.releaseMeta}
        data-version={RELEASE_VERSION}
        id="download"
      >
        <span id="final-cta-heading">AgentDock v{RELEASE_VERSION}</span>
      </div>
    </section>
  );
}
