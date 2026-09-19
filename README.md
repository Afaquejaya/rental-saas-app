# Rental Property Management SaaS

A full-stack rental property management SaaS designed to centralize property, unit, tenant, lease, billing, payment, maintenance, document, expense, reconciliation, reporting, notification, and AI-assisted workflows in one application.

The application is built around an authenticated owner/manager workspace with server-side APIs and a PostgreSQL-backed rental domain. It is designed to replace fragmented spreadsheets, manual calculations, disconnected payment records, messaging threads, and separate maintenance workflows with one connected operational system.

## Dashboard

![Rental Property Management Dashboard](https://rental-property.hatchable.site/)

> Live application: https://rental-property.hatchable.site

---

## What problem does this SaaS solve?

Rental operations often become difficult when information is spread across spreadsheets, PDFs, bank/payment records, messaging apps, and separate maintenance tools.

Typical problems include:

- Tracking multiple properties and units manually.
- Losing visibility into vacant, occupied, and maintenance units.
- Maintaining tenant and lease information in different places.
- Calculating monthly rent and utility charges manually.
- Following up on outstanding rent and overdue invoices.
- Recording cash, bank transfer, UPI, card, and online payments separately.
- Managing recurring property expenses.
- Tracking maintenance requests, vendors, staff, appointments, and costs.
- Keeping tenant documents and document versions organized.
- Reconciling payments and maintaining an audit trail.
- Producing financial and operational reports manually.
- Remembering recurring reminders and operational follow-ups.

Rental Property Management connects these workflows into one system so rental data can flow from property → unit → tenant → lease → billing → invoice → payment → reconciliation → reporting.

## Target audience

### Individual landlords

For landlords managing a small rental portfolio who want centralized rent, tenant, lease, document, payment, and expense tracking instead of spreadsheets and manual follow-ups.

### Property managers

For managers responsible for multiple properties, tenants, vendors, staff, maintenance requests, billing, reconciliation, and reporting.

### Small and medium property-management businesses

For teams that need a shared operational system with standardized billing, payment workflows, maintenance operations, reports, notifications, and audit history.

### Residential rental portfolios

The current domain model supports properties, units, tenants, leases, rent history, meters, utilities, invoices, payments, expenses, documents, and maintenance workflows suitable for residential rental operations.

### Property operations teams

Staff and vendors can participate in maintenance assignments, appointments, updates, attachments, and cost tracking.

---

# Core application modules

## 1. Dashboard

The dashboard provides a portfolio-level operational overview including total properties, units, occupied/vacant units, expected rent, collected amount, outstanding amount, collection rate, rent collection progress, and occupancy distribution.

## 2. Properties & Units

Properties are the top-level portfolio entities. A property can contain multiple units. Units can have their own rent amount, rent frequency, status, tenant, lease, meters, invoices, maintenance activity, and documents.

```text
Owner
  └── Property
       ├── Unit
       │    ├── Tenant
       │    ├── Lease
       │    ├── Meter
       │    ├── Invoice
       │    └── Maintenance
       └── Unit
```

Rent can be represented as per month or per day.

## 3. Tenant Management

Tenant records connect people to rental operations. The workflow includes tenant profiles, contact information, documents, leases, invoices, payments, maintenance interactions, and tenant-facing account APIs.

Tenant API surfaces include account/home, lease, invoices, payments, documents, maintenance, notifications, and profile.

## 4. Lease Management

Leases connect tenants to units for defined rental periods. The system supports lease creation, rent history, renewal, termination, and lease-bound billing.

Historical rent is important because billing should use the rent effective during the relevant billing period rather than blindly using the current rent.

## 5. Billing Engine

The billing engine is server-side and uses the existing rental domain model instead of creating a disconnected billing database.

```text
Lease + Billing Period
          ↓
Historical Rent
          ↓
Utility Configuration
          ↓
Meter Readings
          ↓
Consumption Calculation
          ↓
Utility Charge
          ↓
Invoice Line Items
          ↓
Invoice Total
          ↓
Payment Allocation
          ↓
Invoice Balance / Status
```

The engine supports historical rent, unit/property utility configuration, effective rates, meter readings, fixed charges, per-unit charges, progressive slabs, and utilities included in rent.

Financial rules include PostgreSQL NUMERIC values, decimal-safe server-side calculations using scaled integers/BigInt, 2-decimal currency precision, 3-decimal meter precision, 4-decimal utility rates, half-up currency rounding, overpayment rejection, server-side balances, and paid-invoice protection.

## 6. Invoices

Invoice lifecycle:

```text
draft → issued → partially_paid → paid
```

Overdue is derived when a balance remains after the due date. Paid invoices are protected from silent recalculation.

## 7. Payments

Manual payment flow:

```text
Owner records payment
        ↓
Validate invoice and amount
        ↓
Check financial period
        ↓
Record payment
        ↓
Update invoice balance/status
        ↓
Create reconciliation + audit/notification events
```

Supported methods include cash, bank transfer, UPI, card, and other.

Online payment flow:

```text
Tenant → Invoice → Pay Now → Create Order → Payment Provider
                                      ↓
                              Provider Verification
                                      ↓
                              Verified Payment
                                      ↓
                         Payment Allocation / Balance
```

Project configuration supports payment providers such as Razorpay and Stripe. Gateway secrets are managed through secure project secrets and are not exposed to clients.

## 8. Expenses & Recurring Expenses

The expense system tracks property-related costs, cancellation, recurring expenses, pause/resume/end operations, exports, and reporting. Recurring processing can create operational records automatically according to configured recurrence.

## 9. Maintenance & Field Service

Maintenance is modeled as an operational workflow. The backend includes requests, status transitions, updates, appointments, change requests, confirmations, assignments, staff, vendors, attachments, cost items, field-service information, and a maintenance calendar.

```text
Tenant / Owner
      ↓
Maintenance Request
      ↓
Assignment
      ↓
Vendor / Staff
      ↓
Appointment
      ↓
Updates / Attachments / Costs
      ↓
Completion
```

## 10. Documents

Documents are first-class entities with requirements, links, versions, download, archive, restore, and access logging. They can be associated with tenants, units, and other rental entities.

## 11. Reconciliation & Financial Control

Reconciliation connects recorded payments with their financial records. The system includes flagging, reconcile/unreconcile actions, summaries, exports, financial periods, and audit functionality.

## 12. Reports

Reporting APIs cover financial summaries, monthly trends, occupancy, outstanding aging, payment channels, payment methods, property summaries, rent performance, maintenance, expenses, and exports.

## 13. Notifications & Automation

Notifications include notification lists, read/read-all actions, unread counts, preferences, and reminder processing. The project has a scheduled hourly reminder processor.

## 14. AI & Automation Layer

The backend contains AI/automation surfaces for conversations/chat, insights, briefings, drafts, reconciliation suggestions, automation rules, preferences, and automated processing.

```text
Rental Data
    ↓
Business APIs
    ↓
AI / Automation Layer
    ↓
Insights / Suggestions / Drafts / Actions
    ↓
Owner Review
    ↓
Business Operation
```

The AI layer is intended as an assistance layer over the rental source of truth rather than a replacement for financial and operational records. Some AI experiences are staged separately from the core rental UI.

---

# Architecture

The application follows a layered architecture:

```text
┌──────────────────────────────────────────────┐
│                 User Interface               │
│ Dashboard · Properties · Tenants · Leases    │
│ Billing · Payments · Maintenance · Reports   │
│ Documents · Expenses · Reconciliation        │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│              API / Application Layer         │
│              /api/v1/* domain APIs           │
│ Properties · Tenants · Leases · Billing      │
│ Payments · Maintenance · Documents · Reports│
│ Reconciliation · Notifications · AI         │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│             Domain / Business Logic          │
│ Billing · Payment Allocation · Utilities     │
│ Maintenance · Notifications · Audit          │
│ Reconciliation · Reporting                   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│              PostgreSQL Data Layer           │
│ Properties · Units · Tenants · Leases        │
│ Rent · Meters · Invoices · Payments          │
│ Expenses · Maintenance · Documents           │
│ Notifications · Audit · Financial Periods    │
│ AI / Automation data                          │
└──────────────────────────────────────────────┘
```

### Frontend architecture

The web UI uses a shared application shell with client-side navigation. The shell provides the sidebar, top bar, authentication/user information, notification badge, responsive mobile menu, desktop sidebar collapse, and shared content area.

Some modules use dedicated page scripts loaded into the same shell. This lets Documents, Expenses, Recurring Expenses, Reconciliation, Audit, Financial Periods, Vendors, Staff, and Maintenance Calendar participate in the shared application experience.

### Backend architecture

Server-side API functions are organized by domain under `api/v1/`. This keeps resources separated while allowing cross-domain business workflows such as billing, payments, maintenance, reconciliation, and reporting.

### Data architecture

PostgreSQL is the operational source of truth. Rental entities are linked relationally instead of being stored as isolated feature-specific records.

### Scheduled architecture

```text
Scheduler
   ↓
/api/v1/notifications/process-reminders
   ↓
Reminder / notification processing
```

---

# End-to-end rental workflow

A typical monthly rental operation can follow:

```text
1. Create Property
        ↓
2. Add Units
        ↓
3. Add Tenant
        ↓
4. Create Lease
        ↓
5. Configure Rent / Utilities
        ↓
6. Record Meter Readings
        ↓
7. Generate Billing Preview
        ↓
8. Generate Invoice
        ↓
9. Tenant / Owner Makes Payment
        ↓
10. Allocate Payment
        ↓
11. Reconcile Payment
        ↓
12. Notifications / Reminders
        ↓
13. Dashboard & Reports
```

Maintenance operates alongside the financial workflow:

```text
Unit → Maintenance Request → Assignment → Appointment
                                  ↓
                         Vendor / Staff Work
                                  ↓
                         Updates + Costs
                                  ↓
                              Completion
```

---

# Example business scenario

**Green Valley Apartments → A-101 → Rahul Sharma**

Example September 2026 billing:

- Rent: ₹12,000
- Electricity: 230 units × ₹8 = ₹1,840
- Water: 15 units × ₹20 = ₹300
- Expected invoice total: ₹14,140

The billing engine calculates the invoice from rental and utility records, creates invoice line items, and payment allocation updates the invoice balance.

---

# Key benefits

### Centralized operations
Properties, units, tenants, leases, payments, maintenance, documents, and expenses are managed from one system.

### Reduced manual work
Automated billing calculations, recurring processing, reminders, reporting, and payment workflows reduce repetitive operational work.

### Financial visibility
Owners and managers can see expected rent, collected rent, outstanding balances, payment history, expenses, and reports in one place.

### Controlled billing
Historical rent resolution, meter-reading validation, decimal-safe money calculations, overpayment checks, and server-side invoice balances provide controlled financial processing.

### Better tenant experience
Tenant-facing APIs provide a foundation for tenants to access their account, lease, invoices, payments, documents, maintenance requests, and notifications.

### Better maintenance coordination
Maintenance can move through assignment, appointment, vendor/staff work, updates, attachments, and cost tracking instead of remaining in unstructured messages.

### Auditability
Payments, reconciliation, documents, and financial operations retain operational history rather than depending only on manually edited spreadsheets.

### Extensible architecture
Resource-oriented APIs allow additional modules and integrations to be added without redesigning the rental domain.

### AI-ready operations
Rental data can support insights, briefings, drafts, reconciliation suggestions, and workflow automation while the core business records remain in the application database.

---

# Technology / platform

- **Hatchable** — application hosting, authentication, managed backend capabilities, deployment, scheduled jobs, secrets, and AI integration
- **JavaScript** — web UI and server-side API functions
- **PostgreSQL** — relational application database
- **HTML/CSS** — web interface
- **REST-style APIs** — domain-specific `/api/v1/*` endpoints
- **Server-side billing logic** — centralized financial calculations and validation
- **Secure project secrets** — payment provider credentials
- **Scheduled jobs** — reminders and recurring operational processing

The repository also documents an external Flutter/domain-contract architecture for clients that may consume the backend APIs.

---

# Authentication & security

Authentication is enabled through the application platform. The application verifies the signed-in user before loading the owner workspace and sends authenticated API requests using same-origin credentials.

Important server-side responsibilities include authentication checks, owner-scoped operations, server-side financial validation, payment verification, webhook verification, secure payment secrets, and audit records.

Payment secrets are managed through secure project secrets rather than being stored in PostgreSQL or rendered in the UI.

---

# API overview

| Domain | API |
|---|---|
| Properties | `/api/v1/properties` |
| Units | `/api/v1/units` |
| Tenants | `/api/v1/tenants` |
| Leases | `/api/v1/leases` |
| Billing | `/api/v1/billing` |
| Invoices | `/api/v1/invoices` |
| Payments | `/api/v1/payments` |
| Expenses | `/api/v1/expenses` |
| Maintenance | `/api/v1/maintenance` |
| Documents | `/api/v1/documents` |
| Reconciliation | `/api/v1/reconciliation` |
| Reports | `/api/v1/reports` |
| Notifications | `/api/v1/notifications` |
| AI | `/api/v1/ai` |
| Tenant portal | `/api/v1/tenant` |

---

# Product philosophy

1. **Keep the rental domain as the source of truth.**
2. **Keep financial calculations server-side.**
3. **Do not silently overwrite historical financial data.**
4. **Validate payments before changing invoice balances.**
5. **Keep authentication and sensitive credentials outside the client.**
6. **Separate operational domains while connecting them through business workflows.**
7. **Use automation and AI as assistance layers over verified application data.**
8. **Prefer incremental modules over a monolithic workflow.**

---
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
