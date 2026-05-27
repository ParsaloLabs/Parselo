import Pusher from 'pusher';
import { env } from './env';

let pusher: Pusher | null = null;

export function initializeSocket() {
  if (
    env.PUSHER_APP_ID &&
    env.PUSHER_KEY &&
    env.PUSHER_SECRET &&
    env.PUSHER_CLUSTER
  ) {
    pusher = new Pusher({
      appId: env.PUSHER_APP_ID,
      key: env.PUSHER_KEY,
      secret: env.PUSHER_SECRET,
      cluster: env.PUSHER_CLUSTER,
      useTLS: true,
    });
    console.log('[pusher] Channels API client initialized');
  } else {
    console.warn(
      '[pusher] credentials missing — real-time events will log to standard console'
    );
  }
}

export function broadcastToOrder(orderId: string, event: string, payload: any) {
  if (!pusher) {
    console.log(`[pusher:mock] broadcast order-${orderId} event:${event}`, payload);
    return;
  }
  pusher.trigger(`order-${orderId}`, event, payload)
    .catch((err) => {
      console.error(`[pusher:error] broadcast to order-${orderId} failed`, err);
    });
}
