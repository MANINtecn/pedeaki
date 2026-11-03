// Regra do fechamento de mesa/comanda (utils/fechamentoMesa.ts). Rodar:
//   ENTRY=fechamento.ts OUT=fechamento.cjs node build.cjs && node fechamento.cjs
import { planejarFechamentoMesa } from "@proj/utils/fechamentoMesa";

let falhas = 0;
const confere = (nome: string, cond: boolean, extra = "") => { console.log(`${cond ? "ok  " : "FALHOU"} ${nome}${extra ? "  -> " + extra : ""}`); if (!cond) falhas++; };
const soma = (p: any) => Number(p.partes.reduce((a: number, x: any) => a + x.total, 0).toFixed(2));
const sem = { discount: 0, tax: 0 };

// 1) O CASO REAL: pedido #165 (sexta 09/10). Tela cobrava 26,50 (2 pesos); o banco so tinha 1 sub-pedido de 13,57.
let p: any = planejarFechamentoMesa([{ id: "A", total: 13.57 }], 26.5, { ...sem, finalTotal: 26.5 });
confere("#165: tela 26,50 x banco 13,57 BLOQUEIA", p.ok === false && p.totalTela === 26.5 && p.totalBanco === 13.57);

// 2) Lista local atrasada: tela 13,57, banco ja tem os dois (26,50) -> bloqueia (senao gravava a venda pela metade)
p = planejarFechamentoMesa([{ id: "A", total: 13.57 }, { id: "B", total: 12.93 }], 13.57, { ...sem, finalTotal: 13.57 });
confere("tela atrasada 13,57 x banco 26,50 BLOQUEIA", p.ok === false);

// 3) AVANCAR de UM sub-pedido (total so dele) numa comanda com dois -> bloqueia
p = planejarFechamentoMesa([{ id: "A", total: 20 }, { id: "B", total: 30 }], 20, { ...sem, finalTotal: 20 });
confere("AVANCAR de 1 sub-pedido (20) x comanda (50) BLOQUEIA", p.ok === false);

// 4) Normal, sem desconto/taxa: cada sub-pedido MANTEM o seu total, soma bate
p = planejarFechamentoMesa([{ id: "A", total: 13.57 }, { id: "B", total: 12.93 }], 26.5, { ...sem, finalTotal: 26.5 });
confere("normal sem ajuste: cada um mantem o total", p.ok && p.partes[0].total === 13.57 && p.partes[1].total === 12.93 && soma(p) === 26.5);

// 5) Desconto: rateia proporcional, soma = valor cobrado
p = planejarFechamentoMesa([{ id: "A", total: 13.57 }, { id: "B", total: 12.93 }], 26.5, { discount: 2, tax: 0, finalTotal: 24.5 });
confere("desconto R$2: soma = 24,50", p.ok && soma(p) === 24.5, JSON.stringify(p.partes));

// 6) Taxa: soma = valor + taxa
p = planejarFechamentoMesa([{ id: "A", total: 18 }, { id: "B", total: 3 }], 21, { discount: 0, tax: 1, finalTotal: 22 });
confere("taxa R$1: soma = 22,00 (caso #232 da sexta)", p.ok && soma(p) === 22, JSON.stringify(p.partes));

// 7) Tres sub-pedidos iguais + desconto de centavos: o ultimo absorve o resto, soma exata
p = planejarFechamentoMesa([{ id: "A", total: 10.01 }, { id: "B", total: 10.01 }, { id: "C", total: 10.01 }], 30.03, { discount: 0.5, tax: 0, finalTotal: 29.53 });
confere("3 sub-pedidos + desconto 0,50: soma exata 29,53", p.ok && soma(p) === 29.53, JSON.stringify(p.partes));

// 8) Diferenca de 1 centavo de ponto flutuante NAO bloqueia
p = planejarFechamentoMesa([{ id: "A", total: 0.1 }, { id: "B", total: 0.2 }], 0.30000000000000004, { ...sem, finalTotal: 0.3 });
confere("ruido de ponto flutuante nao bloqueia", p.ok === true);

// 9) Banco sem nenhum sub-pedido aberto (comanda ja fechada/apagada) -> bloqueia
p = planejarFechamentoMesa([], 13.57, { ...sem, finalTotal: 13.57 });
confere("banco sem sub-pedidos abertos BLOQUEIA", p.ok === false);

// 10) Um unico sub-pedido normal (caso mais comum no dia a dia) com taxa de cartao
p = planejarFechamentoMesa([{ id: "A", total: 6 }], 6, { discount: 0, tax: 2, finalTotal: 8 });
confere("um sub-pedido + taxa 2: total 8,00 (caso #152 da quarta)", p.ok && p.partes[0].total === 8);

console.log(`\nFALHAS: ${falhas}`);
process.exit(falhas ? 1 : 0);
