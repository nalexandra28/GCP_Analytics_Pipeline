import {PubSub} from '@google-cloud/pubsub';
import { PublishedMessage } from '../schemas/pub-sub';

const topicName = 'movie-events';

const projectId = process.env.GCP_PROJECT_ID;
const pubSubClient = projectId ? new PubSub({ projectId }) : new PubSub();

export async function publishMessage(data: PublishedMessage) {
  
  const dataBuffer = Buffer.from(JSON.stringify(data));

  const topic = pubSubClient.topic(topicName);

  try {
    const messageId = await topic.publishMessage({data: dataBuffer});
    console.log(`Message ${messageId} published.`);
    return messageId;
  } catch (error) {
    console.error(
      `Received error while publishing: ${(error as Error).message}`,
    );
    return 1;
  }
}

