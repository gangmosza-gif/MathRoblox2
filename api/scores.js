import { ensureScoreSchema, getSql, requireAdmin, toSafeName } from './_scores_db.js';

function toNumberOrNull(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function toNumberOrDefault(value, fallback = 0) {
  const number = toNumberOrNull(value);
  return number === null ? fallback : number;
}

export default async function handler(req, res) {
  try {
    const sql = getSql();
    await ensureScoreSchema(sql);

    if (req.method === 'POST') {
      const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
      const answers = Array.isArray(body.answers) ? body.answers.slice(0, 200) : [];
      const playerName = toSafeName(body.playerName);
      const totalQuestions = toNumberOrDefault(body.totalQuestions, answers.length);

      const inserted = await sql`
        INSERT INTO game_sessions (
          player_name,
          level,
          mode,
          correct_count,
          total_questions,
          stars,
          coins_earned,
          is_endless,
          started_at,
          finished_at
        )
        VALUES (
          ${playerName},
          ${toNumberOrNull(body.level)},
          ${String(body.mode || 'practice').slice(0, 30)},
          ${toNumberOrDefault(body.correctCount)},
          ${totalQuestions},
          ${toNumberOrDefault(body.stars)},
          ${toNumberOrDefault(body.coinsEarned)},
          ${Boolean(body.isEndless)},
          ${body.startedAt ? new Date(body.startedAt).toISOString() : null},
          ${body.finishedAt ? new Date(body.finishedAt).toISOString() : new Date().toISOString()}
        )
        RETURNING id
      `;

      const sessionId = inserted[0].id;

      for (const answer of answers) {
        await sql`
          INSERT INTO game_answers (
            session_id,
            question_index,
            attempt_number,
            expression,
            story_text,
            operation,
            correct_answer,
            player_answer,
            is_correct,
            timed_out,
            hint_step,
            answered_at
          )
          VALUES (
            ${sessionId},
            ${toNumberOrDefault(answer.questionIndex)},
            ${toNumberOrDefault(answer.attemptNumber, 1)},
            ${String(answer.expression || '').slice(0, 500)},
            ${answer.storyText ? String(answer.storyText).slice(0, 1000) : null},
            ${answer.operation ? String(answer.operation).slice(0, 5) : null},
            ${toNumberOrNull(answer.correctAnswer)},
            ${toNumberOrNull(answer.playerAnswer)},
            ${Boolean(answer.isCorrect)},
            ${Boolean(answer.timedOut)},
            ${toNumberOrDefault(answer.hintStep)},
            ${answer.answeredAt ? new Date(answer.answeredAt).toISOString() : new Date().toISOString()}
          )
        `;
      }

      return res.status(200).json({ ok: true, sessionId });
    }

    if (req.method === 'GET') {
      const admin = requireAdmin(req);
      if (!admin.ok) return res.status(admin.status).json({ error: admin.error });

      const rows = await sql`
        SELECT
          s.id,
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
          COUNT(a.id)::INT AS answer_count
        FROM game_sessions s
        LEFT JOIN game_answers a ON a.session_id = s.id
        GROUP BY s.id
        ORDER BY s.finished_at DESC
        LIMIT 200
      `;

      return res.status(200).json({ rows });
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message || 'Unexpected server error' });
  }
}
