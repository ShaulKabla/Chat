const getProfile = (pool) => async (req, res) => {
  const t = req.t || ((key) => key);
  const userId = req.user?.sub;
  if (!userId) {
    return res.status(401).json({ error: t("errors.unauthorized") });
  }
  try {
    const { rows } = await pool.query(
      "SELECT user_id, gender, age_group, interests, gender_preference FROM profiles WHERE user_id = $1",
      [userId]
    );
    return res.json({ profile: rows[0] || null });
  } catch (err) {
    return res.status(500).json({ error: t("errors.failedProfileLoad") });
  }
};

const upsertProfile = (pool) => async (req, res) => {
  const t = req.t || ((key) => key);
  const userId = req.user?.sub;
  if (!userId) {
    return res.status(401).json({ error: t("errors.unauthorized") });
  }
  const { gender, ageGroup, interests, genderPreference } = req.body || {};
  if (!gender || !ageGroup || !Array.isArray(interests) || interests.length < 3) {
    return res.status(400).json({ error: t("errors.missingProfile") });
  }
  const sanitizedInterests = interests.map((item) => String(item).trim()).filter(Boolean);
  if (sanitizedInterests.length < 3) {
    return res.status(400).json({ error: t("errors.missingProfile") });
  }

  try {
    const { rows } = await pool.query(
      `
        INSERT INTO profiles (user_id, gender, age_group, interests, gender_preference)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id)
        DO UPDATE SET gender = $2, age_group = $3, interests = $4, gender_preference = $5, updated_at = NOW()
        RETURNING user_id, gender, age_group, interests, gender_preference
      `,
      [userId, gender, ageGroup, sanitizedInterests, genderPreference || "any"]
    );
    return res.json({ profile: rows[0] });
  } catch (err) {
    return res.status(500).json({ error: t("errors.failedProfileSave") });
  }
};

module.exports = {
  getProfile,
  upsertProfile
};
