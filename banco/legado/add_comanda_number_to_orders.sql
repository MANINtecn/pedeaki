-- EXECUTAR ESTE SCRIPT NO SQL EDITOR DO SUPABASE
-- Isso garante que todas as colunas necessárias existam com os nomes corretos (snake_case)

ALTER TABLE orders ADD COLUMN IF NOT EXISTS comanda_number INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_number INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS origin TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_loyalty_eligible BOOLEAN DEFAULT FALSE;
