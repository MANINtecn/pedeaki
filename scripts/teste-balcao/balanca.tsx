// BATERIA DA BALANÇA AUTOMÁTICA -- Balcão V2 (offline), CounterTab REAL, balança falsa controlável.
// Motivo: 18/10/2026 19h16, comanda 5 (#415): o 2º prato (0,085 kg) nunca entrou; a atendente cobrou
// R$ 5,47 de acréscimo na mão. O diário mostrou: a comanda foi enviada UMA vez com 1 peso.
// Cada cenário: o que a atendente QUERIA x o que o app FEZ.
//   ENTRY=balanca.tsx OUT=balanca.cjs node build.cjs && NODE_PATH=$PWD/node_modules node balanca.cjs
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
w.electron = { balcao: { carregar: async () => disco.texto, salvar: async (t: string) => { disco.texto = t; return { ok: true }; }, diario: async () => true, log: async () => true, espacoLivre: async () => 1e12 } };
const _err = console.error; console.error = (...a: any[]) => { if (String(a[0]).includes("not wrapped in act")) return; _err(...a); };
const _log = console.log; console.log = (...a: any[]) => { if (String(a[0]).startsWith("[Balcao]")) return; };
const dormir = (ms: number) => new Promise(r => setTimeout(r, ms));

const base = { isAvailable: true, eligibleForCombo: false, isCombo: false, selectedAddons: [], store_id: "s1", description: "" };
const menuItems: any[] = [{ ...base, id: 103, name: "MILK-SHAKE", price: 15, categoryId: 1, codigo: 103, allowedAddons: [] }];
const settings: any = { balcaoV2: true, isScaleEnabled: true, scalePricePerKg: 64, comboPrice: 13, defaultDDD: "32", mostrarDicasAtalho: false, deliveryFee: 0 };

let enviarRef: any = null; let setSinal: any = null; let comandaAtiva: number | null = null;
const Parent = () => {
  const [, setVer] = useState(0);
  const [sinal, _s] = useState(0); setSinal = _s;
  useEffect(() => A.assinarArmazem(() => setVer(v => v + 1)), []);
  const ref = useRef<any>(null); enviarRef = ref;
  const onOrderComplete = async (order: any) => {
    if (order.id && String(order.id).startsWith("L-")) await A.atualizarPedidoLocal(order.id, order); else await A.criarPedidoLocal(order);
  };
  return <CounterTab categories={[{ id: 1, name: "Milk" }]} menuItems={menuItems} addons={[]} settings={settings} storeId="s1"
    onOrderComplete={onOrderComplete} activeOrders={A.pedidosAbertosLocais()} enviarComandaAtivaRef={ref}
    fecharComandaSignal={sinal} onComandaAtivaChange={(n: number | null) => { comandaAtiva = n; }} />;
};
const press = (key: string) => w.dispatchEvent(new w.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));
const passo = async (ms: number, fn?: () => void) => { await act(async () => { fn && fn(); await dormir(ms); }); };
const balanca = async (kg: number, estavel = true) => { await act(async () => { g.__balanca.set(kg, estavel); await dormir(40); }); };
const enter = async (pausa = 120) => { await passo(pausa, () => press("Enter")); };
async function abrir(n: number) { for (const c of String(n)) await passo(8, () => press(c)); await passo(300, () => press("Enter")); }
async function codigo(c: string) { for (const k of c) await passo(5, () => press(k)); await passo(650); }
const pesosDaComanda = (n: number): number[] => {
  const salvos = A.pedidosAbertosDaComanda(n).flatMap(o => o.items || []).filter((i: any) => i.weightKg).map((i: any) => i.weightKg);
  return salvos;
};
const pesosNaTela = (): number[] => Array.from(document.querySelectorAll('button[title="Remover item"]'))
  .map(b => (b.parentElement!.querySelector("span")?.childNodes[0]?.textContent || "").match(/\(([\d,]+) kg\)/)?.[1])
  .filter(Boolean).map(x => Number(String(x).replace(",", ".")));
