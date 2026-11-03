CREATE OR REPLACE FUNCTION get_active_order_for_ai(
  p_phone TEXT,
  p_store_id UUID
) 
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Sanitize phone (remove country code 55 and non-digits)
  p_phone := REGEXP_REPLACE(p_phone, '^55', '');
  p_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');

  -- Find most recent order that is NOT completed/cancelled/delivered
  -- We include 'Entregue' in the exclusion list because 'Entregue' usually means the transaction is done, 
  -- but if you want to allow feedback for 'Entregue', you might adjust this. 
  -- For now, we assume 'Entregue' is finished flow.
  SELECT * INTO v_order
  FROM orders
  WHERE store_id = p_store_id
    AND phone = p_phone
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
      'items', v_order.items,
      'timestamp', v_order.timestamp
    );
  ELSE
    RETURN jsonb_build_object('hasActiveOrder', false);
  END IF;
END;
$$;
