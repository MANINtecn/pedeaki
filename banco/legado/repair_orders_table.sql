-- SCRIPT DE REPARAÇÃO TOTAL (VERSÃO ROBUSTA)
-- Este script padroniza os nomes para snake_case e resolve conflitos de colunas duplicadas.
-- Execute no SQL Editor do Supabase.

DO $$ 
BEGIN
    -- 1. Tratar cada coluna com verificação de colisão
    
    -- CUSTOMER_NAME
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customerName') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_name') THEN
            ALTER TABLE orders DROP COLUMN "customerName";
        ELSE
            ALTER TABLE orders RENAME COLUMN "customerName" TO customer_name;
        END IF;
    END IF;

    -- DAILY_ORDER_NUMBER
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'dailyOrderNumber') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'daily_order_number') THEN
            ALTER TABLE orders DROP COLUMN "dailyOrderNumber";
        ELSE
            ALTER TABLE orders RENAME COLUMN "dailyOrderNumber" TO daily_order_number;
        END IF;
    END IF;

    -- ORDER_TYPE
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'orderType') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'order_type') THEN
            ALTER TABLE orders DROP COLUMN "orderType";
        ELSE
            ALTER TABLE orders RENAME COLUMN "orderType" TO order_type;
        END IF;
    END IF;

    -- PAYMENT_METHOD
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'paymentMethod') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_method') THEN
            ALTER TABLE orders DROP COLUMN "paymentMethod";
        ELSE
            ALTER TABLE orders RENAME COLUMN "paymentMethod" TO payment_method;
        END IF;
    END IF;

    -- COMANDA_NUMBER
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'comandaNumber') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'comanda_number') THEN
            ALTER TABLE orders DROP COLUMN "comandaNumber";
        ELSE
            ALTER TABLE orders RENAME COLUMN "comandaNumber" TO comanda_number;
        END IF;
    END IF;

    -- 2. Garantir que todas as colunas essenciais existem (caso não existissem nem em camelCase)
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS daily_order_number INTEGER;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS comanda_number INTEGER;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_number INTEGER;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS origin TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_loyalty_eligible BOOLEAN DEFAULT FALSE;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee DECIMAL DEFAULT 0;

END $$;

-- Forçar atualização do cache do Supabase
NOTIFY pgrst, 'reload schema';
