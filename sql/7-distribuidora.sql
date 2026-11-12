-- =====================================================================
-- PASSO 7 — Distribuidora: os pedidos usam as mesmas tabelas do Full,
-- separados pela coluna "canal" ('ml' = Full Mercado Livre, 'dist' = Distribuidora).
-- Todas as regras (transferência do Base, etapas, histórico) valem para os dois.
-- =====================================================================

alter table public.full_envios add column if not exists canal text not null default 'ml';
alter table public.full_envios drop constraint if exists full_envios_canal_check;
alter table public.full_envios add constraint full_envios_canal_check check (canal in ('ml','dist'));
create index if not exists full_envios_canal on public.full_envios (canal, criado_em desc);

select canal, count(*) from public.full_envios group by canal;
