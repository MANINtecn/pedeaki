-- ==========================================================
-- CONSOLIDATED FIX: EXTREME PHONE NORMALIZATION (v4)
-- Created: 2026-01-24
-- Description: Handles 55, automatic DDD 32 for short numbers, 
-- and 9th digit flexibility.
-- ==========================================================

-- 1. get_active_order_for_ai
DROP FUNCTION IF EXISTS get_active_order_for_ai(text,uuid);
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
  v_phone_alt TEXT;
BEGIN
  -- 1. Normalização Inicial
  p_phone := REGEXP_REPLACE(p_phone, '^55', '');
  p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

  -- 2. Garantir DDD (se o cliente digitar apenas 8 ou 9 dígitos no app/chat)
  IF LENGTH(p_phone) IN (8, 9) THEN
    p_phone := '32' || p_phone;
  END IF;

  -- 3. Lógica do Nono Dígito para busca flexível
  IF LENGTH(p_phone) = 11 AND SUBSTRING(p_phone FROM 3 FOR 1) = '9' THEN
    v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || SUBSTRING(p_phone FROM 4);
  ELSIF LENGTH(p_phone) = 10 THEN
    v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || '9' || SUBSTRING(p_phone FROM 3);
  ELSE
    v_phone_alt := p_phone;
  END IF;

  -- 4. Check Ignore Status
  SELECT ignore_until INTO v_ignore_until 
  FROM customers 
  WHERE store_id = p_store_id AND phone IN (p_phone, v_phone_alt)
  ORDER BY ignore_until DESC
  LIMIT 1;

  IF v_ignore_until IS NOT NULL AND v_ignore_until > NOW() THEN
    RETURN jsonb_build_object(
      'isIgnored', true,
      'ignoreUntil', v_ignore_until,
      'hasActiveOrder', false 
    );
  END IF;

  -- 5. Busca Pedido Ativo
  SELECT * INTO v_order
  FROM orders
  WHERE store_id = p_store_id
    AND phone IN (p_phone, v_phone_alt)
    AND status NOT IN ('Concluído', 'Cancelado', 'Entregue')
  ORDER BY timestamp DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'isIgnored', false,
      'hasActiveOrder', true,
      'orderId', v_order.id,
      'displayId', v_order.daily_order_number,
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


-- 2. cancel_active_orders_via_n8n
DROP FUNCTION IF EXISTS cancel_active_orders_via_n8n(text,uuid);
CREATE OR REPLACE FUNCTION cancel_active_orders_via_n8n(
  p_phone TEXT,
  p_store_id UUID
) 
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
  v_phone_alt TEXT;
BEGIN
  p_phone := REGEXP_REPLACE(p_phone, '^55', '');
  p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

  IF LENGTH(p_phone) IN (8, 9) THEN p_phone := '32' || p_phone; END IF;

  IF LENGTH(p_phone) = 11 AND SUBSTRING(p_phone FROM 3 FOR 1) = '9' THEN
    v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || SUBSTRING(p_phone FROM 4);
  ELSIF LENGTH(p_phone) = 10 THEN
    v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || '9' || SUBSTRING(p_phone FROM 3);
  ELSE
    v_phone_alt := p_phone;
  END IF;

  UPDATE orders
  SET status = 'Cancelado'
  WHERE store_id = p_store_id
    AND phone IN (p_phone, v_phone_alt)
    AND status NOT IN ('Concluído', 'Cancelado', 'Entregue');

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('success', true, 'cancelledCount', v_count);
END;
$$;


-- 3. set_customer_ignore
DROP FUNCTION IF EXISTS set_customer_ignore(text,uuid,int);
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
    v_phone_alt TEXT;
BEGIN
    p_phone := REGEXP_REPLACE(p_phone, '^55', '');
    p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

    IF LENGTH(p_phone) IN (8, 9) THEN p_phone := '32' || p_phone; END IF;

    IF LENGTH(p_phone) = 11 AND SUBSTRING(p_phone FROM 3 FOR 1) = '9' THEN
      v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || SUBSTRING(p_phone FROM 4);
    ELSIF LENGTH(p_phone) = 10 THEN
      v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || '9' || SUBSTRING(p_phone FROM 3);
    ELSE
      v_phone_alt := p_phone;
    END IF;
    
    SELECT id INTO v_customer_id FROM customers 
    WHERE store_id = p_store_id AND phone IN (p_phone, v_phone_alt) 
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        INSERT INTO customers (store_id, phone, name, total_orders)
        VALUES (p_store_id, p_phone, 'Cliente WhatsApp', 0)
        RETURNING id INTO v_customer_id;
    END IF;

    UPDATE customers SET ignore_until = NOW() + (p_minutes || ' minutes')::INTERVAL WHERE id = v_customer_id;
END;
$$;


