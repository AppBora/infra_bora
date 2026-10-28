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


## `deploy-frontend.sh` — publica o painel e CONFERE

```
./deploy-frontend.sh --ensaio    # diz o que faria e o que esta diferente hoje. Nao envia nada.
./deploy-frontend.sh             # envia e confere
```

Existe porque o frontend subia na mao. Em **28/10/2026** achei **quatro arquivos de JavaScript com
dois dias de atraso em producao** (`app.js`, `cardapio.js`, `integracoes.js`, `promocoes.js`, todos
sem o commit `a83c104` de 26/10). O commit mexeu em 4 JS e 2 HTML; **os HTML subiram e os JS nao**.
Um `scp` parcial nao reclama: o deploy "deu certo" e ficou dois dias mentindo. Ficaram fora do ar o
cliente deixar de travar no checkout, o cupom certo, e a confirmacao antes de salvar credencial da
plataforma — que no 99Food faz o servidor esquecer os tokens de todas as lojas do canal.

Tres decisoes dele que tem motivo:

- **A lista vem de `git ls-files`, nao da pasta.** A pasta tem backups locais (`*.bak-*`) que o git
  ignora e que o Caddy **serviria** — o codigo antigo do painel baixavel por URL.
- **Respeita a marca `ESTE ARQUIVO NAO VAI PARA O SERVIDOR` pelo CONTEUDO do arquivo.** Hoje so o
  `index.html` do painel a tem: os dois repositorios publicam na mesma pasta e quem copia por
  ultimo vence — em 27/10 venceu o do painel e a raiz do site virou a tela de login. Por conteudo e
  nao por nome, para valer para o proximo arquivo sem ninguem lembrar de editar o script.
- **O backup do estado anterior vai para `/home/ubuntu/backups`, FORA da pasta servida.** Guardar
  copia dentro dela ja aconteceu aqui, e o Caddy serviu o backup.

**Ele falha se o servidor nao ficar igual**, conferindo os 88 arquivos — nao so os que mudaram,
porque foi exatamente "conferir so o que eu acho que mandei" que deixou passar o defeito de 26/10.

**Como foi testado antes de encostar em producao:** o destino sai por `BORA_FRONT_REMOTO`, entao
rodei o caminho inteiro contra `/tmp/ensaio-frontend` — 88 arquivos enviados e conferidos; depois
estraguei um arquivo e apaguei outro la, e ele apontou **exatamente os dois**. O ramo de ERRO do
passo 6 (sair com codigo 1) nao foi exercitado: o que eu exercitei foi a comparacao identica que
ele usa, no passo 3.
