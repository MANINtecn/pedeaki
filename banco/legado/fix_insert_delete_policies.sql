-- Política para permitir INSERIR (Criar) novos itens
-- Permite apenas se o usuário for dono da loja onde o item está sendo criado
CREATE POLICY "Enable insert for store owners" ON "public"."menu_items"
AS PERMISSIVE FOR INSERT
TO public
WITH CHECK (auth.uid() IN (
  SELECT owner_id FROM stores WHERE id = store_id
));

-- Política para permitir DELETAR itens
-- Permite apenas se o usuário for dono da loja
CREATE POLICY "Enable delete for store owners" ON "public"."menu_items"
AS PERMISSIVE FOR DELETE
TO public
USING (auth.uid() IN (
  SELECT owner_id FROM stores WHERE id = store_id
));

-- Recarrega o schema para garantir
NOTIFY pgrst, 'reload schema';