const avisoNaTela = () => { const t = (document.body.textContent || "").replace(/\s+/g, " "); const m = t.match(/(O peso mudou: [\d,]+ → [\d,]+ kg|Este peso \([^)]*\) acabou de ser lançado na Comanda \d+|Aguarde o peso estabilizar|Nenhuma comanda aberta|Aguarde a comanda abrir)/); return m ? m[1].trim() : ""; };
async function f7(n: number) {
  if (comandaAtiva == null) return null;
  const ok = enviarRef.current ? await enviarRef.current() : true;
  const ps = A.pedidosAbertosDaComanda(n);
  if (!ok || !ps.length) return null;
  const total = Number(ps.reduce((s, o) => s + (Number(o.total) || 0), 0).toFixed(2));
  const r: any = await A.fecharComandaLocal(n, total, { method: "Dinheiro", amountTendered: total, discount: 0, tax: 0, finalTotal: total });
  await act(async () => { setSinal((v: number) => v + 1); await dormir(40); });
  return r.ok ? r.venda : null;
}

type Linha = { cenario: string; queria: string; fez: string; classe: "OK" | "PERDA SILENCIOSA" | "ITEM FANTASMA" | "POR REGRA (com aviso)" | "DUPLICOU" };
const linhas: Linha[] = [];
const fmt = (xs: number[]) => xs.length ? xs.map(x => x.toFixed(3)).sort().join(" + ") : "nada";
async function cenario(nome: string, corpo: () => Promise<Omit<Linha, "cenario">>) {
  A.__reiniciarArmazemParaTeste(true); definirContextoBalcao(true); disco.texto = null; banco.orders = []; w.localStorage.clear(); comandaAtiva = null;
  g.__balanca.set(0, true);
  const root = createRoot(document.getElementById("root")!);
  await act(async () => { root.render(<Parent />); await dormir(60); });
  try { linhas.push({ cenario: nome, ...(await corpo()) }); } catch (e: any) { linhas.push({ cenario: nome, queria: "-", fez: "EXCECAO " + (e?.message || e), classe: "PERDA SILENCIOSA" }); }
  await act(async () => { root.unmount(); });
}
const classificar = (queria: number[], tem: number[], avisou: boolean): Linha["classe"] => {
  const q = fmt(queria), t = fmt(tem);
  if (q === t) return "OK";
  if (tem.length > queria.length && tem.some(x => x < 0.03)) return "ITEM FANTASMA";
  if (tem.length > queria.length) return "DUPLICOU";
  return avisou ? "POR REGRA (com aviso)" : "PERDA SILENCIOSA";
};

