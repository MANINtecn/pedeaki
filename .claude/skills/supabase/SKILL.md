---
name: supabase
description: Mexer no banco do PDV Acai do Dudu - criar coluna, tabela, policy de RLS ou rodar migracao. Use ao adicionar campo em settings, criar tabela nova ou quando um INSERT falhar por RLS.
---

# Banco (Supabase)

## Arquitetura: um projeto por cliente
O Icaro **replica o codigo-fonte** a cada cliente novo, com banco, repo e link
separados — cada um no tier gratuito.

**Nao propor multi-tenancy** nem RLS restritiva por `store_id` argumentando que
"uma loja veria dados da outra". Os bancos sao fisicamente separados.

## 🔴 RLS: o `TO public` e obrigatorio

Policy sem `TO public` **nao alcanca o papel anon** que o app usa. Todo INSERT
volta com:
```
new row violates row-level security policy
```

Ja aconteceu com a tabela `impressoes` — a trava existia e nao funcionava.

**O padrao do projeto** (ver `fix_orders_rls.sql`):
```sql
ALTER TABLE minha_tabela ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public All MinhaTabela" ON public.minha_tabela
FOR ALL
TO public
USING (true)
WITH CHECK (true);
```

## Adicionar campo em `settings`

Precisa mexer em **4 lugares**, senao o campo aparece na tela e nao salva:

1. **`src/types.ts`** — declarar em `interface Settings`
2. **`supabaseService.ts` — `defaultSettings`** — valor padrao
3. **`supabaseService.ts` — leitura** — `campo: dbData?.snake_case ?? dbData?.camelCase ?? default`
4. **`supabaseService.ts` — `printerFields`/whitelist** — senao o UPDATE ignora
5. **SQL** — `ALTER TABLE settings ADD COLUMN IF NOT EXISTS ...`

A conversao camelCase -> snake_case e automatica no save.

## Os .sql sao gitignored
`.gitignore` linha 62 tem `*.sql`. Os arquivos ficam **so no disco** — ao criar
migracao, avisar o Icaro para rodar, porque nao vai junto no commit.

## Migracoes ja aplicadas
`add_auto_print_dine_in.sql` · `add_codigo_produto.sql` ·
`add_tabela_impressoes.sql` (+ policy) · `add_pix_whatsapp.sql` ·
`add_sirene_config.sql` · `add_dicas_atalho.sql` (todas rodadas ate 15/09/2026)

## Conferir se uma coluna existe
```bash
node -e "
require('dotenv').config({path:'.env.local'});
const {createClient}=require('@supabase/supabase-js');
const db=createClient(process.env.VITE_SUPABASE_URL,process.env.VITE_SUPABASE_ANON_KEY);
(async()=>{const {error}=await db.from('settings').select('minha_coluna').limit(1);
console.log(error?'NAO existe':'existe');})();"
```

## Credenciais
`.env.local` tem `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` (funcionam).
O `.env` tem `SUPABASE_SERVICE_ROLE_KEY`, mas ela estava **invalida** — usar a anon.

## 🔴 `table_number` chega como STRING

```
{"mesa":"1","tipo":"string","nome":"Mesa 1 · TECX SISTEMAS"}
```

`"1" === 1` e **false**. Comparar com `===` direto contra number fazia o atalho
da aba Pedidos dizer "mesa nao tem comanda aberta" com a comanda na tela.

Use sempre `mesmaMesa()` de `src/utils/mesaUtils.ts`. E o nome vem grudado no
numero — `nomeSemPrefixoDeMesa()` separa.

## Antes de dizer "pronto": leia o dado real

`tsc` verde nao prova nada sobre o FORMATO do dado — a declaracao de tipo pode
estar mentindo (era o caso: `table_number?: number`).

```bash
node -e "
require('dotenv').config({path:'.env.local'});
const {createClient}=require('@supabase/supabase-js');
const db=createClient(process.env.VITE_SUPABASE_URL,process.env.VITE_SUPABASE_ANON_KEY);
(async()=>{const {data}=await db.from('orders').select('*').limit(1);
console.log(Object.keys(data[0]).join(' | '));})();"
```

⚠️ A tabela `orders` **nao tem** `created_at` — a coluna de data e `timestamp`.
