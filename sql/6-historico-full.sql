-- =====================================================================
-- PASSO 6 — Histórico do Full: quem fez cada etapa e envios concluídos
-- Pode rodar de novo sem problema.
-- =====================================================================

-- Etapas de cada item (preenchidas automaticamente pelo banco)
alter table public.full_itens add column if not exists separado_por  text;
alter table public.full_itens add column if not exists separado_em   timestamptz;
alter table public.full_itens add column if not exists concluido_por text;
alter table public.full_itens add column if not exists concluido_em  timestamptz;

-- Envio concluído quando todos os itens estão concluídos
alter table public.full_envios add column if not exists concluido_em timestamptz;

create or replace function public.full_item_etapas() returns trigger
language plpgsql set search_path = public as $$
declare quem text := coalesce(new.status_por, public.meu_nome());
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if old.status = 'separando' and new.status in ('producao','concluido') then
      new.separado_por := quem; new.separado_em := now();
    end if;
    if new.status = 'concluido' then
      new.concluido_por := quem; new.concluido_em := now();
    elsif old.status = 'concluido' then
      new.concluido_por := null; new.concluido_em := null;
    end if;
    if new.status = 'separando' then
      new.separado_por := null; new.separado_em := null;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists full_itens_etapas on public.full_itens;
create trigger full_itens_etapas before update on public.full_itens
  for each row execute function public.full_item_etapas();

-- Marca/desmarca o envio como concluído (roda com permissão do dono para qualquer usuário)
create or replace function public.full_envio_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare env uuid := coalesce(new.envio_id, old.envio_id);
begin
  update public.full_envios e
     set concluido_em = case
           when exists (select 1 from public.full_itens i where i.envio_id = env and i.status <> 'concluido') then null
           when exists (select 1 from public.full_itens i where i.envio_id = env) then coalesce(e.concluido_em, now())
           else null end
   where e.id = env;
  return null;
end $$;

drop trigger if exists full_itens_envio_status on public.full_itens;
create trigger full_itens_envio_status after insert or update of status or delete on public.full_itens
  for each row execute function public.full_envio_status();

-- itens já concluídos antes desta regra
update public.full_itens set concluido_por = coalesce(concluido_por, status_por), concluido_em = coalesce(concluido_em, status_em)
 where status = 'concluido' and concluido_em is null;
update public.full_envios e set concluido_em = now()
 where concluido_em is null
   and exists (select 1 from public.full_itens i where i.envio_id = e.id)
   and not exists (select 1 from public.full_itens i where i.envio_id = e.id and i.status <> 'concluido');

select nome, criado_em, concluido_em from public.full_envios order by criado_em desc;
