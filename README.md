# WordPress + Oxygen Builder (Docker)

Este setup prepara um WordPress pronto para instalar no primeiro acesso.
O WordPress e baixado durante o build da imagem, e o Oxygen pode ser instalado
no mesmo passo se voce fornecer o link direto do ZIP.

## Como usar
1) Copie `.env.example` para `.env` e ajuste as variaveis.
2) Defina `OXYGEN_LICENSE_KEY` no `.env` para ativacao automatica.
3) Coloque o ZIP do Oxygen em `./oxygen-4.9.5.zip` (ja montado no container).
4) Coloque o ZIP do Contact Form 7 em `./contact-form-7.6.1.4.zip` (ja montado no container).
5) O dump do banco deve ficar em `./db.sql` para importacao automatica quando o banco estiver vazio.
   - Opcional: use `OXYGEN_ZIP_URL` se preferir baixar via URL direta.
3) Suba os containers:
   - `docker compose up -d --build`
4) Abra `http://localhost:8080` (ou a porta configurada) e finalize a instalacao do WordPress.

## Observacoes
- Se o volume `wp-data` ja existir, o conteudo nao sera recopiado. Para forcar, remova o volume.
- O Oxygen e um plugin comercial; o link de download normalmente exige login.
- A ativacao automatica usa `OXYGEN_LICENSE_KEY` via MU plugin (arquivo em `mu-plugins/`).
- O entrypoint tenta instalar o Oxygen no runtime se existir `OXYGEN_ZIP_PATH` (arquivo local) ou `OXYGEN_ZIP_URL` (URL direta).
- O Contact Form 7 e instalado automaticamente se existir `CONTACT_FORM_7_ZIP_PATH` (arquivo local) ou `CONTACT_FORM_7_ZIP_URL` (URL direta).
- Se o banco estiver vazio, o entrypoint importa automaticamente `db.sql` e faz flush de permalinks.
- Se ainda nao houver templates do Oxygen, o site usa o tema `moinho-novo` automaticamente (fallback via MU plugin). Assim que houver templates/ct_builder_json, o Oxygen assume o render.

## Healthchecks e testes
- O `docker-compose.yml` inclui healthcheck do WordPress (wp-login).
- Para validar todo o setup automaticamente:
  - `./scripts/verify.sh`
- CI (GitHub Actions): workflow em `.github/workflows/ci.yml` executa `scripts/verify.sh`.
  - Opcional: configure o secret `OXYGEN_LICENSE_KEY` no repo para validar a licenca no CI.
- A pasta `uploads/` do repo e montada em `/var/www/html/wp-content/uploads` para refletir em tempo real os uploads feitos no WordPress.
- O tema `themes/moinho-novo` do repo e montado em `/var/www/html/wp-content/themes/moinho-novo` para desenvolvimento em tempo real.
