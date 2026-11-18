-- =====================================================================
-- PASSO 8 — Tarefas recorrentes: inventário de corredores em rodízio semanal
-- A (VINICIUS) → B (ALISON) → C (RODRIGO) → D (GUILHERME) → volta ao A.
-- Toda semana vira uma tarefa normal (prazo na sexta) para quem está na vez.
-- Pode rodar de novo sem problema.
-- =====================================================================

create table if not exists public.recorrencias (
  id          text primary key,
  titulo      text not null,          -- ex.: 'Inventário'
  descricao   text not null default '',
  acao        text not null default '',
  prioridade  text not null default 'media' check (prioridade in ('baixa','media','alta')),
  inicio      date not null,          -- segunda-feira da 1ª semana do rodízio
  ciclo       jsonb not null,         -- [{"rotulo":"Corredor A","responsavel":"VINICIUS"}, ...]
  ativo       boolean not null default true
);

alter table public.recorrencias enable row level security;
grant select on public.recorrencias to authenticated;
drop policy if exists recorrencias_ler on public.recorrencias;
create policy recorrencias_ler on public.recorrencias for select to authenticated
  using (public.meu_nome() is not null);

-- Cada tarefa gerada guarda a chave da recorrência + semana (evita duplicar)
alter table public.tarefas add column if not exists recorrencia text;
create unique index if not exists tarefas_recorrencia_unica on public.tarefas (recorrencia) where recorrencia is not null;

insert into public.recorrencias (id, titulo, descricao, acao, prioridade, inicio, ciclo)
values (
  'inventario-corredores',
  'Inventário',
  'Inventário semanal do corredor: contar todas as posições do corredor e conferir com o saldo do WMS (Base).',
  'Contar as peças de todas as posições do corredor, ajustar ou registrar as divergências no WMS e avisar o gestor do que não bateu.',
  'media',
  date '2026-11-23',
  '[{"rotulo":"Corredor A","responsavel":"VINICIUS"},
    {"rotulo":"Corredor B","responsavel":"ALISON"},
    {"rotulo":"Corredor C","responsavel":"RODRIGO"},
    {"rotulo":"Corredor D","responsavel":"GUILHERME"}]'::jsonb
)
on conflict (id) do update
  set titulo = excluded.titulo, descricao = excluded.descricao, acao = excluded.acao,
      prioridade = excluded.prioridade, inicio = excluded.inicio, ciclo = excluded.ciclo;

-- Cria a tarefa da semana atual de cada recorrência (e de semanas passadas que ficaram sem tarefa,
-- até 8 semanas para trás). Semanas futuras não são criadas antes da hora.
create or replace function public.gerar_recorrentes() returns integer
language plpgsql security definer set search_path = public as $$
declare
  r record;
  hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  seg_atual date := hoje - (extract(isodow from hoje)::int - 1);
  seg date;
  n int;
  idx int;
  item jsonb;
  criadas int := 0;
  k int;
begin
  if public.meu_nome() is null then return 0; end if;
  for r in select * from public.recorrencias where ativo loop
    n := jsonb_array_length(r.ciclo);
    if n = 0 then continue; end if;
    seg := greatest(r.inicio, seg_atual - 56);
    while seg <= seg_atual loop
      idx := (((seg - r.inicio) / 7) % n);
      item := r.ciclo -> idx;
      insert into public.tarefas (titulo, sku, descricao, acao, responsavel, prazo, prioridade, status,
                                  criado_por, criado_em, recorrencia)
      values (
        r.titulo || ' · ' || (item->>'rotulo') || ' (semana ' || to_char(seg, 'DD/MM') || ' a ' || to_char(seg + 4, 'DD/MM') || ')',
        '', r.descricao, r.acao, item->>'responsavel', seg + 4, r.prioridade, 'pendente',
        'Recorrente', (seg + time '07:00') at time zone 'America/Sao_Paulo',
        r.id || ':' || to_char(seg, 'YYYY-MM-DD')
      )
      on conflict do nothing;
      get diagnostics k = row_count;
      criadas := criadas + k;
      seg := seg + 7;
    end loop;
  end loop;
  return criadas;
end $$;

revoke all on function public.gerar_recorrentes() from public, anon;
grant execute on function public.gerar_recorrentes() to authenticated;

select id, titulo, inicio, ciclo from public.recorrencias;
