# Flutter domain contracts — Step 3 billing

Hatchable executes the working billing engine as JavaScript API functions + PostgreSQL. These contracts are for the external Flutter + FastAPI repository and keep presentation independent from billing implementation details.

## Billing endpoints

`POST /api/v1/billing/preview`
```json
{"lease_id":"uuid","billing_period_start":"YYYY-MM-DD","billing_period_end":"YYYY-MM-DD"}
```
Returns `success`, `data.billing_period`, `data.due_date`, `items`, `rent`, `utilities`, `subtotal`, `adjustments`, `total`, `warnings`, and `errors`.

`POST /api/v1/billing/generate-invoice`
Same request as preview. Creates an invoice transactionally. Repeating the same lease + period is idempotent and returns the existing invoice.

`POST /api/v1/billing/recalculate-invoice/:id`
Recalculates draft/issued invoices with no payments. Paid invoices are immutable.

`GET /api/v1/invoices/:id`
Returns invoice, line items, and payments.

`GET /api/v1/invoices/:id/payments`
Returns payments allocated to the invoice.

`GET /api/v1/invoices/:id/balance`
Returns `{total, amount_paid, amount_due, status}` from server-side payment data.

`POST /api/v1/payments`
Creates a payment allocation. Overpayments are rejected.

## Domain models

### BillingPreview
- billingPeriod
- dueDate
- items: List<InvoiceItem>
- rent: RentCalculation
- utilities: UtilityCalculationSet
- subtotal
- adjustments
- total
- warnings
- errors

### BillingResult
- invoiceId
- invoiceNumber
- billingPeriod
- items
- subtotal
- adjustments
- total
- amountPaid
- amountDue
- status

### UtilityCalculation
- utility: electricity | water
- configured
- scope: unit | property
- billingMethod: fixed | per_unit | per_unit_fixed | slab | included_in_rent
- configId
- rateId
- ratePerUnit
- fixedCharge
- meterId
- meterNumber
- previousReading
- currentReading
- previousReadingDate
- currentReadingDate
- consumption
- amount
- includedInRent
- warnings
- errors

### InvoiceGenerationRequest
- leaseId
- billingPeriodStart
- billingPeriodEnd

### PaymentAllocation
- invoiceId
- amount
- paymentDate
- paymentMethod
- transactionReference
- notes

### InvoiceBalance
- total
- amountPaid
- amountDue
- status

## Repository interfaces

`BillingRepository.preview(request)`
`BillingRepository.generateInvoice(request)`
`BillingRepository.recalculateInvoice(invoiceId)`
`InvoiceRepository.get(invoiceId)`
`InvoiceRepository.list()`
`PaymentRepository.create(allocation)`
`PaymentRepository.listForInvoice(invoiceId)`
`PaymentRepository.getBalance(invoiceId)`

## Financial policy

Money is stored in PostgreSQL `NUMERIC`; the Hatchable engine uses scaled integer arithmetic for final JavaScript money operations. Currency precision is 2 decimal places, consumption precision is 3, utility rates support 4 decimal places. Rounding is half-up to currency cents. No frontend calculation is authoritative.

Lease proration defaults to `full_month`. `prorated_actual_days` is available on the lease and uses actual occupied calendar days divided by the number of calendar days in the billing month.