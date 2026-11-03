-- Copia os adicionais da 'Picanha Completa (Média)' para todos os itens das categorias:
-- 'Lanches Tradicionais', 'Lanches Gourmet' e 'Porções'

UPDATE public.menu_items
SET selected_addons = (
    SELECT selected_addons 
    FROM public.menu_items 
    WHERE name ILIKE '%Picanha Completa (Média)%' 
    LIMIT 1
)
WHERE "categoryId" IN (
    SELECT id 
    FROM public.categories 
    WHERE name ILIKE '%Tradicionais%' 
       OR name ILIKE '%Gourmet%' 
       OR name ILIKE '%Porções%'
);

-- Confirmação (opcional, apenas para log no SQL Editor)
-- SELECT count(*) as itens_atualizados FROM menu_items WHERE "categoryId" IN (SELECT id FROM categories WHERE name ILIKE '%Tradicionais%' OR name ILIKE '%Gourmet%' OR name ILIKE '%Porções%');
