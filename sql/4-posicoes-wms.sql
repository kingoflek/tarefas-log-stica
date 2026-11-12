-- =====================================================================
-- PASSO 4 — Posições do WMS (só para consulta na aba Full ML)
-- Cole tudo no Supabase > SQL Editor > New query e clique em RUN.
-- Pode rodar de novo sem problema (não apaga dados).
-- =====================================================================

create table if not exists public.wms_posicoes (
  id            bigint generated always as identity primary key,
  sku           text not null,
  posicao       text not null,
  quantidade    numeric,
  importado_por text,
  importado_em  timestamptz not null default now()
);
create index if not exists wms_posicoes_sku on public.wms_posicoes (sku);

alter table public.wms_posicoes enable row level security;
grant select on public.wms_posicoes to authenticated;

drop policy if exists wms_ler on public.wms_posicoes;
create policy wms_ler on public.wms_posicoes for select to authenticated
  using (public.meu_nome() is not null);
-- Ninguém grava direto: a importação passa pela função abaixo (só gestores).

-- Troca todas as posições de uma vez (tudo ou nada)
create or replace function public.substituir_posicoes_wms(dados jsonb)
returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.sou_gestor() then
    raise exception 'Só gestores podem importar posições' using errcode = '42501';
  end if;
  delete from public.wms_posicoes where true;
  insert into public.wms_posicoes (sku, posicao, quantidade, importado_por)
  select upper(btrim(d.sku)), btrim(d.posicao), d.quantidade, public.meu_nome()
    from jsonb_to_recordset(dados) as d(sku text, posicao text, quantidade numeric)
   where coalesce(btrim(d.sku), '') <> '' and coalesce(btrim(d.posicao), '') <> '';
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.substituir_posicoes_wms(jsonb) from public, anon;
grant execute on function public.substituir_posicoes_wms(jsonb) to authenticated;
