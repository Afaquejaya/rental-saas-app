import { db } from "hatchable";

export const access = "public";
export const methods = ["GET", "POST"];
function fail(res, status, code, message) { return res.status(status).json({ success: false, error: { code, message } }); }

export default async function (req, res) {
  try {
    if (req.method === "GET") {
      const { rows } = await db.query(`SELECT t.*, COUNT(l.id)::int AS lease_count FROM tenants t LEFT JOIN leases l ON l.tenant_id=t.id GROUP BY t.id ORDER BY t.created_at DESC`);
      return res.json({ success: true, data: rows, message: "OK" });
    }
    const b=req.body||{};
    if (!b.name) return fail(res,400,"VALIDATION_ERROR","name is required");
    const { rows }=await db.query(`INSERT INTO tenants (name,phone,email,address,emergency_contact_name,emergency_contact_phone,id_document_type,id_document_reference,status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,COALESCE($9,'active')) RETURNING *`,[b.name,b.phone||null,b.email||null,b.address||null,b.emergency_contact_name||null,b.emergency_contact_phone||null,b.id_document_type||null,b.id_document_reference||null,b.status||"active"]);
    return res.status(201).json({success:true,data:rows[0],message:"Tenant created successfully"});
  } catch(e){ return fail(res,500,"INTERNAL_ERROR","Unable to process tenant request"); }
}