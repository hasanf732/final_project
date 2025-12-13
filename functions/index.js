const {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

// 1. Force the use of Application Default Credentials
initializeApp({
  credential: applicationDefault(),
  projectId: 'univent-app-9fb5c'
});

exports.sendEventNotification = onDocumentCreated({
  region: "us-central1",
  document: "News/{eventId}"
}, async (event) => {
  const eventData = event.data.data();
  const eventName = eventData.Name;
  const eventTimestamp = eventData.Date;

  // Safety check: Ensure date exists
  let eventDate = "an upcoming date";
  if (eventTimestamp) {
     eventDate = new Date(eventTimestamp.seconds * 1000).toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric'
    });
  }

  logger.log(`New event created: ${eventName} on ${eventDate}`);

  // 2. USE MODERN V1 MESSAGE FORMAT
  // We put the 'topic' directly inside the message object.
  const message = {
    notification: {
      title: `New Event: ${eventName}`,
      body: `Check it out, it's happening on ${eventDate}!`,
    },
    data: {
      eventId: event.params.eventId,
    },
    topic: "newEvents" // <--- The topic goes here now
  };

  logger.log("Sending message object:", JSON.stringify(message));

  try {
    // 3. Use the direct .send() method instead of .sendToTopic()
    const response = await getMessaging().send(message);
    logger.log("Successfully sent message:", response);
    
    // NEW: Persist to global_notifications so it shows in the app list
    await getFirestore().collection("global_notifications").add({
      title: message.notification.title,
      body: message.notification.body,
      timestamp: FieldValue.serverTimestamp(),
      type: 'new_event',
      eventId: event.params.eventId
    });
    
    return {success: true};
  } catch (error) {
    logger.error("Error sending message:", error);
    // Print the exact error code to help debugging
    if (error.code) logger.error("Error Code:", error.code);
    return {error: error.code};
  }
});

exports.sendEventUpdateNotification = onDocumentUpdated({
  region: "us-central1",
  document: "News/{eventId}"
}, async (event) => {
  const newData = event.data.after.data();
  const oldData = event.data.before.data();
  const eventId = event.params.eventId;

  // Check if important fields changed
  if (newData.Name === oldData.Name && 
      newData.Date.seconds === oldData.Date.seconds &&
      newData.Location === oldData.Location) {
    return null;
  }

  const title = `Event Update: ${newData.Name}`;
  const body = `Details for ${newData.Name} have been updated. Check the app for changes.`;

  const message = {
    notification: { title, body },
    data: { eventId },
    topic: `event_${eventId}`
  };

  try {
    const response = await getMessaging().send(message);
    logger.log("Successfully sent update message:", response);

    // Persist notification for subscribed users
    const usersSnapshot = await getFirestore().collection("users")
      .where("bookedEvents", "array-contains", eventId)
      .get();
    
    if (!usersSnapshot.empty) {
        const batch = getFirestore().batch();
        usersSnapshot.docs.forEach(doc => {
            const ref = doc.ref.collection("notifications").doc();
            batch.set(ref, {
                title,
                body,
                timestamp: FieldValue.serverTimestamp(),
                read: false,
                type: 'event_update',
                eventId: eventId
            });
        });
        await batch.commit();
        logger.log(`Persisted notifications for ${usersSnapshot.size} users`);
    }

    return {success: true};
  } catch (error) {
    logger.error("Error sending update message:", error);
    return {error: error.code};
  }
});

