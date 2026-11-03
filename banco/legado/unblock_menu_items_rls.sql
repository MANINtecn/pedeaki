-- REMOVE políticas antigas para evitar conflitos
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."menu_items";
DROP POLICY IF EXISTS "Enable insert for store owners" ON "public"."menu_items";
DROP POLICY IF EXISTS "Enable update for store owners" ON "public"."menu_items";
DROP POLICY IF EXISTS "Enable delete for store owners" ON "public"."menu_items";
DROP POLICY IF EXISTS "Enable update for authenticated users" ON "public"."menu_items";

-- CRIA políticas permissivas para desbloquear o desenvolvimento
-- Isso permite que qualquer usuário LOGADO crie, edite e delete itens.
-- Em produção, você pode querer restringir isso novamente.

CREATE POLICY "Allow all actions for authenticated users" ON "public"."menu_items"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Garante que leitura pública continua funcionando (para o cardápio do cliente)
CREATE POLICY "Allow public read access" ON "public"."menu_items"
AS PERMISSIVE FOR SELECT
TO public
USING (true);

-- Recarrega o schema
NOTIFY pgrst, 'reload schema';
