-- Opcao: imprimir automaticamente pedidos de Mesa / Retirada.
--
-- Quando FALSE, o pedido de mesa/retirada e recebido normalmente mas NAO
-- dispara impressao automatica — o operador imprime pelo botao do card.
-- Pedidos de Entrega NAO sao afetados: seguem imprimindo sozinhos.
--
-- DEFAULT TRUE para nao mudar o comportamento de quem ja usa o sistema.

ALTER TABLE settings
ADD COLUMN IF NOT EXISTS auto_print_dine_in BOOLEAN DEFAULT TRUE;

-- Garante que lojas ja existentes fiquem com a impressao automatica ligada.
UPDATE settings
SET auto_print_dine_in = TRUE
WHERE auto_print_dine_in IS NULL;
