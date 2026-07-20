import { PrivacyCardVisual } from "./privacy-card-visual";
import styles from "./privacy-section.module.css";

export function PrivacySection() {
  return (
    <section
      id="privacy"
      className={styles.section}
      data-header="dark"
      aria-labelledby="privacy-card-title"
    >
      <div className={styles.inner}>
        <PrivacyCardVisual />
      </div>
    </section>
  );
}

export default PrivacySection;
