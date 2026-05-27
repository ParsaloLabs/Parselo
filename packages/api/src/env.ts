import 'dotenv/config';

export const env = {
  PORT: Number(process.env.PORT ?? 4000),
  JWT_SECRET: process.env.JWT_SECRET ?? 'dev-secret-change-me',
  OTP_DEV_MODE: (process.env.OTP_DEV_MODE ?? 'true') === 'true',
  CORS_ORIGINS: process.env.CORS_ORIGINS ?? '',
  TRUST_PROXY: (process.env.TRUST_PROXY ?? 'false') === 'true',
  MSG91_AUTH_KEY: process.env.MSG91_AUTH_KEY ?? '',
  MSG91_SENDER_ID: process.env.MSG91_SENDER_ID ?? 'PRCLPL',
  MSG91_TEMPLATE_ID: process.env.MSG91_TEMPLATE_ID ?? '',
  MSG91_TXN_TEMPLATE_ID: process.env.MSG91_TXN_TEMPLATE_ID ?? '',
  RAZORPAY_KEY_ID: process.env.RAZORPAY_KEY_ID ?? '',
  RAZORPAY_KEY_SECRET: process.env.RAZORPAY_KEY_SECRET ?? '',
  RAZORPAY_WEBHOOK_SECRET: process.env.RAZORPAY_WEBHOOK_SECRET ?? '',
  PUSHER_APP_ID: process.env.PUSHER_APP_ID ?? '',
  PUSHER_KEY: process.env.PUSHER_KEY ?? '',
  PUSHER_SECRET: process.env.PUSHER_SECRET ?? '',
  PUSHER_CLUSTER: process.env.PUSHER_CLUSTER ?? 'ap2',
  // Firebase Admin SDK — pick whichever is easier per environment.
  // PATH = filesystem path to service-account JSON (best for local dev,
  // never commit the file). JSON = the entire JSON inlined as one env var
  // (best for hosts like Fly/Render that prefer env-only secrets).
  FIREBASE_SERVICE_ACCOUNT_PATH: process.env.FIREBASE_SERVICE_ACCOUNT_PATH ?? '',
  FIREBASE_SERVICE_ACCOUNT_JSON: process.env.FIREBASE_SERVICE_ACCOUNT_JSON ?? '',
};
