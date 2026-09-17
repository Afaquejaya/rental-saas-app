import { db } from "hatchable";

export const access = "public";
export const methods = ["GET"];

export default async function (req, res) {
  try {
    await db.query("SELECT 1");
    res.json({
      status: "ok",
      service: "rental-property-api",
      version: "v1",
      database: "ok",
    });
  } catch (error) {
    console.error("Health check failed", error);
    res.status(503).json({
      status: "degraded",
      service: "rental-property-api",
      version: "v1",
      database: "unavailable",
    });
  }
}