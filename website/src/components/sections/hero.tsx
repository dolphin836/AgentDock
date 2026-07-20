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
      <HeroCanvas />
      <HeroContent />
    </section>
  );
}
