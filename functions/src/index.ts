// functions/src/index.ts - UPDATED FOR 2ND GEN
import {
  onDocumentCreated,
} from "firebase-functions/v2/firestore"; // Import v2 Firestore trigger
import * as logger from "firebase-functions/logger"; // Use v2 logger
import * as admin from "firebase-admin";
import {
  MessagingPayload,
  getMessaging,
} from "firebase-admin/messaging"; // Updated messaging import

// Initialize Firebase Admin SDK (runs once per function instance)
try {
  admin.initializeApp();
} catch (e) {
  logger.error("Firebase Admin initialization error:", e);
}

const db = admin.firestore();
// const messaging = admin.messaging(); // Use getMessaging() instead

/**
 * Sends notifications to group members when an activity is activated.
 * Triggered by Firestore document creation:
 * /groups/{groupId}/activities/{activityId}/activations/{activationId}
 */
export const sendActivityActivationNotification = onDocumentCreated(
  // Define trigger path and options, including region
  {
    document: "groups/{groupId}/activities/"+
    "{activityId}/activations/{activationId}",
    region: "africa-south1", // Specify your region here
    // Add memory/cpu options if needed later
    // memory: "1GiB",
  },
  async (event) => { // Use the event object provided
    const snapshot = event.data; // Get the document snapshot from the event
    if (!snapshot) {
      logger.log("Activation event contained no data snapshot.");
      return; // Exit gracefully
    }

    const activationData = snapshot.data();
    if (!activationData) {
      logger.log("Activation snapshot data is empty.");
      return;
    }

    // Extract necessary data from the activation document
    const {
      userId: activatorId, // User who triggered
      userName: activatorName = "Someone", // Default name
      activityName = "an activity", // Default name
      timeDescription = "soon", // Default time
      groupId,
    } = activationData;
    // const { groupId, activityId } = event.params;

    // Validate essential data
    if (!activatorId || !groupId) {
      logger.error(
        "Missing activatorId or groupId in activation data:",
        activationData
      );
      return;
    }

    logger.log(
      `Processing activation: User ${activatorName} (${activatorId}) `+
      `starting "${activityName}" ${timeDescription} in group ${groupId}.`
    );

    // 1. Get Group Members
    let memberUids: string[] = [];
    try {
      const groupRef = db.collection("groups").doc(groupId);
      const groupDoc = await groupRef.get();
      if (!groupDoc.exists) {
        logger.error(`Group document ${groupId} not found.`);
        return;
      }
      memberUids = groupDoc.data()?.memberUids || [];
    } catch (error) {
      logger.error(`Error fetching group ${groupId}:`, error);
      return;
    }

    // 2. Filter out the activator
    const recipientUids = memberUids.filter((uid) => uid !== activatorId);

    if (recipientUids.length === 0) {
      logger.log(`No other members found in group ${groupId} to notify.`);
      return;
    }

    logger.log(`Potential recipients for group ${groupId}:`, recipientUids);

    // 3. Get FCM Tokens for Recipients
    const tokens: string[] = [];
    const tokenPromises = recipientUids.map(async (uid) => {
      try {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const userTokens = userData?.fcmTokens as string[] | undefined;
          if (
            userTokens &&
            Array.isArray(userTokens) &&
            userTokens.length > 0
          ) {
            return userTokens; // Return array of tokens for this user
          } else {
            logger.log(`User ${uid} has no FCM tokens.`);
            return [];
          }
        } else {
          logger.log(`User document ${uid} not found.`);
          return [];
        }
      } catch (error) {
        logger.error(`Error fetching user data for ${uid}:`, error);
        return []; // Return empty array on error for this user
      }
    });

    try {
      const results = await Promise.all(tokenPromises);
      results.forEach((userTokens) => tokens.push(...userTokens)); // Flatten
    } catch (error) {
      logger.error("Error resolving token promises:", error);
      return;
    }

    // Remove duplicates and invalid entries
    const uniqueTokens = [
      ...new Set(tokens.filter((t) => typeof t === "string" && t.length > 0)),
    ];


    if (uniqueTokens.length === 0) {
      logger.log(
        `No valid FCM tokens found for any recipients in group ${groupId}.`
      );
      return;
    }

    logger.log(
      `Found ${uniqueTokens.length} unique tokens for group ${groupId}.`
    );

    // 4. Construct Notification Payload
    // Use MessagingPayload from 'firebase-admin/messaging'
    const messagePayload: MessagingPayload = {
      notification: {
        title: `Keeen: ${activityName}!`, // App Name + Activity
        body:
          `${activatorName} is starting "${activityName}" `+
          `${timeDescription}! Are you keen?`,
      },
      // Data payload for handling taps in Flutter app
      data: {
        groupId: groupId,
        // activityId from event.params or activationData - ensure consistency
        activityId: event.params.activityId,
        activityName: activityName,
        activatedBy: activatorName,
        timeDescription: timeDescription,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    // 5. Send Notifications using getMessaging()
    logger.log("Sending FCM message to tokens:", uniqueTokens);
    try {
      // Use sendEachForMulticast(), the new replacement
      const response = await getMessaging().sendEachForMulticast({
        tokens: uniqueTokens,
        notification: messagePayload.notification,
        data: messagePayload.data,

        // Platform-specific overrides for priority
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true, // Good for data-only messages on iOS
            },
          },
          headers: {
            "apns-priority": "10", // "10" is high priority for Apple
          },
        },
      });

      logger.log(
        `FCM send finished for group ${groupId}. `+
        `Success: ${response.successCount}, Failure: ${response.failureCount}`
      );

      // Optional: Handle failures
      if (response.failureCount > 0) {
        response.responses.forEach((result, index) => {
          const error = result.error;
          if (error) {
            const failedToken = uniqueTokens[index];
            logger.error(`Failed to send to token: ${failedToken}`, error);
            if (
              error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
            ) {
              logger.warn(
                `Token ${failedToken} is invalid or unregistered. ` +
                "Consider implementing cleanup."
              );
              // TODO: Add code here to remove this token from Firestore
            }
          }
        });
      }
    } catch (error) {
      logger.error(`Error sending FCM messages for group ${groupId}:`, error);
    }
    // No explicit return needed for onCreate typically
  }
);
