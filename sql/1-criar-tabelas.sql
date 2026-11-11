-- =====================================================================
-- PASSO 1 — Tarefas da Logística: tabelas, regras de acesso e tempo real
-- Cole tudo no Supabase > SQL Editor > New query e clique em RUN.
-- Pode rodar de novo sem problema (não apaga dados).
-- =====================================================================

-- Quem é quem na equipe (ligado aos usuários do Supabase Auth)
create table if not exists public.perfis (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null unique,
  email      text not null,
  gestor     boolean not null default false,   -- pode criar, reabrir e excluir tarefas
  conferente boolean not null default false,   -- pode aprovar ou devolver na Conferência
  ordem      int not null default 0
);

-- As tarefas
create table if not exists public.tarefas (
  id              uuid primary key default gen_random_uuid(),
  titulo          text not null,
  sku             text default '',
  descricao       text not null default '',
  acao            text not null default '',
  responsavel     text not null,
  prazo           date,
  prioridade      text not null default 'media' check (prioridade in ('baixa','media','alta')),
  status          text not null default 'pendente' check (status in ('pendente','concluida')),
  criado_por      text,
  criado_em       timestamptz not null default now(),
  concluido_em    timestamptz,
  concluido_por   text,
  obs_conclusao   text default '',
  conferida       boolean not null default false,
  conferido_por   text,
  conferido_em    timestamptz,
  obs_conferencia text default '',
  devolucao       jsonb
);

-- Funções de apoio: quem está logado e qual o papel
create or replace function public.meu_nome() returns text
language sql stable security definer set search_path = public as $$
  select nome from public.perfis where id = auth.uid()
$$;

create or replace function public.sou_gestor() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select gestor from public.perfis where id = auth.uid()), false)
$$;

create or replace function public.sou_conferente() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select conferente from public.perfis where id = auth.uid()), false)
$$;

-- Liga a segurança por linha (RLS)
alter table public.perfis  enable row level security;
alter table public.tarefas enable row level security;

grant select on public.perfis to anon, authenticated;
grant select, insert, update, delete on public.tarefas to authenticated;
grant execute on function public.meu_nome(), public.sou_gestor(), public.sou_conferente() to anon, authenticated;

-- Perfis: a lista de nomes aparece na tela de entrada. Ninguém altera pelo site.
drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to anon, authenticated using (true);

-- Tarefas
drop policy if exists tarefas_ler     on public.tarefas;
drop policy if exists tarefas_criar   on public.tarefas;
drop policy if exists tarefas_alterar on public.tarefas;
drop policy if exists tarefas_excluir on public.tarefas;

-- Só quem está na tabela perfis vê as tarefas
create policy tarefas_ler on public.tarefas for select to authenticated
  using (public.meu_nome() is not null);

-- Só gestores criam
create policy tarefas_criar on public.tarefas for insert to authenticated
  with check (public.sou_gestor());

-- Gestor e conferente alteram qualquer uma; o executor só as dele
create policy tarefas_alterar on public.tarefas for update to authenticated
  using      (public.sou_gestor() or public.sou_conferente() or responsavel = public.meu_nome())
  with check (public.sou_gestor() or public.sou_conferente() or responsavel = public.meu_nome());

-- Só gestores excluem
create policy tarefas_excluir on public.tarefas for delete to authenticated
  using (public.sou_gestor());

-- Trava extra: quem não é gestor não muda o conteúdo da tarefa,
-- e quem não é conferente não aprova nem devolve.
create or replace function public.proteger_tarefa() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.sou_gestor() then
    return new;
  end if;
  if (new.titulo, new.sku, new.descricao, new.acao, new.responsavel, new.prazo,
      new.prioridade, new.criado_por, new.criado_em)
     is distinct from
     (old.titulo, old.sku, old.descricao, old.acao, old.responsavel, old.prazo,
      old.prioridade, old.criado_por, old.criado_em) then
    raise exception 'Sem permissão para editar os dados da tarefa' using errcode = '42501';
  end if;
  if not public.sou_conferente() then
    if new.devolucao is distinct from old.devolucao
       or new.conferida
       or new.conferido_por is not null then
      raise exception 'Somente a conferência pode aprovar ou devolver' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists tarefas_proteger on public.tarefas;
create trigger tarefas_proteger before update on public.tarefas
  for each row execute function public.proteger_tarefa();

-- Atualização em tempo real para todos que estão com o site aberto
do $$
begin
  alter publication supabase_realtime add table public.tarefas;
exception when duplicate_object then null;
end $$;
