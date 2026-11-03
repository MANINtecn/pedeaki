-- EMERGENCY RECOVERY SCRIPT
-- Run this if you are getting "column does not exist" errors.
-- This script ADDS the columns if they are missing.

DO $$ 
BEGIN
    -- 1. Ensure all columns exist in 'orders' table (SNAKE_CASE)
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS daily_order_number INTEGER;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS reference_point TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS change_for NUMERIC;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC DEFAULT 0;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS combo_price NUMERIC DEFAULT 0;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS comanda_number INTEGER;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS origin TEXT DEFAULT 'APP';
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_loyalty_eligible BOOLEAN DEFAULT FALSE;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS loyalty_redeemed_at TIMESTAMPTZ;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS printed BOOLEAN DEFAULT FALSE;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS observation TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_number INTEGER;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount NUMERIC DEFAULT 0;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS tax NUMERIC DEFAULT 0;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS rating INTEGER;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS feedback TEXT;

    -- 2. Try to migrate data from camelCase columns if they exist (OPTIONAL/SAFETY)
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'comboPrice') THEN
            UPDATE orders SET combo_price = "comboPrice" WHERE combo_price IS NULL;
        END IF;
    EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Skipping comboPrice migration';
    END;

    -- Repeat for other critical ones if needed
END $$;


-- 3. Fix 'set_daily_order_number' function (SNAKE_CASE)
CREATE OR REPLACE FUNCTION set_daily_order_number()
RETURNS TRIGGER AS $$
DECLARE
  next_num INTEGER;
  is_delivery BOOLEAN;
BEGIN
  IF NEW.daily_order_number IS NULL OR NEW.daily_order_number = 0 THEN
      -- Determine sequence group
      is_delivery := (NEW.order_type = 'Entrega');

      IF is_delivery THEN
          -- Sequence A: Entrega
          SELECT COALESCE(MAX(daily_order_number), 0) + 1
          INTO next_num
          FROM orders
          WHERE store_id = NEW.store_id
            AND order_type = 'Entrega'
            AND date(timestamp) = date(NEW.timestamp);
      ELSE
          -- Sequence B: Balcão and Retirada
          SELECT COALESCE(MAX(daily_order_number), 0) + 1
          INTO next_num
          FROM orders
          WHERE store_id = NEW.store_id
            AND order_type IN ('Balcão', 'Retirada')
            AND date(timestamp) = date(NEW.timestamp);
      END IF;
      
      NEW.daily_order_number := next_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 4. Fix 'update_customer_on_order' function (SNAKE_CASE)
CREATE OR REPLACE FUNCTION update_customer_on_order()
RETURNS TRIGGER AS $$
BEGIN
  -- SKIP if no phone is provided (Counter/Generic orders)
  IF NEW.phone IS NULL OR NEW.phone = '' THEN
    RETURN NEW;
  END IF;

  INSERT INTO customers (store_id, phone, name, address, reference_point, total_orders, last_order_at)
  VALUES (
    NEW.store_id,
    NEW.phone,
    NEW.customer_name,
    NEW.address,
    NEW.reference_point,
    1,
    NEW.timestamp
  )
  ON CONFLICT (store_id, phone)
  DO UPDATE SET
    name = COALESCE(NULLIF(EXCLUDED.name, ''), customers.name),
    address = COALESCE(NULLIF(EXCLUDED.address, ''), customers.address),
    reference_point = COALESCE(NULLIF(EXCLUDED.reference_point, ''), customers.reference_point),
    total_orders = customers.total_orders + 1,
    last_order_at = EXCLUDED.last_order_at;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 5. Final Reset of Triggers
DROP TRIGGER IF EXISTS trigger_set_daily_order_number ON orders;
CREATE TRIGGER trigger_set_daily_order_number
BEFORE INSERT ON orders FOR EACH ROW EXECUTE FUNCTION set_daily_order_number();

DROP TRIGGER IF EXISTS trigger_update_customer ON orders;
CREATE TRIGGER trigger_update_customer
AFTER INSERT ON orders FOR EACH ROW EXECUTE FUNCTION update_customer_on_order();

-- 6. Inform PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
