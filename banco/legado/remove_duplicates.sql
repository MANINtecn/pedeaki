-- Remover duplicatas de sabores de Milk Shake (mantendo apenas 1 de cada)
DELETE FROM public.addons
WHERE id IN (
  SELECT id FROM (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY name, "categoryId" ORDER BY id) AS rnum
    FROM public.addons
    WHERE "categoryId" = 9
  ) t
  WHERE t.rnum > 1
);
