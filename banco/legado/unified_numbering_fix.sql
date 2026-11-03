-- CONSOLIDATED FIX FOR ORDER NUMBERING AND TIMEZONE
-- This script ensures consistent numbering and resets correctly at midnight America/Sao_Paulo.

DO $$ 
BEGIN
    -- 1. Ensure columns are snake_case (Safety check)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'dailyOrderNumber') THEN
        ALTER TABLE orders RENAME COLUMN "dailyOrderNumber" TO daily_order_number;
    END IF;
END $$;

-- 2. Create the unified sequence function
CREATE OR REPLACE FUNCTION set_daily_order_number()
RETURNS TRIGGER AS $$
DECLARE
  next_num INTEGER;
BEGIN
  -- We ONLY calculate if it's not provided (null or 0)
  IF NEW.daily_order_number IS NULL OR NEW.daily_order_number = 0 THEN
      -- Atomic increment for the current store and current Brazilian day
      SELECT COALESCE(MAX(daily_order_number), 0) + 1
      INTO next_num
      FROM orders
      WHERE store_id = NEW.store_id
        AND date(timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo') = 
            date(NEW.timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo');
      
      NEW.daily_order_number := next_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Re-create the trigger for automatic numbering
DROP TRIGGER IF EXISTS trigger_set_daily_order_number ON orders;
CREATE TRIGGER trigger_set_daily_order_number
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION set_daily_order_number();

-- 4. Update the N8N creation function to use the same logic and column names
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
    -- Unwrap JSON if double-encoded
    IF jsonb_typeof(p_customer) = 'string' THEN p_customer := (p_customer #>> '{}')::jsonb; END IF;
    IF jsonb_typeof(p_order) = 'string' THEN p_order := (p_order #>> '{}')::jsonb; END IF;
    IF jsonb_typeof(p_items) = 'string' THEN p_items := (p_items #>> '{}')::jsonb; END IF;

    v_customer_phone := REGEXP_REPLACE(p_customer->>'phone', '\D', '', 'g');
    
    -- Upsert Customer
    INSERT INTO customers (store_id, phone, name, address, reference_point, total_orders, last_order_at)
    VALUES (p_store_id, v_customer_phone, p_customer->>'name', p_customer->>'address', p_customer->>'reference', 1, NOW())
    ON CONFLICT (store_id, phone) DO UPDATE SET 
        name = EXCLUDED.name,
        address = COALESCE(NULLIF(EXCLUDED.address, ''), customers.address),
        reference_point = COALESCE(NULLIF(EXCLUDED.reference_point, ''), customers.reference_point),
        total_orders = customers.total_orders + 1,
        last_order_at = NOW()
    RETURNING id INTO v_customer_id;

    -- Calculate Daily Number (Consistent with trigger logic)
    SELECT COALESCE(MAX(daily_order_number), 0) + 1
    INTO v_daily_number
    FROM orders
    WHERE store_id = p_store_id
      AND date(timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo') = 
          date(NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo');

    -- Process Items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total := v_total + (COALESCE((v_item->>'price')::NUMERIC, 0) * COALESCE((v_item->>'quantity')::INTEGER, 1));
        IF v_item->>'cartId' IS NULL THEN v_item := jsonb_set(v_item, '{cartId}', to_jsonb(gen_random_uuid())); END IF;
        IF v_item->>'selectedAddons' IS NULL THEN v_item := jsonb_set(v_item, '{selectedAddons}', '[]'::JSONB); END IF;
        v_processed_items := v_processed_items || v_item;
    END LOOP;

    v_delivery_fee := COALESCE((p_order->>'deliveryFee')::NUMERIC, 2.00);
    v_total := COALESCE((p_order->>'total')::NUMERIC, v_total + v_delivery_fee);

    -- Insert Order (using internal snake_case columns)
    INSERT INTO orders (
        store_id, daily_order_number, customer_name, phone, address, 
        reference_point, order_type, payment_method, status, 
        change_for, items, total, delivery_fee, timestamp, origin
    )
    VALUES (
        p_store_id, v_daily_number, p_customer->>'name', v_customer_phone, p_customer->>'address', 
        p_customer->>'reference', COALESCE(p_order->>'type', 'Entrega'), COALESCE(p_order->>'paymentMethod', 'Dinheiro'), 
        'Novo', (NULLIF(p_order->>'changeFor', ''))::NUMERIC, v_processed_items, v_total, v_delivery_fee, NOW(), 'AI'
    )
    RETURNING id INTO v_order_id;

    RETURN jsonb_build_object('success', true, 'orderId', v_order_id, 'dailyOrderNumber', v_daily_number);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

NOTIFY pgrst, 'reload schema';
