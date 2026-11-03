// INVESTIGAÇÃO (20/10/2026): peso some de COMANDA JÁ ENVIADA? Rascunhos já estão cobertos (aba.tsx).
// Atendente aleatória, balança AUTOMÁTICA usada do jeito certo (põe o prato, espera firmar, Enter, tira),
// várias comandas enviadas e reabertas, trocas, códigos, Enter de envio, X, F7, paradas -- e a lista de
// pedidos ATUALIZANDO SOZINHA por baixo (o AdminPage refaz a lista a cada 30 s). SEM sair da aba
// (essa causa já foi achada e corrigida na 1.0.96).
// Juiz: modelo do que foi lançado; confere a TELA após cada ação e a VENDA em cada F7.
//   ENTRY=enviadas.tsx OUT=enviadas.cjs node build.cjs && SESSOES=10 PASSOS=80 SEED=1 NODE_PATH=$PWD/node_modules node enviadas.cjs
//   versão antiga: PROJSRC=<src da 1.0.93> ENTRY=enviadas.tsx OUT=enviadas_193.cjs node build.cjs
import "./prelude";
import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { act } from "react";
import { CounterTab } from "@proj/components/CounterTab";
import * as A from "@proj/offline/armazemBalcao";
import { definirContextoBalcao } from "@proj/services/comandaBackend";
import { banco } from "./stub-supabase";

