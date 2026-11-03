-- Adiciona colunas de preferências de pagamento à tabela de clientes
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'preferred_payment_method') THEN
        ALTER TABLE customers ADD COLUMN preferred_payment_method TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'last_change_for') THEN
        ALTER TABLE customers ADD COLUMN last_change_for NUMERIC;
    END IF;
END $$;

-- Atualiza a função que sincroniza dados do pedido com o cadastro do cliente
CREATE OR REPLACE FUNCTION update_customer_on_order()
RETURNS TRIGGER AS $$
BEGIN
  -- Ignora se não houver telefone (balcão/pedidos genéricos)
  IF NEW.phone IS NULL OR NEW.phone = '' THEN
    RETURN NEW;
  END IF;

  INSERT INTO customers (
    store_id, 
    phone, 
    name, 
    address, 
    reference_point, 
    preferred_payment_method,
    last_change_for,
    total_orders, 
    last_order_at
  )
  VALUES (
    NEW.store_id,
    NEW.phone,
    NEW.customer_name,
    NEW.address,
    NEW.reference_point,
    NEW.payment_method,
    NEW.change_for,
    1,
    NEW.timestamp
  )
  ON CONFLICT (store_id, phone)
  DO UPDATE SET
    name = COALESCE(NULLIF(EXCLUDED.name, ''), customers.name),
    address = COALESCE(NULLIF(EXCLUDED.address, ''), customers.address),
    reference_point = COALESCE(NULLIF(EXCLUDED.reference_point, ''), customers.reference_point),
    preferred_payment_method = COALESCE(EXCLUDED.preferred_payment_method, customers.preferred_payment_method),
    last_change_for = COALESCE(EXCLUDED.last_change_for, customers.last_change_for),
    total_orders = customers.total_orders + 1,
    last_order_at = EXCLUDED.last_order_at;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Notifica o PostgREST para recarregar o esquema
NOTIFY pgrst, 'reload schema';
