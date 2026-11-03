---
name: build
description: Compilar o .exe do PDV Acai do Dudu. Use quando o usuario pedir para gerar executavel, build, nova versao ou instalador. Cobre a checagem de disco (que ja derrubou builds) e a verificacao de que o instalador saiu integro.
---

# Gerar o .exe do PDV

## 1. ANTES de compilar: checar o disco

O C: do Icaro vive perto de 100%. Ja derrubou build duas vezes.

```bash
df -h /c | tail -1
```

**Menos de 4 GB livres?** Liberar antes, nesta ordem:
```bash
cd .
rm -rf dist-electron/win-unpacked                    # recriada a cada build
rm -f "dist-electron/Açaí do Dudu PDV Setup <versao-antiga>.exe"*
```
Se ainda faltar, limpar `%TEMP%` e `%LOCALAPPDATA%\electron\Cache`.

> Limpar o `%TEMP%` apaga o arquivo de saida do proprio comando em execucao —
> o retorno vem vazio. Rodar um segundo comando para confirmar.

Cada build consome **~2 GB temporarios** alem dos 103 MB do resultado.

## 2. Subir a versao e compilar

Sempre incrementar — o auto-update so dispara com versao maior.

```bash
cd .
sed -i 's/"version": "1.0.44"/"version": "1.0.45"/' package.json
npm run electron:build
```

O build demora mais de 2 min: rodar com `run_in_background: true`.

A formula encadeia 3 etapas:
1. `build:bot` -> empacota `servidor.ts` em `servidor.cjs`
2. `vite build --base=./` -> **o `--base=./` e obrigatorio**, sem ele o Electron abre em branco
3. `electron-builder --win nsis`

## 3. DEPOIS: conferir o tamanho

**Exit code 0 NAO garante sucesso.**

```bash
ls -lh dist-electron/*<versao>*.exe | grep -v uninstaller
```

| Tamanho | Significa |
|---|---|
| **~103 MB** | build OK |
| **200-400 KB** | **FALHOU** — quase sempre disco cheio |

Confirmar tambem que o codigo novo entrou, procurando uma **string literal**
(nome de variavel some na minificacao):

```bash
grep -l "Comanda da mesa atualizada" dist/assets/*.js
```

## 4. Publicar (se pedido)

O `latest.yml` procura `acai-do-dudu-setup-<versao>.exe`, mas o builder gera
`Açaí do Dudu PDV Setup <versao>.exe`. **Renomear antes de subir no Release**,
junto com o `.blockmap`. Tag no formato `v1.0.45`.

## Pendencias conhecidas
- O projeto esta dentro do **OneDrive**: cada .exe de 103 MB sobe para a nuvem.
  Vale excluir `dist-electron` da sincronizacao.
- Investigar os ~170 GB fora do perfil de usuario (WinDirStat).

## 5. Limpar: manter SO a atual e a anterior

Regra do Icaro. Depois de confirmar que o build saiu integro (~103 MB):

```bash
cd dist-electron
for v in <versoes-antigas>; do rm -f *"$v"*.exe *"$v"*.blockmap; done
```

**Mantem a anterior como rede:** se a nova der problema, da para reinstalar a
que funcionava sem recompilar.

Faz parte da rotina de build — nao precisa perguntar.

⚠️ O `rm -fv` imprime o nome do arquivo com a acentuacao quebrada
(`Aça\255 do Dudu...`) por causa do locale do Git Bash. **Nao e erro** — os
arquivos saem certo. Conferir com `ls` depois.

## 🔴 Legacy NUNCA no Electron

`vite.config.ts` liga o `@vitejs/plugin-legacy` so quando **nao** e modo
electron. O `electron:build` passa `--mode electron` (sintaxe nativa do vite —
`cross-env` NAO esta instalado e quebraria o build).

**Por que:** o .exe carrega por `file://` (`main.js:379`). Nesse protocolo a
flag `window.__vite_is_modern_browser` nem sempre e definida, e o script inline
do plugin injeta o bundle legacy POR CIMA do moderno. Resultado: **dois
AdminPage rodando em paralelo**, com dois pollings, dois realtime, dois caches
de estacao e dois listeners de teclado no mesmo `window`.

Foi a causa raiz de: sirene tocando com `escopoSom: "mudo"`, impressao em 2
vias, campo de nome travando "as vezes", F4 intermitente e checkout travado.

**Conferir apos todo build do Electron:**
```bash
ls -1 dist/assets/ | grep -c legacy      # tem que ser 0
ls -1 dist/assets/AdminPage*.js          # tem que ser 1 arquivo
grep -c nomodule dist/index.html         # tem que ser 0
```

O build do SITE (`npm run build`, Vercel) **mantem** o legacy — celular antigo
precisa dele para abrir o cardapio. Conferir que continua saindo:
```bash
npx vite build && ls -1 dist/assets/ | grep -c legacy   # ~22
```

## Bug que volta e e "as vezes"? Peca o log do console

Antes de reler codigo, peca o console do cliente (Ctrl+Shift+I) e olhe o **nome
do arquivo** em cada linha, nao so a mensagem. Linha repetida com origens
diferentes (`AdminPage-*.js` e `AdminPage-legacy-*.js`) = codigo duplicado em
execucao. Seis horas de leitura de codigo correto nao acharam o que o log
mostrou em 2 minutos.
