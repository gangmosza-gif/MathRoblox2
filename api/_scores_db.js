import { neon } from '@neondatabase/serverless';

let sqlClient = null;
let schemaReady = false;

export function getSql() {
  if (!process.env.DATABASE_URL) {
    throw new Error('Missing DATABASE_URL');
  }

  if (!sqlClient) {
    sqlClient = neon(process.env.DATABASE_URL);
  }

  return sqlClient;
}

export async function ensureScoreSchema(sql) {
  if (schemaReady) return;

  await sql`
    CREATE TABLE IF NOT EXISTS game_sessions (
      id BIGSERIAL PRIMARY KEY,
      player_name TEXT NOT NULL,
      level INTEGER,
      mode TEXT NOT NULL,
      correct_count INTEGER NOT NULL,
      total_questions INTEGER NOT NULL,
      stars INTEGER NOT NULL,
      coins_earned INTEGER NOT NULL,
      is_endless BOOLEAN NOT NULL DEFAULT FALSE,
      started_at TIMESTAMPTZ,
      finished_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`
    CREATE TABLE IF NOT EXISTS game_answers (
      id BIGSERIAL PRIMARY KEY,
      session_id BIGINT NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
      question_index INTEGER NOT NULL,
      attempt_number INTEGER NOT NULL,
      expression TEXT NOT NULL,
      story_text TEXT,
      operation TEXT,
      correct_answer INTEGER,
      player_answer INTEGER,
      is_correct BOOLEAN NOT NULL,
      timed_out BOOLEAN NOT NULL DEFAULT FALSE,
      hint_step INTEGER NOT NULL DEFAULT 0,
      answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;

  await sql`CREATE INDEX IF NOT EXISTS idx_game_sessions_finished_at ON game_sessions(finished_at DESC)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_game_answers_session_id ON game_answers(session_id)`;

  schemaReady = true;
}

export function requireAdmin(req) {
  const token = process.env.ADMIN_TOKEN;
  if (!token) {
    return { ok: false, status: 500, error: 'Missing ADMIN_TOKEN' };
  }

  const authHeader = req.headers.authorization || '';
  const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  const queryToken = req.query?.token || '';

  if (bearerToken !== token && queryToken !== token) {
    return { ok: false, status: 401, error: 'Unauthorized' };
  }

  return { ok: true };
}

export function toSafeName(name) {
  const cleaned = String(name || '').trim().slice(0, 40);
  return cleaned || 'นักเรียน';
}

export function toCsv(rows) {
  const headers = [
    'session_id',
    'player_name',
    'level',
    'mode',
    'correct_count',
    'total_questions',
    'stars',
    'coins_earned',
    'is_endless',
    'started_at',
    'finished_at',
    'question_index',
    'attempt_number',
    'expression',
    'story_text',
    'operation',
    'correct_answer',
    'player_answer',
    'is_correct',
    'timed_out',
    'hint_step',
    'answered_at'
  ];

  const escapeCell = (value) => {
    if (value === null || value === undefined) return '';
    const text = String(value);
    return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
  };

  return [
    headers.join(','),
    ...rows.map((row) => headers.map((header) => escapeCell(row[header])).join(','))
  ].join('\n');
}
