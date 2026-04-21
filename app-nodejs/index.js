// =============================================================================
// Node.js Express App
// =============================================================================
// Endpoints:
//   GET /        → greeting + secret status
//   GET /health  → health check (liveness/readiness probe target)
// =============================================================================

const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

app.get("/", (_req, res) => {
  const secretValue = process.env.NODEJS_APP_SECRET;
  res.json({
    app: "nodejs-express",
    version: "1.0.0",
    message: "Hello from the Node.js Express app! 🚀",
    secret_mounted: secretValue !== undefined,
    secret_preview: secretValue ? `${secretValue.substring(0, 4)}****` : "NOT_SET",
  });
});

app.get("/health", (_req, res) => {
  res.status(200).json({ status: "healthy" });
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Node.js Express app listening on port ${PORT}`);
});
