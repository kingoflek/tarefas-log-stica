-- =====================================================================
-- PASSO 5 — Quem pode importar (PDF do Full e posições do WMS)
-- Hoje: só o DANILO. Para liberar outra pessoa, troque a lista no UPDATE.
-- =====================================================================

alter table public.perfis add column if not exists pode_importar boolean not null default false;
update public.perfis set pode_importar = (nome in ('DANILO'));

create or replace function public.sou_importador() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select pode_importar from public.perfis where id = auth.uid()), false)
$$;
grant execute on function public.sou_importador() to authenticated;

-- Envios do Full: só quem pode importar cria; gestores continuam alterando e excluindo
drop policy if exists full_envios_gestor  on public.full_envios;
drop policy if exists full_envios_criar   on public.full_envios;
drop policy if exists full_envios_alterar on public.full_envios;
drop policy if exists full_envios_excluir on public.full_envios;
create policy full_envios_criar on public.full_envios for insert to authenticated
  with check (public.sou_importador());
create policy full_envios_alterar on public.full_envios for update to authenticated
  using (public.sou_gestor()) with check (public.sou_gestor());
create policy full_envios_excluir on public.full_envios for delete to authenticated
  using (public.sou_gestor() or public.sou_importador());

drop policy if exists full_itens_criar on public.full_itens;
create policy full_itens_criar on public.full_itens for insert to authenticated
  with check (public.sou_importador());

-- Posições do WMS: só quem pode importar
create or replace function public.substituir_posicoes_wms(dados jsonb)
returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.sou_importador() then
    raise exception 'Sem permissão para importar posições' using errcode = '42501';
  end if;
  delete from public.wms_posicoes where true;
  insert into public.wms_posicoes (sku, posicao, quantidade, importado_por)
  select upper(btrim(d.sku)), btrim(d.posicao), d.quantidade, public.meu_nome()
    from jsonb_to_recordset(dados) as d(sku text, posicao text, quantidade numeric)
   where coalesce(btrim(d.sku), '') <> '' and coalesce(btrim(d.posicao), '') <> '';
  get diagnostics n = row_count;
  return n;
end $$;

select nome, gestor, pode_importar from public.perfis order by ordem;
