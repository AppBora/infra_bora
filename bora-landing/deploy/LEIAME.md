# Configuração de produção

O que está aqui é **cópia** do que roda no servidor (AWS Lightsail, `/home/ubuntu/bora/`).
Até 04/10/2026 esses arquivos existiam **só lá**: se a instância se perdesse, a configuração ia junto,
e ninguém conseguia revisar uma mudança sem entrar por ssh.

## Caddyfile

Serve o site e o painel, e encaminha a API. Três decisões que não são óbvias e têm motivo:

- **`lb_try_duration 40s`** — durante o deploy a API fica uns 20s fora do ar entre parar e subir o
  container. Sem isto o cliente levava 502 na cara. Com isto o Caddy segura a chamada até a API
  responder. Deploy deixou de ser queda visível (provado: 60 chamadas durante um restart, todas 200).
- **`encode zstd gzip`** — compacta a saída. O cardápio e os .js são texto e encolhem bem.
- **`header Cache-Control "no-cache"`** nos arquivos do painel — o painel é atualizado por scp, e sem
  isto o navegador do lojista ficava com a tela antiga depois do deploy (já aconteceu). `no-cache` não
  desliga o cache: obriga a revalidar, e a resposta vira um 304 curtinho.

## O que NÃO está aqui

O `api.env`, com as chaves do Asaas, do iFood, da 99 e o segredo do JWT. Segredo não entra em
repositório. Ele vive só no servidor, com permissão 600.
