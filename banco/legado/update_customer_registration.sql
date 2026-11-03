CREATE OR REPLACE FUNCTION update_customer_registration_via_n8n(
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
DECLARE
    v_phone_sanitized TEXT;
BEGIN
    -- Sanitize phone
    v_phone_sanitized := REGEXP_REPLACE(p_phone, '^55', '');
    v_phone_sanitized := REGEXP_REPLACE(v_phone_sanitized, '\D', '', 'g');

    -- Upsert/Update customer info
    INSERT INTO customers (store_id, phone, name, address, reference_point, total_orders, last_order_at)
    VALUES (
        p_store_id,
        v_phone_sanitized,
        p_name,
        p_address,
        p_reference,
        0, -- Default for new customers
        NOW()
    )
    ON CONFLICT (store_id, phone) 
    DO UPDATE SET 
        name = COALESCE(NULLIF(p_name, ''), customers.name),
        address = COALESCE(NULLIF(p_address, ''), customers.address),
        reference_point = COALESCE(NULLIF(p_reference, ''), customers.reference_point),
        last_order_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Dados do cliente atualizados com sucesso.'
    );
END;
$$;
