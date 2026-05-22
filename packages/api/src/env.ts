import 'dotenv/config';

export const env = {
  PORT: Number(process.env.PORT ?? 4000),
  JWT_SECRET: process.env.JWT_SECRET ?? 'dev-secret-change-me',
  OTP_DEV_MODE: (process.env.OTP_DEV_MODE ?? 'true') === 'true',
  MSG91_AUTH_KEY: process.env.MSG91_AUTH_KEY ?? '',
  MSG91_SENDER_ID: process.env.MSG91_SENDER_ID ?? 'PRCLPL',
  MSG91_TEMPLATE_ID: process.env.MSG91_TEMPLATE_ID ?? '',
  MSG91_TXN_TEMPLATE_ID: process.env.MSG91_TXN_TEMPLATE_ID ?? '',
  RAZORPAY_KEY_ID: process.env.RAZORPAY_KEY_ID ?? '',
  RAZORPAY_KEY_SECRET: process.env.RAZORPAY_KEY_SECRET ?? '',
  RAZORPAY_WEBHOOK_SECRET: process.env.RAZORPAY_WEBHOOK_SECRET ?? '',
};
