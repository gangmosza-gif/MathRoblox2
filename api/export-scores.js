import { ensureScoreSchema, getSql, requireAdmin, toCsv } from './_scores_db.js';

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const admin = requireAdmin(req);
  if (!admin.ok) return res.status(admin.status).json({ error: admin.error });

  try {
    const sql = getSql();
    await ensureScoreSchema(sql);

    const rows = await sql`
      SELECT
        s.id AS session_id,
        s.player_name,
        s.level,
        s.mode,
        s.correct_count,
        s.total_questions,
        s.stars,
        s.coins_earned,
        s.is_endless,
        s.started_at,
        s.finished_at,
        a.question_index,
        a.attempt_number,
        a.expression,
        a.story_text,
        a.operation,
        a.correct_answer,
        a.player_answer,
        a.is_correct,
        a.timed_out,
        a.hint_step,
        a.answered_at
      FROM game_sessions s
      LEFT JOIN game_answers a ON a.session_id = s.id
      ORDER BY s.finished_at DESC, a.question_index ASC, a.attempt_number ASC
    `;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename="mathroblox-scores.csv"');
    return res.status(200).send('\uFEFF' + toCsv(rows));
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message || 'Unexpected server error' });
  }
}
