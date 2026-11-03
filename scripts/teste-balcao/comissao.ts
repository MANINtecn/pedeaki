// Contas da comissão, saúde das lojas e auditoria de cancelamentos (src/services/comissao.ts).
//   ENTRY=comissao.ts OUT=comissao.cjs node build.cjs && node comissao.cjs
import { calcularPedido, taxaDoGateway, nivelDeContato, resumirCancelamentos, estimarComissao, simularVolume, receitaComMistura, taxasPorMeio, TAXAS_ASAAS_PADRAO, TAXAS_ASAAS_PROMO } from "@proj/services/comissao";

let falhas = 0, n = 0;
const ok = (nome: string, cond: boolean, extra = "") => { n++; if (!cond) { falhas++; console.log("FALHA", nome, extra); } else console.log("ok   ", nome); };
const igual = (nome: string, a: any, b: any) => ok(nome, JSON.stringify(a) === JSON.stringify(b), `obtido ${JSON.stringify(a)} esperado ${JSON.stringify(b)}`);

const padrao = { comissao_pct_propria: 8, comissao_pct_app: 20, comissao_fixa: 0.99, repassa_taxa_pagamento: true };
const semFixa = { ...padrao, comissao_fixa: 0 };
const plataformaPaga = { ...padrao, repassa_taxa_pagamento: false };

// ---- taxas do gateway (valores da página de preços do Asaas)
igual("G1 pix padrão", taxaDoGateway(30, "pix"), 1.99);
igual("G2 pix promocional", taxaDoGateway(30, "pix", TAXAS_ASAAS_PROMO), 0.99);
igual("G3 crédito à vista R$ 30 = 0,49 + 2,99%", taxaDoGateway(30, "credito"), 1.39);
igual("G4 débito R$ 30 = 0,35 + 1,89%", taxaDoGateway(30, "debito"), 0.92);
igual("G5 dinheiro não tem taxa", taxaDoGateway(30, "dinheiro"), 0);
igual("G6 pix R$ 30 pesa 6,6% do pedido", Math.round(1.99 / 30 * 1000) / 10, 6.6);

// ---- a conta que fiz com o Ikarus: ticket R$ 30, 8% sem parte fixa, plataforma pagando o gateway
{
  const r = calcularPedido({ total: 30, meio: "pix", entrega: "propria", condicoes: { ...semFixa, repassa_taxa_pagamento: false } });
  igual("A1 8% de R$ 30 = R$ 2,40; no Pix padrão sobram R$ 0,41 para a plataforma", [r.comissao, r.margemPlataforma], [2.4, 0.41]);
  const c = calcularPedido({ total: 30, meio: "credito", entrega: "propria", condicoes: { ...semFixa, repassa_taxa_pagamento: false } });
  igual("A2 no crédito sobra R$ 1,01", c.margemPlataforma, 1.01);
}

// ---- com parte fixa e repasse da taxa ao lojista (o padrão)
{
  const r = calcularPedido({ total: 30, meio: "pix", entrega: "propria", condicoes: padrao });
  igual("B1 comissão = 8% + R$ 0,99", r.comissao, 3.39);
  igual("B2 a plataforma fica com a comissão inteira (o lojista paga o gateway)", r.margemPlataforma, 3.39);
  igual("B3 o lojista recebe total - comissão - taxa", r.repasseLojista, r2(30 - 3.39 - 1.99));
  ok("B4 as partes somam o total", Math.abs(r.repasseLojista + r.comissao + r.taxaGateway + r.repasseMotoboy - r.total) < 0.011);
}
function r2(x: number) { return Math.round(x * 100) / 100; }

// ---- plataforma paga o gateway: a margem encolhe
{
  const r = calcularPedido({ total: 30, meio: "pix", entrega: "propria", condicoes: plataformaPaga });
  igual("C1 margem = comissão - gateway", r.margemPlataforma, r2(3.39 - 1.99));
  igual("C2 o lojista não paga a taxa", r.repasseLojista, r2(30 - 3.39));
}

