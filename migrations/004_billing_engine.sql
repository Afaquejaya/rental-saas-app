ALTER TABLE leases ADD COLUMN IF NOT EXISTS billing_proration_strategy TEXT NOT NULL DEFAULT 'full_month' CHECK (billing_proration_strategy IN ('full_month','prorated_actual_days'));

CREATE INDEX IF NOT EXISTS idx_utility_configs_scope_effective ON utility_configs(utility_type, property_id, unit_id, effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_utility_rates_effective ON utility_rates(utility_config_id, effective_from, effective_to);

CREATE OR REPLACE FUNCTION validate_utility_slabs() RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM utility_slabs s
    WHERE s.utility_config_id = NEW.utility_config_id
      AND s.id <> NEW.id
      AND NEW.min_units < COALESCE(s.max_units, 999999999999)
      AND s.min_units < COALESCE(NEW.max_units, 999999999999)
  ) THEN
    RAISE EXCEPTION 'Utility slabs overlap for configuration %', NEW.utility_config_id USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_utility_slabs ON utility_slabs;
CREATE TRIGGER trg_validate_utility_slabs BEFORE INSERT OR UPDATE ON utility_slabs FOR EACH ROW EXECUTE FUNCTION validate_utility_slabs();