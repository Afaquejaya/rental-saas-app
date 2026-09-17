# Rental Property Management

## Step 3 — deterministic billing engine

Step 2's domain schema is preserved. Step 3 adds a centralized server-side billing engine using Hatchable JavaScript API functions + managed PostgreSQL. Flutter, Python/FastAPI, Docker Compose, SQLAlchemy and Alembic remain documented as the external repository architecture; they are not executed inside Hatchable.

## Existing tables used

No billing table redesign was introduced. The engine uses the existing `leases`, `rent_history`, `utility_configs`, `utility_rates`, `utility_slabs`, `meters`, `meter_readings`, `invoices`, `invoice_items`, and `payments` tables. One small migration adds `leases.billing_proration_strategy` because lease-boundary billing needs an explicit full-month/prorated policy. A trigger validates utility slab overlap.

## Billing flow

1. Validate lease and billing period.
2. Resolve historical rent for the period.
3. Resolve utility configuration using unit override → property configuration → no configuration.
4. Resolve effective utility rate/slabs.
5. Select the latest valid meter reading on or before period end and the previous valid reading; future readings are never used.
6. Calculate consumption as current minus previous.
7. Calculate utility charge using fixed, per-unit, per-unit + fixed, progressive slabs, or included-in-rent rules.
8. Build invoice line items and server-side totals.
9. For generation, create invoice + all line items in one PostgreSQL transaction.
10. Payments are allocated transactionally and update the invoice balance/status.

## Financial rules

- PostgreSQL money values are `NUMERIC`.
- JavaScript does not use floating-point arithmetic for final money calculations; the shared billing service converts decimal values to scaled integers (`BigInt`) for money operations.
- Currency precision is 2 decimals.
- Meter/consumption precision is 3 decimals.
- Utility rates support 4 decimals.
- Rounding is half-up to currency cents.
- Overpayments are rejected.
- Paid invoices are immutable.
- Recalculation is allowed for draft/issued invoices only when no payments exist.
- Historical readings and rent records are never overwritten during invoice generation.
- Missing required meter readings return `METER_READING_REQUIRED`; the engine never silently charges zero.

## Invoice lifecycle

`draft → issued → partially_paid → paid`, with `overdue` derived when a balance remains after the due date. Cancelled invoices are excluded from duplicate-generation protection. Paid invoices cannot be silently recalculated; a future adjustment/credit-note model should be used for corrections.

## Payment lifecycle

Every payment is an allocation to one invoice. The server verifies that the new cumulative payment does not exceed invoice total, then atomically records the payment and updates `amount_paid`, `amount_due`, and status. Outstanding balance is always calculated server-side as total minus valid payments.

## API

- `POST /api/v1/billing/preview`
- `POST /api/v1/billing/generate-invoice`
- `POST /api/v1/billing/recalculate-invoice/:id`
- `GET /api/v1/invoices`
- `GET /api/v1/invoices/:id`
- `GET /api/v1/invoices/:id/payments`
- `GET /api/v1/invoices/:id/balance`
- `POST /api/v1/payments`

All responses use the Step 2 envelope: `{success,data,message}` or `{success:false,error:{code,message}}`.

## Demo scenario

Green Valley Apartments → A-101 → Rahul Sharma.

September 2026: rent ₹12,000; electricity 12,450 → 12,680 = 230 units at ₹8 = ₹1,840; water 100 → 115 = 15 units at ₹20 = ₹300. Expected total: ₹14,140. Migration `006_demo_billing_values.sql` updates only the existing demo water rate so this requested scenario is reproduced by the real engine.

## External Flutter contract

See `lib/flutter-domain-contracts.md` for BillingPreview, BillingResult, UtilityCalculation, InvoiceGenerationRequest, PaymentAllocation, InvoiceBalance and repository contracts.

## Step 4

Do not implement automatically. Recommended next step is authentication/owner data scoping only after the billing engine has been accepted, followed by the real Flutter screens. Do not start Step 4 automatically.