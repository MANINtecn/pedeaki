-- Opção 1: Política Segura (Recomendada)
-- Permite atualização apenas se o usuário for o DONO da loja.
-- Certifique-se de que a tabela 'stores' tem a coluna 'owner_id' preenchida corretamente.

CREATE POLICY "Enable update for store owners" ON "public"."menu_items"
AS PERMISSIVE FOR UPDATE
TO public
USING (auth.uid() IN (
  SELECT owner_id FROM stores WHERE id = store_id
))
WITH CHECK (auth.uid() IN (
  SELECT owner_id FROM stores WHERE id = store_id
));


-- Opção 2: Política Permissiva (Use se a Opção 1 não funcionar imediatamente)
-- Permite que qualquer usuário autenticado atualize itens.
-- Útil para testes ou se a lógica de 'owner_id' ainda não estiver 100%.

-- CREATE POLICY "Enable update for authenticated users" ON "public"."menu_items"
-- AS PERMISSIVE FOR UPDATE
-- TO authenticated
-- USING (true)
-- WITH CHECK (true);
