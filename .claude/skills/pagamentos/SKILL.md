---
name: pagamentos
description: Formas de pagamento do PDV Acai do Dudu - PIX com comprovante no WhatsApp, dinheiro e cartao. Use ao mexer no checkout, na tela pos-pedido do cliente ou ao integrar maquininha/gateway.
---

# Pagamentos

## O que JA existe (1.0.42+)

### PIX com comprovante no WhatsApp
Ao fechar pedido no PIX, o cliente ve: chave com botao de copiar, aviso de que o
pedido **ja entrou em producao**, e um botao que abre o WhatsApp da loja com o
**resumo do pedido ja escrito** — ele so anexa o comprovante.

Arquivos: `PixPosPedido.tsx`, `resumoPedidoService.ts`, `PixWhatsappConfig.tsx`
Config: chave, tipo, beneficiario, WhatsApp da loja, modelo editavel do resumo.
SQL: `add_pix_whatsapp.sql`

### 🔴 A regra do texto
Enquadrar como **"agilizar a entrega"**, NUNCA como "desbloquear" ou "liberar".

> ❌ "Envie o comprovante para desbloquear a entrega" — soa como desconfianca
> ✅ "Envie o comprovante — assim confirmamos na hora e seu pedido sai mais rapido"

O pedido **ja esta em producao**; o comprovante agiliza, nao destrava. Pedir para
liberar aumenta abandono.

### Checkout (fechar conta no PDV)
`CheckoutModal.tsx` — atalhos **D** (dinheiro) / **C** (cartao) / **P** (pix),
**ENTER** ou **F2** finaliza, **ESC** cancela. Letras visiveis nos botoes.

⚠️ O modal tem early-return; hook apos `return` quebra as regras do React.
Por isso o teclado esta em `onKeyDown` no container, nao em `useEffect`.

⚠️ `ref={(el) => el?.focus()}` roda a CADA render e rouba o foco do campo —
foi o bug do "campo de valor nao aceita digitar". Focar so na abertura.

## O que o sistema TEM hoje
Apenas 3 formas: **Dinheiro · Cartao · PIX** (`PaymentMethod` em `types.ts`).

⚠️ O Multipedidos tem 7 (separa credito, debito, crediario, fidelidade, voucher).
Se o cliente pedir essa separacao, **nao e so atalho** — muda `PaymentMethod`,
o caixa e os relatorios. Avaliar o impacto antes.

## O que NAO esta decidido

Integracao real de pagamento (maquininha, gateway, PIX automatico com conciliacao)
**ainda nao foi discutida**. Hoje:
- PIX = manual, conferido pelo comprovante no WhatsApp
- Cartao = maquininha propria do cliente, na entrega/balcao
- Dinheiro = troco calculado no checkout

**Nao presuma gateway.** Se o assunto surgir, perguntar antes:
1. Querem conciliacao automatica (saber que o PIX caiu sem olhar comprovante)?
2. Ja tem adquirente/maquininha com API?
3. Quem paga a taxa por transacao?

## Ligacao com a NFC-e
A forma de pagamento entra na nota (tag `detPag`). Ao implementar a NFC-e,
mapear: Dinheiro=01, Cartao Credito=03, Cartao Debito=04, PIX=17.
Como o sistema nao separa credito de debito, **decidir com o contador** qual usar.
