import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { pool } from '../src/db';

async function main() {
  const sql = fs.readFileSync(path.join(__dirname, '..', 'db', 'seed.sql'), 'utf8');
  console.log('[seed] inserting couriers + branches + pricing rules');
  await pool.query(sql);

  // Default admin
  const adminEmail = process.env.SEED_ADMIN_EMAIL ?? 'admin@parsalo.in';
  const adminPass = process.env.SEED_ADMIN_PASSWORD ?? 'admin1234';
  const adminHash = await bcrypt.hash(adminPass, 10);
  await pool.query(
    `INSERT INTO admins (email, password_hash, full_name, role)
     VALUES ($1, $2, 'Default Admin', 'ops')
     ON CONFLICT (email) DO NOTHING`,
    [adminEmail, adminHash],
  );

  // Default test agent
  const agentPhone = process.env.SEED_AGENT_PHONE ?? '+919999999999';
  const agentPass = process.env.SEED_AGENT_PASSWORD ?? 'agent1234';
  const agentHash = await bcrypt.hash(agentPass, 10);
  await pool.query(
    `INSERT INTO agents (phone, full_name, password_hash, vehicle_type, vehicle_number, status)
     VALUES ($1, 'Test Agent', $2, 'bike', 'KL-08-AA-1234', 'approved')
     ON CONFLICT (phone) DO NOTHING`,
    [agentPhone, agentHash],
  );

  console.log('[seed] done');
  console.log(`  admin: ${adminEmail} / ${adminPass}`);
  console.log(`  agent: ${agentPhone} / ${agentPass}`);
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
