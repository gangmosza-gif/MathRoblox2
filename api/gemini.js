export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'Missing GEMINI_API_KEY' });
  }

  try {
    const { type, prompt, systemInstruction } = req.body || {};
    if (!prompt || !['text', 'image'].includes(type)) {
      return res.status(400).json({ error: 'Invalid request' });
    }

    if (type === 'text') {
      const payload = {
        contents: [{ parts: [{ text: prompt }] }]
      };

      if (systemInstruction) {
        payload.systemInstruction = {
          parts: [{ text: systemInstruction }]
        };
      }

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        }
      );

      const result = await response.json();
      if (!response.ok) {
        return res.status(response.status).json({ error: result.error?.message || 'Gemini request failed' });
      }

      return res.status(200).json({
        text: result.candidates?.[0]?.content?.parts?.[0]?.text || null
      });
    }

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          instances: { prompt },
          parameters: { sampleCount: 1 }
        })
      }
    );

    const result = await response.json();
    if (!response.ok) {
      return res.status(response.status).json({ error: result.error?.message || 'Imagen request failed' });
    }

    const base64Data = result.predictions?.[0]?.bytesBase64Encoded;
    return res.status(200).json({
      imageUrl: base64Data ? `data:image/png;base64,${base64Data}` : null
    });
  } catch (error) {
    return res.status(500).json({ error: error.message || 'Unexpected server error' });
  }
}
