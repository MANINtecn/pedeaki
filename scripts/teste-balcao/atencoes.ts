// Lista "Precisa da sua atenção" da central de gestão (src/pages/superadmin/atencoes.ts).
//   ENTRY=atencoes.ts OUT=atencoes.cjs node build.cjs && node atencoes.cjs
import { calcularAtencoes } from "@proj/pages/superadmin/atencoes";

let falhas = 0, n = 0;
const ok = (nome: string, cond: boolean, extra = "") => { n++; if (!cond) { falhas++; console.log("FALHA", nome, extra); } else console.log("ok   ", nome); };
const igual = (nome: string, a: any, b: any) => ok(nome, JSON.stringify(a) === JSON.stringify(b), `obtido ${JSON.stringify(a)} esperado ${JSON.stringify(b)}`);

const T = Date.parse("2026-10-30T15:00:00Z");
const ha = (min: number) => new Date(T - min * 60000).toISOString();
const loja = (id: string, extra: any = {}): any => ({ id, name: "Loja " + id, slug: id, is_active: true, modelo: "pdv", plan: "avancado", ...extra });
const base = (o: any = {}) => ({ stores: [], financeiros: {}, cardapio: {}, sinais: [], pedidos: [], agora: T, ...o });
const ids = (a: any[], id: string) => a.find(x => x.id === id)?.lojas;

igual("A0 sem nada para ver, lista vazia", calcularAtencoes(base()), []);

// computador sem contato com venda presa
{
  const r = calcularAtencoes(base({ stores: [loja("a"), loja("b")], cardapio: { a: 5, b: 5 },
    sinais: [{ store_id: "a", ultimo_contato: ha(45), vendas_na_fila: 4 }, { store_id: "b", ultimo_contato: ha(45), vendas_na_fila: 0 }] }));
  igual("A1 só a loja com venda presa entra (a sem fila não é urgente)", ids(r, "fila-presa"), ["Loja a"]);
  igual("A1 e é urgente, no topo", r[0].gravidade, "alta");
}

// débito perto do limite
{
  const com = (id: string, debito: number, limite = 100) => ({ [id]: { store_id: id, comissao_pct_propria: 8, comissao_pct_app: 20, comissao_fixa: 0.99, repassa_taxa_pagamento: true, limite_debito: limite, debito_dinheiro: debito } });
  const stores = [loja("c1", { modelo: "comissao", plan: null }), loja("c2", { modelo: "comissao", plan: null }), loja("c3", { modelo: "comissao", plan: null })];
  const r = calcularAtencoes(base({ stores, cardapio: { c1: 3, c2: 3, c3: 3 }, financeiros: { ...com("c1", 85), ...com("c2", 79), ...com("c3", 10, 0) } }));
  igual("B1 débito a 80% ou mais entra; 79% não; limite zero não acusa", ids(r, "debito"), ["Loja c1"]);
}

// mensalidade
{
  const r = calcularAtencoes(base({ stores: [
    loja("v1", { subscription_end_date: new Date(T + 3 * 86400000).toISOString() }),
    loja("v2", { subscription_end_date: new Date(T - 2 * 86400000).toISOString() }),
    loja("v3", { subscription_end_date: new Date(T + 20 * 86400000).toISOString() }),
    loja("v4", { modelo: "comissao", plan: null, subscription_end_date: new Date(T - 9 * 86400000).toISOString() }),
  ], cardapio: { v1: 1, v2: 1, v3: 1, v4: 1 }, financeiros: { v4: {} as any } }));
  igual("C1 vence em 3 dias e já venceu entram; 20 dias não; loja de comissão não tem vencimento", ids(r, "vencimento"), ["Loja v1", "Loja v2"]);
}

// dono sem login, comissão sem condições, shopping sem cardápio, cardápio vazio, loja suspensa
{
  const r = calcularAtencoes(base({ stores: [
    loja("d1", { owner_email: "x@x.com", owner_id: null }),
    loja("d2", { owner_email: "y@y.com", owner_id: "u" }),
    loja("e1", { modelo: "comissao", plan: null }),
    loja("s1", { aparecer_no_shopping: true }),
    loja("s2", { aparecer_no_shopping: true }),
    loja("z1", { is_active: false, aparecer_no_shopping: true }),
  ], cardapio: { d1: 4, d2: 4, e1: 4, s2: 9 } }));
  igual("D1 dono sem login", ids(r, "sem-login"), ["Loja d1"]);
  igual("D2 comissão sem condições", ids(r, "sem-condicoes"), ["Loja e1"]);
  igual("D3 no shopping sem cardápio (a suspensa não conta)", ids(r, "shopping-vazio"), ["Loja s1"]);
  igual("D4 cardápio vazio só de loja ativa", ids(r, "cardapio-vazio"), ["Loja s1"]);
}

// cancelamento suspeito
{
  const mk = (s: string, st: string) => ({ store_id: s, status: st, total: 10 });
  const pedidos = [...Array.from({ length: 6 }, () => mk("p1", "Entregue")), ...Array.from({ length: 4 }, () => mk("p1", "Cancelado")), ...Array.from({ length: 12 }, () => mk("p2", "Entregue")), mk("p2", "Cancelado")];
  const r = calcularAtencoes(base({ stores: [loja("p1"), loja("p2")], cardapio: { p1: 1, p2: 1 }, pedidos }));
  igual("E1 só a loja com 40% de cancelamento", ids(r, "cancelamento"), ["Loja p1"]);
}

// ordem: urgente antes de atenção antes de quando-der
{
  const r = calcularAtencoes(base({ stores: [loja("o1", { owner_email: "a@a.com" }), loja("o2")], cardapio: { o1: 1 }, sinais: [{ store_id: "o1", ultimo_contato: ha(60), vendas_na_fila: 2 }] }));
  igual("F1 ordenado por gravidade", r.map(x => x.gravidade), ["alta", "media", "baixa"]);
}

console.log(falhas === 0 ? `\nTODOS OK (${n} verificações)` : `\nFALHAS: ${falhas} de ${n}`);
process.exit(falhas ? 1 : 0);
