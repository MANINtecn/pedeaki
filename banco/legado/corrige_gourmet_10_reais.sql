-- PICOLES GOURMET: preco padrao de R$ 10 no produto e sabores a R$ 0 (mesmo modelo dos outros picoles).
-- No Electron, "Prosseguir sem adicional" passa a lancar o Gourmet direto a R$ 10; no site o total de cada
-- picole continua R$ 10 (produto 10 + sabor 0). Com backup e rollback no fim.
-- ORDEM: se for criar o produto "Picole de Acai" (R$ 7), crie ANTES e desmarque o sabor
-- "açai c/ recheio de ninho" nos Adicionais Permitidos do Gourmet (Admin > Cardapio). Se rodar este SQL antes,
-- esse sabor passa a custar R$ 10 enquanto estiver no Gourmet (nao fica 17).

BEGIN;

CREATE TABLE IF NOT EXISTS backup_gourmet_20261005 (tipo TEXT, id TEXT, nome TEXT, preco_antigo NUMERIC);
ALTER TABLE backup_gourmet_20261005 ENABLE ROW LEVEL SECURITY;
INSERT INTO backup_gourmet_20261005 (tipo, id, nome, preco_antigo)
SELECT 'produto', id::text, name, price FROM menu_items WHERE codigo = 420;
INSERT INTO backup_gourmet_20261005 (tipo, id, nome, preco_antigo)
SELECT 'sabor', id::text, name, price FROM addons WHERE id IN ('2246cf65-8e51-48a2-bb71-90b556b53cdf', '1c75fc52-64a0-4e03-a61d-e3f1e2b3e002', '6237227f-278f-4829-81af-cfdbecf22ff5', 'e15a31fa-5a2e-4c1a-9a73-97d74d73296f', '71ad28ce-bef9-4840-bbad-37ac6abd4a11', '09dfcd6d-8254-46a2-87ec-a67e996d2649');

UPDATE menu_items SET price = 10 WHERE codigo = 420;
UPDATE addons SET price = 0 WHERE id IN ('2246cf65-8e51-48a2-bb71-90b556b53cdf', '1c75fc52-64a0-4e03-a61d-e3f1e2b3e002', '6237227f-278f-4829-81af-cfdbecf22ff5', 'e15a31fa-5a2e-4c1a-9a73-97d74d73296f', '71ad28ce-bef9-4840-bbad-37ac6abd4a11', '09dfcd6d-8254-46a2-87ec-a67e996d2649');

COMMIT;

-- Conferir: produto = 10 e todos os sabores = 0
SELECT 'produto' AS tipo, name, price FROM menu_items WHERE codigo = 420
UNION ALL
SELECT 'sabor', name, price FROM addons WHERE id IN ('2246cf65-8e51-48a2-bb71-90b556b53cdf', '1c75fc52-64a0-4e03-a61d-e3f1e2b3e002', '6237227f-278f-4829-81af-cfdbecf22ff5', 'e15a31fa-5a2e-4c1a-9a73-97d74d73296f', '71ad28ce-bef9-4840-bbad-37ac6abd4a11', '09dfcd6d-8254-46a2-87ec-a67e996d2649');

-- ROLLBACK (so se precisar desfazer):
-- UPDATE menu_items m SET price = b.preco_antigo FROM backup_gourmet_20261005 b WHERE b.tipo = 'produto' AND m.id::text = b.id;
-- UPDATE addons a SET price = b.preco_antigo FROM backup_gourmet_20261005 b WHERE b.tipo = 'sabor' AND a.id::text = b.id;
