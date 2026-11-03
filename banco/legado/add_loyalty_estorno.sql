-- Adiciona o tipo 'estorno' ao ledger de pontos, para o cancelamento de
-- pedido devolver os pontos ganhos -- regra fechada com o Ikarus,
-- 21/09/2026: "pedido for cancelado a gente retira o ponto".

-- 1. Amplia o CHECK que hoje so aceita 'ganho'/'resgate'.
ALTER TABLE loyalty_points_ledger DROP CONSTRAINT IF EXISTS loyalty_points_ledger_tipo_check;
ALTER TABLE loyalty_points_ledger ADD CONSTRAINT loyalty_points_ledger_tipo_check
    CHECK (tipo IN ('ganho', 'resgate', 'estorno'));

-- 2. Impede estornar o mesmo pedido duas vezes (mesmo padrao do "ganho").
CREATE UNIQUE INDEX IF NOT EXISTS loyalty_ledger_estorno_unico
    ON loyalty_points_ledger (order_id)
    WHERE tipo = 'estorno' AND order_id IS NOT NULL;
