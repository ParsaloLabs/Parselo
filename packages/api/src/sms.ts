import { env } from './env';

export async function sendOtpSms(phone: string, code: string) {
  if (env.OTP_DEV_MODE || !env.MSG91_AUTH_KEY) {
    console.log(`[sms:dev] OTP for ${phone} = ${code}`);
    return;
  }
  const url = 'https://control.msg91.com/api/v5/otp';
  const params = new URLSearchParams({
    template_id: env.MSG91_TEMPLATE_ID,
    mobile: phone.replace(/^\+?/, ''),
    otp: code,
    sender: env.MSG91_SENDER_ID,
  });
  await fetch(`${url}?${params.toString()}`, {
    method: 'POST',
    headers: { authkey: env.MSG91_AUTH_KEY },
  });
}
