-- btree_gist is not available in Hatchable; the partial unique active-lease index below enforces the one-active-lease-per-unit rule.

CREATE TABLE IF NOT EXISTS owners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  email TEXT NOT NULL UNIQUE CHECK (position('@' IN email) > 1),
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES owners(id) ON DELETE RESTRICT,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  address_line1 TEXT NOT NULL,
  address_line2 TEXT,
  city TEXT NOT NULL,
  state TEXT,
  postal_code TEXT,
  country TEXT NOT NULL DEFAULT 'India',
  property_type TEXT NOT NULL CHECK (property_type IN ('apartment','house','building','commercial','other')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_properties_owner_id ON properties(owner_id);

CREATE TABLE IF NOT EXISTS units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
  unit_number TEXT NOT NULL CHECK (length(trim(unit_number)) > 0),
  floor INTEGER,
  unit_type TEXT,
  status TEXT NOT NULL DEFAULT 'vacant' CHECK (status IN ('vacant','occupied','maintenance','inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(property_id, unit_number)
);
CREATE INDEX IF NOT EXISTS idx_units_property_id ON units(property_id);

CREATE TABLE IF NOT EXISTS tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  phone TEXT,
  email TEXT,
  address TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  id_document_type TEXT,
  id_document_reference TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants(status);
CREATE INDEX IF NOT EXISTS idx_tenants_email ON tenants(email);

CREATE TABLE IF NOT EXISTS leases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  start_date DATE NOT NULL,
  end_date DATE,
  monthly_rent NUMERIC(14,2) NOT NULL CHECK (monthly_rent >= 0),
  security_deposit NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (security_deposit >= 0),
  rent_due_day SMALLINT NOT NULL DEFAULT 1 CHECK (rent_due_day BETWEEN 1 AND 31),
  notice_period_days INTEGER NOT NULL DEFAULT 30 CHECK (notice_period_days >= 0),
  rent_escalation_type TEXT NOT NULL DEFAULT 'none' CHECK (rent_escalation_type IN ('none','percentage','fixed_amount')),
  rent_escalation_value NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (rent_escalation_value >= 0),
  rent_escalation_interval_months INTEGER CHECK (rent_escalation_interval_months IS NULL OR rent_escalation_interval_months > 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','expired','terminated')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_date IS NULL OR end_date >= start_date),
  CHECK ((rent_escalation_type = 'none' AND rent_escalation_value = 0) OR rent_escalation_type <> 'none')
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_leases_one_active_per_unit ON leases(unit_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_leases_tenant_id ON leases(tenant_id);
CREATE INDEX IF NOT EXISTS idx_leases_unit_dates ON leases(unit_id, start_date, end_date);

CREATE TABLE IF NOT EXISTS rent_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lease_id UUID NOT NULL REFERENCES leases(id) ON DELETE RESTRICT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  monthly_rent NUMERIC(14,2) NOT NULL CHECK (monthly_rent >= 0),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
CREATE INDEX IF NOT EXISTS idx_rent_history_lease_dates ON rent_history(lease_id, effective_from, effective_to);

CREATE TABLE IF NOT EXISTS utility_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  utility_type TEXT NOT NULL CHECK (utility_type IN ('electricity','water')),
  property_id UUID REFERENCES properties(id) ON DELETE RESTRICT,
  unit_id UUID REFERENCES units(id) ON DELETE RESTRICT,
  billing_method TEXT NOT NULL CHECK (billing_method IN ('fixed','per_unit','per_unit_fixed','slab','included_in_rent')),
  fixed_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (fixed_amount >= 0),
  included_in_rent BOOLEAN NOT NULL DEFAULT false,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((property_id IS NOT NULL) <> (unit_id IS NOT NULL)),
  CHECK (effective_to IS NULL OR effective_to >= effective_from),
  CHECK (billing_method = 'included_in_rent' OR included_in_rent = false),
  CHECK (billing_method <> 'fixed' OR fixed_amount >= 0)
);
CREATE INDEX IF NOT EXISTS idx_utility_configs_property ON utility_configs(property_id, utility_type, effective_from);
CREATE INDEX IF NOT EXISTS idx_utility_configs_unit ON utility_configs(unit_id, utility_type, effective_from);

CREATE TABLE IF NOT EXISTS utility_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  utility_config_id UUID NOT NULL REFERENCES utility_configs(id) ON DELETE CASCADE,
  rate_per_unit NUMERIC(14,4) CHECK (rate_per_unit IS NULL OR rate_per_unit >= 0),
  fixed_charge NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (fixed_charge >= 0),
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (effective_to IS NULL OR effective_to >= effective_from),
  CHECK (rate_per_unit IS NOT NULL OR fixed_charge > 0)
);
CREATE INDEX IF NOT EXISTS idx_utility_rates_config_dates ON utility_rates(utility_config_id, effective_from, effective_to);

CREATE TABLE IF NOT EXISTS utility_slabs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  utility_config_id UUID NOT NULL REFERENCES utility_configs(id) ON DELETE CASCADE,
  min_units NUMERIC(14,3) NOT NULL CHECK (min_units >= 0),
  max_units NUMERIC(14,3),
  rate_per_unit NUMERIC(14,4) NOT NULL CHECK (rate_per_unit >= 0),
  fixed_charge NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (fixed_charge >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (max_units IS NULL OR max_units > min_units)
);
CREATE INDEX IF NOT EXISTS idx_utility_slabs_config_min ON utility_slabs(utility_config_id, min_units);

CREATE TABLE IF NOT EXISTS meters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  utility_type TEXT NOT NULL CHECK (utility_type IN ('electricity','water')),
  meter_number TEXT NOT NULL UNIQUE,
  installation_date DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','replaced')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(unit_id, utility_type)
);
CREATE INDEX IF NOT EXISTS idx_meters_unit_id ON meters(unit_id);

CREATE TABLE IF NOT EXISTS meter_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_id UUID NOT NULL REFERENCES meters(id) ON DELETE RESTRICT,
  reading_date DATE NOT NULL,
  reading_value NUMERIC(14,3) NOT NULL CHECK (reading_value >= 0),
  reading_source TEXT NOT NULL DEFAULT 'manual' CHECK (reading_source IN ('manual','photo','imported')),
  photo_document_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(meter_id, reading_date)
);
CREATE INDEX IF NOT EXISTS idx_meter_readings_meter_date ON meter_readings(meter_id, reading_date DESC);

CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lease_id UUID NOT NULL REFERENCES leases(id) ON DELETE RESTRICT,
  invoice_number TEXT NOT NULL UNIQUE,
  billing_period_start DATE NOT NULL,
  billing_period_end DATE NOT NULL,
  due_date DATE NOT NULL,
  subtotal NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  adjustments NUMERIC(14,2) NOT NULL DEFAULT 0,
  total NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  amount_paid NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
  amount_due NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (amount_due >= 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','partially_paid','paid','overdue','cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (billing_period_end >= billing_period_start),
  CHECK (amount_paid <= total + 0.01),
  CHECK (amount_due = GREATEST(total - amount_paid, 0))
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_invoice_lease_period ON invoices(lease_id, billing_period_start, billing_period_end) WHERE status <> 'cancelled';
CREATE INDEX IF NOT EXISTS idx_invoices_status_due_date ON invoices(status, due_date);
CREATE INDEX IF NOT EXISTS idx_invoices_lease_id ON invoices(lease_id);

CREATE TABLE IF NOT EXISTS invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN ('rent','electricity','water','maintenance','late_fee','adjustment','other')),
  description TEXT NOT NULL,
  quantity NUMERIC(14,3) NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  unit_rate NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK (unit_rate >= 0),
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items(invoice_id);

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  amount NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  payment_date DATE NOT NULL,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('cash','bank_transfer','upi','card','other')),
  transaction_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payments_invoice_id_date ON payments(invoice_id, payment_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_transaction_reference ON payments(transaction_reference) WHERE transaction_reference IS NOT NULL;

CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_owners_updated_at ON owners;
CREATE TRIGGER trg_owners_updated_at BEFORE UPDATE ON owners FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_properties_updated_at ON properties;
CREATE TRIGGER trg_properties_updated_at BEFORE UPDATE ON properties FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_units_updated_at ON units;
CREATE TRIGGER trg_units_updated_at BEFORE UPDATE ON units FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_tenants_updated_at ON tenants;
CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_leases_updated_at ON leases;
CREATE TRIGGER trg_leases_updated_at BEFORE UPDATE ON leases FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_utility_configs_updated_at ON utility_configs;
CREATE TRIGGER trg_utility_configs_updated_at BEFORE UPDATE ON utility_configs FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_meters_updated_at ON meters;
CREATE TRIGGER trg_meters_updated_at BEFORE UPDATE ON meters FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
DROP TRIGGER IF EXISTS trg_invoices_updated_at ON invoices;
CREATE TRIGGER trg_invoices_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION touch_updated_at();