# O que roda no servidor

Cópia fiel do que está em `/home/ubuntu` na instância Lightsail, tirada em 14/10/2026.

## Por que isto está aqui

Estes arquivos existiam **só no servidor**. Se a instância morresse, a recuperação dependia de alguém
lembrar o que eles faziam. Os três `docs/DEPLOY*.md` do `bora-projeto-completo` descrevem uma
arquitetura que **nunca existiu em produção** (Container Service e bucket) — quem seguir aqueles
documentos erra; o que vale é o `../LEIAME.md` e estes arquivos.

| Arquivo | Onde vive | O que faz |
|---|---|---|
| `backup-bora.sh` | `/home/ubuntu/backup-bora.sh` | `pg_dump -Fc` do banco gerenciado, 14 dias de retenção em `~/backups`. Roda pelo cron às 06:15 UTC e é chamado pelo `../deploy-api.sh` antes de cada troca de versão. |
| `vigia-bora.sh` | `/home/ubuntu/vigia-bora.sh` | A cada 5 min, confere o health e reinicia a API depois de 2 falhas seguidas. **Não avisa ninguém** — só escreve em `vigia.log`. |
| `crontab.txt` | `crontab -l` do usuário `ubuntu` | As duas entradas acima. |

Nenhum deles tem segredo dentro: a senha do banco é lida do `api.env` por `--env-file`
(`PGPASSWORD="$SPRING_DATASOURCE_PASSWORD"`), nunca escrita no script. Conferido antes de versionar.

## O que continua fora do repositório, e precisa ficar

**`/home/ubuntu/bora/api.env`** — 23 variáveis, entre elas o segredo do JWT, a chave do Asaas da
plataforma e o token do webhook. É a peça sem a qual nada volta, e é a única que **não pode** ser
versionada. Ela precisa estar num gerenciador de senhas (Bitwarden ou equivalente). Hoje existe apenas
no servidor e nos snapshots da instância.

## O comando do Caddy

O container `caddy` nunca foi recriado (está de pé há mais de 3 meses) e o `docker run` dele não
estava escrito em lugar nenhum. Reconstruído a partir do `docker inspect`:

```bash
docker run -d --name caddy --restart unless-stopped --network bora \
  -p 80:80 -p 443:443 -p 443:443/udp \
  -v /home/ubuntu/bora/Caddyfile:/etc/caddy/Caddyfile \
  -v /home/ubuntu/bora/frontend:/srv \
  -v caddy_data:/data \
  caddy:2
```

O `Caddyfile` versionado é o `../Caddyfile`. Para aplicar mudança nele **sem derrubar o site**:

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Antes de aplicar, validar: `docker run --rm -v <arquivo>:/etc/caddy/Caddyfile caddy:2 caddy validate --config /etc/caddy/Caddyfile`.

## Pegadinhas que custaram deploy

- A rede chama **`bora`**, não `bora_rede`.
- O container da API chama **`api`**, não `bora-api`. Um deploy inteiro foi perdido por isso: o
  container novo passava no health e não recebia tráfego.
- O Caddy serve **`/home/ubuntu/bora/frontend`** (montado em `/srv`), não `bora/landing`.
- A API **não** tem prefixo `/api` próprio: o Caddy encaminha `/api/*`, `/auth/*`, `/public/*`,
  `/webhooks/*`, `/admin-bora/*` e `/actuator/*` para `api:8080`. Então
  `borahapp.com.br/api/public/loja/1/marca` dá 401; o certo é `borahapp.com.br/public/loja/1/marca`.
- `docker restart` **não** relê o `api.env`. Trocar variável exige `docker rm` e `docker run`.
