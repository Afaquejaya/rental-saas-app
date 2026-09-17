import { db } from "hatchable";
import { buildPreview, fail, isUuid, validDate } from "lib/billing.js";
export const access="public"; export const methods=["POST"];
function envelope(res,s,c,m){return res.status(s).json({success:false,error:{code:c,message:m}})}
export default async function(req,res){
 try{
  const b=req.body||{}; if(!isUuid(b.lease_id)||!validDate(b.billing_period_start)||!validDate(b.billing_period_end)) return envelope(res,400,"VALIDATION_ERROR","lease_id, billing_period_start and billing_period_end are required");
  const existing=await db.query(`SELECT id FROM invoices WHERE lease_id=$1 AND billing_period_start=$2 AND billing_period_end=$3 AND status<>'cancelled' LIMIT 1`,[b.lease_id,b.billing_period_start,b.billing_period_end]);
  if(existing.rows[0]) return res.json({success:true,data:await getInvoice(existing.rows[0].id),message:"Invoice already exists for this lease and billing period"});
  const preview=await buildPreview(b);
  const invoiceNumber=`INV-${b.billing_period_start.slice(0,7)}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
  const invoiceId=crypto.randomUUID();
  const tx=[{sql:`INSERT INTO invoices (id,lease_id,invoice_number,billing_period_start,billing_period_end,due_date,subtotal,adjustments,total,amount_paid,amount_due,status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0,$9,'issued') RETURNING id`,params:[invoiceId,b.lease_id,invoiceNumber,b.billing_period_start,b.billing_period_end,preview.due_date,preview.subtotal,"0.00",preview.total]}];
  for(const item of preview.items) tx.push({sql:`INSERT INTO invoice_items (invoice_id,item_type,description,quantity,unit_rate,amount,metadata) VALUES ($1,$2,$3,$4,$5,$6,$7)`,params:[invoiceId,item.type,item.description,item.quantity,item.unit_rate,item.amount,item.metadata]});
  await db.transaction(tx);
  return res.status(201).json({success:true,data:await getInvoice(invoiceId),message:"Invoice generated successfully"});
 }catch(e){const conflict=e?.code==="23505"||String(e?.message||"").toLowerCase().includes("duplicate");return envelope(res,conflict?409:(e.httpStatus||500),conflict?"INVOICE_ALREADY_EXISTS":(e.code||"INTERNAL_ERROR"),conflict?"Invoice already exists for this lease and billing period":(e.message||"Unable to generate invoice"))}
}
async function getInvoice(id){const {rows}=await db.query(`SELECT i.*,l.tenant_id,l.unit_id,t.name tenant_name,u.unit_number,p.name property_name FROM invoices i JOIN leases l ON l.id=i.lease_id JOIN tenants t ON t.id=l.tenant_id JOIN units u ON u.id=l.unit_id JOIN properties p ON p.id=u.property_id WHERE i.id=$1`,[id]);const i=rows[0];const {rows:items}=await db.query(`SELECT * FROM invoice_items WHERE invoice_id=$1 ORDER BY created_at`,[id]);const {rows:payments}=await db.query(`SELECT * FROM payments WHERE invoice_id=$1 ORDER BY payment_date,created_at`,[id]);return {...i,items,payments};}