---
name: pedido-teste
description: Mandar um pedido de teste para o PDV do Acai do Dudu. Use quando o usuario pedir para testar o fluxo de pedidos, a impressao ou a chegada na cozinha. Ha um script pronto - nao escreva outro na hora.
---

# Pedido de teste

Script pronto em `claude-pedido-teste.cjs`. **Nao escreva outro.**

```bash
cd .
node claude-pedido-teste.cjs              # ENTREGA (o padrao)
node claude-pedido-teste.cjs --retirada   # coluna Balcao/Retirada
node claude-pedido-teste.cjs --mesa 3     # mesa 3
node claude-pedido-teste.cjs --conferir   # reservas de impressao do ultimo
node claude-pedido-teste.cjs --limpar     # apaga os pedidos de teste
```

## Convencoes que o Icaro usa

- Cliente e **sempre TECX SISTEMAS** (a empresa dele) — nunca inventar outro nome
- `origin: 'WEB'`, para cair no filtro "So pedidos do app" da cozinha
- Padrao **Entrega**, salvo pedido em contrario

## Armadilha

O AdminPage separa as colunas por `order_type === 'Entrega'`.
Mandar como **Retirada** faz o pedido aparecer na coluna **Balcao/Retirada**,
nao em Entrega — ja gerou retrabalho.

## Limpar depois

Antes de o cliente usar em producao:
```bash
node claude-pedido-teste.cjs --limpar
```

## Conferir duplicidade de impressao

```sql
SELECT order_id, estacao, tipo_via, count(*) FROM impressoes
GROUP BY 1,2,3 HAVING count(*) > 1;
```
Nao deve retornar nada. Se retornar, a trava da tabela `impressoes` falhou.
