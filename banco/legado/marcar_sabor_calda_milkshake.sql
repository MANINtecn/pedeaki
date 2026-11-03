-- Marca os complementos de Milkshake como 'sabor' ou 'calda', para ativar
-- o fluxo em 2 passos (1 sabor, depois 1 calda) -- Ikarus, 21/09/2026.
-- Rodar DEPOIS de add_addon_group.sql (cria a coluna).
--
-- Cobre 2 produtos: "Milk Shake 500ml" (21 sabores + 4 caldas) e "Milk Shake
-- Gourmet Ferrero Rocher 500ml" (1 sabor + 1 calda).
--
-- NAO cobre "milk shake mousse de uva com limao 500ml" -- esse produto so
-- tem 3 caldas cadastradas, sem nenhum complemento de sabor (o sabor
-- provavelmente ja esta fixo no nome do produto). Fica de fora do fluxo
-- dual de proposito; se quiser trata-lo tambem, e' so eu ajustar depois.

-- Sabores do "Milk Shake 500ml"
UPDATE addons SET addon_group = 'sabor' WHERE id IN (
    '0fa4c5e0-a08b-4e6d-b265-69577aa556f5', -- Kinder Ovo
    '0a1d169a-d84e-41f6-af28-4293ee54e929', -- Flocos
    '3c240c69-e369-4093-b237-62cd7eb13821', -- Morango
    '59a7c737-c426-4fd3-8649-4645502e6848', -- Chocolate
    'be493845-eea7-4a9c-bb06-cc7783e0679c', -- Ninho Trufado
    '0ddf7a84-6702-4b20-b005-769ed3b1c648', -- Ovomaltine
    '280f0fb4-01b1-4d38-889d-e9880fd49228', -- Blue Ice
    'f667a931-2e90-498d-a737-6721a71edf64', -- Chocomenta
    'cba1a84a-9a2f-45b1-b053-cba1e1aeaf52', -- Creme
    '8a236284-235f-4dba-a8eb-8273061c7791', -- Bombom
    '494ccfc2-b169-41ea-b1b6-ed66020e41fb', -- Banana c/ Nutella
    '5a2863d7-e170-4a28-a3e9-f5ac296d9e8b', -- Maracuja Trufado
    'a23f40ed-d14d-4f19-995b-31540fd443d0', -- Torta Alema
    '88f93eb9-be8d-449c-9b29-c4f77eeed91b', -- Milho Verde
    '0cdfecdb-1e07-4663-b07e-1c9886f5a288', -- Sonho de Valsa
    '5bafb0ac-fcb4-49c6-bc58-7545daace588', -- Ferreiro Rocher
    'f9a7ba8f-f6a7-4818-974e-5c8f20f54a4a', -- Ninho com Morango
    'f64d5ac5-e79f-4b59-9913-eea75c294a73', -- Prestigio
    'ce44c6f0-fc46-4c55-92fa-5d5ced9b3713', -- Torta de Limao
    '6b4998bf-2724-4c56-a0eb-638ed5b8f6c1', -- Pacoquinha
    '82865ca8-f262-4cc5-9525-acd624e2cfac'  -- Amor em Pedacos
);

-- Caldas do "Milk Shake 500ml"
UPDATE addons SET addon_group = 'calda' WHERE id IN (
    '7b5dbbe2-77b1-4840-a650-34921ae1ff4e', -- Calda de morango
    '0dcbea87-8f75-4593-8cf3-98215387be22', -- Calda de chocolate
    'ac17a3e0-9797-4533-b372-59da51fcf9fc', -- Leite condensado
    '3072a32e-b277-4a40-961c-cc2a6b5d4d2d'  -- Chiclete
);

-- "Milk Shake Gourmet Ferrero Rocher 500ml"
UPDATE addons SET addon_group = 'sabor' WHERE id = '2159d89b-4346-4946-b152-6847fe6a5f67'; -- pacoca
UPDATE addons SET addon_group = 'calda' WHERE id = '7315b716-075d-4dc5-a753-7fec37dc4e1d'; -- calda chocolate
