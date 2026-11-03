-- Global Security Trigger: Phone Number Validation
-- Protects BOTH App and Agent by intercepting inserts at the database level.

CREATE OR REPLACE FUNCTION validate_phone_trigger()
RETURNS TRIGGER AS $$
DECLARE
    phone_to_check TEXT;
BEGIN
    -- Determine which column to check based on table
    IF TG_TABLE_NAME = 'orders' THEN
        phone_to_check := NEW.phone;
    ELSIF TG_TABLE_NAME = 'customers' THEN
        phone_to_check := NEW.phone;
    END IF;

    -- Clean non-digits just in case (optional, but good for comparison)
    -- Actually, we expect clean numbers. If we are strict, we check the raw value.
    -- Let's check the RAW value to ensure data quality.

    -- Allow NULL for orders if the system allows (e.g. counter orders might not have phone?)
    -- If phone is NULL and table is orders, maybe allow? 
    -- But 'create_order' usually requires phone for tracking.
    -- Let's be strict: If phone is provided, it MUST be valid.
    
    IF phone_to_check IS NOT NULL THEN
         -- Regex: ^[1-9]{2} (DDD 11-99) + 9? (Optional 9th digit) + [0-9]{8} (8 digits)
        IF phone_to_check !~ '^[1-9]{2}9?[0-9]{8}$' THEN
            RAISE EXCEPTION 'Security Block: Phone number % is invalid. Must be DDD + Number (e.g. 32999999999).', phone_to_check;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to ORDERS table
DROP TRIGGER IF EXISTS trg_validate_phone_orders ON orders;
CREATE TRIGGER trg_validate_phone_orders
    BEFORE INSERT OR UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION validate_phone_trigger();

-- Apply to CUSTOMERS table
DROP TRIGGER IF EXISTS trg_validate_phone_customers ON customers;
CREATE TRIGGER trg_validate_phone_customers
    BEFORE INSERT OR UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION validate_phone_trigger();
