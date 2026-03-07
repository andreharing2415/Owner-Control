import { Client } from "pg";

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.error("DATABASE_URL is required to wait for the database.");
  process.exit(1);
}

const maxAttempts = 30;
const delayMs = 1000;

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForDb() {
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const client = new Client({ connectionString: databaseUrl });
      await client.connect();
      await client.end();
      console.log("Database is ready.");
      return;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.log(`Waiting for database (${attempt}/${maxAttempts})... ${message}`);
      await sleep(delayMs);
    }
  }

  console.error("Database did not become ready in time.");
  process.exit(1);
}

await waitForDb();
