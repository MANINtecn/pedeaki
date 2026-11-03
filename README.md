# Pede Aqui

Plataforma de delivery para lojas: cardápio e pedidos pelo celular do cliente, painel enxuto no celular do lojista
(modelo por comissão), PDV completo para o balcão (Básico e Avançado) e central de gestão (Super Admin).

- Site: https://pedeaki.tecx.pro (React, Vite, Tailwind; Supabase; hospedagem Vercel; imagens no Cloudflare R2)
- Programa instalável do PDV: Electron (ver `main.js`, `npm run electron:build`)
- Banco: `banco/saas` tem os SQL do SaaS na ordem em que foram rodados (o Supabase é rodado à mão, no editor SQL);
  `banco/legado` guarda as migrações antigas.
- Aviso de pedido novo com a tela bloqueada: `api/push-pedido.js` (Vercel), `public/push-sw.js` e `banco/saas/sql_14_web_push.sql`.

## Rodar localmente

```
npm install
cp .env.example .env.local   # preencher VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY
npm run dev
```

## Variáveis (Vercel)

`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_IMAGENS_UPLOAD_URL`, `VITE_IMAGENS_CDN_URL`,
`VITE_VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `PUSH_SEGREDO`.

Textos legais: `src/legal` (preencher `empresa.ts` com CNPJ, e-mail e cidade).
