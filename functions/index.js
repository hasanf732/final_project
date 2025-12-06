const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.eventReminders = functions.pubsub.schedule('every 60 minutes').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const twentyFourHoursFromNow = admin.firestore.Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000);
    const oneHourFromNow = admin.firestore.Timestamp.fromMillis(now.toMillis() + 1 * 60 * 60 * 1000);

    const events = await admin.firestore().collection('News').get();

    for (const eventDoc of events.docs) {
        const event = eventDoc.data();
        const eventId = eventDoc.id;
        const eventDate = event.Date;

        // Check for 24-hour reminder
        if (eventDate <= twentyFourHoursFromNow && eventDate > now) {
            const reminderSent = await wasReminderSent(eventId, '24_hour');
            if (!reminderSent) {
                await sendNotificationsForEvent(eventId, event, '24_hour');
                await markReminderAsSent(eventId, '24_hour');
            }
        }

        // Check for 1-hour reminder
        if (eventDate <= oneHourFromNow && eventDate > now) {
            const reminderSent = await wasReminderSent(eventId, '1_hour');
            if (!reminderSent) {
                await sendNotificationsForEvent(eventId, event, '1_hour');
                await markReminderAsSent(eventId, '1_hour');
            }
        }
    }
});

async function sendNotificationsForEvent(eventId, event, reminderType) {
    const usersSnapshot = await admin.firestore().collection('users').where('bookedEvents', 'array-contains', eventId).get();
    if (usersSnapshot.empty) {
        return;
    }

    const userIds = usersSnapshot.docs.map(doc => doc.id);
    const tokens = [];

    for (const userId of userIds) {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const userData = userDoc.data();
        if (userData && userData.fcmToken) {
            tokens.push(userData.fcmToken);
        }
    }

    if (tokens.length === 0) {
        return;
    }

    const message = {
        notification: {
            title: 'Event Reminder',
            body: `Your event '${event.Name}' is starting ${reminderType === '24_hour' ? 'in 24 hours' : 'in 1 hour'}.`
        },
        tokens: tokens,
    };

    await admin.messaging().sendMulticast(message);
}

async function wasReminderSent(eventId, reminderType) {
    const doc = await admin.firestore().collection('reminders').doc(`${eventId}_${reminderType}`).get();
    return doc.exists;
}

async function markReminderAsSent(eventId, reminderType) {
    await admin.firestore().collection('reminders').doc(`${eventId}_${reminderType}`).set({ sent: true });
}
