-- SCRIPT DE RESET DA FIDELIDADE (COM BYPASS DE VALIDAÇÃO)
-- Execute este script no Editor SQL do Supabase para ZERAR a pontuação.

-- Desabilita temporariamente os gatilhos de USUÁRIO (ignora validações customizadas, mantém chave estrangeira)
ALTER TABLE orders DISABLE TRIGGER USER;

-- 1. Remove a elegibilidade de fidelidade de TODOS os pedidos existentes.
UPDATE orders
SET is_loyalty_eligible = FALSE;

-- 2. Limpa datas de resgate
UPDATE orders
SET loyalty_redeemed_at = NULL;

-- Reabilita os gatilhos de usuário
ALTER TABLE orders ENABLE TRIGGER USER;

-- 3. Confirmação
SELECT count(*) as total_pedidos_elegiveis FROM orders WHERE is_loyalty_eligible = TRUE;
