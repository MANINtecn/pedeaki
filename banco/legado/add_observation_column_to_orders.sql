-- Adiciona a coluna observation à tabela orders se ela não existir
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS observation TEXT;

-- Recarrega o cache do PostgREST para reconhecer a nova coluna imediatamente
NOTIFY pgrst, 'reload schema';
