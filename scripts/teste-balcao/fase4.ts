// Fase 4 do offline (28/10/2026): cópia local, teste rápido de rede e classificação de erro.
//   ENTRY=fase4.ts OUT=fase4.cjs node build.cjs && node fase4.cjs
const g: any = globalThis;
const disco = new Map<string, string>();
let falhaDisco = false;
const ls = new Map<string, string>();
g.window = {
  addEventListener() {}, removeEventListener() {},
  localStorage: { getItem: (k: string) => ls.get(k) ?? null, setItem: (k: string, v: string) => { ls.set(k, v); } },
  electron: { balcao: {}, cacheLocal: {
    ler: async (n: string) => disco.get(n) ?? null,
    gravar: async (n: string, t: string) => { if (falhaDisco) return { ok: false, erro: "disco cheio" }; disco.set(n, t); return { ok: true }; },
  } },
};
g.navigator = { onLine: true };
g.crypto ||= require("crypto").webcrypto;

import { gravarCopia, lerCopia, __esquecerUltimoGravadoParaTeste, definirCopiaEmUso, copiaEmUsoDesde } from "@proj/services/cacheLocal";
import { configurarRadar, redeResponde, informarRede, __zerarRadarParaTeste } from "@proj/services/radarDeRede";
import { __erroTemporarioParaTeste as temp } from "@proj/offline/sincronizadorBalcao";

let falhas = 0, n = 0;
const ok = (nome: string, cond: boolean, extra = "") => { n++; if (!cond) { falhas++; console.log("FALHA", nome, extra); } else console.log("ok   ", nome); };
const igual = (nome: string, a: any, b: any) => ok(nome, JSON.stringify(a) === JSON.stringify(b), `obtido ${JSON.stringify(a)} esperado ${JSON.stringify(b)}`);

