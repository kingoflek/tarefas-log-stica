# Tarefas da Logística: Supabase + GitHub Pages

## Arquivos
- `index.html`: o site. É o único arquivo que precisa ir para o GitHub.
- `sql/1-criar-tabelas.sql`: cria as tabelas e as regras de acesso no Supabase.
- `sql/2-cadastrar-perfis.sql`: liga cada usuário ao nome e ao papel dele.

## Parte A: Supabase

1. **Criar o projeto.** Em supabase.com, clique em **New project**. Dê um nome (ex.: `tarefas-logistica`) e crie uma senha do banco (guarde-a). Escolha a região **South America (São Paulo)** e clique em **Create**. Espere 1 a 2 minutos.
2. **Criar as tabelas.** Vá em **SQL Editor → New query**. Cole o conteúdo de `sql/1-criar-tabelas.sql` e clique em **Run**. O resultado deve ser "Success. No rows returned".
3. **Bloquear cadastro aberto.** Em **Authentication → Sign In / Providers**, desligue **Allow new users to sign up** e salve. Assim só você cria usuários.
4. **Criar os 7 usuários.** Em **Authentication → Users → Add user → Create new user**, faça um cadastro por pessoa, marcando **Auto Confirm User**:

   | Nome | E-mail |
   |---|---|
   | RENAN | renan@logistica.local |
   | CARLOS HENRIQUE | carlos.henrique@logistica.local |
   | DANILO | danilo@logistica.local |
   | VINICIUS | vinicius@logistica.local |
   | GUILHERME | guilherme@logistica.local |
   | RODRIGO | rodrigo@logistica.local |
   | ALISON | alison@logistica.local |

   - A senha precisa ter pelo menos 6 caracteres. Depois, cada um troca a sua no botão "Alterar senha".
   - Os e-mails não precisam existir, porque nenhum e-mail é enviado.
   - Se o Supabase recusar o domínio `.local`, use outro (ex.: `@logistica.com`) e troque os e-mails também no arquivo do passo 5.
5. **Ligar os usuários aos nomes.** Vá em **SQL Editor → New query**, cole `sql/2-cadastrar-perfis.sql` e clique em **Run**. Devem aparecer 7 linhas.
6. **Pegar a URL e a chave.** Em **Project Settings → API Keys**, copie a chave **anon public**. Ela fica na aba **Legacy API Keys**; se não houver essa aba, use a **Publishable key**. A **Project URL** (ex.: `https://abcd.supabase.co`) aparece em **Project Settings → Data API**.
   ⚠ Nunca use a chave **service_role** nem a **secret**.
7. **Colar no site.** Abra o `index.html` no Bloco de Notas e procure `COLE_AQUI`. Substitua os dois valores, mantendo as aspas, e salve.

## Parte B: GitHub Pages

8. **Criar o repositório.** Em github.com, clique em **New repository**. Use o nome `tarefas-logistica`, deixe como **Public** (o plano gratuito exige isso para o Pages) e clique em **Create repository**.
9. **Enviar o site.** Clique em **uploading an existing file**, arraste o `index.html` e clique em **Commit changes**.
10. **Ligar o Pages.** Vá em **Settings → Pages**. Em **Source**, escolha **Deploy from a branch**, depois **Branch: main** e **/(root)**, e clique em **Save**.
11. Espere de 1 a 3 minutos e abra `https://SEU-USUARIO.github.io/tarefas-logistica/`.

## Parte C: Testar
- Entre como DANILO e crie uma tarefa para ALISON.
- Em outra aba anônima, entre como ALISON e conclua a tarefa. Na aba do DANILO, ela deve aparecer sozinha em poucos segundos.
- Volte ao DANILO e aprove a tarefa em **Conferência**.

## Dia a dia
- **Esqueceu a senha:** em Supabase, vá em **Authentication → Users**, clique no usuário e use **Reset password** ou **Update user** para definir uma senha nova.
- **Nova pessoa na equipe:** crie o usuário (passo 4), acrescente uma linha no `2-cadastrar-perfis.sql` e rode de novo.
- **Atualizar o site:** envie o novo `index.html` no GitHub (Add file → Upload files).
- **Projeto pausado:** no plano gratuito, o Supabase pausa o projeto depois de 7 dias sem uso. Para reativar, clique em **Restore** no painel.
- A chave pública aparece no código do site. Isso é normal: quem protege os dados são as regras criadas no passo 2.
