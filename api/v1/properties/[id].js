import { db } from "hatchable";

export const access = "public";
export const methods = ["GET", "PUT", "DELETE"];

function fail(res, status, code, message) { return res.status(status).json({ success: false, error: { code, message } }); }
function isUuid(v) { return typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v); }

export default async function (req, res) {
  const id = req.params.id;
  if (!isUuid(id)) return fail(res, 400, "VALIDATION_ERROR", "Invalid property id");
  try {
    if (req.method === "GET") {
      const { rows } = await db.query(`SELECT p.*, COUNT(u.id)::int AS unit_count FROM properties p LEFT JOIN units u ON u.property_id = p.id WHERE p.id = $1 GROUP BY p.id`, [id]);
      if (!rows[0]) return fail(res, 404, "NOT_FOUND", "Property not found");
      return res.json({ success: true, data: rows[0], message: "OK" });
    }
    if (req.method === "PUT") {
      const b = req.body || {};
      const { rows } = await db.query(`UPDATE properties SET name=COALESCE($2,name),address_line1=COALESCE($3,address_line1),address_line2=$4,city=COALESCE($5,city),state=$6,postal_code=$7,country=COALESCE($8,country),property_type=COALESCE($9,property_type),status=COALESCE($10,status) WHERE id=$1 RETURNING *`, [id,b.name,b.address_line1,b.address_line2===undefined?null:b.address_line2,b.city,b.state===undefined?null:b.state,b.postal_code===undefined?null:b.postal_code,b.country,b.property_type,b.status]);
      if (!rows[0]) return fail(res, 404, "NOT_FOUND", "Property not found");
      return res.json({ success: true, data: rows[0], message: "Property updated successfully" });
    }
    await db.query(`DELETE FROM properties WHERE id = $1`, [id]);
    return res.json({ success: true, data: null, message: "Property deleted successfully" });
  } catch (e) {
    return fail(res, e?.code === "23503" ? 409 : 500, e?.code === "23503" ? "RESOURCE_IN_USE" : "INTERNAL_ERROR", e?.code === "23503" ? "Property cannot be deleted while dependent records exist" : "Unable to process property request");
  }
}