const { addLog } = require("../services/logStream");

const submitReport = (pool) => async (req, res) => {
  const t = req.t || ((key) => key);
  const { reporterId, reportedId, reason, imageUrl } = req.body;
  if (!reporterId || !reportedId) {
    return res.status(400).json({ error: t("errors.missingReportFields") });
  }
  try {
    await pool.query(
      "INSERT INTO reports (reporter_id, reported_id, reason, image_url) VALUES ($1, $2, $3, $4)",
      [reporterId, reportedId, reason || "unspecified", imageUrl || null]
    );
    addLog("info", "Report submitted via API", {
      reporterId,
      reportedId,
      imageUrl,
      requestId: req.requestId
    });
    return res.json({ status: "ok" });
  } catch (err) {
    addLog("error", "Report API error", { error: err.message, requestId: req.requestId });
    return res.status(500).json({ error: t("errors.failedReport") });
  }
};

module.exports = { submitReport };
