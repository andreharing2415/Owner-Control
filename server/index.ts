import express from "express";
import path from "path";
import fs from "fs";
import { createServer } from "http";

const app = express();
const httpServer = createServer(app);

const distPath = path.resolve(import.meta.dirname, "public");
if (!fs.existsSync(distPath)) {
  throw new Error(
    `Could not find the build directory: ${distPath}, make sure to build the client first`,
  );
}

app.use(express.static(distPath));

// SPA fallback - serve index.html for all non-file routes
app.use("/{*path}", (_req, res) => {
  res.sendFile(path.resolve(distPath, "index.html"));
});

const port = parseInt(process.env.PORT || "3000", 10);
httpServer.listen(port, "0.0.0.0", () => {
  console.log(`Frontend serving on port ${port}`);
});
