-- Adiciona colunas de imagem e preço original na tabela promotions
ALTER TABLE public.promotions ADD COLUMN IF NOT EXISTS image TEXT;
ALTER TABLE public.promotions ADD COLUMN IF NOT EXISTS original_price NUMERIC;
ALTER TABLE public.promotions ADD COLUMN IF NOT EXISTS promotional_price NUMERIC;
