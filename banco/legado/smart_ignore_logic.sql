-- 1. Add ignore_until column to customers
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ignore_until TIMESTAMPTZ;

-- 2. Create RPC to set ignore timer
CREATE OR REPLACE FUNCTION set_customer_ignore(
  p_phone TEXT,
  p_store_id UUID,
  p_minutes INT
) 
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id UUID;
BEGIN
    p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

    -- HANDLE COUNTRY CODE (55)
    IF LENGTH(p_phone) >= 12 AND LEFT(p_phone, 2) = '55' THEN
        p_phone := SUBSTRING(p_phone FROM 3);
    END IF;

    -- VALIDATION
    IF p_phone !~ '^[1-9]{2}9?[0-9]{8}$' THEN
         RAISE EXCEPTION 'Security Block: Phone number "%" is Invalid. Must be DDD + Number (e.g. 32999999999).', p_phone;
    END IF;
    
    -- Ensure customer exists (upsert)
    INSERT INTO customers (store_id, phone, name, total_orders)
    VALUES (p_store_id, p_phone, 'Cliente WhatsApp', 0)
    ON CONFLICT (store_id, phone) DO UPDATE SET phone = EXCLUDED.phone
    RETURNING id INTO v_customer_id;

    -- Update ignore timer
    UPDATE customers 
    SET ignore_until = NOW() + (p_minutes || ' minutes')::INTERVAL
    WHERE id = v_customer_id;
END;
$$;

-- 3. Update get_active_order_for_ai to include ignore status
CREATE OR REPLACE FUNCTION get_active_order_for_ai(
  p_phone TEXT,
  p_store_id UUID
) 
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_order RECORD;
  v_ignore_until TIMESTAMPTZ;
BEGIN
  -- Sanitize phone
  p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

  -- HANDLE COUNTRY CODE (55)
  IF LENGTH(p_phone) >= 12 AND LEFT(p_phone, 2) = '55' THEN
      p_phone := SUBSTRING(p_phone FROM 3);
  END IF;

  -- Check Ignore Status First
  SELECT ignore_until INTO v_ignore_until 
  FROM customers 
  WHERE store_id = p_store_id AND phone = p_phone
  LIMIT 1;

  -- If ignored and time hasn't passed, return ignored status
  IF v_ignore_until IS NOT NULL AND v_ignore_until > NOW() THEN
    RETURN jsonb_build_object(
      'isIgnored', true,
      'ignoreUntil', v_ignore_until,
      'hasActiveOrder', false 
    );
  END IF;

  -- Find active order
  SELECT * INTO v_order
  FROM orders
  WHERE store_id = p_store_id
    AND phone = p_phone
    AND status NOT IN ('Concluído', 'Cancelado', 'Entregue')
  ORDER BY timestamp DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'isIgnored', false,
      'hasActiveOrder', true,
      'orderId', v_order.id,
      'status', v_order.status,
      'total', v_order.total,
      'orderType', v_order.order_type,
      'itemCount', jsonb_array_length(v_order.items::jsonb),
      'timestamp', v_order.timestamp
    );
  ELSE
    RETURN jsonb_build_object('isIgnored', false, 'hasActiveOrder', false);
  END IF;
END;
$$;
