-- Script de Atualização Robusta para Colunas de Adicionais
-- Este script adiciona as colunas necessárias em ambos os padrões (camelCase e snake_case)
-- para garantir compatibilidade com o código atual e versões em cache.

-- 1. Padrão snake_case (mais comum no banco)
ALTER TABLE menu_items 
ADD COLUMN IF NOT EXISTS allowed_addons JSONB DEFAULT '[]'::jsonb;

-- 2. Padrão camelCase (forçado com aspas, usado em algumas colunas legadas do projeto)
ALTER TABLE menu_items 
ADD COLUMN IF NOT EXISTS "allowedAddons" JSONB DEFAULT '[]'::jsonb;

-- 3. Forçar o recarregamento do cache do esquema do Supabase (PostgREST)
-- Isso garante que as novas colunas sejam visíveis imediatamente pela API
NOTIFY pgrst, 'reload schema';
