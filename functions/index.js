const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
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
    return {success: true};
  } catch (error) {
    logger.error("Error sending message:", error);
    // Print the exact error code to help debugging
    if (error.code) logger.error("Error Code:", error.code);
    return {error: error.code};
  }
});
