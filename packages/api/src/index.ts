import 'dotenv/config';
import express from 'express';
import cors from 'cors';
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

const app = express();
app.use(cors());

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

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[api:error]', err);
  res.status(500).json({ error: 'internal_error', message: err?.message });
});

app.listen(env.PORT, () => {
  console.log(`[api] listening on http://localhost:${env.PORT}`);
});
