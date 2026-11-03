DROP FUNCTION IF EXISTS get_customer_for_ai(TEXT, UUID);

CREATE OR REPLACE FUNCTION get_customer_for_ai(
    p_phone TEXT,
    p_store_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
    v_customer RECORD;
    v_clean_phone TEXT;
BEGIN
    -- Limpar telefone de entrada (remover 55 e caracteres não numéricos)
    v_clean_phone := REGEXP_REPLACE(p_phone, '\D', '', 'g');
    v_clean_phone := REGEXP_REPLACE(v_clean_phone, '^55', '');

    -- Busca robusta considerando o 9º dígito opcional
    SELECT name, address, reference_point
    INTO v_customer
    FROM customers
    WHERE store_id = p_store_id
      AND (
        -- Caso 1: Correspondência exata (limpa)
        REGEXP_REPLACE(REGEXP_REPLACE(phone, '\D', '', 'g'), '^55', '') = v_clean_phone
        OR 
        -- Caso 2: O banco tem o 9 mas a entrada não tem
        REGEXP_REPLACE(REGEXP_REPLACE(phone, '\D', '', 'g'), '^55', '') = (SUBSTRING(v_clean_phone FROM 1 FOR 2) || '9' || SUBSTRING(v_clean_phone FROM 3))
        OR 
        -- Caso 3: A entrada tem o 9 mas o banco não tem
        (SUBSTRING(REGEXP_REPLACE(REGEXP_REPLACE(phone, '\D', '', 'g'), '^55', '') FROM 1 FOR 2) || '9' || SUBSTRING(REGEXP_REPLACE(REGEXP_REPLACE(phone, '\D', '', 'g'), '^55', '') FROM 3)) = v_clean_phone
      )
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'name', v_customer.name,
            'address', v_customer.address,
            'ponto_referencia', v_customer.reference_point,
            'status', 'cadastrado'
        );
    ELSE
        RETURN jsonb_build_object(
            'status', 'novo'
        );
    END IF;
END;
$func$;
