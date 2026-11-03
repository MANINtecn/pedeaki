CREATE OR REPLACE FUNCTION update_customer_registration(
  p_phone TEXT,
  p_store_id UUID,
  p_name TEXT DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_reference TEXT DEFAULT NULL
) 
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

    INSERT INTO customers (store_id, phone, name, address, reference_point, total_orders)
    VALUES (
        p_store_id, 
        p_phone, 
        p_name, 
        p_address, 
        p_reference, 
        0
    )
  ON CONFLICT (store_id, phone) DO UPDATE SET 
    name = COALESCE(NULLIF(p_name, ''), customers.name),
    address = COALESCE(NULLIF(p_address, ''), customers.address),
    reference_point = COALESCE(NULLIF(p_reference, ''), customers.reference_point);

  RETURN jsonb_build_object('success', true);
END;
$$;
