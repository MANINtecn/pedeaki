-- Sistema de fidelidade por PONTOS (2o modelo, ao lado do "selo" existente).
-- settings.loyalty_model = 'selo' | 'pontos' decide qual esta ativo.

-- 1. Campo do modelo ativo, na tabela settings.
ALTER TABLE settings ADD COLUMN IF NOT EXISTS loyalty_model TEXT DEFAULT 'selo';

-- 2. Produtos resgataveis (ate 4 por loja, controlado na aplicacao).
CREATE TABLE IF NOT EXISTS loyalty_reward_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    menu_item_id INTEGER NOT NULL,
    points_cost INTEGER NOT NULL CHECK (points_cost > 0),
    menu_item_name TEXT NOT NULL,
    menu_item_price NUMERIC(10,2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE loyalty_reward_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public All LoyaltyRewardItems" ON public.loyalty_reward_items
FOR ALL TO public USING (true) WITH CHECK (true);

-- 3. Saldo de pontos por cliente (telefone) + loja. Um registro por par.
CREATE TABLE IF NOT EXISTS customer_loyalty_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    phone TEXT NOT NULL,
    points_balance INTEGER NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, phone)
);

ALTER TABLE customer_loyalty_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public All CustomerLoyaltyPoints" ON public.customer_loyalty_points
FOR ALL TO public USING (true) WITH CHECK (true);

-- 4. Historico de lancamentos (ganho/gasto). Evita contar o mesmo pedido
--    duas vezes (UNIQUE em order_id quando for ganho) e da auditoria.
CREATE TABLE IF NOT EXISTS loyalty_points_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    phone TEXT NOT NULL,
    -- 'ganho' (pedido pago) ou 'resgate' (trocou por produto)
    tipo TEXT NOT NULL CHECK (tipo IN ('ganho', 'resgate')),
    points INTEGER NOT NULL, -- positivo em ganho, negativo em resgate
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    reward_item_id UUID REFERENCES loyalty_reward_items(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Um pedido so pode gerar ganho de pontos UMA vez, mesmo se a tela
-- reenviar a chamada (duplo clique, retry de rede).
CREATE UNIQUE INDEX IF NOT EXISTS loyalty_ledger_ganho_unico
    ON loyalty_points_ledger (order_id)
    WHERE tipo = 'ganho' AND order_id IS NOT NULL;

ALTER TABLE loyalty_points_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public All LoyaltyPointsLedger" ON public.loyalty_points_ledger
FOR ALL TO public USING (true) WITH CHECK (true);
