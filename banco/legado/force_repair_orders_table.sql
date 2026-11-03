-- DEFINITIVE REPAIR FOR ORDERS TABLE SCHEMA
-- This script handles both quoted ("customerName") and unquoted (customername) versions
-- and forces a PostgREST cache reload.

DO $$ 
DECLARE 
    r RECORD;
BEGIN
    -- 1. Create a function to safely rename columns if they exist
    FOR r IN (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name IN ('customerName', 'customername', 'dailyOrderNumber', 'dailyordernumber', 
                          'orderType', 'ordertype', 'paymentMethod', 'paymentmethod', 
                          'referencePoint', 'referencepoint', 'changeFor', 'changefor', 
                          'deliveryFee', 'deliveryfee', 'comboPrice', 'comboprice')
    ) LOOP
        -- Map the old name to the new snake_case name
        CASE 
            WHEN lower(r.column_name) = 'customername' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_name') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO customer_name', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET customer_name = COALESCE(customer_name, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            WHEN lower(r.column_name) = 'dailyordernumber' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'daily_order_number') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO daily_order_number', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET daily_order_number = COALESCE(daily_order_number, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            WHEN lower(r.column_name) = 'ordertype' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'order_type') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO order_type', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET order_type = COALESCE(order_type, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            WHEN lower(r.column_name) = 'paymentmethod' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_method') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO payment_method', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET payment_method = COALESCE(payment_method, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            WHEN lower(r.column_name) = 'referencepoint' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'reference_point') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO reference_point', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET reference_point = COALESCE(reference_point, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            WHEN lower(r.column_name) = 'changefor' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'change_for') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO change_for', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET change_for = COALESCE(change_for, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            WHEN lower(r.column_name) = 'deliveryfee' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivery_fee') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO delivery_fee', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET delivery_fee = COALESCE(delivery_fee, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            WHEN lower(r.column_name) = 'comboprice' THEN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'combo_price') THEN
                    EXECUTE format('ALTER TABLE orders RENAME COLUMN %I TO combo_price', r.column_name);
                ELSE
                    EXECUTE format('UPDATE orders SET combo_price = COALESCE(combo_price, %I)', r.column_name);
                    EXECUTE format('ALTER TABLE orders DROP COLUMN %I', r.column_name);
                END IF;
            ELSE
                -- Skip others
        END CASE;
    END LOOP;
END $$;

-- 2. FORCE RELOAD SCHEMA CACHE
NOTIFY pgrst, 'reload schema';

-- 3. VERIFY COLUMNS (Check your Supabase console output for this result)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'orders' 
ORDER BY column_name;
