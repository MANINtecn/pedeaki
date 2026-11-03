// Login offline: impressão da senha guardada no PC (credencial-local.js do processo principal).
//   ENTRY=credencial.ts OUT=credencial.cjs node build.cjs && node credencial.cjs
import fs from "fs";
import os from "os";
import path from "path";
// @ts-ignore (arquivo .js do processo principal)
import { criarCredenciais } from "../../credencial-local.js";

let falhas = 0, n = 0;
const ok = (nome: string, cond: boolean, extra = "") => { n++; if (!cond) { falhas++; console.log("FALHA", nome, extra); } else console.log("ok   ", nome); };
const igual = (nome: string, a: any, b: any) => ok(nome, JSON.stringify(a) === JSON.stringify(b), `obtido ${JSON.stringify(a)} esperado ${JSON.stringify(b)}`);

// safeStorage falso: "criptografa" embaralhando (basta para provar que o arquivo não guarda texto legível)
const safeFalso = (disponivel = true) => ({
  isEncryptionAvailable: () => disponivel,
  encryptString: (s: string) => Buffer.from(Buffer.from(s, "utf8").map(b => b ^ 0x5a)),
  decryptString: (b: Buffer) => Buffer.from(Buffer.from(b).map(x => x ^ 0x5a)).toString("utf8"),
});

const novaPasta = () => fs.mkdtempSync(path.join(os.tmpdir(), "cred-"));
let relogio = 1_000_000;
const agora = () => relogio;

const dir = novaPasta();
const c = criarCredenciais({ dir, safeStorage: safeFalso(), agora });
const EMAIL = "Admin@Acaidudu.com", SENHA = "Senha-Forte#2026 áç";

ok("L0 sem nenhuma conta ainda", c.existe() === false);
ok("L1 salva depois de um login com internet", c.salvar(EMAIL, SENHA, "user-1").ok === true);
ok("L1 agora existe conta", c.existe() === true && c.existe("admin@acaidudu.com") === true);
igual("L2 senha certa entra (e devolve o usuário)", c.conferir(EMAIL, SENHA), { ok: true, userId: "user-1" });
ok("L3 e-mail com letras maiúsculas ou espaços entra igual", c.conferir("  admin@ACAIDUDU.com ", SENHA).ok === true);
igual("L4 senha errada não entra", c.conferir(EMAIL, "senha-errada").motivo, "senha");
igual("L4 e conta quantas tentativas restam", c.conferir(EMAIL, "errada2").restantes, 3);
igual("L5 e-mail desconhecido", c.conferir("outro@x.com", SENHA), { ok: false, motivo: "sem-credencial" });
igual("L6 senha vazia não entra", c.conferir(EMAIL, "").ok, false);
ok("L6 senha gigante é recusada sem custo", c.conferir(EMAIL, "x".repeat(5000)).ok === false && c.salvar(EMAIL, "x".repeat(5000)).ok === false);
ok("L7 acerto zera a contagem de erros", c.conferir(EMAIL, SENHA).ok === true && c.conferir(EMAIL, "e").restantes === 4);

// trava por erros seguidos (cresce e libera com o tempo)
const t = criarCredenciais({ dir: novaPasta(), safeStorage: safeFalso(), agora });
t.salvar("a@a.com", "certa", "u");
for (let i = 0; i < 4; i++) t.conferir("a@a.com", "x");
const quinto = t.conferir("a@a.com", "x");
igual("T1 o 5º erro trava por 1 minuto", [quinto.travado, quinto.esperaMs], [true, 60_000]);
const preso = t.conferir("a@a.com", "certa");
igual("T2 travado, nem a senha certa entra", [preso.ok, preso.motivo], [false, "travado"]);
relogio += 61_000;
ok("T3 passado o tempo, a senha certa entra de novo", t.conferir("a@a.com", "certa").ok === true);
// reincidência: sem acerto no meio, cada novo erro depois de liberar trava por o DOBRO
const r = criarCredenciais({ dir: novaPasta(), safeStorage: safeFalso(), agora });
r.salvar("r@r.com", "certa", "u");
for (let i = 0; i < 5; i++) r.conferir("r@r.com", "x");
relogio += 61_000;
igual("T4 reincidência: o 6º erro trava por 2 minutos", r.conferir("r@r.com", "x").esperaMs, 120_000);
relogio += 121_000;
igual("T4 e o 7º por 4 minutos", r.conferir("r@r.com", "x").esperaMs, 240_000);
for (let k = 0; k < 8; k++) { relogio += 16 * 60_000; r.conferir("r@r.com", "x"); }
relogio += 16 * 60_000;
ok("T5 a trava tem teto de 15 minutos", r.conferir("r@r.com", "x").esperaMs === 15 * 60_000);