(async () => {
  // ---- cópia local no PC (arquivo)
  const cardapio = { categories: [{ id: 1, name: "Açaí" }], menuItems: Array.from({ length: 84 }, (_, i) => ({ id: i, name: "Item " + i, price: 10 + i })) };
  await gravarCopia("admin_L", { menu: cardapio, settings: { printer: "x" } });
  const c = await lerCopia<any>("admin_L");
  igual("C1 grava e lê de volta o cardápio inteiro", [c?.valor.menu.menuItems.length, c?.valor.settings], [84, { printer: "x" }]);
  ok("C1 guarda a hora da cópia", typeof c?.em === "number" && Math.abs(c.em - Date.now()) < 5000);
  const antes = disco.get("admin_L");
  await new Promise(r => setTimeout(r, 15));
  await gravarCopia("admin_L", { menu: cardapio, settings: { printer: "x" } });
  ok("C2 conteúdo igual não regrava (a carga roda a cada 10 min)", disco.get("admin_L") === antes);
  await gravarCopia("admin_L", { menu: cardapio, settings: { printer: "y" } });
  ok("C3 conteúdo diferente regrava", disco.get("admin_L") !== antes);

  falhaDisco = true; __esquecerUltimoGravadoParaTeste();
  await gravarCopia("outra", { a: 1 });
  ok("C4 disco falhando não derruba nada e não deixa cópia", (await lerCopia("outra")) === null);
  falhaDisco = false;
  await gravarCopia("outra", { a: 1 });
  igual("C4 na próxima carga tenta de novo e grava", (await lerCopia<any>("outra"))?.valor, { a: 1 });

  disco.set("quebrada", "{ isto nao e json");
  ok("C5 arquivo ilegível vira 'sem cópia', não erro", (await lerCopia("quebrada")) === null);
  disco.set("sem_hora", JSON.stringify({ valor: 1 }));
  ok("C6 arquivo sem a hora é recusado", (await lerCopia("sem_hora")) === null);
  ok("C7 cópia que nunca existiu: null", (await lerCopia("nunca")) === null);

  // ---- cópia no navegador (sem Electron): localStorage
  const eletron = g.window.electron; g.window.electron = undefined;
  __esquecerUltimoGravadoParaTeste();
  await gravarCopia("web_L", { x: 7 });
  igual("C8 sem Electron usa o localStorage", (await lerCopia<any>("web_L"))?.valor, { x: 7 });
  g.window.electron = eletron;

  definirCopiaEmUso(123); igual("C9 aviso sabe de quando é a cópia em uso", copiaEmUsoDesde(), 123);
  definirCopiaEmUso(null); igual("C9 e limpa quando a nuvem volta", copiaEmUsoDesde(), null);

  // ---- teste rápido de rede (radar)
  let chamadas = 0; let modo: "ok" | "cai" | "pendura" | "401" = "ok";
  g.fetch = (_u: string, init: any) => new Promise((res, rej) => {
    chamadas++;
    if (modo === "ok") return res({ status: 200 });
    if (modo === "401") return res({ status: 401 });
    if (modo === "cai") return rej(new TypeError("Failed to fetch"));
    init?.signal?.addEventListener("abort", () => rej(new Error("abortado"))); // pendura até o limite
  });
  __zerarRadarParaTeste(); configurarRadar("https://x.supabase.co", "anon");
  ok("R1 internet ok: responde", (await redeResponde(1_000_000)) === true);
  const c1 = chamadas; await redeResponde(1_000_000 + 5_000);
  igual("R2 resultado vale 10 s: não testa de novo", chamadas, c1);
  modo = "cai"; await redeResponde(1_000_000 + 11_000) ;
  ok("R3 depois de 10 s testa de novo e vê a queda", (await redeResponde(1_000_000 + 11_500)) === false);
  modo = "401"; ok("R4 resposta 401 do servidor também prova que a internet chegou", (await redeResponde(1_000_000 + 30_000)) === true);
  modo = "pendura"; __zerarRadarParaTeste(); configurarRadar("https://x.supabase.co", "anon");
  const t0 = Date.now(); const r = await redeResponde();
  ok("R5 internet que pendura: desiste em ~2,5 s (não 25 s)", r === false && Date.now() - t0 < 4000, `levou ${Date.now() - t0} ms`);
  __zerarRadarParaTeste(); configurarRadar("https://x.supabase.co", "anon"); modo = "ok";
  g.navigator.onLine = false; const antesF = chamadas;
  ok("R6 Windows diz sem rede: responde falso sem testar", (await redeResponde()) === false && chamadas === antesF);
  g.navigator.onLine = true;
  __zerarRadarParaTeste(); configurarRadar("https://x.supabase.co", "anon"); modo = "cai";
  const [a, b, d] = await Promise.all([redeResponde(), redeResponde(), redeResponde()]);
  ok("R7 três perguntas ao mesmo tempo fazem um teste só", !a && !b && !d);
  informarRede(true); ok("R8 quem já sabe informa e evita teste", (await redeResponde()) === true);
  __zerarRadarParaTeste(); ok("R9 sem configuração não atrapalha", (await redeResponde()) === true);

  // ---- classificação de erro do envio
  ok("E1 token vencido (401) é temporário, NÃO recusa", temp({ status: 401, message: "x" }) === true);
  ok("E2 'JWT expired' é temporário", temp({ message: "JWT expired", code: "PGRST303" }) === true);
  ok("E3 PGRST301 é temporário", temp({ code: "PGRST301" }) === true);
  ok("E4 recusa de dado (23505) continua permanente", temp({ code: "23505" }) === false);
  ok("E5 coluna que não existe continua permanente", temp({ code: "PGRST204" }) === false);
  ok("E6 queda de rede (sem código) temporário", temp(new TypeError("Failed to fetch")) === true);
  ok("E7 erro 500 temporário", temp({ status: 503 }) === true);

  console.log(falhas === 0 ? `\nTODOS OK (${n} verificações)` : `\nFALHAS: ${falhas} de ${n}`);
  process.exit(falhas ? 1 : 0);
})();
