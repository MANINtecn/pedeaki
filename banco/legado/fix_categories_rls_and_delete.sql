-- 1. Corrige as permissões (RLS) para a tabela CATEGORIES
-- Permite que qualquer usuário logado crie, edite e delete categorias
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON "public"."categories";
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."categories";

CREATE POLICY "Allow all actions for authenticated users" ON "public"."categories"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Mantém leitura pública (para o cardápio)
CREATE POLICY "Allow public read access" ON "public"."categories"
AS PERMISSIVE FOR SELECT
TO public
USING (true);


-- 2. Deleta as categorias indesejadas (pelo nome)
DELETE FROM "public"."categories"
WHERE name IN ('Adicionais de Açaí', 'Adicionais de Lanche', 'Sabores de Milk-Shake');


-- Recarrega o schema
NOTIFY pgrst, 'reload schema';
