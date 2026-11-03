-- Adiciona a coluna 'image' na tabela 'menu_items' se ela não existir
ALTER TABLE public.menu_items 
ADD COLUMN IF NOT EXISTS image text;

-- Recarrega o cache do schema (opcional, mas recomendado após alterações de estrutura)
NOTIFY pgrst, 'reload schema';
