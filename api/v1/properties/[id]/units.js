import { db } from "hatchable";

export const access = "public";
export const methods = ["GET", "POST"];
function fail(res, status, code, message) { return res.status(status).json({ success: false, error: { code, message } }); }
function isUuid(v) { return typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v); }

export default async function (req, res) {
  const propertyId = req.params.id;
  if (!isUuid(propertyId)) return fail(res, 400, "VALIDATION_ERROR", "Invalid property id");
  try {
    const exists = await db.query(`SELECT id FROM properties WHERE id=$1`, [propertyId]);
    if (!exists.rows[0]) return fail(res, 404, "NOT_FOUND", "Property not found");
    if (req.method === "GET") {
      const { rows } = await db.query(`SELECT * FROM units WHERE property_id=$1 ORDER BY unit_number`, [propertyId]);
      return res.json({ success: true, data: rows, message: "OK" });
    }
    const b = req.body || {};
    if (!b.unit_number) return fail(res, 400, "VALIDATION_ERROR", "unit_number is required");
    const { rows } = await db.query(`INSERT INTO units (property_id,unit_number,floor,unit_type,status) VALUES ($1,$2,$3,$4,COALESCE($5,'vacant')) RETURNING *`, [propertyId,b.unit_number,b.floor??null,b.unit_type||null,b.status||"vacant"]);
    return res.status(201).json({ success: true, data: rows[0], message: "Unit created successfully" });
  } catch (e) {
    const duplicate = e?.code === "23505" || e?.constraint === "units_property_id_unit_number_key" || String(e?.message || "").toLowerCase().includes("duplicate key");
    return fail(res, duplicate ? 409 : 500, duplicate ? "DUPLICATE_UNIT" : "INTERNAL_ERROR", duplicate ? "Unit number already exists in this property" : "Unable to process unit request");
  }
}