(async () => {
  await cenario("S1  dois pratos, tira o 1º (balança zera) e põe o 2º", async () => {
    await abrir(1); await balanca(0.300); await enter(); await balanca(0); await balanca(0.200); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(1); return { queria: "0.300 + 0.200", fez: fmt(tem), classe: classificar([0.3, 0.2], tem, false) };
  });
  await cenario("S2  TROCA DIRETA de prato, sem a balança zerar (0,136 -> 0,085) [caso de 18/10]", async () => {
    await abrir(5); await balanca(0.136); await enter(); await balanca(0.085); await enter(); const aviso = avisoNaTela();
    await enter(); await balanca(0); await enter(400); // atendente responde ENTER = outro prato; tira o prato; envia
    const tem = pesosDaComanda(5); return { queria: "0.136 + 0.085", fez: fmt(tem) + (aviso ? ` (perguntou: "${aviso}")` : " (NAO perguntou)"), classe: classificar([0.136, 0.085], tem, false) };
  });
  await cenario("S3  troca direta, prato mais PESADO (0,085 -> 0,136)", async () => {
    await abrir(2); await balanca(0.085); await enter(); await balanca(0.136); await enter(); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(2); return { queria: "0.085 + 0.136", fez: fmt(tem), classe: classificar([0.085, 0.136], tem, false) };
  });
  await cenario("S4  tira o prato mas fica RESÍDUO de 16 g, põe o 2º prato", async () => {
    await abrir(3); await balanca(0.200); await enter(); await balanca(0.016); await balanca(0.150); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(3); return { queria: "0.200 + 0.150", fez: fmt(tem), classe: classificar([0.2, 0.15], tem, false) };
  });
  await cenario("S5  resíduo de 3 g (abaixo do limite de 5 g) entre os pratos", async () => {
    await abrir(3); await balanca(0.200); await enter(); await balanca(0.003); await balanca(0.150); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(3); return { queria: "0.200 + 0.150", fez: fmt(tem), classe: classificar([0.2, 0.15], tem, false) };
  });
  await cenario("S6  mesmo prato, cliente pede MAIS comida (0,350 -> 0,420)", async () => {
    await abrir(4); await balanca(0.350); await enter(); await balanca(0.420); await enter(); await passo(60, () => press("a")); await balanca(0); await enter(400); // A = atualizar o prato
    const tem = pesosDaComanda(4);
    // Regra de 05/10: não relança o mesmo prato. O certo seria cobrar 0,420 (o que o cliente leva).
    return { queria: "0.420 (o prato final)", fez: fmt(tem), classe: fmt(tem) === "0.420" ? "OK" : "PERDA SILENCIOSA" };
  });
  await cenario("S7  peso oscilando, Enter, espera estabilizar, Enter", async () => {
    await abrir(6); await balanca(0.250, false); await enter(); const aviso = avisoNaTela(); await balanca(0.250, true); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(6); return { queria: "0.250", fez: fmt(tem) + (aviso ? ` (aviso: "${aviso}")` : ""), classe: classificar([0.25], tem, !!aviso) };
  });
  await cenario("S8  peso oscilando e Enter, Enter rápido (insistiu)", async () => {
    await abrir(6); await balanca(0.250, false); await enter(); const aviso = avisoNaTela(); await enter(400); await balanca(0); await enter(400); // tira o prato e envia
    const tem = pesosDaComanda(6); return { queria: "0.250", fez: fmt(tem) + (aviso ? ` (aviso: "${aviso}")` : ""), classe: classificar([0.25], tem, !!aviso) };
  });
  await cenario("S9  Enter duas vezes rápido com o prato na balança", async () => {
    await abrir(7); await balanca(0.300); await enter(30); await enter(400);
    const tem = pesosDaComanda(7); return { queria: "0.300 (1 vez)", fez: fmt(tem), classe: classificar([0.3], tem, false) };
  });
  await cenario("S10 RESÍDUO de 16 g na balança vazia, comanda só com produto, Enter para enviar", async () => {
    await abrir(8); await codigo("103"); await balanca(0.016); await enter(400);
    const tem = pesosDaComanda(8); return { queria: "nada (só o milk-shake)", fez: fmt(tem), classe: classificar([], tem, false) };
  });
  await cenario("S11 comanda 1 pesa e envia; troca o prato DIRETO e abre a comanda 2", async () => {
    await abrir(1); await balanca(0.300); await enter(); await enter(400); await balanca(0.200); await abrir(2); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(2); return { queria: "comanda 2: 0.200", fez: "comanda 2: " + fmt(tem), classe: classificar([0.2], tem, false) };
  });
  await cenario("S12 igual S11, mas a balança zera na troca", async () => {
    await abrir(1); await balanca(0.300); await enter(); await enter(400); await balanca(0); await balanca(0.200); await abrir(2); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(2); return { queria: "comanda 2: 0.200", fez: "comanda 2: " + fmt(tem), classe: classificar([0.2], tem, false) };
  });
  await cenario("S13 prato posto ANTES de abrir a comanda", async () => {
    await balanca(0.250); await abrir(3); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(3); return { queria: "0.250", fez: fmt(tem), classe: classificar([0.25], tem, false) };
  });
  await cenario("S14 lança o peso e aperta F7 na hora (prato ainda na balança)", async () => {
    await abrir(4); await balanca(0.310); await enter(); const v = await f7(4);
    const tem = (v?.itens || []).filter((i: any) => i.weightKg).map((i: any) => i.weightKg); return { queria: "venda com 0.310", fez: "venda com " + fmt(tem), classe: classificar([0.31], tem, false) };
  });
  await cenario("S15 lança, sai com X, volta na mesma comanda com o MESMO prato, Enter", async () => {
    await abrir(5); await balanca(0.280); await enter(); await passo(80, () => press("x")); await abrir(5); await enter(400);
    const tem = pesosDaComanda(5); return { queria: "0.280 (1 vez, não duplicar)", fez: fmt(tem), classe: classificar([0.28], tem, false) };
  });
  await cenario("S16 balança desconecta no meio da comanda, Enter", async () => {
    await abrir(6); await balanca(0.200); await enter(); await act(async () => { g.__balanca.desconectar(); await dormir(40); }); await enter(400);
    const tem = pesosDaComanda(6); return { queria: "0.200", fez: fmt(tem), classe: classificar([0.2], tem, false) };
  });
  await cenario("S17 zero só por um instante (1 leitura) entre os pratos", async () => {
    await abrir(7); await balanca(0.200); await enter(); await act(async () => { g.__balanca.set(0, true); g.__balanca.set(0.180, true); await dormir(40); }); await enter(); await balanca(0); await enter(400);
    const tem = pesosDaComanda(7); return { queria: "0.200 + 0.180", fez: fmt(tem), classe: classificar([0.2, 0.18], tem, false) };
  });

  await cenario("S18 prato ESQUECIDO na balança: comanda 1 pesa e envia, abre a comanda 2 com o MESMO prato", async () => {
    await abrir(1); await balanca(0.300); await enter(); await enter(400); await abrir(2); await codigo("103"); await enter(); const aviso = avisoNaTela();
    await passo(60, () => press("Escape")); await enter(400); // Esc = não lançar (prato do cliente anterior); Enter envia
    const tem = pesosDaComanda(2); return { queria: "comanda 2: nada (não cobrar o prato da 1)", fez: "comanda 2: " + fmt(tem) + (aviso ? ` (perguntou: "${aviso}")` : " (NAO perguntou)"), classe: classificar([], tem, !!aviso) };
  });
  await cenario("S19 troca direta, a atendente responde ESC (ignorar) e envia", async () => {
    await abrir(6); await balanca(0.136); await enter(); await balanca(0.085); await enter(); const aviso = avisoNaTela(); await passo(60, () => press("Escape")); await enter(400);
    const tem = pesosDaComanda(6); return { queria: "0.136 (ela escolheu ignorar)", fez: fmt(tem) + (aviso ? " (perguntou)" : " (NAO perguntou)"), classe: aviso && fmt(tem) === "0.136" ? "OK" : "PERDA SILENCIOSA" };
  });
  await cenario("S20 troca direta e a atendente NÃO responde: não pode enviar calado", async () => {
    await abrir(7); await balanca(0.136); await enter(); await balanca(0.085); await enter(400); const aviso = avisoNaTela();
    const enviou = comandaAtiva == null;
    return { queria: "perguntar e esperar (não enviar)", fez: (aviso ? `perguntou ("${aviso}")` : "NAO perguntou") + (enviou ? " e ENVIOU" : ", comanda continua aberta"), classe: aviso && !enviou ? "OK" : "PERDA SILENCIOSA" };
  });

  // ---- RELATO DA ATENDENTE (19/10/2026): "abre a comanda, lança o 1º peso, fica com a comanda aberta,
  // minutos depois outro peso entra na balança; dá Enter para lançar e só o peso 1 fica, o outro some;
  // tem que abrir a comanda de novo para relançar."
  await cenario("S21 RELATO: 1º peso lançado; minutos depois o 2º prato chega e ainda está ESTABILIZANDO; Enter, Enter", async () => {
    await abrir(5); await balanca(0.136); await enter(); await balanca(0); await dormir(300);
    await balanca(0.084, false); await enter(60); await enter(400); // pressa: o 2º Enter vem antes de estabilizar
    const tem = [...pesosDaComanda(5), ...pesosNaTela().filter(x => !pesosDaComanda(5).includes(x))];
    const fechou = comandaAtiva == null;
    return { queria: "0.136 + 0.085 (aprox.)", fez: fmt(tem) + (fechou ? " e a comanda FOI ENVIADA/FECHADA" : ", comanda aberta"), classe: tem.length === 2 ? "OK" : "PERDA SILENCIOSA" };
  });
  await cenario("S22 RELATO: igual, mas 1 Enter só e a balança estabiliza logo depois", async () => {
    await abrir(6); await balanca(0.136); await enter(); await balanca(0); await dormir(300);
    await balanca(0.084, false); await enter(60); await balanca(0.085, true); await dormir(300);
    const tem = [...pesosDaComanda(6), ...pesosNaTela().filter(x => !pesosDaComanda(6).includes(x))];
    return { queria: "0.136 + 0.085 (lançar sozinho quando estabilizar)", fez: fmt(tem) + (comandaAtiva == null ? " e a comanda FECHOU" : ", comanda aberta"), classe: tem.length === 2 ? "OK" : "PERDA SILENCIOSA" };
  });

  const larg = Math.max(...linhas.map(l => l.cenario.length));
  g.process.stdout.write("\n" + linhas.map(l => `${l.classe === "OK" ? "ok  " : "<<<<"} ${l.cenario.padEnd(larg)} | queria: ${l.queria} | fez: ${l.fez} | ${l.classe}`).join("\n") + "\n");
  const ruins = linhas.filter(l => l.classe === "PERDA SILENCIOSA" || l.classe === "ITEM FANTASMA" || l.classe === "DUPLICOU");
  g.process.stdout.write(`\nRESUMO: ${linhas.length} cenarios | OK ${linhas.filter(l => l.classe === "OK").length} | por regra com aviso ${linhas.filter(l => l.classe.startsWith("POR REGRA")).length} | PERDA/FANTASMA/DUPLICOU ${ruins.length}\n`);
  g.process.exit(0);
})();
