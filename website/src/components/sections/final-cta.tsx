import { DOWNLOAD_URL, RELEASE_VERSION } from "@/lib/release";

import { FinalCtaCardVisual } from "./final-cta-card-visual";
import styles from "./final-cta.module.css";

export type FinalCtaProps = {
  downloadUrl?: string;
  version?: string;
};

export function FinalCta({
  downloadUrl = DOWNLOAD_URL,
  version = RELEASE_VERSION,
}: FinalCtaProps) {
  return (
    <section
      id="download"
      className={styles.section}
      data-download-url={downloadUrl}
      data-header="dark"
      data-version={version}
    >
      <div className={styles.inner}>
        <FinalCtaCardVisual downloadUrl={downloadUrl} version={version} />
      </div>
    </section>
  );
}

export default FinalCta;
