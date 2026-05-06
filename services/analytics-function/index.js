const functions = require('@google-cloud/functions-framework');
const { Firestore } = require('@google-cloud/firestore');
const { TypeCompiler } = require('@sinclair/typebox/compiler');


const { MovieStatsSchema, ProcessedStatsSchema } = require('./schemas/collection-schemas');


const MovieStatsValidator = TypeCompiler.Compile(MovieStatsSchema);
const ProcessedStatsValidator = TypeCompiler.Compile(ProcessedStatsSchema);

const { PublishedMessageSchema } = require('./schemas/messages-schemas');
const { publishMessage } = require('./utils/pub-sub-utils');
const NotificationMessageValidator = TypeCompiler.Compile(PublishedMessageSchema);

const firestore = new Firestore({ databaseId: '(default)' });

const statsCollection = firestore.collection('movie-stats');
const processedCollection = firestore.collection('processed-messages');

async function processEvent(messageId, eventName, eventData) {

  const movieData = eventData.data;

  if (eventName == "movie_viewed") {

    console.log("messageId =", messageId);
    console.log("movie data ", movieData);

    const processedDoc = await processedCollection.doc(messageId).get();

    if (processedDoc.exists) {
      console.log(JSON.stringify({
        msg: 'Duplicate message skipped',
        messageId,
        movieId: movieData.movieId
      }));
      return { status: 'duplicate' };
    }

    const movieDoc = {
      movieId: movieData.movieId,
      movieTitle: movieData.movieTitle || 'Unknown',
      timestamp: new Date().toISOString()
    }

    if (!MovieStatsValidator.Check(movieDoc)) {
      console.error("Invalid schema", [...MovieStatsValidator.Errors(movieDoc)]);
      throw new Error("Invalid MovieStats");
    }

    movieDoc.expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    const statsDocRef = await statsCollection.add(movieDoc);

    const prcDoc = {
      movieId: movieData.movieId,
      processedAt: new Date().toISOString()
    }

    if (!ProcessedStatsValidator.Check(prcDoc)) {
      console.error("Invalid schema", [...ProcessedStatsValidator.Errors(prcDoc)]);
      throw new Error("Invalid ProcessedStats");
    }

    await processedCollection.doc(messageId).set(prcDoc);

    console.log(JSON.stringify({
      msg: 'Event processed',
      messageId,
      movieId: movieData.movieId,
      event: eventName
    }));


    const notificationMessage = {
      event: eventName,
      data: {
        movieId: movieData.movieId,
        movieTitle: movieData.movieTitle || 'Unknown'
      },
      timestamp: new Date().toISOString(),
      sourceEventId: statsDocRef.id
    }

    if (!NotificationMessageValidator.Check(notificationMessage)) {
      console.error("Invalid schema", [...NotificationMessageValidator.Errors(notificationMessage)]);
      throw new Error("Invalid NotificationMessage");
    }

    try {
      await publishMessage(notificationMessage);
      console.log("Message was published ", notificationMessage);
    } catch (err) {
      console.error('Publish failed', err);
      throw new Error("Failed to publish message");
    }

    return { status: 'processed' };
  }
  if (eventName == "movies_viewed" || eventName == "comments_viewed") {
    return { status: 'skipped for now' };
  }

  return { status: 'ignored', event: eventName };

}

functions.cloudEvent('processEvent', async cloudEvent => {

  try {

    console.log('Function triggered');

    const message = cloudEvent.data?.message;

    if (!message || !message.data) {
      console.log('No message payload');
      return;
    }

    const messageId = message.messageId;

    const decodedData = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );
    const eventName = decodedData.event;

    console.log('Received event:', decodedData);

    const result = await processEvent(messageId, eventName, decodedData);

    console.log(JSON.stringify({
      msg: 'Push message handled',
      messageId,
      result: result.status
    }));


  } catch (error) {
    console.error('Error processing event:', error);
    throw error;
  }
});
