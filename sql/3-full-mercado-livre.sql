-- =====================================================================
-- PASSO 3 — Aba "Full ML": envios para o Full do Mercado Livre
-- Cole tudo no Supabase > SQL Editor > New query e clique em RUN.
-- Pode rodar de novo sem problema (não apaga dados).
-- =====================================================================

-- Cada PDF importado vira um envio
create table if not exists public.full_envios (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  arquivo     text default '',
  criado_por  text,
  criado_em   timestamptz not null default now()
);

-- Os SKUs de cada envio, separados em par ou lado
create table if not exists public.full_itens (
  id          uuid primary key default gen_random_uuid(),
  envio_id    uuid not null references public.full_envios(id) on delete cascade,
  sku         text not null,
  descricao   text default '',
  tipo        text not null check (tipo in ('par','lado')),
  quantidade  int  not null check (quantidade > 0),
  produzido   int  not null default 0 check (produzido >= 0),
  ordem       int  not null default 0
);
create index if not exists full_itens_envio on public.full_itens(envio_id);

alter table public.full_envios enable row level security;
alter table public.full_itens  enable row level security;
grant select, insert, update, delete on public.full_envios, public.full_itens to authenticated;

drop policy if exists full_envios_ler     on public.full_envios;
drop policy if exists full_envios_gestor  on public.full_envios;
drop policy if exists full_itens_ler      on public.full_itens;
drop policy if exists full_itens_criar    on public.full_itens;
drop policy if exists full_itens_alterar  on public.full_itens;
drop policy if exists full_itens_excluir  on public.full_itens;

-- Toda a equipe vê o que precisa produzir
create policy full_envios_ler on public.full_envios for select to authenticated
  using (public.meu_nome() is not null);
create policy full_itens_ler on public.full_itens for select to authenticated
  using (public.meu_nome() is not null);

-- Só gestores importam, alteram e excluem envios
create policy full_envios_gestor on public.full_envios for all to authenticated
  using (public.sou_gestor()) with check (public.sou_gestor());
create policy full_itens_criar on public.full_itens for insert to authenticated
  with check (public.sou_gestor());
create policy full_itens_excluir on public.full_itens for delete to authenticated
  using (public.sou_gestor());

-- Qualquer pessoa da equipe atualiza a quantidade produzida
create policy full_itens_alterar on public.full_itens for update to authenticated
  using (public.meu_nome() is not null) with check (public.meu_nome() is not null);

-- Trava extra: quem não é gestor só pode mudar a coluna "produzido"
create or replace function public.proteger_full_item() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.sou_gestor() then
    return new;
  end if;
  if (new.envio_id, new.sku, new.descricao, new.tipo, new.quantidade, new.ordem)
     is distinct from
     (old.envio_id, old.sku, old.descricao, old.tipo, old.quantidade, old.ordem) then
    raise exception 'Só gestores podem alterar os itens do envio' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists full_itens_proteger on public.full_itens;
create trigger full_itens_proteger before update on public.full_itens
  for each row execute function public.proteger_full_item();

-- Regra do tipo: SKU que começa com "PAR" é Par; qualquer outro é Só lado
create or replace function public.full_item_tipo() returns trigger
language plpgsql set search_path = public as $$
begin
  new.tipo := case when upper(btrim(new.sku)) like 'PAR%' then 'par' else 'lado' end;
  return new;
end $$;

drop trigger if exists full_itens_tipo on public.full_itens;
create trigger full_itens_tipo before insert or update on public.full_itens
  for each row execute function public.full_item_tipo();

-- Corrige os itens que já estavam salvos
update public.full_itens
   set tipo = case when upper(btrim(sku)) like 'PAR%' then 'par' else 'lado' end
 where tipo is distinct from case when upper(btrim(sku)) like 'PAR%' then 'par' else 'lado' end;

-- Status de cada item: Separando -> Em produção -> Concluído (toda a equipe pode mudar)
alter table public.full_itens add column if not exists status text not null default 'separando';
alter table public.full_itens add column if not exists status_por text;
alter table public.full_itens add column if not exists status_em timestamptz;
alter table public.full_itens drop constraint if exists full_itens_status_check;
alter table public.full_itens add constraint full_itens_status_check
  check (status in ('separando','producao','concluido'));

-- Tempo real
do $$
begin
  alter publication supabase_realtime add table public.full_envios;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.full_itens;
exception when duplicate_object then null;
end $$;
