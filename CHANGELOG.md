# Changelog

## 1.0.0 - 2026-02-03
- Ambiente Docker completo para WordPress + Oxygen Builder, com Redis e Opcache.
- Instalação automatizada de plugins e importação de `db.sql` no primeiro boot.
- Healthchecks e validação end-to-end via `scripts/verify.sh`.
- Montagens em tempo real de `uploads/` e do tema `themes/moinho-novo`.
- Exposição via Ngrok com scripts para alternar URLs sem quebrar assets.
- MU-plugins para login, HTTPS atrás de proxy e URLs dinâmicas.