-- 4. get_customer_for_ai
DROP FUNCTION IF EXISTS get_customer_for_ai(text,uuid);
CREATE OR REPLACE FUNCTION get_customer_for_ai(
    p_phone TEXT,
    p_store_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_customer RECORD;
    v_result TEXT;
    v_phone_alt TEXT;
BEGIN
    p_phone := REGEXP_REPLACE(p_phone, '^55', '');
    p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

    IF LENGTH(p_phone) IN (8, 9) THEN p_phone := '32' || p_phone; END IF;

    IF LENGTH(p_phone) = 11 AND SUBSTRING(p_phone FROM 3 FOR 1) = '9' THEN
      v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || SUBSTRING(p_phone FROM 4);
    ELSIF LENGTH(p_phone) = 10 THEN
      v_phone_alt := SUBSTRING(p_phone FROM 1 FOR 2) || '9' || SUBSTRING(p_phone FROM 3);
    ELSE
      v_phone_alt := p_phone;
    END IF;

    SELECT name, address, reference_point
    INTO v_customer
    FROM customers
    WHERE store_id = p_store_id
      AND phone IN (p_phone, v_phone_alt)
    LIMIT 1;

    IF FOUND THEN
        v_result := 'Cliente já cadastrado.' || E'\n' ||
                    'Nome: ' || COALESCE(v_customer.name, 'Não informado') || E'\n' ||
                    'Endereço Cadastrado: ' || COALESCE(v_customer.address, 'Não informado') || E'\n' ||
                    'Ponto de Referência: ' || COALESCE(v_customer.reference_point, 'Não informado') || E'\n' ||
                    'Instrução: Confirme se o cliente quer entregar neste endereço. Se sim, não precisa pedir de novo.';
    ELSE
        v_result := 'Cliente Novo. Necessário solicitar Nome e Endereço Completo.';
    END IF;

    RETURN v_result;
END;
$$;


-- 5. create_order_via_n8n
DROP FUNCTION IF EXISTS create_order_via_n8n(uuid,jsonb,jsonb,jsonb);
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
    v_phone_alt TEXT;
BEGIN
    IF jsonb_typeof(p_customer) = 'string' THEN p_customer := (p_customer #>> '{}')::jsonb; END IF;
    IF jsonb_typeof(p_order) = 'string' THEN p_order := (p_order #>> '{}')::jsonb; END IF;
    IF jsonb_typeof(p_items) = 'string' THEN p_items := (p_items #>> '{}')::jsonb; END IF;

    v_customer_phone := REGEXP_REPLACE(p_customer->>'phone', '^55', '');
    v_customer_phone := REGEXP_REPLACE(v_customer_phone, '\D', '', 'g');
    
    IF LENGTH(v_customer_phone) IN (8, 9) THEN v_customer_phone := '32' || v_customer_phone; END IF;

    IF LENGTH(v_customer_phone) = 11 AND SUBSTRING(v_customer_phone FROM 3 FOR 1) = '9' THEN
      v_phone_alt := SUBSTRING(v_customer_phone FROM 1 FOR 2) || SUBSTRING(v_customer_phone FROM 4);
    ELSIF LENGTH(v_customer_phone) = 10 THEN
      v_phone_alt := SUBSTRING(v_customer_phone FROM 1 FOR 2) || '9' || SUBSTRING(v_customer_phone FROM 3);
    END IF;

    IF v_customer_phone !~ '^[1-9]{2}9?[0-9]{8}$' THEN
         RETURN jsonb_build_object('success', false, 'error', 'Número inválido (' || v_customer_phone || '). Use DDD + Número.');
    END IF;
    
    SELECT id INTO v_customer_id FROM customers WHERE store_id = p_store_id AND phone IN (v_customer_phone, v_phone_alt) LIMIT 1;

    IF v_customer_id IS NULL THEN
        INSERT INTO customers (store_id, phone, name, address, reference_point)
        VALUES (p_store_id, v_customer_phone, p_customer->>'name', p_customer->>'address', p_customer->>'reference')
        RETURNING id INTO v_customer_id;
    END IF;

    SELECT COALESCE(MAX(daily_order_number), 0) + 1 INTO v_daily_number
    FROM orders WHERE store_id = p_store_id AND date(timestamp) = date(now() AT TIME ZONE 'America/Sao_Paulo');

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_total := v_total + (COALESCE((v_item->>'price')::NUMERIC, 0) * COALESCE((v_item->>'quantity')::INTEGER, 1));
        v_processed_items := v_processed_items || v_item;
    END LOOP;

    v_delivery_fee := COALESCE((p_order->>'deliveryFee')::NUMERIC, 2.00);
    v_total := COALESCE((p_order->>'total')::NUMERIC, v_total + v_delivery_fee);

    INSERT INTO orders (store_id, daily_order_number, customer_name, phone, address, reference_point, order_type, payment_method, status, change_for, items, total, delivery_fee)
    VALUES (p_store_id, v_daily_number, p_customer->>'name', v_customer_phone, p_customer->>'address', p_customer->>'reference', COALESCE(p_order->>'type', 'Entrega'), COALESCE(p_order->>'paymentMethod', 'Dinheiro'), 'Novo', (NULLIF(p_order->>'changeFor', ''))::NUMERIC, v_processed_items, v_total, v_delivery_fee)
    RETURNING id INTO v_order_id;

    RETURN jsonb_build_object('success', true, 'orderId', v_order_id, 'dailyOrderNumber', v_daily_number);
END;
$$;
