-- RESET PARA TESTE 100% (05/10/2026)
-- Apaga: vendas, caixas, pontos de fidelidade, notas fiscais, fila de impressao.
-- Mantem: cardapio, categorias, adicionais, configuracoes, dados fiscais, usuarios, clientes.
-- Tudo e copiado antes para o schema backup_reset_20261005.

-- ===== PASSO 1: PREVIA (so le) =====
select 'orders' t, count(*) from orders union all
select 'cash_sessions', count(*) from cash_sessions union all
select 'cash_transactions', count(*) from cash_transactions union all
select 'table_payments', count(*) from table_payments union all
select 'loyalty_points_ledger', count(*) from loyalty_points_ledger union all
select 'customer_loyalty_points', count(*) from customer_loyalty_points union all
select 'notas_fiscais', count(*) from notas_fiscais union all
select 'impressoes', count(*) from impressoes;

-- ===== PASSO 2: BACKUP + APAGAR (tudo ou nada) =====
begin;

create schema if not exists backup_reset_20261005;
create table backup_reset_20261005.orders                  as select * from orders;
create table backup_reset_20261005.cash_sessions           as select * from cash_sessions;
create table backup_reset_20261005.cash_transactions       as select * from cash_transactions;
create table backup_reset_20261005.table_payments          as select * from table_payments;
create table backup_reset_20261005.loyalty_points_ledger   as select * from loyalty_points_ledger;
create table backup_reset_20261005.customer_loyalty_points as select * from customer_loyalty_points;
create table backup_reset_20261005.notas_fiscais           as select * from notas_fiscais;
create table backup_reset_20261005.impressoes              as select * from impressoes;

delete from impressoes;
delete from notas_fiscais;
delete from table_payments;
delete from loyalty_points_ledger;
delete from customer_loyalty_points;
delete from cash_transactions;
delete from cash_sessions;
delete from orders;

-- pedidos voltam a numerar do 1
update settings set order_numbering_reset_at = now();

commit;

-- ===== PASSO 3 (OPCIONAL): apagar tambem os clientes de teste =====
-- create table backup_reset_20261005.customers as select * from customers;
-- delete from customers;

-- ===== RESTAURAR (so se precisar desfazer) =====
-- insert into orders                  select * from backup_reset_20261005.orders;
-- insert into cash_sessions           select * from backup_reset_20261005.cash_sessions;
-- insert into cash_transactions       select * from backup_reset_20261005.cash_transactions;
-- insert into table_payments          select * from backup_reset_20261005.table_payments;
-- insert into loyalty_points_ledger   select * from backup_reset_20261005.loyalty_points_ledger;
-- insert into customer_loyalty_points select * from backup_reset_20261005.customer_loyalty_points;
-- insert into notas_fiscais           select * from backup_reset_20261005.notas_fiscais;
-- insert into impressoes              select * from backup_reset_20261005.impressoes;