const g: any = globalThis; const w: any = g.window; const env: any = g.process?.env || {};
const disco: { texto: string | null } = { texto: null };
w.electron = { balcao: { carregar: async () => disco.texto, salvar: async (t: string) => { disco.texto = t; return { ok: true }; }, diario: async (l: string) => { (g.__diario ||= []).push(l); return true; }, log: async () => true, espacoLivre: async () => 1e12 } };
const _err = console.error; console.error = (...a: any[]) => { const s = String(a[0]); if (s.includes("not wrapped in act") || s.includes("[Balcao]")) return; _err(...a); };
console.log = (...a: any[]) => { if (env.VERBOSO) g.process.stdout.write(a.join(" ") + "\n"); };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));
const base = { isAvailable: true, eligibleForCombo: false, isCombo: false, selectedAddons: [], store_id: "s1", description: "" };
const menuItems: any[] = [
  { ...base, id: 103, name: "MILK-SHAKE", price: 15, categoryId: 1, codigo: 103, allowedAddons: [] },
  { ...base, id: 222, name: "AGUA", price: 4, categoryId: 1, codigo: 222, allowedAddons: [] },
];
const settings: any = { balcaoV2: true, isScaleEnabled: true, scalePricePerKg: 64, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

let enviarRef: any = null; let setSinal: any = null; let comandaAtiva: number | null = null;
const Parent = () => {
  const [, setVer] = useState(0);
  const [sinal, _s] = useState(0); setSinal = _s;
  useEffect(() => A.assinarArmazem(() => setVer(v => v + 1)), []);
  // = polling/realtime do AdminPage: a lista de pedidos é refeita sozinha, por baixo
  useEffect(() => { const t = setInterval(() => setVer(v => v + 1), 700); return () => clearInterval(t); }, []);
  const ref = useRef<any>(null); enviarRef = ref;
  const onOrderComplete = async (order: any) => { if (order.id && String(order.id).startsWith("L-")) await A.atualizarPedidoLocal(order.id, order); else await A.criarPedidoLocal(order); };
  return <CounterTab categories={[{ id: 1, name: "Milk" }]} menuItems={menuItems} addons={[]} settings={settings} storeId="s1"
    onOrderComplete={onOrderComplete} activeOrders={A.pedidosAbertosLocais()} enviarComandaAtivaRef={ref}
    fecharComandaSignal={sinal} onComandaAtivaChange={(n: number | null) => { comandaAtiva = n; }} />;
};
const press = (key: string) => w.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const passo = async (ms: number, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };
const balanca = async (kg: number, estavel = true, ms = 40) => { await act(async () => { g.__balanca.set(kg, estavel); await dormir(ms); }); };
type Conteudo = Map<string, number>;
const nomePeso = (kg: string) => `Açaí/Sorvete por Quilo (${kg.replace(".", ",")} kg)`;
const tela = (): Conteudo => { const m: Conteudo = new Map(); document.querySelectorAll('button[title="Remover item"]').forEach(b => { const l = b.parentElement!; const n = (l.querySelector("span")?.childNodes[0]?.textContent || "").trim(); const q = Number(l.querySelector("span.px-1\\.5")?.textContent || "1"); m.set(n, (m.get(n) || 0) + q); }); return m; };
const ultimaLinha = () => { const bs = document.querySelectorAll('button[title="Remover item"]'); if (!bs.length) return null; const l = bs[bs.length - 1].parentElement!; return { nome: (l.querySelector("span")?.childNodes[0]?.textContent || "").trim(), qtd: Number(l.querySelector("span.px-1\\.5")?.textContent || "1") }; };
const igual = (a: Conteudo, b: Conteudo) => { for (const k of new Set([...a.keys(), ...b.keys()])) if ((a.get(k) || 0) !== (b.get(k) || 0)) return false; return true; };
const txt = (m: Conteudo) => JSON.stringify([...m.entries()].filter(([, q]) => q).sort()).split("Açaí/Sorvete por Quilo ").join("P");
const doVenda = (itens: any[]): Conteudo => { const m: Conteudo = new Map(); itens.forEach(i => m.set(i.name, (m.get(i.name) || 0) + (Number(i.quantity) || 1))); return m; };
const salvo = (n: number): Conteudo => doVenda(A.pedidosAbertosDaComanda(n).flatMap(o => o.items || []));

let seed = Number(env.SEED || 1);
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const escolhe = <T,>(xs: T[]) => xs[Math.floor(rnd() * xs.length)];
const problemas: string[] = [];
const est = { acoes: 0, vendas: 0, pesos: 0, reaberturas: 0, enviosDeComandaJaEnviada: 0 };

async function sessao(num: number, passos: number) {
  A.__reiniciarArmazemParaTeste(true); definirContextoBalcao(true); disco.texto = null; banco.orders = []; w.localStorage.clear(); comandaAtiva = null; g.__balanca.set(0, true);
  const modelo = new Map<number, Conteudo>(); const de = (n: number) => { if (!modelo.has(n)) modelo.set(n, new Map()); return modelo.get(n)!; };
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(60); });
  const hist: string[] = [];
  const falha = (m: string) => problemas.push(`sessao ${num}: ${m}\n      acoes: ${hist.slice(-10).join(" > ")}`);
  const confere = async (onde: string) => { await passo(40); if (comandaAtiva == null) return; const t = tela(), m = de(comandaAtiva); if (!igual(t, m)) falha(`${onde}: comanda ${comandaAtiva} TELA ${txt(t)} x LANCADO ${txt(m)}`); };
  const usados = new Set<string>();
  const novoKg = () => { let k: string; do { k = (0.08 + Math.floor(rnd() * 600) / 1000).toFixed(3); } while (usados.has(k)); usados.add(k); return k; };

  for (let i = 0; i < passos; i++) {
    est.acoes++;
    const r = rnd(); const aberta = comandaAtiva != null;
    if (!aberta || r < 0.14) {
      const n = 1 + Math.floor(rnd() * 4);
      if (aberta && tela().size === 0) { const s = salvo(comandaAtiva!); if (s.size) modelo.set(comandaAtiva!, s); }
      const modo = rnd();
      if (modo < 0.75) { hist.push(`abre ${n}`); for (const c of String(n)) await passo(8, () => press(c)); await passo(300, () => press("Enter")); if (A.pedidosAbertosDaComanda(n).length) est.reaberturas++; }
      else { if (aberta) { hist.push("X"); await passo(60, () => press("x")); } hist.push("C"); await passo(300, () => press("c")); }
      await confere("depois de abrir");
    } else if (r < 0.46) {
      // PESO do jeito certo: põe o prato (firma em 0-500 ms), Enter quando firmar, tira o prato
      const n = comandaAtiva!; const kg = novoKg();
      const demora = escolhe([0, 0, 150, 500]);
      hist.push(`peso ${kg}@${n}`);
      await balanca(Number(kg), demora === 0, 30);
      if (demora) { if (rnd() < 0.4) await passo(30, () => press("Enter")); await dormir(demora); await balanca(Number(kg), true, 30); }
      await passo(150, () => press("Enter"));
      { const m = de(n); m.set(nomePeso(kg), (m.get(nomePeso(kg)) || 0) + 1); est.pesos++; } // a comanda n estava aberta quando ela pesou: o peso TEM que estar nela (mesmo que o Enter seguinte tenha enviado)
      await balanca(0, true, escolhe([40, 300]));
      await confere(`depois do peso ${kg}`);
    } else if (r < 0.56) {
      const cod = escolhe(["103", "222"]); const nome = cod === "103" ? "MILK-SHAKE" : "AGUA"; const n = comandaAtiva!;
      hist.push(`cod ${cod}@${n}`); for (const c of cod) await passo(5, () => press(c)); await passo(600); // regra: Enter < 0,5 s depois do código é ignorado
      if (comandaAtiva === n) { const m = de(n); m.set(nome, (m.get(nome) || 0) + 1); }
      await confere(`depois do codigo ${cod}`);
    } else if (r < 0.74) {
      const n = comandaAtiva!; if (A.pedidosAbertosDaComanda(n).length) est.enviosDeComandaJaEnviada++;
      const vezes = rnd() < 0.2 ? 2 + Math.floor(rnd() * 3) : 1; hist.push(`Enter x${vezes}@${n}`);
      await dormir(550); for (let k = 0; k < vezes; k++) await passo(escolhe([15, 120]), () => press("Enter"));
      await passo(250);
      await confere("depois do Enter");
    } else if (r < 0.79) {
      if (tela().size === 0) { const s = salvo(comandaAtiva!); if (s.size) modelo.set(comandaAtiva!, s); }
      hist.push("X"); await passo(80, () => press("x"));
    } else if (r < 0.84) {
      const u = ultimaLinha();
      if (u) { const del = rnd() < 0.6; hist.push(`${del ? "Delete" : "+"}(${u.nome.slice(-12)})`); await passo(80, () => press(del ? "Delete" : "+")); const m = de(comandaAtiva!); m.set(u.nome, (m.get(u.nome) || 0) + (del ? -u.qtd : 1)); await confere(del ? "depois do Delete" : "depois do +"); }
    } else if (r < 0.92) {
      const ms = escolhe([300, 900, 1600]); hist.push(`parada ${ms}ms`); await passo(ms); await confere("depois da parada");
    } else {
      const n = comandaAtiva!; hist.push(`F7@${n}`);
      const ok = await enviarRef.current();
      if (!ok) { falha(`F7 comanda ${n} recusou`); continue; }
      const ps = A.pedidosAbertosDaComanda(n); const esperado = de(n);
      if (!ps.length) { if ([...esperado.values()].some(q => q > 0)) falha(`F7 comanda ${n}: nada salvo mas lancado ${txt(esperado)}`); continue; }
      const total = Number(ps.reduce((s, o) => s + (Number(o.total) || 0), 0).toFixed(2));
      const antes = A.vendasNaFila().length;
      const rr: any = await A.fecharComandaLocal(n, total, { method: "Dinheiro", amountTendered: total, discount: 0, tax: 0, finalTotal: total });
      if (!rr.ok) { falha(`F7 comanda ${n} bloqueado`); continue; }
      const v = A.vendasNaFila()[antes]; const vend = doVenda(v.itens);
      if (!igual(vend, esperado)) falha(`F7 comanda ${n}: VENDA ${txt(vend)} x LANCADO ${txt(esperado)}`);
      modelo.set(n, new Map()); est.vendas++;
      await act(async () => { setSinal((x: number) => x + 1); await dormir(40); });
    }
  }
  await act(async () => { root.unmount(); });
}

(async () => {
  const S = Number(env.SESSOES || 8), P = Number(env.PASSOS || 70);
  for (let s = 1; s <= S; s++) { await sessao(s, P); g.process.stdout.write(`sessao ${s}/${S}: ${problemas.length} problema(s)\n`); }
  g.process.stdout.write(`\nACOES ${est.acoes} | pesos ${est.pesos} | reaberturas de comanda ja enviada ${est.reaberturas} | envios de comanda ja enviada ${est.enviosDeComandaJaEnviada} | vendas ${est.vendas}\n`);
  g.process.stdout.write(`PROBLEMAS: ${problemas.length}\n${problemas.slice(0, 8).map(p => " - " + p).join("\n")}\n`);
  if (env.DIARIO_SAIDA) require("fs").writeFileSync(env.DIARIO_SAIDA, (g.__diario || []).join("\n") + "\n");
  g.process.exit(problemas.length ? 1 : 0);
})();
