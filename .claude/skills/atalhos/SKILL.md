---
name: atalhos
description: Mexer nos atalhos de teclado do PDV (teclas F4-F7, digitos, N, R, ESC, campo de nome). Use ao alterar qualquer captura de tecla no CounterTab ou AdminPage. Quatro bugs ja nasceram daqui - leia antes de tocar no codigo.
---

# Atalhos de teclado — leia antes de mexer

## 🔴 O sintoma-assinatura

> **"minimiza o app e volta, ai funciona"**

Se o usuario disser isso, **e closure defasada**. Nao procure noutro lugar.
Minimizar forca o remount, que atualiza a closure velha.

## A causa de 4 bugs seguidos

O `CounterTab` e o `AdminPage` registram `keydown` no `window`. O handler vive
fora do ciclo de render, entao **a closure fica um ciclo atras do estado**.

| Sintoma | Causa |
|---|---|
| Produto entrava 2x | efeito sem deps reinstalava o listener |
| F4 demorava ~1 min | listener adicionado/removido a cada render |
| Item avulso nao digitava | `isCustomItemModalOpen` lido da closure |
| Campo de nome (N) travado | `nomeAberto` lido da closure |

## As 4 regras

**1. Registrar o listener UMA vez** (`useEffect` com `[]`) e delegar para uma ref.

**2. Estado que decide bloquear tecla vem de REF, atualizada no CORPO do render:**
```ts
const nomeAbertoRef = useRef(false);
nomeAbertoRef.current = nomeAberto;   // no corpo, NAO em useEffect
```
Hoje existem duas: `modalAbertoRef` e `nomeAbertoRef`. Criou estado novo que
silencia atalho? Crie a ref junto.

**3. Sair ANTES de chamar `preventDefault()`** quando o foco esta em
INPUT/TEXTAREA ou ha modal/campo aberto. `preventDefault()` numa tecla que era
do campo = campo morto, e o sintoma nao aponta para o listener.

**4. Overlays do atalho (`z-[9998]`) nao podem aparecer com modal aberto** —
cobrem a tela e bloqueiam o clique nos modais, que estao em `z-50`.

**Bonus:** foco por `setInterval` compete com o clique do usuario.
Use `autoFocus` + `requestAnimationFrame`, uma vez so.

## Mapa atual

| Tecla | Acao |
|---|---|
| F4 / F5 / F6 | Balcao / Pedidos / Comandos |
| F7 | Checkout da comanda aberta |
| 1-30 | Numero da mesa · **100+** = codigo do produto |
| R | Retirada (sem mesa) |
| N | Campo de nome |
| ENTER | 1x monta · 2x envia |
| ESC | Cancela |
| D / C / P | Dinheiro / Cartao / Pix (so no checkout) |

Digitos/ENTER/ESC no AdminPage **so valem na aba Pedidos** — no Balcao sao do
lancamento.

## ⚠️ Testar SEMPRE apos mexer

Sao os quatro que ja quebraram:
1. **Item avulso** — abrir e digitar nome e valor
2. **Campo de nome** — apertar N e digitar; depois clicar no campo
3. **Busca de produto** — digitar texto normalmente
4. **F4/F5** — de varios lugares, varias vezes seguidas

Atualizar tambem a lista `ATALHOS` em `ComandosTab.tsx`, que alimenta a tela
E a colinha impressa em 58mm.

## 🔒 A trava automatica

`scripts/checar-atalhos.cjs` roda dentro do `npm run electron:build`.
**O build quebra** se algum destes for lido cru dentro do handler de teclado:

`nomeAberto` · `isCustomItemModalOpen` · `isTableModalOpen` ·
`isScaleModalOpen` · `isCategoryModalOpen` · `isAddonModalOpen`

Existe porque a Regra 10 reincidiu **cinco vezes**. Se o build acusar, a
correcao e sempre a mesma: usar a ref (`nomeAbertoRef.current`), atualizada no
corpo do render.

Estado novo que silencia atalho? **Crie a ref E adicione o nome na lista
`PROIBIDOS` do script.**

Rodar sozinho: `npm run lint:atalhos`
