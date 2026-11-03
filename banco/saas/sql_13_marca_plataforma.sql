-- SQL 13: marca da plataforma (logo e cores do Pede Aqui). Leitura publica, escrita so do administrador da plataforma.

create table if not exists public.plataforma_marca (
  id int primary key check (id = 1),
  nome text not null default 'Pede Aqui',
  logo_url text,
  cor_primaria text not null default '#ea580c' check (cor_primaria ~* '^#[0-9a-f]{6}$'),
  cor_secundaria text not null default '#f59e0b' check (cor_secundaria ~* '^#[0-9a-f]{6}$'),
  atualizado_em timestamptz default now()
);

insert into public.plataforma_marca (id) values (1) on conflict (id) do nothing;

alter table public.plataforma_marca enable row level security;

drop policy if exists marca_leitura_publica on public.plataforma_marca;
create policy marca_leitura_publica on public.plataforma_marca for select to anon, authenticated using (true);

drop policy if exists marca_escrita_admin on public.plataforma_marca;
create policy marca_escrita_admin on public.plataforma_marca for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

select * from public.plataforma_marca;