// ---- dinheiro vira débito
{
  const r = calcularPedido({ total: 30, meio: "dinheiro", entrega: "propria", condicoes: padrao });
  igual("D1 dinheiro: a comissão vira débito e nada é repassado", [r.debitoGerado, r.repasseLojista, r.margemPlataforma, r.taxaGateway], [3.39, 0, 0, 0]);
}

// ---- entrega do app: percentual maior e o frete vai inteiro para o motoboy
{
  const r = calcularPedido({ total: 40, frete: 8, meio: "pix", entrega: "app", condicoes: padrao });
  igual("E1 base da comissão = só os produtos (R$ 32)", r.baseComissao, 32);
  igual("E2 comissão de 20% sobre R$ 32 + 0,99", r.comissao, r2(32 * 0.2 + 0.99));
  igual("E3 o motoboy recebe o frete inteiro", r.repasseMotoboy, 8);
  ok("E4 as partes somam o total", Math.abs(r.repasseLojista + r.comissao + r.taxaGateway + r.repasseMotoboy - r.total) < 0.011);
  const p = calcularPedido({ total: 40, frete: 8, meio: "pix", entrega: "propria", condicoes: padrao });
  igual("E5 entrega do lojista: o frete fica com ele e não entra na comissão", [p.repasseMotoboy, p.baseComissao], [0, 32]);
}

// ---- bordas
{
  const z = calcularPedido({ total: 0, meio: "pix", entrega: "propria", condicoes: padrao });
  igual("X1 pedido zerado não cobra parte fixa", z.comissao, 0);
  const f = calcularPedido({ total: 5, frete: 9, meio: "dinheiro", entrega: "propria", condicoes: padrao });
  igual("X2 frete maior que o total não gera base negativa", f.baseComissao, 0);
  ok("X3 pedido pequeno no Pix padrão com 8% e sem parte fixa fica negativo se a plataforma paga o gateway",
     calcularPedido({ total: 10, meio: "pix", entrega: "propria", condicoes: { ...plataformaPaga, comissao_fixa: 0 } }).margemPlataforma < 0);
}

// ---- saúde das lojas
const T = Date.parse("2026-10-30T15:00:00Z"), ha = (min: number) => new Date(T - min * 60000).toISOString();
igual("S1 contato há 1 min: ok", nivelDeContato(ha(1), T), "ok");
igual("S2 há 10 min sem fila: atenção", nivelDeContato(ha(10), T), "atencao");
igual("S3 há 10 min COM venda na fila: crítico", nivelDeContato(ha(10), T, 3), "critico");
igual("S4 há 31 min: crítico", nivelDeContato(ha(31), T), "critico");
igual("S5 nunca deu sinal: crítico", nivelDeContato(null, T), "critico");
igual("S6 recém-chegado com fila: ok (a fila é normal por segundos)", nivelDeContato(ha(2), T, 2), "ok");

// ---- auditoria de cancelamentos
{
  const L = "loja-A", M = "loja-B";
  const mk = (s: string, st: string, motivo?: string, total = 20) => ({ store_id: s, status: st, total, cancel_reason: motivo });
  const pedidos = [
    ...Array.from({ length: 6 }, () => mk(L, "Entregue")),
    mk(L, "Cancelado", "Produto em falta"), mk(L, "Cancelado", "Produto em falta", 30), mk(L, "Cancelado", "Outro motivo: acabou o gás"), mk(L, "Cancelado", ""),
    ...Array.from({ length: 10 }, () => mk(M, "Entregue")), mk(M, "Cancelado", "Cliente pediu para cancelar"),
  ];
  const r = resumirCancelamentos(pedidos);
  igual("U1 a loja com mais cancelamento vem primeiro", r.map(x => x.store_id), [L, M]);
  const a = r[0];
  igual("U2 conta pedidos, cancelados e taxa (4 de 10 = 40%)", [a.pedidos, a.cancelados, a.taxaPct], [10, 4, 40]);
  igual("U3 agrupa os motivos e junta os 'Outro motivo'", a.motivos, { "Produto em falta": 2, "Outro motivo": 1 });
  igual("U4 cancelamento sem motivo é contado à parte", a.semMotivo, 1);
  igual("U5 valor cancelado", a.valorCancelado, 90);
  igual("U6 loja A é suspeita (40% com amostra suficiente)", a.suspeito, true);
  igual("U7 loja B não é (1 de 11)", r[1].suspeito, false);
  const poucas = resumirCancelamentos([mk("C", "Cancelado", "x"), mk("C", "Cancelado", "y")]);
  igual("U8 amostra pequena não acusa ninguém", poucas[0].suspeito, false);
}

