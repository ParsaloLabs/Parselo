import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './env';
import authRouter from './routes/auth';
import meRouter from './routes/me';
import addressesRouter from './routes/addresses';
import couriersRouter from './routes/couriers';
import quotesRouter from './routes/quotes';
import ordersRouter from './routes/orders';
import agentRouter from './routes/agent';
import adminRouter from './routes/admin';
import paymentsRouter, { webhookHandler } from './routes/payments';
import configRouter from './routes/config';
import { dispatchSweep } from './dispatch';
import { initializeSocket } from './io';

const app = express();
initializeSocket();

if (env.TRUST_PROXY) app.set('trust proxy', true);

app.use(helmet());

const corsOrigins = env.CORS_ORIGINS
  ? env.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean)
  : true;
app.use(cors({ origin: corsOrigins }));

// Razorpay webhook needs the raw body for HMAC verification — mount before json parser.
app.post('/api/v1/payments/webhook', ...webhookHandler);

app.use(express.json({ limit: '2mb' }));

app.get('/', (_req, res) => res.json({
  message: 'Welcome to the Parsalo API',
  version: '0.1.0',
  health: '/health',
  endpoints: '/api/v1'
}));

app.get('/health', (_req, res) => res.json({ ok: true }));

app.use('/api/v1/auth', authRouter);
app.use('/api/v1', meRouter);
app.use('/api/v1/addresses', addressesRouter);
app.use('/api/v1/couriers', couriersRouter);
app.use('/api/v1/quotes', quotesRouter);
app.use('/api/v1/orders', ordersRouter);
app.use('/api/v1/agent', agentRouter);
app.use('/api/v1/admin', adminRouter);
app.use('/api/v1/payments', paymentsRouter);
app.use('/api/v1/config', configRouter);

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[api:error]', err);
  res.status(500).json({ error: 'internal_error', message: err?.message });
});

app.listen(env.PORT, '0.0.0.0', () => {
  console.log(`[api] listening on http://localhost:${env.PORT}`);
});

// Background dispatch sweeper: expires stale offers + re-dispatches orders
// whose offers all aged out. Runs in-process; safe because every operation is
// idempotent and guarded by row-level state in the DB.
const DISPATCH_SWEEP_INTERVAL_MS = 10_000;
setInterval(() => { void dispatchSweep(); }, DISPATCH_SWEEP_INTERVAL_MS);
// Initial kick so any pending paid orders from before the deploy get offered.
setTimeout(() => { void dispatchSweep(); }, 2_000);
