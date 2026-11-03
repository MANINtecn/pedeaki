-- DEFINITIVE FIX FOR PAPALEGUAS DATABASE SCHEMA
-- This script fixes the trigger that calculates daily order numbers and ensures all columns are snake_case.

DO $$ 
BEGIN
    -- 1. Rename columns if they exist in camelCase
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'dailyOrderNumber') THEN
        ALTER TABLE orders RENAME COLUMN "dailyOrderNumber" TO daily_order_number;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customerName') THEN
        ALTER TABLE orders RENAME COLUMN "customerName" TO customer_name;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'orderType') THEN
        ALTER TABLE orders RENAME COLUMN "orderType" TO order_type;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'paymentMethod') THEN
        ALTER TABLE orders RENAME COLUMN "paymentMethod" TO payment_method;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'referencePoint') THEN
        ALTER TABLE orders RENAME COLUMN "referencePoint" TO reference_point;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'changeFor') THEN
        ALTER TABLE orders RENAME COLUMN "changeFor" TO change_for;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'deliveryFee') THEN
        ALTER TABLE orders RENAME COLUMN "deliveryFee" TO delivery_fee;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'comboPrice') THEN
        ALTER TABLE orders RENAME COLUMN "comboPrice" TO combo_price;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'comandaNumber') THEN
        ALTER TABLE orders RENAME COLUMN "comandaNumber" TO comanda_number;
    END IF;
END $$;

-- 2. Create or Replace the Daily Order Number Function with correct column names
CREATE OR REPLACE FUNCTION set_daily_order_number()
RETURNS TRIGGER AS $$
DECLARE
  next_num INTEGER;
BEGIN
  -- We ONLY calculate if it's not provided (null or 0)
  IF NEW.daily_order_number IS NULL OR NEW.daily_order_number = 0 THEN
      SELECT COALESCE(MAX(daily_order_number), 0) + 1
      INTO next_num
      FROM orders
      WHERE store_id = NEW.store_id
        AND date(timestamp) = date(NEW.timestamp);
      
      NEW.daily_order_number := next_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Re-create the trigger
DROP TRIGGER IF EXISTS trigger_set_daily_order_number ON orders;
CREATE TRIGGER trigger_set_daily_order_number
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION set_daily_order_number();

-- 4. Reload PostgREST Schema Cache
NOTIFY pgrst, 'reload schema';
