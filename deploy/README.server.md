# Server Deploy

Full guide:

- [服务器部署指南](/Users/weize/Desktop/work/toolStore/docs/服务器部署指南.md)

Recommended local workflow:

1. Copy `deploy/.env.server.example` to `deploy/.env.server` and fill in real values.
2. Copy `deploy/.deploy.env.example` to `deploy/.deploy.env` and fill in server access values.
3. Run from the project root:

```bash
chmod +x deploy/deploy_server.sh
./deploy/deploy_server.sh
```

If you also want to upload a fresh local `deploy/.env.server`, run:

```bash
./deploy/deploy_server.sh --sync-env
```

Notes:

- `deploy/.deploy.env` is intended for local use and should not be committed.
- `SERVER_PASSWORD` is left blank by default; fill it locally if you still use password login, or switch to SSH keys.

The script will:

- package the project locally
- upload the release archive
- preserve the existing remote `.env.server` by default
- rebuild and restart Docker Compose on the server
- run a final `/health` check

Manual server-side commands remain:

```bash
cd /srv/toolStore/deploy
docker compose --env-file .env.server -f docker-compose.server.yml up -d --build
docker compose --env-file .env.server -f docker-compose.server.yml ps
```

API default entry:

- `http://<server-ip>/docs`
- `http://<server-ip>/health`

Useful commands:

```bash
docker compose --env-file .env.server -f docker-compose.server.yml logs -f app
docker compose --env-file .env.server -f docker-compose.server.yml restart app
docker compose --env-file .env.server -f docker-compose.server.yml down
```
