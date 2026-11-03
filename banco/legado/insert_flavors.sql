-- Inserir sabores de Milk Shake (Categoria ID 9)
-- Assumindo que o preço é 0 (incluso no valor do tamanho)

INSERT INTO public.addons ("name", "price", "categoryId")
VALUES 
  ('Chocolate', 0.00, 9),
  ('Morango', 0.00, 9),
  ('Ovomaltine', 0.00, 9),
  ('Nutela', 0.00, 9),
  ('Ninho Trufado', 0.00, 9);

-- Se der erro dizendo que a coluna "categoryId" não existe, tente usar "category_id" (sem aspas ou com aspas):
-- INSERT INTO public.addons (name, price, category_id) ...
