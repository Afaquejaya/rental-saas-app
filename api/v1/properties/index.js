import { db } from "hatchable";

export const access = "public";
export const methods = ["GET", "POST"];

function response(res, data, message = "OK") {
  return res.json({ success: true, data, message });
}
function fail(res, status, code, message) {
  return res.status(status).json({ success: false, error: { code, message } });
}
function isUuid(value) { return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }

export default async function (req, res) {
  try {
    if (req.method === "GET") {
      const { rows } = await db.query(`SELECT p.*, COUNT(u.id)::int AS unit_count FROM properties p LEFT JOIN units u ON u.property_id = p.id GROUP BY p.id ORDER BY p.created_at DESC`);
      return response(res, rows);
    }
    const b = req.body || {};
    if (!isUuid(b.owner_id) || !b.name || !b.address_line1 || !b.city || !b.property_type) return fail(res, 400, "VALIDATION_ERROR", "owner_id, name, address_line1, city and property_type are required");
    const allowed = ["apartment", "house", "building", "commercial", "other"];
    if (!allowed.includes(b.property_type)) return fail(res, 400, "VALIDATION_ERROR", "Invalid property_type");
    const { rows } = await db.query(`INSERT INTO properties (owner_id,name,address_line1,address_line2,city,state,postal_code,country,property_type,status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,COALESCE($10,'active')) RETURNING *`, [b.owner_id,b.name,b.address_line1,b.address_line2||null,b.city,b.state||null,b.postal_code||null,b.country||"India",b.property_type,b.status||"active"]);
    return res.status(201).json({ success: true, data: rows[0], message: "Property created successfully" });
  } catch (e) {
    return fail(res, e?.code === "23505" ? 409 : 500, e?.code === "23505" ? "DUPLICATE_RESOURCE" : "INTERNAL_ERROR", e?.code === "23505" ? "A property with this unique value already exists" : "Unable to process property request");
  }
}