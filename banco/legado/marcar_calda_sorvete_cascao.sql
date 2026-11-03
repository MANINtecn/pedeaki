-- Marca as caldas do "Sorvete kit cascão" (2 produtos) para o fluxo de
-- troca de tela -- Ikarus, 23/09/2026: "apenas separar as caldas, igual
-- fez no milk". Rodar DEPOIS de add_addon_group.sql (cria a coluna).
--
-- So as caldas "270g" (chocolate/morango/leite condensado) entram no
-- grupo -- decisao explicita do Ikarus: "Calda quente" fica de fora
-- (pode ser servida diferente, nao e' o mesmo padrao de pote), e as
-- variantes minusculas duplicadas do produto #277 ("calda chocolate" sem
-- 270g) tambem ficam de fora, mantendo so as com "270g" para bater com o
-- padrao do produto #276.

-- "sorvete 1,8ls + cascão" (id 276)
UPDATE addons SET addon_group = 'calda' WHERE id IN (
    'f28b0855-dd14-41dd-82b4-61b9e76873e6', -- Calda de Chocolate 270g
    'dc83875c-2035-4596-be0b-562bd0382b27', -- Calda de morango 270g
    'de088a72-ff7c-471b-9173-4e05e2ce0e32'  -- Calda de leite cond 270g
);

-- "sorvete 1,8lts + cascão + calda" (id 277)
UPDATE addons SET addon_group = 'calda' WHERE id IN (
    '8ecdefb0-9861-4ff6-8594-9462bad0e025', -- Calda de Chocolate 270g
    'e31d5809-d6bd-4f3a-978f-a2a261a0db1a', -- Calda de morango 270g
    '9a5e6af6-b8df-40a9-b20c-8cc44985e1d6'  -- Calda de leite cond 270g
);
