-- Separa "sabor" de "calda" nos complementos, para o fluxo em 2 passos do
-- Milkshake -- pedido do Ikarus, 21/09/2026: "cliente escolhe o sabor
-- primeiro... no maximo 1 sabor... e depois perguntamos qual calda, 1
-- calda apenas selecionada".
--
-- NULL = generico (comportamento historico, lista unica sem separacao).
ALTER TABLE addons ADD COLUMN IF NOT EXISTS addon_group TEXT CHECK (addon_group IN ('sabor', 'calda'));