exports.sendEventCancellationNotification = onDocumentDeleted({
  region: "us-central1",
  document: "News/{eventId}"
}, async (event) => {
  const eventData = event.data.data();
  const eventId = event.params.eventId;
  const eventName = eventData.Name;

  const title = `Event Cancelled: ${eventName}`;
  const body = `The event ${eventName} has been cancelled.`;

  const message = {
    notification: { title, body },
    data: { eventId },
    topic: `event_${eventId}`
  };

  try {
    const response = await getMessaging().send(message);
    logger.log("Successfully sent cancellation message:", response);

    // Persist notification for subscribed users
    const usersSnapshot = await getFirestore().collection("users")
      .where("bookedEvents", "array-contains", eventId)
      .get();
    
    if (!usersSnapshot.empty) {
        const batch = getFirestore().batch();
        usersSnapshot.docs.forEach(doc => {
            const ref = doc.ref.collection("notifications").doc();
            batch.set(ref, {
                title,
                body,
                timestamp: FieldValue.serverTimestamp(),
                read: false,
                type: 'event_cancellation',
                eventId: eventId
            });
        });
        await batch.commit();
        logger.log(`Persisted notifications for ${usersSnapshot.size} users`);
    }

    return {success: true};
  } catch (error) {
    logger.error("Error sending cancellation message:", error);
    return {error: error.code};
  }
});

exports.sendReviewNotification = onDocumentUpdated({
  region: "us-central1",
  document: "News/{eventId}"
}, async (event) => {
  const newData = event.data.after.data();
  const oldData = event.data.before.data();
  
  const newRatings = newData.ratings || {};
  const oldRatings = oldData.ratings || {};

  // Check if a new review was added
  if (Object.keys(newRatings).length <= Object.keys(oldRatings).length) {
    return null;
  }
  
  const creatorId = newData.creatorId;
  if (!creatorId) return null;

  // Get creator's FCM token
  const userDoc = await getFirestore().collection("users").doc(creatorId).get();
  if (!userDoc.exists) return null;
  
  const token = userDoc.data().fcmToken;

  const title = `New Review for ${newData.Name}`;
  const body = `Someone left a review on your event!`;

  if (token) {
      const message = {
        notification: { title, body },
        data: { eventId: event.params.eventId },
        token: token
      };

      try {
        const response = await getMessaging().send(message);
        logger.log("Successfully sent review message:", response);
      } catch (error) {
        logger.error("Error sending review message:", error);
      }
  } else {
    logger.log("No FCM token for creator");
  }

  // Persist notification for creator
  await getFirestore().collection("users").doc(creatorId).collection("notifications").add({
      title,
      body,
      timestamp: FieldValue.serverTimestamp(),
      read: false,
      type: 'review',
      eventId: event.params.eventId
  });

  return {success: true};
});

exports.checkWaitlistOnCancellation = onDocumentUpdated({
  region: "us-central1",
  document: "users/{userId}"
}, async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  
  const beforeBooked = beforeData.bookedEvents || [];
  const afterBooked = afterData.bookedEvents || [];

  // Find events that were removed (cancelled)
  const cancelledEvents = beforeBooked.filter(id => !afterBooked.includes(id));

  if (cancelledEvents.length === 0) return null;

  const promises = cancelledEvents.map(async (eventId) => {
      const eventRef = getFirestore().collection("News").doc(eventId);
      const eventDoc = await eventRef.get();
      
      if (!eventDoc.exists) return;

      const eventData = eventDoc.data();
      const waitlist = eventData.waitlist || [];

      if (waitlist.length > 0) {
          const firstUserId = waitlist[0];
          
          // Get that user's token
          const userDoc = await getFirestore().collection("users").doc(firstUserId).get();
          
          if (!userDoc.exists) return;

          const token = userDoc.data().fcmToken;

          const title = `Spot Opened: ${eventData.Name}`;
          const body = `A spot has opened up for ${eventData.Name}! Register now to secure your place.`;

          if (token) {
              const message = {
                  notification: { title, body },
                  token: token
              };
              await getMessaging().send(message);
              logger.log(`Notified waitlisted user ${firstUserId} for event ${eventId}`);
          }
          
          // Persist notification
          await getFirestore().collection("users").doc(firstUserId).collection("notifications").add({
              title,
              body,
              timestamp: FieldValue.serverTimestamp(),
              read: false,
              type: 'waitlist_alert',
              eventId: eventId
          });
      }
  });

  await Promise.all(promises);
});
