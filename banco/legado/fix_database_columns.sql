-- Adiciona colunas que podem estar faltando na tabela 'menu_items'
-- Usamos aspas duplas para garantir que o nome da coluna seja EXATAMENTE igual ao que o código espera (camelCase)

ALTER TABLE public.menu_items 
ADD COLUMN IF NOT EXISTS "isCombo" boolean DEFAULT false;

ALTER TABLE public.menu_items 
ADD COLUMN IF NOT EXISTS "eligibleForCombo" boolean DEFAULT false;

ALTER TABLE public.menu_items 
ADD COLUMN IF NOT EXISTS "isAvailable" boolean DEFAULT true;

ALTER TABLE public.menu_items 
ADD COLUMN IF NOT EXISTS "categoryId" bigint;

-- Garante que a coluna 'image' existe (caso o passo anterior tenha falhado)
ALTER TABLE public.menu_items 
ADD COLUMN IF NOT EXISTS image text;

-- Recarrega o cache do schema
NOTIFY pgrst, 'reload schema';


