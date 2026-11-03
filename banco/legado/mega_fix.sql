-- MEGA FIX FOR PAPALEGUAS DATABASE SCHEMA
-- This script fixes ALL triggers and functions that reference old camelCase names.

DO $$ 
BEGIN
    -- 1. Ensure columns are snake_case in 'orders' table
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


-- 2. Fix 'set_daily_order_number' function
CREATE OR REPLACE FUNCTION set_daily_order_number()
RETURNS TRIGGER AS $$
DECLARE
  next_num INTEGER;
BEGIN
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


-- 3. Fix 'update_customer_on_order' function (CRITICAL FIX)
CREATE OR REPLACE FUNCTION update_customer_on_order()
RETURNS TRIGGER AS $$
BEGIN
  -- SKIP if no phone is provided (Counter/Generic orders)
  IF NEW.phone IS NULL OR NEW.phone = '' THEN
    RETURN NEW;
  END IF;

  -- We use NEW.customer_name and NEW.reference_point (snake_case)
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


-- 4. Fix 'create_order_via_n8n' function (SaaS/Bot functionality)
CREATE OR REPLACE FUNCTION create_order_via_n8n(
    p_store_id UUID,
    p_customer JSONB,
    p_order JSONB,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_customer_id UUID;
    v_order_id UUID;
    v_daily_number INTEGER;
    v_item JSONB;
    v_processed_items JSONB := '[]'::JSONB;
    v_total NUMERIC := 0;
    v_delivery_fee NUMERIC;
    v_customer_phone TEXT;
BEGIN
    IF jsonb_typeof(p_customer) = 'string' THEN p_customer := (p_customer #>> '{}')::jsonb; END IF;
    IF jsonb_typeof(p_order) = 'string' THEN p_order := (p_order #>> '{}')::jsonb; END IF;
    IF jsonb_typeof(p_items) = 'string' THEN p_items := (p_items #>> '{}')::jsonb; END IF;

    v_customer_phone := REGEXP_REPLACE(p_customer->>'phone', '\D', '', 'g');
    
    IF v_customer_phone !~ '^[1-9]{2}9?[0-9]{8}$' THEN
         RETURN jsonb_build_object('success', false, 'error', 'Número inválido: ' || v_customer_phone);
    END IF;
    
    IF v_customer_phone IS NOT NULL AND v_customer_phone <> '' THEN
        INSERT INTO customers (store_id, phone, name, address, reference_point, total_orders, last_order_at)
        VALUES (p_store_id, v_customer_phone, p_customer->>'name', p_customer->>'address', p_customer->>'reference', 1, NOW())
        ON CONFLICT (store_id, phone) 
        DO UPDATE SET 
            name = EXCLUDED.name,
            address = COALESCE(NULLIF(EXCLUDED.address, ''), customers.address),
            reference_point = COALESCE(NULLIF(EXCLUDED.reference_point, ''), customers.reference_point),
            total_orders = customers.total_orders + 1,
            last_order_at = NOW()
        RETURNING id INTO v_customer_id;
    END IF;

    SELECT COALESCE(MAX(daily_order_number), 0) + 1
    INTO v_daily_number
    FROM orders
    WHERE store_id = p_store_id
      AND date(timestamp) = date(now() AT TIME ZONE 'America/Sao_Paulo');

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total := v_total + (COALESCE((v_item->>'price')::NUMERIC, 0) * COALESCE((v_item->>'quantity')::INTEGER, 1));
        IF v_item->>'cartId' IS NULL THEN v_item := jsonb_set(v_item, '{cartId}', to_jsonb(gen_random_uuid())); END IF;
        IF v_item->>'selectedAddons' IS NULL THEN v_item := jsonb_set(v_item, '{selectedAddons}', '[]'::JSONB); END IF;
        v_processed_items := v_processed_items || v_item;
    END LOOP;

    v_delivery_fee := COALESCE((p_order->>'deliveryFee')::NUMERIC, 2.00);
    IF (p_order->>'total') IS NOT NULL THEN v_total := (p_order->>'total')::NUMERIC;
    ELSE v_total := v_total + v_delivery_fee; END IF;

    INSERT INTO orders (
        store_id, daily_order_number, customer_name, phone, address, reference_point, order_type, payment_method, status, change_for, items, total, delivery_fee, timestamp
    )
    VALUES (
        p_store_id, v_daily_number, p_customer->>'name', v_customer_phone, p_customer->>'address', p_customer->>'reference',
        COALESCE(p_order->>'type', 'Entrega'), COALESCE(p_order->>'paymentMethod', 'Dinheiro'), 'Novo',
        (NULLIF(p_order->>'changeFor', ''))::NUMERIC, v_processed_items, v_total, v_delivery_fee, NOW()
    )
    RETURNING id INTO v_order_id;

    RETURN jsonb_build_object('success', true, 'orderId', v_order_id, 'dailyOrderNumber', v_daily_number);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 5. Final Reset of Triggers (ensure they are attached to correct functions)
DROP TRIGGER IF EXISTS trigger_set_daily_order_number ON orders;
CREATE TRIGGER trigger_set_daily_order_number
BEFORE INSERT ON orders FOR EACH ROW EXECUTE FUNCTION set_daily_order_number();

DROP TRIGGER IF EXISTS trigger_update_customer ON orders;
CREATE TRIGGER trigger_update_customer
AFTER INSERT ON orders FOR EACH ROW EXECUTE FUNCTION update_customer_on_order();

-- 6. Inform PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
