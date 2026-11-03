-- RUN THIS IN SUPABASE SQL EDITOR TO FIX BOT ORDER VISIBILITY, EDITING, AND NUMBER PRESERVATION

-- 1. FIX VISIBILITY & EDITING (Adding 'items' and SECURITY DEFINER)
CREATE OR REPLACE FUNCTION get_active_order_for_ai(
  p_phone TEXT,
  p_store_id UUID
) 
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Ensures the bot can see orders regardless of RLS
AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Sanitize phone (remove country code 55 and non-digits)
  p_phone := REGEXP_REPLACE(p_phone, '^55', '');
  p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

  -- Find most recent order that is NOT completed/cancelled/delivered
  SELECT * INTO v_order
  FROM orders
  WHERE store_id = p_store_id
    AND (REGEXP_REPLACE(phone, '^55', '') = p_phone OR phone = p_phone)
    AND status NOT IN ('Concluído', 'Cancelado', 'Entregue')
  ORDER BY timestamp DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'hasActiveOrder', true,
      'orderId', v_order.id,
      'displayId', v_order.daily_order_number,
      'status', v_order.status,
      'total', v_order.total,
      'orderType', v_order.order_type,
      'itemCount', jsonb_array_length(v_order.items::jsonb),
      'items', v_order.items, -- Added items for editing capability
      'timestamp', v_order.timestamp
    );
  ELSE
    RETURN jsonb_build_object('hasActiveOrder', false);
  END IF;
END;
$$;

-- 2. FIX NUMBER PRESERVATION (Allow overriding dailyOrderNumber)
CREATE OR REPLACE FUNCTION create_order_via_n8n(
    p_store_id UUID,
    p_customer JSONB,
    p_order JSONB,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator
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
    -- 0. UNWRAP DOUBLE-ENCODED JSON & STRIP MARKDOWN
    DECLARE
        v_text_tmp TEXT;
    BEGIN
        -- Customer
        IF jsonb_typeof(p_customer) = 'string' THEN
            v_text_tmp := p_customer #>> '{}';
            v_text_tmp := REGEXP_REPLACE(v_text_tmp, '^```(json)?\s*', '', 'i');
            v_text_tmp := REGEXP_REPLACE(v_text_tmp, '\s*```$', '');
            p_customer := v_text_tmp::jsonb;
        END IF;

        -- Order
        IF jsonb_typeof(p_order) = 'string' THEN
            v_text_tmp := p_order #>> '{}';
            v_text_tmp := REGEXP_REPLACE(v_text_tmp, '^```(json)?\s*', '', 'i');
            v_text_tmp := REGEXP_REPLACE(v_text_tmp, '\s*```$', '');
            p_order := v_text_tmp::jsonb;
        END IF;

        -- Items
        IF jsonb_typeof(p_items) = 'string' THEN
            v_text_tmp := p_items #>> '{}';
            v_text_tmp := REGEXP_REPLACE(v_text_tmp, '^```(json)?\s*', '', 'i');
            v_text_tmp := REGEXP_REPLACE(v_text_tmp, '\s*```$', '');
            p_items := v_text_tmp::jsonb;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'JSON Parsing Error: ' || SQLERRM);
    END;

    -- 1. Extract and Sanitize Customer Data
    v_customer_phone := REGEXP_REPLACE(p_customer->>'phone', '\D', '', 'g');

    -- HANDLE COUNTRY CODE (55)
    IF LENGTH(v_customer_phone) >= 12 AND LEFT(v_customer_phone, 2) = '55' THEN
        v_customer_phone := SUBSTRING(v_customer_phone FROM 3);
    END IF;
    
    -- VALIDATION: Strict Brazilian Phone Format
    IF v_customer_phone !~ '^[1-9]{2}9?[0-9]{8}$' THEN
         RETURN jsonb_build_object(
            'success', false,
            'error', 'Bloqueio de Segurança: Número inválido ou fora do formato seguro (' || v_customer_phone || '). Utilize formato DDD + Número (ex: 11999999999).'
        );
    END IF;
    
    -- Upsert Customer
    INSERT INTO customers (store_id, phone, name, address, reference_point, total_orders, last_order_at)
    VALUES (
        p_store_id,
        v_customer_phone,
        p_customer->>'name',
        p_customer->>'address',
        p_customer->>'reference',
        1,
        NOW()
    )
    ON CONFLICT (store_id, phone) 
    DO UPDATE SET 
        name = EXCLUDED.name,
        address = COALESCE(NULLIF(EXCLUDED.address, ''), customers.address),
        reference_point = COALESCE(NULLIF(EXCLUDED.reference_point, ''), customers.reference_point),
        total_orders = customers.total_orders + 1,
        last_order_at = NOW()
    RETURNING id INTO v_customer_id;

    -- 2. Calculate Daily Order Number (Atomic Increment)
    -- Allow override if provided in p_order (e.g. for updates/replacements)
    IF (p_order->>'dailyOrderNumber') IS NOT NULL THEN
         v_daily_number := (p_order->>'dailyOrderNumber')::INTEGER;
    ELSE
         SELECT COALESCE(MAX(daily_order_number), 0) + 1
         INTO v_daily_number
         FROM orders
         WHERE store_id = p_store_id
           AND date(timestamp) = date(now() AT TIME ZONE 'America/Sao_Paulo');
    END IF;

    -- 3. Process Items and Calculate Total
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total := v_total + (COALESCE((v_item->>'price')::NUMERIC, 0) * COALESCE((v_item->>'quantity')::INTEGER, 1));
        
        IF v_item->>'cartId' IS NULL THEN
            v_item := jsonb_set(v_item, '{cartId}', to_jsonb(gen_random_uuid()));
        END IF;
        
        IF v_item->>'selectedAddons' IS NULL THEN
            v_item := jsonb_set(v_item, '{selectedAddons}', '[]'::JSONB);
        END IF;

         v_processed_items := v_processed_items || v_item;
    END LOOP;

    -- 4. Finalize Total and Delivery Fee
    v_delivery_fee := COALESCE((p_order->>'deliveryFee')::NUMERIC, 2.00); 
    
    IF (p_order->>'total') IS NOT NULL THEN
        v_total := (p_order->>'total')::NUMERIC;
    ELSE
         v_total := v_total + v_delivery_fee;
    END IF;

    -- 5. Insert Order
    INSERT INTO orders (
        store_id,
        daily_order_number,
        customer_name,
        phone,
        address,
        reference_point,
        order_type,
        payment_method,
        status,
        change_for,
        items,
        total,
        delivery_fee,
        timestamp
    )
    VALUES (
        p_store_id,
        v_daily_number,
        p_customer->>'name',
        v_customer_phone,
        p_customer->>'address',
        p_customer->>'reference',
        COALESCE(p_order->>'type', 'Entrega'),
        COALESCE(p_order->>'paymentMethod', 'Dinheiro'),
        'Novo',
        (NULLIF(p_order->>'changeFor', ''))::NUMERIC,
        v_processed_items,
        v_total,
        v_delivery_fee,
        NOW()
    )
    RETURNING id INTO v_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'orderId', v_order_id,
        'dailyOrderNumber', v_daily_number
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;
