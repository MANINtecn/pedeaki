// "Um peso sumiu da comanda SOZINHO depois de um tempo" (relato de 19/10/2026 sobre a comanda 5 de 18/10).
// Hipótese: o Balcão é DESMONTADO (atendente vai em Pedidos/F5, Comandos, Histórico... ou o app recarrega)
// com um peso lançado na tela e ainda NÃO salvo -- e nada salva o rascunho na saída.
//   ENTRY=aba.tsx OUT=aba.cjs node build.cjs && NODE_PATH=$PWD/node_modules node aba.cjs
import "./prelude";
import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { act } from "react";
import { CounterTab } from "@proj/components/CounterTab";
import * as A from "@novo/offline/armazemBalcao";
import { definirContextoBalcao } from "@novo/services/comandaBackend";
import { banco } from "./stub-supabase";

const g: any = globalThis; const w: any = g.window;
const disco: { texto: string | null } = { texto: null };
w.electron = { balcao: { carregar: async () => disco.texto, salvar: async (t: string) => { disco.texto = t; return { ok: true }; }, diario: async (l: string) => { (g.__diarioLinhas ||= []).push(l); return true; }, log: async () => true, espacoLivre: async () => 1e12 } };
const _err = console.error; console.error = (...a: any[]) => { if (String(a[0]).includes("not wrapped in act")) return; _err(...a); };
const _log = console.log; console.log = (...a: any[]) => { if (String(a[0]).startsWith("[Balcao]")) return; };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));
const settings: any = { balcaoV2: true, isScaleEnabled: true, scalePricePerKg: 64, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

let enviarRef: any = null; let setSinal: any = null; let comandaAtiva: number | null = null; let setAba: any = null;
const Parent = () => {
  const [, setVer] = useState(0);
  const [sinal, _s] = useState(0); setSinal = _s;
  const [aba, _a] = useState<"counter" | "orders">("counter"); setAba = _a;   // = activeTab do AdminPage
  useEffect(() => A.assinarArmazem(() => setVer(v => v + 1)), []);
  const ref = useRef<any>(null); enviarRef = ref;
  const onOrderComplete = async (order: any) => { if (order.id && String(order.id).startsWith("L-")) await A.atualizarPedidoLocal(order.id, order); else await A.criarPedidoLocal(order); };
  if (aba !== "counter") return <div>aba Pedidos</div>;   // o AdminPage só monta o CounterTab na aba Balcão
  return <CounterTab categories={[{ id: 1, name: "Milk" }]} menuItems={[]} addons={[]} settings={settings} storeId="s1"
    onOrderComplete={onOrderComplete} activeOrders={A.pedidosAbertosLocais()} enviarComandaAtivaRef={ref}
    fecharComandaSignal={sinal} onComandaAtivaChange={(n: number | null) => { comandaAtiva = n; }} />;
};
const press = (key: string) => w.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const passo = async (ms: number, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };
const balanca = async (kg: number) => { await act(async () => { g.__balanca.set(kg, true); await dormir(40); }); };
async function abrir(n: number) { for (const c of String(n)) await passo(8, () => press(c)); await passo(300, () => press("Enter")); }
const pesosNaTela = (): number[] => Array.from(document.querySelectorAll('button[title="Remover item"]'))
  .map(b => (b.parentElement!.querySelector("span")?.childNodes[0]?.textContent || "").match(/\(([\d,]+) kg\)/)?.[1]).filter(Boolean).map(x => Number(String(x).replace(",", ".")));
async function irParaPedidosEVoltar() { await act(async () => { setAba("orders"); await dormir(80); }); await act(async () => { setAba("counter"); await dormir(150); }); }
async function f7(n: number) {
  if (comandaAtiva == null) return null;
  const ok = await enviarRef.current(); const ps = A.pedidosAbertosDaComanda(n); if (!ok || !ps.length) return null;
  const total = Number(ps.reduce((s, o) => s + (Number(o.total) || 0), 0).toFixed(2));
  const r: any = await A.fecharComandaLocal(n, total, { method: "Dinheiro", amountTendered: total, discount: 0, tax: 0, finalTotal: total });
  await act(async () => { setSinal((v: number) => v + 1); await dormir(40); }); return r.ok ? r.venda : null;
}
let falhas = 0;
async function cenario(nome: string, corpo: () => Promise<{ ok: boolean; detalhe: string }>) {
  A.__reiniciarArmazemParaTeste(true); definirContextoBalcao(true); disco.texto = null; banco.orders = []; w.localStorage.clear(); comandaAtiva = null; g.__balanca.set(0, true);
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(60); });
  const r = await corpo();
  g.process.stdout.write(`${r.ok ? "ok    " : "FALHOU"} ${nome}\n         -> ${r.detalhe}\n`); if (!r.ok) falhas++;
  await act(async () => { root.unmount(); });
}
(async () => {
  await cenario("A1 comanda 5: peso 1 salvo; reabre, lança peso 2 (NÃO salvo); vai em Pedidos (F5) e volta; F7", async () => {
    await abrir(5); await balanca(0.136); await passo(120, () => press("Enter")); await balanca(0); await passo(400, () => press("Enter")); // salvo com 1 peso
    await abrir(5); await balanca(0.085); await passo(120, () => press("Enter")); // peso 2 só na tela
    const antes = pesosNaTela();
    await irParaPedidosEVoltar();
    await abrir(5); const depois = pesosNaTela();
    const v = await f7(5); const vendido = (v?.itens || []).filter((i: any) => i.weightKg).map((i: any) => i.weightKg);
    return { ok: vendido.length === 2, detalhe: `na tela antes de sair: [${antes.join(", ")}] | ao voltar: [${depois.join(", ")}] | vendido no F7: [${vendido.join(", ")}]` };
  });
  await cenario("A2 comanda nova: 2 pesos lançados (nada salvo ainda); vai em Pedidos e volta", async () => {
    await abrir(3); await balanca(0.200); await passo(120, () => press("Enter")); await balanca(0); await balanca(0.150); await passo(120, () => press("Enter"));
    const antes = pesosNaTela();
    await irParaPedidosEVoltar();
    await abrir(3); const depois = pesosNaTela();
    return { ok: depois.length === 2, detalhe: `na tela antes de sair: [${antes.join(", ")}] | ao voltar e reabrir a comanda 3: [${depois.join(", ")}]` };
  });
  // ---- COMANDA QUE JÁ VIROU PEDIDO (salva no disco) -- pedido do Ikarus, 19/10/2026 ----
  const salvarComanda = async (n: number, pesos: number[]) => {
    await abrir(n);
    for (const kg of pesos) { await balanca(kg); await passo(120, () => press("Enter")); await balanca(0); }
    await passo(400, () => press("Enter")); // envia (salva) -> a tela fecha
  };
  const pesosSalvos = (n: number) => A.pedidosAbertosDaComanda(n).flatMap(o => o.items || []).filter((i: any) => i.weightKg).map((i: any) => i.weightKg);
  const pesosVendidos = (v: any) => (v?.itens || []).filter((i: any) => i.weightKg).map((i: any) => i.weightKg).sort().join(", ");

  await cenario("B1 comanda SALVA (2 pesos); reabre SEM mexer; vai em Pedidos e volta; F7: nada some, nada duplica", async () => {
    await salvarComanda(4, [0.300, 0.200]);
    await abrir(4); await irParaPedidosEVoltar(); await abrir(4); const tela = pesosNaTela();
    const v = await f7(4);
    return { ok: tela.length === 2 && pesosVendidos(v) === "0.2, 0.3", detalhe: `tela ao voltar: [${tela.join(", ")}] | vendido: [${pesosVendidos(v)}]` };
  });
  await cenario("B2 comanda SALVA; reabre e ACRESCENTA um peso (não salvo); vai em Pedidos e volta; F7", async () => {
    await salvarComanda(4, [0.300]);
    await abrir(4); await balanca(0.250); await passo(120, () => press("Enter")); await irParaPedidosEVoltar(); await abrir(4); const tela = pesosNaTela();
    const v = await f7(4);
    return { ok: pesosVendidos(v) === "0.25, 0.3", detalhe: `tela ao voltar: [${tela.join(", ")}] | vendido: [${pesosVendidos(v)}]` };
  });
  await cenario("B3 comanda SALVA (2 pesos); reabre e APAGA um (Delete, não salvo); vai em Pedidos e volta; F7", async () => {
    await salvarComanda(4, [0.300, 0.200]);
    await abrir(4); await passo(80, () => press("Delete")); const aposApagar = pesosNaTela();
    await irParaPedidosEVoltar(); await abrir(4); const tela = pesosNaTela();
    const v = await f7(4);
    return { ok: tela.length === 1 && pesosVendidos(v) === aposApagar.sort().join(", "), detalhe: `depois do Delete: [${aposApagar.join(", ")}] | tela ao voltar: [${tela.join(", ")}] | vendido: [${pesosVendidos(v)}]` };
  });
  await cenario("B4 comanda SALVA com 1 produto; reabre e soma +1 (não salvo); vai em Pedidos e volta; F7", async () => {
    await abrir(6); await balanca(0.180); await passo(120, () => press("Enter")); await balanca(0); await passo(400, () => press("Enter"));
    await abrir(6); await passo(80, () => press("+"));
    await irParaPedidosEVoltar(); await abrir(6);
    const qtd = Array.from(document.querySelectorAll('button[title="Remover item"]')).map(b => Number(b.parentElement!.querySelector("span.px-1\\.5")?.textContent || "1"));
    const v = await f7(6); const qv = (v?.itens || []).reduce((s: number, i: any) => s + (Number(i.quantity) || 1), 0);
    return { ok: qv === 2, detalhe: `quantidade na tela ao voltar: [${qtd.join(", ")}] | unidades vendidas: ${qv}` };
  });
  await cenario("B5 comanda SALVA; o app REINICIA (sem X) com ela aberta e um peso a mais na tela; reabre; F7", async () => {
    await salvarComanda(7, [0.300]);
    await abrir(7); await balanca(0.150); await passo(120, () => press("Enter"));
    await act(async () => { setAba("orders"); await dormir(50); });            // a janela some (desmonta)
    await A.__simularReinicioParaTeste(); await A.carregarArmazem();           // app volta lendo o disco
    await act(async () => { setAba("counter"); await dormir(150); });
    await abrir(7); const tela = pesosNaTela(); const v = await f7(7);
    return { ok: pesosVendidos(v) === "0.15, 0.3", detalhe: `salvo no disco: [${pesosSalvos(7).join(", ") || "-"}] | tela ao reabrir: [${tela.join(", ")}] | vendido: [${pesosVendidos(v)}]` };
  });
  await cenario("B6 comanda SALVA; vai em Pedidos e volta 5 vezes seguidas (sem mexer); F7: nada duplica", async () => {
    await salvarComanda(8, [0.320, 0.110]);
    for (let k = 0; k < 5; k++) { await abrir(8); await irParaPedidosEVoltar(); }
    await abrir(8); const v = await f7(8);
    return { ok: pesosVendidos(v) === "0.11, 0.32", detalhe: `vendido: [${pesosVendidos(v)}]` };
  });
  await cenario("B7 comanda FECHADA (F7) vira venda; vai em Pedidos e volta: a venda continua na fila e a comanda some", async () => {
    await salvarComanda(9, [0.400]); await abrir(9); const v = await f7(9);
    await irParaPedidosEVoltar();
    const naFila = A.vendasNaFila().some(x => x.id === v?.id); const aberta = A.pedidosAbertosDaComanda(9).length;
    return { ok: naFila && aberta === 0, detalhe: `venda na fila: ${naFila} | comanda 9 ainda aberta: ${aberta}` };
  });
  if (g.process.env.DIARIO_SAIDA) require("fs").writeFileSync(g.process.env.DIARIO_SAIDA, (g.__diarioLinhas || []).join("\n") + "\n");
  g.process.stdout.write(`\nFALHAS: ${falhas}\n`); g.process.exit(falhas ? 1 : 0);
})();
