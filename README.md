# WordPress + Oxygen Builder (Docker)

Este setup prepara um WordPress pronto para instalar no primeiro acesso.
O WordPress e baixado durante o build da imagem, e o Oxygen pode ser instalado
no mesmo passo se voce fornecer o link direto do ZIP.

## Como usar
1) Copie `.env.example` para `.env` e ajuste as variaveis.
2) Defina `OXYGEN_LICENSE_KEY` no `.env` para ativacao automatica.
3) Coloque o ZIP do Oxygen em `./oxygen-4.9.5.zip` (ja montado no container).
4) Coloque o ZIP do Contact Form 7 em `./contact-form-7.6.1.4.zip` (ja montado no container).
5) Coloque o ZIP do All-in-One WP Migration Unlimited em `./all-in-one-wp-migration-unlimited-main.zip`.
6) Coloque o ZIP do WP-Optimize em `./wp-optimize.4.4.1.zip`.
7) Coloque o ZIP do Defender Security em `./defender-security.5.9.0.zip`.
8) O dump do banco deve ficar em `./db.sql` para importacao automatica quando o banco estiver vazio.
   - Opcional: use `OXYGEN_ZIP_URL` se preferir baixar via URL direta.
3) Suba os containers:
   - `docker compose up -d --build`
4) Abra `http://localhost:8080` (ou a porta configurada) e finalize a instalacao do WordPress.
5) (Opcional) Exponha o ambiente local via Ngrok:
   - Defina `NGROK_AUTHTOKEN` no `.env`.
   - Rode `./scripts/ngrok.sh` para criar o tunnel e atualizar `home`/`siteurl`.
   - A URL publica aparece no terminal.
6) Para voltar ao ambiente local depois do Ngrok:
   - `./scripts/set-site-url.sh http://localhost:8080`

## Credenciais de login
- Usuario: `admin`
- Senha: `admin`

## Observacoes
- Se o volume `wp-data` ja existir, o conteudo nao sera recopiado. Para forcar, remova o volume.
- O Oxygen e um plugin comercial; o link de download normalmente exige login.
- A ativacao automatica usa `OXYGEN_LICENSE_KEY` via MU plugin (arquivo em `mu-plugins/`).
- O entrypoint tenta instalar o Oxygen no runtime se existir `OXYGEN_ZIP_PATH` (arquivo local) ou `OXYGEN_ZIP_URL` (URL direta).
- O Contact Form 7 e instalado automaticamente se existir `CONTACT_FORM_7_ZIP_PATH` (arquivo local) ou `CONTACT_FORM_7_ZIP_URL` (URL direta).
- O All-in-One WP Migration Unlimited e instalado automaticamente se existir `AIOWPM_ZIP_PATH` (arquivo local) ou `AIOWPM_ZIP_URL` (URL direta), mas a ativacao e manual.
- O WP-Optimize e instalado automaticamente se existir `WP_OPTIMIZE_ZIP_PATH` (arquivo local) ou `WP_OPTIMIZE_ZIP_URL` (URL direta).
- O Defender Security e instalado automaticamente se existir `DEFENDER_ZIP_PATH` (arquivo local) ou `DEFENDER_ZIP_URL` (URL direta).
- Redis (container dedicado) e Opcache estao habilitados por padrao para melhorar performance.
- O plugin Redis Cache e baixado automaticamente no primeiro boot (ou voce pode fornecer `REDIS_CACHE_ZIP_URL`).
- Se o banco estiver vazio, o entrypoint importa automaticamente `db.sql` e faz flush de permalinks.
- Se ainda nao houver templates do Oxygen, o site usa o tema `moinho-novo` automaticamente (fallback via MU plugin). Assim que houver templates/ct_builder_json, o Oxygen assume o render.
- O script `scripts/ngrok.sh` atualiza `home`/`siteurl` e ajusta o cache do WP-Optimize para o dominio do Ngrok.
- O script `scripts/set-site-url.sh` alterna a URL do site e ajusta Oxygen/WP-Optimize sem quebrar os assets.
- O MU plugin `moinho-novo-proxy-ssl.php` evita loop de HTTPS quando acessado via proxy (ngrok).
- O MU plugin `moinho-novo-dynamic-urls.php` garante que localhost e ngrok funcionem ao mesmo tempo (URLs dinamicas).

## Healthchecks e testes
- O `docker-compose.yml` inclui healthcheck do WordPress (wp-login).
- Para validar todo o setup automaticamente:
  - `./scripts/verify.sh`
- CI (GitHub Actions): workflow em `.github/workflows/ci.yml` executa `scripts/verify.sh`.
  - Opcional: configure o secret `OXYGEN_LICENSE_KEY` no repo para validar a licenca no CI.
- A pasta `uploads/` do repo e montada em `/var/www/html/wp-content/uploads` para refletir em tempo real os uploads feitos no WordPress.
- O tema `themes/moinho-novo` do repo e montado em `/var/www/html/wp-content/themes/moinho-novo` para desenvolvimento em tempo real.
