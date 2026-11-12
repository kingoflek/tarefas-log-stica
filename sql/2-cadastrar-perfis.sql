-- =====================================================================
-- PASSO 2 — Liga cada usuário criado em Authentication > Users ao nome
-- e ao papel dele. Rode DEPOIS de criar os 7 usuários.
-- Se você usou outros e-mails, troque-os abaixo antes de rodar.
-- =====================================================================

insert into public.perfis (id, nome, email, gestor, conferente, ordem)
select u.id, v.nome, v.email, v.gestor, v.conferente, v.ordem
from (values
  ('RENAN',           'renan@logistica.local',           true,  false, 1),
  ('CARLOS HENRIQUE', 'carlos.henrique@logistica.local', true,  true,  2),
  ('DANILO',          'danilo@logistica.localca',        true,  true,  3),
  ('VINICIUS',        'vinicius@logistica.local',        false, false, 4),
  ('GUILHERME',       'guilherme@logistica.local',       false, false, 5),
  ('RODRIGO',         'rodrigo@logistica.local',         false, false, 6),
  ('ALISON',          'alison@logistica.local',          false, false, 7),
  ('VICTOR',          'victor@logistica.local',          true,  false, 8),
  ('MAILSON',         'mailson@logistica.local',         false, false, 9),
  ('RAFAEL BARBOSA',  'rafaelbarbosa@logistica.local',   false, false, 10),
  ('JOÃO VICTOR',     'joaovictor@logistica.local',      false, false, 11),
  ('FELIPE',          'felipe@logistica.local',          false, false, 12)
) as v(nome, email, gestor, conferente, ordem)
join auth.users u on lower(u.email) = lower(v.email)
on conflict (id) do update
  set nome = excluded.nome, email = excluded.email,
      gestor = excluded.gestor, conferente = excluded.conferente, ordem = excluded.ordem;

-- Conferência: devem aparecer 7 linhas. Se faltar alguém, o e-mail
-- dessa pessoa não bate com o que foi criado em Authentication > Users.
select nome, email, gestor, conferente from public.perfis order by ordem;
