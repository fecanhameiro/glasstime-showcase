const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onTaskDispatched } = require("firebase-functions/v2/tasks");
const { getFunctions } = require("firebase-admin/functions");
const admin = require("firebase-admin");
const { sendAPNsPush } = require("./src/apns");

admin.initializeApp();

const QUEUE_NAME = "sendTimerEndPush";
const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "YOUR_PROJECT_ID";
const LOCATION = "us-central1";

// Reuse CloudTasksClient across invocations
const { CloudTasksClient } = require("@google-cloud/tasks");
const tasksClient = new CloudTasksClient();

/**
 * scheduleTimerEnd — Callable function (secured by Firebase SDK context).
 * Schedules a Cloud Task to send an APNs push at the timer's end date.
 *
 * Data: { pushToken, endDate (ISO string), sessionID }
 */
exports.scheduleTimerEnd = onCall(async (request) => {
  const { pushToken, endDate, sessionID, shouldEndActivity } = request.data;

  if (!pushToken || !endDate || !sessionID) {
    throw new HttpsError("invalid-argument", "Missing pushToken, endDate, or sessionID");
  }

  const endActivity = shouldEndActivity !== false; // default true

  const endDateMs = new Date(endDate).getTime();
  const now = Date.now();

  if (endDateMs <= now) {
    try {
      await sendAPNsPush(pushToken, endActivity);
      return { status: "sent_immediately" };
    } catch (err) {
      console.error("APNs push failed:", err);
      throw new HttpsError("internal", "Push failed: " + err.message);
    }
  }

  const queue = getFunctions().taskQueue(QUEUE_NAME);
  const taskName = `projects/${PROJECT_ID}/locations/${LOCATION}/queues/${QUEUE_NAME}/tasks/timer-${sessionID}`;

  try {
    await queue.enqueue(
      { pushToken, sessionID, shouldEndActivity: endActivity },
      {
        scheduleDelaySeconds: Math.ceil((endDateMs - now) / 1000),
        id: `timer-${sessionID}`,
      }
    );

    console.log(`Scheduled task timer-${sessionID} for ${endDate}`);
    return { status: "scheduled", sessionID, endDate };
  } catch (err) {
    if (err.code === 6 || err.message?.includes("ALREADY_EXISTS")) {
      try {
        await deleteTask(taskName);
        await queue.enqueue(
          { pushToken, sessionID, shouldEndActivity: endActivity },
          {
            scheduleDelaySeconds: Math.ceil((endDateMs - now) / 1000),
            id: `timer-${sessionID}`,
          }
        );
        console.log(`Rescheduled task timer-${sessionID} for ${endDate}`);
        return { status: "rescheduled", sessionID, endDate };
      } catch (retryErr) {
        console.error("Failed to reschedule:", retryErr);
        throw new HttpsError("internal", "Reschedule failed");
      }
    }

    console.error("Failed to schedule task:", err);
    throw new HttpsError("internal", "Schedule failed: " + err.message);
  }
});

/**
 * cancelTimerEnd — Callable function (secured by Firebase SDK context).
 * Deletes the scheduled Cloud Task.
 *
 * Data: { sessionID }
 */
exports.cancelTimerEnd = onCall(async (request) => {
  const { sessionID } = request.data;

  if (!sessionID) {
    throw new HttpsError("invalid-argument", "Missing sessionID");
  }

  const taskName = `projects/${PROJECT_ID}/locations/${LOCATION}/queues/${QUEUE_NAME}/tasks/timer-${sessionID}`;

  try {
    await deleteTask(taskName);
    console.log(`Cancelled task timer-${sessionID}`);
    return { status: "cancelled", sessionID };
  } catch (err) {
    if (err.code === 5 || err.message?.includes("NOT_FOUND")) {
      return { status: "not_found", sessionID };
    }
    console.error("Failed to cancel task:", err);
    throw new HttpsError("internal", "Cancel failed: " + err.message);
  }
});

/**
 * sendTimerEndPush — Cloud Task handler (internal, not callable by clients).
 * Fires at the scheduled time and sends an APNs push to end the Live Activity.
 */
exports.sendTimerEndPush = onTaskDispatched(
  {
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 10,
    },
    rateLimits: {
      maxConcurrentDispatches: 10,
    },
  },
  async (req) => {
    const { pushToken, sessionID, shouldEndActivity } = req.data;

    if (!pushToken) {
      console.error("No pushToken in task data");
      return;
    }

    try {
      await sendAPNsPush(pushToken, shouldEndActivity !== false);
      console.log(`Push sent for session ${sessionID}`);
    } catch (err) {
      console.error(`Push failed for session ${sessionID}:`, err);
      throw err; // Retry
    }
  }
);

/**
 * Delete a Cloud Task by its full resource name.
 */
async function deleteTask(taskName) {
  await tasksClient.deleteTask({ name: taskName });
}
