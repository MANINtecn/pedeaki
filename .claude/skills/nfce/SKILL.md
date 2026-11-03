---
name: nfce
description: Emissao de NFC-e no PDV Acai do Dudu (SEFAZ-TO). Use ao implementar, depurar ou configurar nota fiscal, certificado digital, CSC, NCM, CFOP ou SINTEGRA. Traz os dados reais do cliente ja levantados e as regras que nao podem ser esquecidas.
---

# NFC-e — Acai do Dudu (SEFAZ-TO)

## Estado: NAO IMPLEMENTADO
Arquitetura desenhada e registrada no `claude-acai.md`. Nada em codigo ainda.

## Por que e obrigatorio
NFC-e e exigida no Tocantins desde **jul/2019**, inclusive para Simples Nacional
abaixo de R$ 1 milhao. Sorveteria entra na regra (alimento para consumo imediato).

Hoje quem emite e o **Multipedidos**, automaticamente a cada venda. Se migrarem
sem emissao, **ficam irregulares no dia da virada**.

## Dados REAIS do cliente (extraidos do export do Multipedidos)

| Campo | Valor |
|---|---|
| CNPJ | 44.344.954/0001-97 |
| CFOP | 5101 (venda dentro do estado) |
| ICMS / CSOSN | 102 (Simples Nacional) |
| PIS / COFINS | 07 (isenta) |
| Carga tributaria aprox. | 4% |
| Taxa de entrega | **entra na nota** |
| Contador | cs.cont@yahoo.com.br |

## 🔐 A regra de seguranca mais importante

**O token da API fiscal NAO pode ficar no front (Electron).**
O .exe esta na maquina do cliente; qualquer um extrai a string do bundle e passa
a emitir nota em nome da empresa.

Solucao: **Edge Function no Supabase** guarda o token.
```
App (Electron) -> Edge Function (token aqui) -> API fiscal -> SEFAZ-TO
```

## Nunca montar/assinar XML por conta propria
Assinatura, contingencia e mudanca de layout da SEFAZ sao um projeto inteiro e
mudam sozinhos. Usar API de terceiro: Focus NFe, TecnoSpeed ou Webmania.

## Regras que NAO podem ser esquecidas

1. **Venda por peso usa unidade KG com 3 casas.** O acai e o carro-chefe —
   errar isso erra a nota inteira.
2. **Cancelamento so ate 30 min** apos a autorizacao, com justificativa de 15+
   caracteres.
3. **Contingencia offline:** se a SEFAZ cair, a venda NAO PODE PARAR.
4. **Guarda de 5 anos** dos XMLs — por isso ficam no banco, nunca em disco local.
5. **Numeracao sem buraco** — numero pulado exige inutilizacao na SEFAZ.
6. **Serie por maquina** (decisao do Icaro): salao serie 1, cozinha serie 2.
   Dois PCs emitindo com a mesma serie = rejeicao por numero duplicado.
   Encaixa no `estacaoService.ts`, junto da impressora.
7. **Gravar a nota como 'pendente' ANTES de chamar a API.** Se a luz cair entre
   a chamada e a resposta, a nota fica registrada em vez de sumir.

## Estruturas planejadas
- `fiscal_config` — 1 linha por loja (CNPJ, IE, CFOP, CSOSN, ambiente, CSC)
- `menu_items` — colunas `ncm`, `cest`, `unidade`, `origem`
- `notas_fiscais` — chave, protocolo, status, XML, serie, numero

## Pendencias externas (nao sao codigo)
- [ ] Certificado A1 — ✅ esta com o contador, pedir o .pfx + senha
- [ ] **CSC da SEFAZ-TO** — pode estar preso ao Multipedidos; se estiver, gerar
      novo no portal
- [ ] **NCM de 33 dos 73 produtos** — contador define
- [ ] Contratar a API fiscal

## SINTEGRA
O contador usa para conferencia (cruza com o XML). ⚠️ O arquivo que ele mandou
era de **outro cliente** (loja de moveis, NF-e modelo 55, sem registro 60).
Para venda ao consumidor o correto e o **registro 60** (60M/60A/60D/60R).
Pedir um exemplo de cliente que emita NFC-e antes de montar.

## Ordem de virada
1. Testar em **homologacao** ate sair nota limpa
2. Descobrir o ultimo numero emitido pelo Multipedidos
3. Virar **fora do horario de pico**
4. Manter o Multipedidos acessivel alguns dias para consulta
