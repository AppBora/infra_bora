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


## Backup: o que está medido (18/11/2026) e o que falta

### O que eu medi, e o que o QA disse errado

O QA relatou "a cópia do PC falhou em 16/11". **Não falhou.** O `copias.log` tem **duas** falhas em
toda a sua vida — 07/11 e 08/11, as duas `scp código 255`, que é a assinatura do IP morto depois de a
conta AWS cair. O que houve em 16/11 é outra coisa: **nenhuma linha de log**, porque o PC estava
desligado às 10:00. E isso **se recuperou sozinho**: `StartWhenAvailable` é `True`, e a corrida
atrasada rodou às **08:28 de 17/11**, trazendo 8 arquivos. Mesmo padrão em 25/10, 30/10, 06/11 e
09/11. A minha primeira hipótese ("a tarefa não roda quando o PC está desligado") também estava
errada — medi antes de consertar o que não estava quebrado.

Estado real da corrente de cópia, medido:

| | |
|---|---|
| dumps em `C:\bora-backups` | **188**, 691 MB, média 3,7 MB (crescendo: 3,2 → 4,5 MB em 45 dias) |
| mais novo | de hoje, ~5 h de idade |
| cobertura por dia de calendário | **04/10 → 18/11 sem furo**, exceto **07/11** — o dia em que o servidor estava desligado e não produziu dump nenhum |
| verificação da transferência | byte a byte contra o `stat -c %s` do servidor, em toda cópia |
| tarefa agendada | `BoraHapp - copia do backup`, diária 10:00, último resultado **0** |

### O que estava faltando de verdade: ninguém nunca restaurou esta cópia

O que existia antes de hoje:

- `conferir-dump.sh` — prova que o arquivo está **inteiro** … **no servidor**
- `ensaio-de-restauracao.sh` — restaura e conta linhas, todo domingo … **no servidor**
- `copiar-backup-bora.ps1` — confere que o tamanho bate com o do servidor … **aqui**

Tamanho batendo prova que a transferência chegou completa, e isso é forte. **Não é a mesma coisa que
provar que o arquivo restaura.** E era justamente esta cópia — a **única fora da AWS** — a que
ninguém ensaiava. Rodei à mão em 18/11 e ela restaurou: **8 lojas, 13 usuários, 268 produtos, 43
pedidos, schema V74**, em 8 segundos. Mas "eu rodei uma vez" não diz nada sobre o dump da semana que
vem.

**Agora o ensaio roda sozinho**, pendurado na tarefa de cópia — que *provadamente* roda, ao
contrário de uma tarefa nova, que só vale depois de o dono registrar (e já existe uma pendente de
registro desde 08/11, o `vigia-site.ps1`). Uma vez por semana; o resultado fica em
`C:\bora-backups\ULTIMO-ENSAIO.txt` e no `copias.log`.

Três coisas que medi nesse mecanismo, cada uma por teste:

- **falha é alta e não some**: com um dump inválido, o log sai com `!!! O ENSAIO DE RESTAURACAO
  FALHOU` e o erro real do `pg_restore` — e a marca **não** é atualizada, então o aviso volta em toda
  cópia até alguém resolver;
- **falha no ensaio não derruba a cópia**: o script continua saindo com 0, porque a cópia é o
  crítico e o ensaio é a conferência;
- **Docker desligado é pulado**, sem mexer na marca, para tentar no dia seguinte.

O ensaio detecta: arquivo que não é dump (código 1), dump **truncado em 60%** (1), pasta vazia (1), e
o dump bom como controle (0). Sem o controle, "sempre devolve 1" passaria pelos três primeiros.

### O que FALTA, e é decisão do dono: a terceira perna

Hoje há **duas** cópias, e elas são independentes — o que é bom. Mas:

- a da AWS está numa conta que **já foi encerrada uma vez** por falta de pagamento (06/11), e o
  e-mail deles avisa que passados **90 dias** a conta não reabre e o que sobrou é apagado;
- a do PC está num **disco só**, o `C:` (446 GB, 158 livres), sem redundância.

