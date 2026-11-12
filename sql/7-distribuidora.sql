-- =====================================================================
-- PASSO 7 — Distribuidora: os pedidos usam as mesmas tabelas do Full,
-- separados pela coluna "canal" ('ml' = Full Mercado Livre, 'dist' = Distribuidora).
-- Todas as regras (transferência do Base, etapas, histórico) valem para os dois.
-- =====================================================================

alter table public.full_envios add column if not exists canal text not null default 'ml';
alter table public.full_envios drop constraint if exists full_envios_canal_check;
alter table public.full_envios add constraint full_envios_canal_check check (canal in ('ml','dist'));
create index if not exists full_envios_canal on public.full_envios (canal, criado_em desc);

-- Quem importa: no Full ML só quem tem pode_importar (DANILO);
-- na Distribuidora também todos os gestores
drop policy if exists full_envios_criar on public.full_envios;
create policy full_envios_criar on public.full_envios for insert to authenticated
  with check (public.sou_importador() or (canal = 'dist' and public.sou_gestor()));

drop policy if exists full_itens_criar on public.full_itens;
create policy full_itens_criar on public.full_itens for insert to authenticated
  with check (public.sou_importador() or (public.sou_gestor() and exists (
    select 1 from public.full_envios e where e.id = envio_id and e.canal = 'dist')));

select canal, count(*) from public.full_envios group by canal;
