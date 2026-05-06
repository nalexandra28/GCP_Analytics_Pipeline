const { PubSub } = require('@google-cloud/pubsub');

const topicName = 'event-notifications';

const projectId = process.env.GCP_PROJECT_ID;

const pubSubClient = projectId
  ? new PubSub({ projectId })
  : new PubSub();

async function publishMessage(data) {
  
  const dataBuffer = Buffer.from(JSON.stringify(data));

  const topic = pubSubClient.topic(topicName);

  try {
    const messageId = await topic.publishMessage({data: dataBuffer});
    console.log(`Message ${messageId} published.`);
    return messageId;
  } catch (error) {
    console.error(
      `Received error while publishing: ${error.message}`,
    );
    throw error;
  }

}

module.exports = { publishMessage };