// ---- estimativa de comissão de uma loja
{
  const e = estimarComissao([
    { total: 30, payment_method: "PIX", status: "Entregue" },
    { total: 30, payment_method: "Cartão", status: "Entregue" },
    { total: 30, payment_method: "Dinheiro", status: "Entregue" },
    { total: 99, payment_method: "PIX", status: "Cancelado" },
  ], padrao);
  igual("V1 não conta cancelado; soma comissão e débito do dinheiro", [e.pedidos, e.vendas, e.comissao, e.debito], [3, 90, r2(3.39 * 3), 3.39]);
  igual("V2 a margem não inclui o dinheiro (ainda é débito)", e.margem, r2(3.39 * 2));
}

// ---- simulador de volume (ticket médio x quantidade)
{
  const prop = simularVolume({ ticket: 30, pedidosPorMes: 100, pct: 8, fixa: 0.99 });
  igual("W1 8% + R$ 0,99 sobre R$ 30 = R$ 3,39 por pedido", prop.comissaoPorPedido, 3.39);
  igual("W2 100 pedidos por mês = R$ 339,00", prop.comissaoMensal, 339);
  igual("W3 o lojista paga 11,3% do ticket", prop.custoDoLojistaPct, 11.3);
  igual("W4 o lojista fica com R$ 26,61 por pedido e R$ 2.661,00 no mês", [prop.lojistaRecebePorPedido, prop.lojistaRecebeMes], [26.61, 2661]);
  const app = simularVolume({ ticket: 30, pedidosPorMes: 100, pct: 20, fixa: 0.99 });
  igual("W5 entrega do app, 20% + 0,99 = R$ 6,99 por pedido, R$ 699 no mês", [app.comissaoPorPedido, app.comissaoMensal], [6.99, 699]);
  igual("W6 sem parte fixa e sem pedidos tudo zera sem dar erro", simularVolume({ ticket: 0, pedidosPorMes: 0, pct: 8, fixa: 0.99 }), { comissaoPorPedido: 0, comissaoMensal: 0, custoDoLojistaPct: 0, lojistaRecebePorPedido: 0, lojistaRecebeMes: 0 });
  igual("W7 valor negativo ou texto vira zero", simularVolume({ ticket: -5, pedidosPorMes: NaN as any, pct: 8, fixa: 1 }).comissaoMensal, 0);
  igual("W8 pedidos quebrados são arredondados para baixo", simularVolume({ ticket: 10, pedidosPorMes: 3.9, pct: 10, fixa: 0 }).comissaoMensal, 3);
  const mix = receitaComMistura(prop, app, 100, 30);
  igual("W9 mistura 30% pelo app: 70 x 3,39 + 30 x 6,99", [mix.pedidosApp, mix.pedidosProprios, mix.comissaoMensal], [30, 70, 447]);
  igual("W10 0% pelo app = só entrega do lojista", receitaComMistura(prop, app, 100, 0).comissaoMensal, 339);
  igual("W11 100% pelo app", receitaComMistura(prop, app, 100, 100).comissaoMensal, 699);
  igual("W12 porcentagem fora de 0 a 100 é limitada", receitaComMistura(prop, app, 100, 250).comissaoMensal, 699);
  const t = taxasPorMeio(30);
  igual("W13 taxas do gateway no ticket de R$ 30", [t.pix, t.credito, t.debito], [1.99, 1.39, 0.92]);
  const baixa = simularVolume({ ticket: 30, pedidosPorMes: 100, pct: 5, fixa: 0.99 });
  ok("W14 baixar a porcentagem baixa a comissão", baixa.comissaoMensal < prop.comissaoMensal);
}

console.log(falhas === 0 ? `\nTODOS OK (${n} verificações)` : `\nFALHAS: ${falhas} de ${n}`);
process.exit(falhas ? 1 : 0);