// o que fica no disco
const bruto = fs.readFileSync(path.join(dir, "credenciais.dat"), "utf8");
ok("D1 arquivo começa marcado como cifrado", bruto.startsWith("enc1:"));
ok("D2 a senha não aparece no arquivo", !bruto.includes("Senha-Forte") && !Buffer.from(bruto.slice(5), "base64").toString("utf8").includes("Senha-Forte"));
const claro = safeFalso().decryptString(Buffer.from(bruto.slice(5), "base64"));
ok("D3 nem decifrado o arquivo tem a senha (só a impressão)", !claro.includes("Senha-Forte") && claro.includes('"hash"') && claro.includes('"salt"'));
ok("D4 duas gravações da mesma senha dão impressões diferentes (sal)", (() => {
  const d1 = novaPasta(), d2 = novaPasta();
  const a = criarCredenciais({ dir: d1, safeStorage: safeFalso(), agora }), b = criarCredenciais({ dir: d2, safeStorage: safeFalso(), agora });
  a.salvar("a@a.com", "igual", "u"); b.salvar("a@a.com", "igual", "u");
  const ler = (d: string) => JSON.parse(safeFalso().decryptString(Buffer.from(fs.readFileSync(path.join(d, "credenciais.dat"), "utf8").slice(5), "base64"))).contas["a@a.com"].hash;
  return ler(d1) !== ler(d2);
})());

// reiniciar o programa: nova instância, mesma pasta
const c2 = criarCredenciais({ dir, safeStorage: safeFalso(), agora });
ok("R1 depois de reiniciar a senha continua valendo", c2.conferir(EMAIL, SENHA).ok === true);

// sem criptografia do Windows: guarda só a impressão e avisa que não está cifrado
const dirSem = novaPasta();
const sem = criarCredenciais({ dir: dirSem, safeStorage: safeFalso(false), agora });
sem.salvar("b@b.com", "outra-senha", "u2");
const brutoSem = fs.readFileSync(path.join(dirSem, "credenciais.dat"), "utf8");
ok("S1 sem safeStorage grava em formato simples, sem a senha", brutoSem.startsWith("txt1:") && !brutoSem.includes("outra-senha"));
ok("S2 e confere do mesmo jeito", sem.conferir("b@b.com", "outra-senha").ok === true);
const semNada = criarCredenciais({ dir: novaPasta(), safeStorage: null, agora });
semNada.salvar("c@c.com", "x1", "u3"); ok("S3 sem safeStorage nenhum também funciona", semNada.conferir("c@c.com", "x1").ok === true);
const trocouMaquina = criarCredenciais({ dir, safeStorage: safeFalso(false), agora });
ok("S4 arquivo cifrado mas Windows sem criptografia: não quebra, volta a 'sem credencial'", trocouMaquina.conferir(EMAIL, SENHA).motivo === "sem-credencial");

// arquivo corrompido e cópia de segurança
const dirC = novaPasta();
const cc = criarCredenciais({ dir: dirC, safeStorage: safeFalso(), agora });
cc.salvar("d@d.com", "s1", "u4"); cc.salvar("d@d.com", "s2", "u4"); // 2ª gravação cria o .bak com a 1ª
fs.writeFileSync(path.join(dirC, "credenciais.dat"), "enc1:lixo-que-nao-e-base64-valido!!");
ok("B1 arquivo corrompido: usa a cópia .bak, não quebra", ["s1", "s2"].some(s => cc.conferir("d@d.com", s).ok));
fs.writeFileSync(path.join(dirC, "credenciais.dat"), "isso nao e nada");
fs.writeFileSync(path.join(dirC, "credenciais.dat.bak"), "tambem nao");
ok("B2 tudo corrompido: volta a 'sem credencial' sem erro", cc.conferir("d@d.com", "s2").motivo === "sem-credencial");

// trocar a senha (novo login online com a senha nova)
const cs = criarCredenciais({ dir: novaPasta(), safeStorage: safeFalso(), agora });
cs.salvar("e@e.com", "antiga", "u5"); cs.salvar("e@e.com", "nova", "u5");
ok("P1 depois de entrar online com a senha nova, a antiga deixa de valer", cs.conferir("e@e.com", "antiga").ok === false && cs.conferir("e@e.com", "nova").ok === true);
cs.esquecer("e@e.com"); ok("P2 esquecer apaga a conta", cs.existe("e@e.com") === false);

console.log(falhas === 0 ? `\nTODOS OK (${n} verificações)` : `\nFALHAS: ${falhas} de ${n}`);
process.exit(falhas ? 1 : 0);
