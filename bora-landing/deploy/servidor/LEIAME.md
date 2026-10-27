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

Este é o comando do container que está no ar **desde 27/10/2026**, quando ele foi recriado para ganhar
limite de log. Confirmado contra `docker inspect` depois da troca:

```bash
docker run -d --name caddy --restart unless-stopped --network bora \
  -p 80:80 -p 443:443 \
  --log-opt max-size=20m --log-opt max-file=5 \
  -v /home/ubuntu/bora/Caddyfile:/etc/caddy/Caddyfile \
  -v /home/ubuntu/bora/frontend:/srv \
  -v caddy_data:/data \
  caddy@sha256:af5fdcd76f2db5e4e974ee92f96ee8c0fc3edb55bd4ba5032547cbf3f65e486d
```

### Três coisas deste comando que não são escolha de estilo

**Sem `-p 443:443/udp`.** A versão anterior deste arquivo tinha essa linha, e **o container no ar
nunca teve** — conferido no `docker inspect` antes de recriar (as `PortBindings` eram só `80/tcp` e
`443/tcp`). Publicar a UDP ligaria HTTP/3 de fora, que é uma mudança de comportamento. Quem recria só
para trocar log não deve ligar protocolo novo de carona. O Caddy escuta HTTP/3 **dentro** do
container de qualquer jeito (aparece no log dele); sem a porta publicada, ninguém de fora alcança.

**Pelo digest da imagem, não pela tag `caddy:2`.** A tag aponta para o que estiver mais novo no
registry no dia. Recriar para mexer no log não é hora de descobrir que o Caddy mudou de versão: o
digest acima é o v2.11.4 que já estava rodando.

**`-v caddy_data:/data` é o que guarda os certificados TLS.** Esquecer essa montagem faz o Caddy
pedir certificado novo ao Let's Encrypt, que tem limite de emissões — e num dia ruim o site fica sem
HTTPS. Depois de recriar, **confira que o certificado é o MESMO**:

```bash
echo | openssl s_client -connect borahapp.com.br:443 -servername borahapp.com.br 2>/dev/null \
  | openssl x509 -noout -dates
```

Em 27/10 as datas continuaram `notBefore=Sep 3 2026 / notAfter=Dec 2 2026` — o certificado foi
reusado, nada foi pedido.

### A sonda de saúde: `--resolve`, nunca `-H "Host:"`

Isto derrubou a primeira tentativa de recriar, em 27/10/2026, e custou dois rollbacks.

Para conferir o Caddy **de dentro do servidor**, `-H "Host: borahapp.com.br"` **não serve em HTTPS**:
ele muda o cabeçalho HTTP e não o nome do handshake TLS (SNI). A URL é `https://localhost/`, o Caddy
não tem certificado para `localhost`, o handshake falha e o `curl` devolve **000 mesmo com o site
perfeito**. Foi exatamente o que aconteceu: o container novo estava sadio e servindo, a sonda disse
que não, e o script fez rollback de um deploy que tinha dado certo.

A sonda que funciona manda o SNI certo:

```bash
curl -sk -o /dev/null -w '%{http_code}' --resolve borahapp.com.br:443:127.0.0.1 \
  https://borahapp.com.br/
```

**A regra que ficou: provar a sonda contra o container que está de pé ANTES de parar qualquer coisa.**
O script de troca passou a fazer isso no passo 1 e a abortar sem mexer em nada se a sonda não
devolver 200 antes.

### O log antigo, de 303 MB

O container velho ficou guardado como **`caddy-anterior`** (parado, `Exited (0)`), e os 303 MB de log
estão com ele — o dono optou por não jogar o histórico fora. Ele **não sobe sozinho** num reinício da
máquina: `restart: unless-stopped` só religa o que não foi parado de propósito, e este foi.

Para liberar os 303 MB, `docker rm caddy-anterior` — **isso apaga o log junto**, e com ele vai a
possibilidade de rollback para o container de julho.

## A colisão do `index.html` (medida em 27/10/2026)

Os dois repositórios publicam na **mesma pasta** `/home/ubuntu/bora/frontend`, e os dois têm um
arquivo chamado `index.html`:

- `bora-fase-2-frontend/index.html` → `<script>location.href="dashboard.html"</script>`
- `bora-landing/index.html` → a página comercial ("Sistema de delivery com a sua marca, sem taxa por
  pedido")

**Quem copiou por último, vence.** Hoje está o do painel: quem digita `borahapp.com.br` cai direto na
tela de login, sem passar pela página de vendas. O conteúdo da landing continua no ar e intacto —
`/landing.html`, `/precos.html`, `/funcionalidades.html` e `/contato.html` respondem 200, e o
`landing.html` servido é byte a byte o do repositório.

Qual das duas deve estar na raiz é decisão do dono, não do script. O que **não** pode continuar é
cada deploy decidir isso por acidente, pela ordem em que alguém copiou a pasta.

**Enquanto não houver decisão: publique arquivo por arquivo, nunca a pasta inteira.** Foi o que foi
feito no deploy da v150 (dois arquivos por `scp`, com md5 conferido por HTTPS depois).

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
