import jwt from 'jsonwebtoken';
import type { Request, Response, NextFunction } from 'express';
import { env } from './env';

export type Principal =
  | { kind: 'user'; userId: string }
  | { kind: 'agent'; agentId: string }
  | { kind: 'admin'; adminId: string; role: string };

export function signUserToken(userId: string) {
  return jwt.sign({ kind: 'user', userId }, env.JWT_SECRET, { expiresIn: '30d' });
}

export function signAgentToken(agentId: string) {
  return jwt.sign({ kind: 'agent', agentId }, env.JWT_SECRET, { expiresIn: '7d' });
}

export function signAdminToken(adminId: string, role: string) {
  return jwt.sign({ kind: 'admin', adminId, role }, env.JWT_SECRET, { expiresIn: '7d' });
}

declare global {
  namespace Express {
    interface Request {
      principal?: Principal;
    }
  }
}

export function requireAuth(kinds: Array<Principal['kind']> = ['user', 'agent', 'admin']) {
  return (req: Request, res: Response, next: NextFunction) => {
    const header = req.header('authorization') ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'missing_token' });
    try {
      const decoded = jwt.verify(token, env.JWT_SECRET) as Principal;
      if (!kinds.includes(decoded.kind)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      req.principal = decoded;
      next();
    } catch {
      return res.status(401).json({ error: 'invalid_token' });
    }
  };
}
