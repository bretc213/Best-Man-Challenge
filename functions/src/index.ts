import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

/**
 * Runs every hour. Sets is_active = true on whichever weekly_challenge
 * has start_date <= now < end_date, and is_active = false on all others.
 *
 * Deploy: firebase deploy --only functions
 */
export const syncWeeklyChallengeActive = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "America/Chicago",  // ← change to your timezone if needed
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection("weekly_challenges")
      .where("weekInt", ">=", 24)
      .where("weekInt", "<=", 50)
      .get();

    const batch = db.batch();
    let activatedWeek: number | null = null;
    let deactivatedCount = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const startDate: admin.firestore.Timestamp | undefined = data.start_date;
      const endDate: admin.firestore.Timestamp | undefined = data.end_date;
      const currentlyActive: boolean = data.is_active === true;

      if (!startDate || !endDate) continue;

      const shouldBeActive =
        now.toMillis() >= startDate.toMillis() &&
        now.toMillis() < endDate.toMillis();

      // Only write if the value actually needs to change
      if (shouldBeActive && !currentlyActive) {
        batch.update(doc.ref, { is_active: true });
        activatedWeek = data.weekInt ?? data.week ?? null;
      } else if (!shouldBeActive && currentlyActive) {
        batch.update(doc.ref, { is_active: false });
        deactivatedCount++;
      }
    }

    await batch.commit();

    if (activatedWeek) {
      console.log(`✅ Activated week ${activatedWeek}`);
    }
    if (deactivatedCount > 0) {
      console.log(`⬇️  Deactivated ${deactivatedCount} challenge(s)`);
    }
    if (!activatedWeek && deactivatedCount === 0) {
      console.log("ℹ️  No changes needed.");
    }
  }
);