**O armazenamento não é o problema: 691 MB hoje, 1,31 GB por ano guardando um dump por dia.** Isso
cabe inteiro na camada gratuita de Cloudflare R2 (10 GB) e de Backblaze B2 (10 GB). O custo mensal da
terceira perna é, na prática, **zero**.

O que falta não é dinheiro, são três decisões que são do dono:

1. **onde** — recomendo **R2 ou B2**, não um segundo bucket na AWS: o ponto é sair do alcance de um
   problema de cobrança da Amazon, e um bucket na mesma empresa não sai;
2. **a chave** — o dump tem telefone, endereço e CPF de todo cliente de todas as lojas. No servidor
   ele nasce `600` por isso, e é por isso que o destino aqui é `C:\bora-backups` e **nunca o
   OneDrive** (item 9.10). Para a nuvem, ele tem de ser **cifrado antes de sair da máquina**, com
   senha que só o dono tenha — e aí a senha passa a ser o novo ponto único de falha: **backup cifrado
   com chave perdida não é backup**. Ela precisa estar no gerenciador de senhas dele, não num arquivo
   ao lado do backup;
3. **a conta** — eu não crio conta nem digito credencial.

**Eu não escrevi o script de envio ainda, de propósito.** Script que fala com um destino que não
existe não pode ser testado, e código não testado no caminho do backup é pior que a falta dele —
parece pronto. Quando ele escolher o destino, o envio cifrado é curto e eu testo de ponta a ponta,
incluindo **decifrar e restaurar** a cópia que subiu, que é a única prova que vale.


## `teste-do-rollback.sh` — prova que o rollback do `deploy-api.sh` não derruba o site

```
bash deploy/teste-do-rollback.sh    # precisa do Docker local. Nao toca no servidor.
```

Rode **depois de qualquer mexida no `rollback()`** do `deploy-api.sh`.

Existe porque em **18/11/2026** o QA achou que o `rollback()` **apagava o container sadio**. Ele
começava sempre com `docker rm -f api`, partindo de que o `api` do servidor é a versão nova e ruim e
que a boa está guardada em `api-anterior`. Isso vale em **um** dos quatro pontos em que o passo 8
pode falhar. Nos outros três o `api` que está lá **é o bom**:

| o que falhou no passo 8 | estado | rollback antigo |
|---|---|---|
| `docker tag bora-api:$TAG` | `api` **rodando e sadio**, sem `api-anterior` | destruía o sadio → **site no chão** |
| `docker stop -t 30 api` | `api` existe, sem `api-anterior` | destruía → **site no chão** |
| `docker rename api api-anterior` | `api` existe **parado**, imagem boa | destruía → **site no chão** |
| `docker run -d --name api` | sem `api`, `api-anterior` é o bom | **único caso que ele tratava** |

E não havia volta: o `vigia-bora.sh`, quando não existe `api`, tenta o `api-anterior` e, não achando,
escreve `ISTO PRECISA DE MAO HUMANA` e desiste. Uma falha num passo inofensivo — um nome de tag
errado — derrubava a produção até alguém entrar no servidor e rodar `docker run` à mão.

Agora a decisão é **por fato**: existe `api-anterior`? Se existe, o rename aconteceu e o `api` de
agora é o novo — apaga e devolve. Se não existe, o rename não aconteceu e o `api` de agora **é o
bom** — não se apaga, só religa.

O teste **extrai a lógica de dentro do `deploy-api.sh`** (entre os marcadores `INICIO/FIM DA LOGICA
DO ROLLBACK`), não uma cópia que envelhece, e roda os 5 estados contra containers de mentira no
Docker local. Não dá para ensaiar um deploy de verdade sem derrubar o site; dá para provar a decisão.

**Medido em 18/11/2026:** lógica nova → 5 de 5 verdes. Lógica antiga → **reprova em A, B e C**,
passa em D e E. Se os marcadores desaparecerem, o teste **recusa rodar** em vez de ficar verde
medindo nada.


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
