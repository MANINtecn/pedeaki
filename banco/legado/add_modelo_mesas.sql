-- Layout do grid de mesas na aba Balcao.
-- 'padrao' (ou NULL) = grade numerada de sempre. 'personalizado' = cartoes
-- com nome do cliente, 8 visiveis + scroll. So exibicao — nao muda TOTAL_MESAS
-- nem a logica de selecao.
ALTER TABLE settings ADD COLUMN IF NOT EXISTS modelo_mesas TEXT DEFAULT 'padrao';
