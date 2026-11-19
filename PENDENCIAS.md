# As pendências — a lista viva

**Este arquivo é o único que você precisa abrir.** O nome dele nunca muda de data, então o atalho
que você guardar hoje continua valendo no mês que vem. Aqui estão **só as ações**, em ordem, com
onde clicar. A prova de cada uma — o que foi medido, quando e onde — está em
[PENDENCIAS-2026-10-30.md](PENDENCIAS-2026-10-30.md).

Última conferência contra a produção: **13/11/2026** — nesse dia subiram a **v160** (venda
duplicada, frete zerado em silêncio, loja que cai e fica verde) e a **v161** (o aviso de "sem
pedido" passou a contar o tempo), a limpeza de dados foi aplicada, e a ficha de abertura virou
[uma página que grava a cada tecla](https://borahapp.com.br/ficha.html). **13 itens fecharam.**
Antes disso, **11/11/2026** — nesse dia a **v158 subiu** e as credenciais do banco ficaram **40 cifradas / 0 em texto puro**. Antes disso, em 10/11 — e nesse dia rodou a **varredura dos 15 agentes na aplicação inteira** ([VARREDURA-2026-11-10.md](VARREDURA-2026-11-10.md)). Os itens de cadastro e operação seguem como foram medidos em **04/11**. Tudo marcado como pendente aqui foi medido, não deduzido.

## 🔴 18/11/2026 (noite) — **a varredura dos 15 agentes na aplicação inteira**

**O relatório inteiro está em [VARREDURA-2026-11-18.md](VARREDURA-2026-11-18.md).** Cada achado está
marcado como **confirmado por mim**, **medido pelo agente e não reconferido**, ou **errado/qualificado**.

**O que eu NÃO consigo dizer, e não vou escrever:** que a aplicação está sem nenhum bug. Isso não é
mediável. Três limites concretos: a **fatura da AWS não foi vista** (o teto de R$ 800 não está
certificado), o **custo da fila por venda não foi medido** (nenhuma venda desde as 19:08), e **nenhum
exploit foi executado**.

### Consertado hoje, durante a varredura

| o que | estado |
|---|---|
| **XSS armazenado no cardápio** que levava ao token do ADMINISTRADOR_BORA | **NO AR**, conferido byte a byte |
| **A leitura da chave do outbox derrubava a venda no commit** (meu erro, de 18/11) | **NO AR na v171**, 19/11 às 07:38 UTC |

### ✅ A v171 está NO AR (19/11/2026, 07:38 UTC)

Publicada da aba de terminal daqui, com você vendo a saída. Os nove passos passaram, e eu conferi
por fora depois — não pela palavra do script:

| o que eu medi | resultado |
|---|---|
| o jar que roda em produção | `sha256 464ab855…`, **idêntico** ao jar que eu construí do commit `9e664f2` |
| health | `UP`, **0 reinicios** |
| erro no log desde que subiu | **nenhum** (o único achado era a palavra `Error` dentro da flag `-XX:+ExitOnOutOfMemoryError`) |
| migração | **V76** aplicada, 0 falhas |
| backup antes da troca | `bora-20261119-0738.dump`, 4,5 MB, lido inteiro pelo `pg_restore` |

### ✅ A FILA DE EVENTOS está PROVADA com uma venda de verdade (19/11/2026)

Antes disso ela estava ligada e tinha entregado **zero** eventos — e isso não era defeito: eram **0
pedidos em 24h**. Ligada e nunca exercitada é "não testada", não "funcionando". Como os módulos vão
consumir esse cano, eu fiz um pedido de verdade na **loja 1** (a de teste) antes de qualquer módulo:

| o que eu medi | resultado |
|---|---|
| o log do container | `evento PedidoRecebido do pedido 144 (loja 1) em 23.7 ms. A chave 'outbox.habilitado' esta LIGADA` |
| a linha gravada na fila | `id=1, tipo=PedidoRecebido, schema=1.0.0, empresa_id=1, loja_id=1, agregado=pedido/144` |
| a empresa confere com o cadastro? | evento `empresa_id=1` = loja `empresa_id=1` = **Sorveteria da Rosa** — **conferem** |
| eventos sem empresa | **0** |

De propósito **não** usei PIX: criaria cobrança de verdade na conta Asaas do lojista. O pedido de
teste ficou na loja 1 (**CD-144**, R$ 25, retirada, dinheiro, com observação "não preparar") — se
quiser, eu cancelo.

### ⚠️ Uma coisa que eu te disse errado: a idempotência **existe**

Eu afirmei que o `POST /api/pedidos` grava venda duas vezes "hoje". Isso vinha de um estudo de
**30/10** e deixou de valer em **17/11**. Os **quatro** canais têm a trava: marketplace (V28),
painel e PDV (V71, com `crypto.randomUUID()` por venda), e o cardápio desde 17/11. Medido no ar
hoje: reenviei o mesmo pedido com a mesma chave e a API devolveu **`jaEstavaGravado: true` com o
mesmo pedido 144**; o banco ficou com **1** pedido e **1** evento.

A ressalva que continua valendo: a trava só vale para quem **manda o cabeçalho**. Cardápio antigo
em cache no celular de alguém segue sem ela.

### Os sete seguintes, na ordem que eu faria

1. **segunda ponta do XSS** — recusar URL de imagem inválida na gravação;
2. **promoção automática dá 500** no cupom do cardápio a partir do 2º dia (código duplicado, sem índice único);
3. **cliente do cardápio com PIX nunca recebe WhatsApp** — recurso pago de R$ 99/mês que não dispara;
4. **dois bloqueios no celular**: em Novo Pedido o botão "Adicionar" fica 100% fora da tela, e na Frente de
   Caixa a comanda está **3,9 telas abaixo da dobra**;
5. **um canal de aviso de verdade** — o log registra **49 horas** sem o vigia rodar, em 08/11, sem ninguém saber;
6. **testar o rollback com banco já migrado** — o maior risco **não medido** da infra, e o teste é barato;
7. **a limpeza de testes emitir cancelamento** — antes de existir consumidor da fila.

E uma decisão sua: **70 imagens Docker, 11,46 GB**, 62 tags de v110 a v170, crescendo **164 MB/dia** sem
ninguém podar. Minha sugestão é pôr a poda dentro do `deploy-api.sh` — aí resolve sozinho e você aprova
uma vez.


## ✅ 18/11/2026 (noite) — **v170 NO AR**: a fila já sabe de QUEM é a venda

Você mandou resolver o `empresa_id` antes de ligar a fila. Está resolvido e **publicado**, API e
frontend, medido em produção — não só commitado:

| conferência | medido |
|---|---|
| API | **v170**, commit `dd72710`, imagem `5fc4484e`, container **healthy**, `health/viva` **200** |
| migração | schema **75 → 76** em **0,048 s** (`Successfully applied 1 migration`) |
| rollback guardado | `bora-api:anterior` = v169 (`a54858ec`), e **nenhum** `api-anterior` sobrando |
| o índice da V76 **no schema** | `ix_outbox_sem_empresa ... WHERE (empresa_id IS NULL)` — lido de um dump novo restaurado, não só do que o Flyway disse |
| a garantia da V74 intacta | `not null = false` e **0 chaves estrangeiras**: a fila **continua sem poder recusar uma venda** |
| frontend | **100 arquivos** com o mesmo sha256; o `configuracoes.html` no ar é **idêntico byte a byte** ao local |
| erros no log | **0** |

Os `ERROR` que aparecem no log do deploy são dos **testes rodando dentro do build da imagem**
(passo 3/9), não de produção — vale lembrar, porque assustam na leitura.

### O que estava errado

A V74 criou a coluna `empresa_id` na fila e a entrega A2 gravava **`null` literal** nela. Só
`loja_id` ia preenchido: o evento dizia em qual unidade a venda aconteceu, mas **não de quem era a
unidade**. Ficou assim porque o `Pedido` não carrega a empresa, e coluna opcional vazia não reclama
de nada.

**O caso que mostra o preço: as lojas 18, 19, 20, 21 e 22 são a rede da Zirá e pertencem a UMA
empresa (a 3).** Sem a coluna, quem consome a fila veria **cinco clientes** em vez de cinco unidades
de um. Medido no dump: 8 lojas, 4 empresas, **0 lojas sem empresa**, 0 órfãs.

**E era agora ou nunca de graça:** com a fila em zero evento, o retrofit não tocou em nada. Se você
tivesse clicado primeiro, cada venda nasceria um evento sem empresa.

### Três decisões que têm motivo

- **a empresa vem da loja por subconsulta dentro do próprio `INSERT`**, não por consulta separada em
  Java — essa custaria uma ida e volta a mais no caminho de **toda venda**, o dobro do que a tela mede;
- **a fila continua sem poder recusar uma venda**: loja sem empresa, ou loja que não existe, grava o
  evento com nulo e a venda segue. Dois testes de integração medem isso, e o schema de produção
  confirma `not null = false` e 0 chaves estrangeiras;
- **o modo de falha dessa coluna é o silêncio**, então a tela da fila mostra quantos eventos estão sem
  empresa. Zero é a resposta saudável; se sair de zero, o conserto é no cadastro da loja.

Fechei também o terceiro caminho que cria loja: o bootstrap do primeiro start era o único que não
preenchia `empresa_id`. Em produção nunca rodou, mas numa instalação nova **todo** evento sairia sem
empresa, para sempre.

**Medido:** 1588 testes unitários e 245 de integração, 0 falhas. **Quatro mutantes, nenhum
sobreviveu** — voltar o `null` literal morreu em 4 unitários e 3 de integração. Três arquivos de
teste travavam a forma antiga do `INSERT` por posição de argumento e os três falharam quando a
mudança entrou, que é o que se quer deles.

### 🔴 Agora sim: só falta o seu clique

**Configurações → 🔧 Plataforma BoraHapp → 📬 Fila de eventos do ERP.** Confirmado às 21:21 que a
chave `outbox.habilitado` **ainda não existe** no banco (e sem a linha ela nasce desligada) e que
`evento_outbox` tem **0 eventos, 0 sem empresa**.


## ✅ 18/11/2026 — **v169 NO AR**, com os 4 itens que você mandou

A ordem foi a sua: preço zero → os 5 ganchos sem teste → rollback do deploy → backup fora da conta.
**Tudo publicado às 15:27**, API e frontend, medido em produção:

| conferência | medido |
|---|---|
| API | **v169**, commit `1d62dbd`, imagem `a54858ec`, container **healthy** |
| migração | schema **74 → 75** em **0,029 s** (`Successfully applied 1 migration`) |
| rollback guardado | `bora-api:anterior` = v168, e **nenhum** `api-anterior` sobrando |
| frontend | **100 arquivos**, mesmo sha256 aqui e no servidor; o navegador recebe `?v=20261118` |
| as 6 lojas reais | respondem, **182 produtos**, e os **5 zeros de propósito intactos** — o "Monte Seu Açaí" continua vendendo nas três lojas da Zirá |
| erros no log | **0** (o único casamento foi `ExitOnOutOfMemoryError`, falso positivo do grep) |

E o `deploy-frontend.sh` saiu com **código 0** — primeira vez num deploy real, depois do conserto
descrito no fim deste arquivo.

### 1. Produto sem preço não vende de graça — e o zero da Zirá continua vendendo

**Quase quebrei três lojas suas.** O QA disse "produto sem preço (ou negativo) vende de graça". Medi
o cardápio público antes de consertar: dos **182 produtos ativos** das 6 lojas reais, **nenhum** tem
preço nulo e **5 têm preço ZERO de propósito** — o **"Monte Seu Açaí"** nas lojas 18, 19 e 20, que
está a R$ 0,00 porque quem carrega o preço é o grupo "Recipientes" (mínimo 1, opções de R$ 12,90 a
R$ 50,00), mais "Brinde Grátis" e "Brinde Gratuito" na loja 1. Recusar `preço <= 0` teria parado
esses 5 produtos em 4 lojas. **Zero diz "é de graça"; nulo diz "ninguém disse".**

**O buraco de verdade era o carrinho MISTO.** O cardápio já recusava carrinho que dava total zero
("Pedido sem valor"), mas essa guarda olha o **total**, não o item. Medido: 2 açaís sem preço + 1
refrigerante de R$ 8,00 **gravavam o pedido com total R$ 8,00, sem erro nenhum**. Os dois açaís de
R$ 20 saíram de graça dentro de um pedido que fechou normal — e você não teria como notar.

**A porta que o QA não viu:** a importação de cardápio por foto fazia
`try { new BigDecimal(...) } catch { preço = ZERO }` e **salvava**, contando como sucesso. O prompt
pede ponto decimal, mas o que está impresso no cardápio é **vírgula** — e medi que "24,90",
"R$ 24,90" e preço ausente **todos** estouram, logo todos viravam R$ 0,00 publicados. Agora a
vírgula é lida, e o que não dá para ler volta pelo nome, para você digitar à mão.

Fechado em: cadastro, venda do painel, venda do cardápio, importação por IA, complementos, e uma
trava no banco (`V75`) para as portas que não passam por nenhum deles — como a **cópia de cardápio**,
que é o caminho de abrir unidade nova.

### 2. Os 5 ganchos de evento que nenhum teste media

É o que **travava ligar a fila**. Medi comentando cada gravação de evento, uma por vez:

| gancho | antes | agora |
|---|---|---|
| venda do balcão | **mutante vivo** | 3 falhas |
| pedido de iFood/99 | **mutante vivo** | 2 falhas |
| cancelamento do marketplace | **mutante vivo** | 2 falhas |
| avanço do marketplace | coberto | 3 falhas |
| clique de status no painel | **mutante vivo** | 4 falhas |
| excluir pedido | **mutante vivo** | 1 falha |

**Cinco de seis podiam ser apagados sem uma única reclamação** dos 1563 testes. É o caminho inteiro
do dinheiro. Hoje ninguém consome a fila, então gancho errado não aparece; no dia em que ligar, o
módulo decide estoque e contabilidade por eles.

### 3. O rollback do deploy apagava o container SADIO

O `rollback()` começava sempre com `docker rm -f api`. Isso está certo em **um** dos quatro pontos em
que o deploy pode falhar. Nos outros três o container que está no servidor **é o bom**, e o rollback
o destruía — deixando a produção **sem nenhum container**, sem nada para devolver, e com o vigia
escrevendo "ISTO PRECISA DE MAO HUMANA". Uma falha num passo inofensivo (um nome de tag errado)
derrubava o site até alguém entrar no servidor de madrugada.

Agora a decisão é por fato: existe `api-anterior`? Se não existe, o rename não aconteceu e o `api`
de agora é o bom — **não se apaga**. Provado com containers de mentira no Docker: lógica nova 5/5
verdes, **lógica antiga reprova em 3 dos 5**.

### 4. O backup fora da AWS passa a ser RESTAURADO toda semana

**O QA errou a data e eu errei a causa.** Ele disse que a cópia falhou em 16/11. O log tem **duas**
falhas na vida (07 e 08/11, o IP morto). Em 16/11 o PC estava desligado às 10:00 — e o Windows
**recuperou sozinho**, rodando o atraso às 08:28 de 17/11 com 8 arquivos. Estado real: **188 dumps,
691 MB**, cobertura diária de 04/10 a hoje sem furo, exceto 07/11 (o dia em que o servidor estava
desligado e não produziu dump).

**O que faltava era outra coisa: ninguém nunca restaurou essa cópia.** Tamanho batendo prova que a
transferência chegou completa; não prova que o arquivo restaura. E era justamente ela — a **única
fora da AWS**. Rodei hoje: restaurou, com 8 lojas, 13 usuários, 268 produtos, 43 pedidos, schema
V74. Agora roda **toda semana sozinho**, pendurado na tarefa de cópia (que provadamente roda), com o
aviso saindo em toda cópia enquanto estiver atrasado ou falhando.

### 🔴 O ÚNICO CLIQUE QUE FALTA É SEU: ligar a fila de eventos

Vá em **Configurações → 🔧 Plataforma BoraHapp → 📬 Fila de eventos do ERP**, ligue, e a própria
tela passa a mostrar a média que a gravação custa em cada venda. Eu não consigo clicar: é conta sua.

Os 5 ganchos que não tinham teste nenhum — e que eram o motivo de eu não recomendar ligar antes —
estão travados desde hoje.

**Confirmado hoje que você ainda não clicou, e isso é medido, não suposição.** Restaurei o dump de
produção das 18:26 UTC num Postgres descartável e li duas coisas: a chave `outbox.habilitado` **não
existe** em `config_plataforma` (e sem a linha ela nasce desligada), e `evento_outbox` tem **0
linhas**. O log do container sozinho não respondia isso — ele começa às 18:26 e não houve nenhuma
venda desde então, então uma fila ligada também apareceria como silêncio.

#### E o `empresa_id`, que eu fechei ANTES de você clicar

A V74 criou a coluna `empresa_id` na fila e a entrega A2 gravava **`null` literal** nela. Só
`loja_id` ia preenchido — ou seja, o evento dizia em qual unidade a venda aconteceu, mas não de
quem era a unidade. **O caso que mostra o preço está em produção: as lojas 18, 19, 20, 21 e 22 são
a rede da Zirá e pertencem a UMA empresa (a 3).** Sem a coluna, quem consome a fila veria cinco
clientes em vez de cinco unidades de um.

Resolvido hoje (V76 + backend + tela), e **era agora ou nunca de graça**: com a fila em zero evento,
o retrofit não toca em nada. Se você tivesse ligado primeiro, cada venda nasceria um evento sem
empresa e o retrofit passaria a ser correção de histórico.

Três coisas que vale você saber:

- **a empresa vem da loja por subconsulta dentro do próprio INSERT**, não por uma consulta separada
  em Java — essa custaria uma ida e volta a mais no caminho de **toda venda**, o dobro do custo que a
  tela mede;
- **a fila continua sem poder recusar uma venda.** A coluna segue sem `NOT NULL` e sem chave
  estrangeira, como a V74 decidiu: loja sem empresa, ou loja que não existe, grava o evento com nulo
  e a venda segue. Dois testes de integração medem exatamente isso;
- **o modo de falha dessa coluna é o silêncio**, então a tela passa a mostrar quantos eventos estão
  sem empresa. Zero é a resposta saudável; se sair de zero, o conserto é no cadastro da loja, não na
  fila.

Também fechei o terceiro caminho que cria loja: o bootstrap do primeiro start era o único que não
preenchia `empresa_id`. Em produção ele nunca rodou (só entra quando não existe nenhuma loja), mas
numa instalação nova **todo** evento sairia sem empresa, para sempre.

**Medido:** 1588 testes unitários e 245 de integração, 0 falhas. Quatro mutantes, nenhum sobreviveu
— inclusive voltar o `null` literal, que morreu em 4 unitários e 3 de integração.

### 🔴 O que ficou PARA VOCÊ decidir: a terceira cópia

Hoje há duas, e a da AWS está na conta que **já foi encerrada uma vez** — e o e-mail deles diz que
passados **90 dias** a conta não reabre e o que sobrou é apagado. A do PC está num disco só.

**Não é dinheiro:** 691 MB hoje, 1,31 GB por ano. Cabe de graça no Cloudflare R2 ou Backblaze B2.
São três decisões suas: **onde** (recomendo R2 ou B2, não um segundo bucket na AWS — o ponto é sair
do alcance de um problema de cobrança da Amazon); **a chave**, porque o dump tem telefone, endereço e
CPF de todo cliente e precisa ser cifrado antes de sair da máquina, com senha no seu gerenciador de
senhas (backup cifrado com chave perdida não é backup); e **a conta**, que eu não crio.

Não escrevi o script de envio de propósito: script que fala com um destino que não existe não pode
ser testado, e código não testado no caminho do backup **parece pronto** e é pior que a falta dele.

---

## 🔴 17/11/2026 (noite) — **o próximo clique é SEU: ligar a fila de eventos do ERP**

A v167 subiu a gravação da fila de eventos (outbox, entrega A2) **desligada**, e eu não consigo
ligá-la. Não é cautela minha: não há caminho. Está commitado como a **v168**, aguardando deploy.

### O que eu achei ao tentar ligar, e que era um defeito meu

A chave `outbox.habilitado` **podia ser lida** na tela e **não podia ser escrita por lugar nenhum**.
Só o `fiscal.habilitado` tinha endpoint de escrita. Ligar ou desligar exigia escrever direto no
banco de produção.

Isso é pior do que parece: a gravação fica no caminho de **toda venda**. O interruptor de
emergência dela só era alcançável por quem tem acesso ao banco — o que, numa emergência, é o
mesmo que não ter interruptor.

### O que a v168 traz (commitada, **não** em produção)

- `GET` e `PUT /admin-bora/config/outbox`. O PUT invalida o cache de 30s na hora: ligar e desligar
  valem **na próxima venda, sem deploy**. Sai no log como AUDITORIA.
- **Configurações → Plataforma BoraHapp → "Fila de eventos do ERP"**: o interruptor, e ao lado
  dele o **custo medido por venda** — contagem, média e maior, atualizando a cada 15s. Desligar ou
  não é decisão que se toma olhando o número.
- A própria aplicação mede, porque não há como medir de fora: **nenhum** endpoint que grava evento
  é alcançável sem credencial de loja, e o `/actuator` só expõe `health`. A primeira gravação sai
  sempre no log, com hora — é a prova de que a chave passou a valer.
- Suite: 162 classes, **1488 testes, 0 falhas** (1476 + 12 novos).

### Por que a média do INSERT é a medição certa

O custo que a fila acrescenta a uma venda é **exatamente** a duração do INSERT: com a chave
desligada não existe INSERT nenhum, então o "antes" é zero por construção. Cronometrar a
requisição inteira seria pior — o tempo dela varia com rede, tamanho do carrinho e concorrência,
e o ruído engoliria um INSERT de poucos milissegundos.

No meu ambiente o banco fica na mesma máquina e a diferença caiu no ruído. Em produção o banco
está do outro lado da rede: um INSERT a mais é uma ida e volta a mais. **O número que vale é o
de lá.**

### A ação, em ordem

1. Subir a **v168** (API e frontend).
2. **Configurações → Plataforma BoraHapp → Fila de eventos do ERP** → ligar o interruptor.
3. Deixar as vendas do dia acontecerem e **ler a média na própria tela**.
4. Se incomodar, desligar ali mesmo — vale na próxima venda.

### ✅ FECHADO em 18/11 — o cardápio próprio emite evento (commit `813cfb3`, aguardando deploy)

O checkout do cardápio próprio (`POST /public/loja/{id}/pedido`) **não tem hook de outbox**. Ele
monta o Pedido no próprio controller, com `tx.execute`, sem passar pelo `PedidoService` — e os 5
pontos de gravação estão todos no `PedidoService`.

Consequência para o ERP: venda feita pelo QR / cardápio da própria loja ficaria **invisível** para
os módulos de estoque e fiscal quando eles forem acoplados. **Fechado em três pontos**, porque um não bastava:

1. **A venda nasce** → `PedidoRecebido`, como último passo da transação. Não é estilo: o pedido é
   gravado uma primeira vez com total **zero**, para ter id antes do laço dos itens — emitir ali
   mandaria R$ 0,00 ao financeiro. Frete, cupom e cashback entram depois disso.
2. **O PIX não nasce** (o Asaas recusou) → `PedidoCancelado`. Obrigatório, não extra: o
   `PedidoRecebido` já commitou, e a venda é desfeita por uma transação **posterior** — nenhum
   rollback desfaz o evento. Sem ele a fila fica com uma venda que deixou de existir.
3. **O PIX é pago depois do cancelamento** → o pedido reabre e emite de novo, marcado como
   reabertura. Sem isso o módulo trata como morta uma venda que voltou a valer, com o cliente
   tendo pagado e esperando comida.

O canal vai como **código** (`CARDAPIO`), não como o rótulo "Cardápio Digital". Esse texto já fez o
canal ser contado como Instagram e depois como nada — evento que módulo vai assinar não pode
depender de rótulo.

**A lacuna que ficou, de propósito e travada por teste:** PIX pago de pedido que **não** estava
cancelado não emite nada. "O dinheiro entrou" não tem nome no catálogo — o que existe é
`PedidoFinalizado`, que no código quer dizer ENTREGUE, e PIX pago não é entrega. Inventar
`PedidoPago` agora seria publicar contrato que ninguém leu. **Isso é da entrega A5, e vale para
todos os canais, não só para este.**

**O teste que eu tive de consertar.** Apaguei cada gravação para ver se algum teste reclamava. A
emissão movida para antes do laço dos itens matou 2 testes — e o teste do *total final* continuava
**verde**. O defeito era o meu teste: `ArgumentCaptor` guarda a **referência** do pedido, não uma
cópia, então ele devolve o estado final e a asserção passa mesmo com a emissão no lugar errado.
Trocado por instantâneo gravado no momento da chamada. Suite: **1503 testes, 0 falhas**.

(Lembrete do que medi em 15/11: esse checkout tem **zero POST** em 12 dias de log do Caddy. O canal
próprio não tem tráfego nenhum — o que não diminui o buraco, só adia a conta.)

---

## ✅ 17/11/2026 (tarde) — v165: a fundação do ERP em produção, e 7 defeitos fechados

**A V74 aplicou em 0,199 segundo.** Schema de 73 para **74**, container sadio, zero erro no log,
as lojas reais servindo cardápio. As 8 tabelas novas (`tenant`, `licenca_modulo`, `deposito`,
`fornecedor`, `evento_outbox`, `evento_consumido`, `auditoria`, `certificado_digital`) existem e
estão **vazias** — e `licenca_modulo` vazia quer dizer "tudo desligado", que é o estado correto das
23 lojas. **Nada mudou para nenhum cliente**, que era o objetivo do passo.

### A varredura dos 5 agentes, antes de subir

Rodei QA de API, QA de tela, DBA, segurança e líder técnico na aplicação inteira. Acharam coisa
séria, e **dois deles acharam o mesmo defeito crítico de forma independente**:

- **A V74 quebrava o "Excluir usuário" que eu tinha subido de manhã.** Ela criava chave estrangeira
  para `usuario` sem `ON DELETE` — a prévia dizia "pode excluir" e o DELETE devolvia **500**.
  Corrigido na própria V74, antes de ela existir em produção.
- **Uma loja podia ficar sem nenhum administrador**, por corrida (1 em 6 tentativas). Corrigido:
  0 em 10.
- **E o mesmo buraco, pior, na tela do lojista — esse estava NO AR para as 23 lojas.** O dono podia
  desativar ou rebaixar o único administrador da própria loja e ficar com uma loja que ninguém
  administra, nem para desfazer. E gera **cobrança sem e-mail**.
- Corpo vazio num `PUT /ativo` **desativava a conta** respondendo 200. Teto de 15 usuários burlável
  só reativando alguém. Nome/e-mail longos viravam 500 **com o SQL no corpo**.
- **Todo pedido do cardápio próprio aparecia como "Instagram"** em Pedidos, Canais, Relatórios, KDS
  e Caixa — o `IG` casava dentro de "CARDÁPIO D-IG-ITAL". O lojista decide divulgação em cima
  disso. Ao consertar apareceu o segundo, escondido atrás do primeiro: o canal Site procura
  `CARDAP` e **"CARDÁPIO" tem acento**, então nunca casou.

### 🔴 O que a varredura achou e eu NÃO consertei

São defeitos **pré-existentes**, nenhum causado pela V74. Cada um merece passada própria:

- [ ] **500 com o SQL no corpo** em corrida de chave única, em 3 rotas — uma delas **pública**
      (`/public/signup`). O conserto certo é um handler global, que muda o erro dos 166 endpoints.
- [ ] **Freio de login burlável por `X-Forwarded-For`** se a porta da API for alcançável sem passar
      pelo Caddy. **Conferir se a porta do container está exposta na internet** — é verificação de
      infra, não de código.
- [ ] **Token não é revogado ao trocar a senha.** Funcionário demitido com sessão aberta continua
      dentro por até 24h; só desativar a conta derruba. Contradiz o comentário do próprio código.
- [ ] Webhook sem id externo cria **pedido vazio de R$ 0,00** a cada chamada.
- [ ] Seletor de cor virou linha de 3px em Configurações; botões do cartão de pedido estourando a
      coluna (o 🗑 some). Arrastam bump de versão do CSS em 34 telas.
- [ ] "Pagamento na entrega" no cardápio não obriga escolher dinheiro/cartão — e aí a conta do
      **acerto do motoboy sai errada**.
- [ ] `deploy-frontend.sh` **sempre sai com código 1**, mesmo dando certo (ver a seção própria).

---

## ✅ 17/11/2026 — v163 no ar: o adm master vê e mexe em TODO usuário da plataforma

**O que te travava:** a tela de Usuários de uma loja lista só quem é daquela loja. Conta de
plataforma (`ADMINISTRADOR_BORA`) tem **loja nula por desenho**, então não aparecia em lista de loja
nenhuma — foi por isso que o `will@bora.com.br` "não existia". E para achar alguém de outra loja, só
entrando em cada loja pelo suporte, uma por uma.

**Onde está agora:** Configurações → 🔧 Plataforma BoraHapp → 🗂️ **Todos os usuários da
plataforma**. Lista todas as lojas **mais** as contas sem loja, com busca, filtro por loja, e
**incluir / ativar / desativar / excluir**. Inativo aparece na lista, de propósito.

**No ar em 17/11:** API **v163** (commit `509c51b`), front commit `5301f09`. Sem migração de banco.

### As três travas que ele respeita

1. Ninguém mexe na própria conta.
2. Nunca o último administrador de plataforma ativo.
3. **Nunca o último administrador ativo de uma loja** — e esta não é zelo abstrato: é a consulta
   `donosDaLoja` que informa o e-mail do lojista na cobrança do Asaas. Loja sem dono ativo gera
   **cobrança sem e-mail** e o lojista não recebe a fatura.

### Excluir × desativar — leia antes de usar o botão vermelho

**Prefira desativar.** Corta o acesso igual (vale no próximo clique da pessoa, não espera o login
vencer), é reversível e mantém o histórico legível.

**Excluir não apaga o histórico do pedido, mas apaga o NOME de quem mexeu nele.** O
`log_status.usuario_id` não tem chave estrangeira: a linha fica lá apontando para uma conta que não
existe mais. A tela conta essas linhas e te mostra o número antes de confirmar — medido com 7
linhas: avisou 7, excluiu, e as 7 continuaram no banco.

### A prova

1.431 testes (eram 1.410 + 21 novos), 0 falhas. **Dois mutantes mortos:** desligar a trava de
loja-sem-dono deixa 4 testes vermelhos, inverter a ordem do DELETE deixa 1. Mais 28 verificações
contra API e Postgres de verdade, e a tela exercitada no navegador. Depois do deploy: container
`healthy`, **0 erro real no log**, e cardápio das 5 lojas reais (1, 18, 19, 20, 23) respondendo 200.

### 🔴 O próximo clique é SEU

- [ ] Entrar como **adm@borahapp.com.br**, abrir a seção e **conferir se o `will@bora.com.br`
      aparece**. Se for conta de plataforma, vem com a tarja "sem loja". Decidir ali: desativar
      (recomendado) ou excluir.
- [ ] **Trocar a senha do `will@bora.com.br`** — ela foi colada num chat em 17/11 e precisa ser
      trocada mesmo que a conta seja apagada.

---

## 🐞 17/11/2026 — o `deploy-frontend.sh` SEMPRE sai com código 1, mesmo quando dá certo

Achado durante o deploy da v163. **O deploy funciona** — a conferência interna dele passa e eu
conferi o arquivo no ar byte a byte — mas o código de saída é `1` em **todos** os caminhos,
inclusive no `--ensaio`, que não envia nada.

**A raiz, medida com `bash -x`:** `novo_temp()` é chamada como `$(novo_temp)`, ou seja em
**subshell** — então o `TEMPORARIOS+=(...)` nunca chega ao shell pai e o array fica vazio. Com o
array vazio, `"${TEMPORARIOS[@]:-}"` expande para **uma string vazia**, o `[ -n "$t" ]` dá falso, a
função `limpar` retorna 1 — e, **por causa do `set -e`**, esse 1 do trap de `EXIT` atropela o
`exit 0` explícito. Isolado nos dois sentidos: sem `set -e` sai 0, com `set -e` sai 1.

**Por que importa:** quem encadear `./deploy-frontend.sh && alguma-coisa`, ou ler o código de saída
em automação, vai ver **todo deploy como falha** — e um deploy que falha de verdade fica
indistinguível de um que deu certo. **Segunda consequência:** os temporários nunca são apagados —
havia **136** arquivos `/tmp/tmp.*` acumulados.

- [ ] Conserto (não fiz, está fora do que foi pedido): fazer `novo_temp` gravar o nome num arquivo
      de controle em vez de num array, ou trocar o corpo do `limpar` por algo que termine em
      verdadeiro. O `deploy-api.sh` **não** tem esse defeito — sai 0 corretamente.

---

## 📘 17/11/2026 — a documentação do ERP está escrita. **Nada dela está em produção**

Isto **não é código no ar** e não muda nada para nenhuma loja hoje. É o levantamento de requisitos
para transformar o BoraHapp num ERP, feito em **22 documentos, 15.180 linhas**, em
`documentacao-erp/`. Tudo **local**: nada commitado, nada subido.

**Por onde se começa a ler:** `documentacao-erp/00-VISAO-GERAL-E-ARQUITETURA-MODULAR.md` — ele tem
o índice dos outros 21 no começo.

**A decisão de estratégia, sua, de 17/11:** três fases estanques. **A)** ajustar o módulo principal
para rodar sem os acoplamentos, sem quebrar o que roda hoje. **B)** desenvolver cada módulo sem
conectar ao principal. **C)** o acoplamento por último, um módulo de cada vez. O simulador do módulo
principal entrou como entrega **A6** da fase A, para que a fase C não vire integração de big-bang.

### O que falta fechar, em quatro grupos

**1 · Meu, ainda consigo pesquisar — e é o que bloqueia escrever código fiscal:**

- [ ] Investigar a **calculadora oficial do RTC** (`consumo.tributos.gov.br`, código aberto, roda
      offline). Ela fecha de uma vez a mecânica de montar o XML da **gorjeta** e da **comissão de
      plataforma**, e provavelmente diz **onde gravar o ID do pedido do marketplace** — provei que o
      `idCadIntTran` é o perfil da loja, não o pedido.
- [ ] Prazos de cancelamento de nota do **RJ** — o domínio da SEFAZ-RJ bloqueou a pesquisa.

**2 · Precisa de assinatura de profissional — eu não fecho nenhum destes:**

- [ ] **Consultor tributário:** os 13 pontos do checklist (doc 00, cap. 13) e as 7 questões
      pontuais ainda abertas. São **46 marcações `[VALIDAR]`** em 7 documentos. As duas que mais
      pesam: **gorjeta acima de 15% perde a exclusão inteira ou só o excedente** (muda a base de
      todo pedido com gorjeta) e **local da operação no delivery** (decide qual município arrecada).
- [ ] **Advogado trabalhista:** garantia mínima condicionada a turno ou taxa de aceite — efeito no
      vínculo do entregador. Risco de impacto crítico.

**3 · Depende de norma que ainda não existe — é monitorar, não fazer:**

- **Não há data oficial de obrigatoriedade do split payment**, nem geral nem por meio de pagamento.
  O "2028" que circula é declaração à imprensa. No documento está como parâmetro com vigência.
- **Não há resolução do Senado** com as alíquotas de referência de CBS e IBS.
- Cupom custeado pela plataforma: a lei fala em *valores retidos*, não em desconto de terceiro.

**4 · O que trava o módulo Fiscal mesmo depois de pronto:**

Os 11 cenários fiscais do simulador rodam, mas o resultado esperado de cada um é um *golden case*
que **só vale assinado**. Sem assinatura o módulo pode ser construído, **mas não pode emitir nota de
cliente** — e depois do art. 341-G, VI (150 UPF por equipamento, para quem **desenvolve, fornece ou
instala** software fiscal que não atende à lei), o risco é **da ADF Sistemas**, não só do lojista.

> **O estado honesto dos documentos:** todos os 13 do conjunto principal estão marcados "Versão base
> para refinamento". Os capítulos de API são amostra, os requisitos não têm estimativa, e nenhum
> passou por revisão de terceiro — a conferência que existe é a minha, das fontes legais.

---

## ✅ 15/11/2026 — o aceite dos Termos passou a exigir que o texto abra

A faixa trazia um link "Ler os Termos" (outra aba) e, ao lado, um botão "Li e aceito". **Dava
para aceitar sem nunca ter aberto nada.** Agora o botão abre o texto numa janela — Termos e
Política de Privacidade, buscados de `/termos.html` e `/privacidade.html` e passados por
`DOMParser` — e **o aceite fica no fim do documento**, liberado só ao chegar lá.

No ar em 15/11 (front `2b9d1e7`), conferido byte a byte contra o repositório. Medido no navegador:
os dois documentos carregam (12 e 10 seções, ~10 mil caracteres) e saem sem nenhum script.

- [ ] A tela de **cadastro** (`cadastro.html`, inscrição por conta própria) continua com a
      caixinha "Li e aceito" + link para outra aba. É outro fluxo, numa página pública que nem
      carrega o `app.js`. *Falta: decidir se leva o mesmo comportamento.*

---

## 🆕 15/11/2026 — cliente novo: Doce Jardim (loja #23)

Cliente **novo**, não é unidade da Zirá: CNPJ 61.216.168/0001-23 (PATRICIA VIEIRA DE MORAES
PONTES - ME), plano único R$ 199, cortesia até **22/11/2026**. Login `ferreira_114@hotmail.com`.

**Já está no ar** (medido em `GET /public/loja/23/cardapio`, HTTP 200): 5 categorias, 32 produtos,
8 grupos e 92 complementos; 31 produtos com foto (servidas pela API, `image/webp` 200×200).
Preços do **papel** — o site Anota.ai serviu só para as imagens.

### 🔴 O que impede a loja de vender hoje

- [ ] **Nenhuma taxa de entrega cadastrada** (`bairros: []`). **Todo pedido de entrega é
      recusado** (v160). A ficha trazia "São Bento: R$ 0 / 0 min" e **não foi gravado**: R$ 0 é
      entrega de graça de verdade e "0 min" é campo não preenchido. *Falta: os bairros e as taxas.*
- [ ] **Horário 18:00–23:00 todos os dias**, que foi o padrão do painel. A ficha dizia
      "08:06 às 23:07", que é relógio, não horário de loja. *Falta: o horário real.*
- [ ] **PIX online indisponível** (`pixDisponivel: false`) — sem conta Asaas. A ficha marcou
      "PIX online pelo BoraHapp".

### 🟡 Cardápio

- [ ] **Dois adicionais extras sem nome** no papel (R$ 3,00 e R$ 7,00): as duas colunas têm uma
      linha de preço a mais que a de nomes. Ficaram de fora — não dá para adivinhar.
- [ ] **Copo Tropical sem foto** (único dos 32): não existe no site da loja.
- [x] ~~Logo não gravado~~ — **gravado em 15/11**, medido em `GET /public/loja/23/logo`
      (HTTP 200, `image/png` 200×200, sha256 igual ao arquivo original).
- [x] ~~Cor da marca roxa com logo rosa/vermelho~~ — **ajustado em 15/11**: primária `#9C1C24`
      (o vermelho das letras, 8,06:1 com branco) e secundária `#BA4245` (5,31:1). As duas medidas
      com a própria `cores.js`. O rosa do fundo (`#FDCBCC`) foi descartado para secundária porque
      viraria preço em `#8b7070`, um marrom acinzentado. Conferido na tela, no celular.
- [ ] O papel cobra **mais caro que o site** em quase todo item (ver
      [DOCE-JARDIM-PAPEL-x-SITE.md](DOCE-JARDIM-PAPEL-x-SITE.md)). Vale a Patrícia confirmar.
- [ ] O rodapé do site traz **CNPJ 55.052.547/0001-22**, diferente do cadastrado. Resolver
      **antes** da 99: lá a conta bancária tem de ser do mesmo CNPJ.

### ✅ Fechado em 15/11 — v162 no ar

- [x] ~~Trocar o e-mail de acesso~~ — **v162 no ar em 15/11** (`PUT /api/usuarios/{id}/email`
      + campo na tela). Medido no bytecode do jar EM EXECUÇÃO, não deduzido do commit. O dono
      trocou o login da Doce Jardim no mesmo dia: hoje é `docejardim@borah.com.br`.
- [x] ~~Cópia de cardápio entre unidades e campo do ID da loja na 99~~ — **subiram junto na
      v162**: `copiar-cardapio` e `shopIdCanal` conferidos dentro do jar, e os campos conferidos
      no `integracoes.js` e no `configuracoes.html` servidos pelo site.

### 99Food — o que foi medido em 14/11

A conta da Zirá no `merchant.99app.com` **lista, filtra e copia loja, mas não cria**. Não há
autoatendimento: abrir unidade nova passa pelo time da 99. IDs das unidades existentes: Montreal
`5764615393256407102`, Nova Esperança `5764608368417965364`, Zona Norte `5764608427259856166`,
São Bento `5764614166724478604`.

---

---

## 🆕 13/11/2026 (tarde) — abrir a 6ª unidade da Zirá, no endereço do dono

**Decidido:** entra como **6ª loja da Zirá, pelo CNPJ centralizador dela**. O passo a passo inteiro,
dos dois lados, está em **[ABRIR-LOJA-NOVA-NA-99.md](ABRIR-LOJA-NOVA-NA-99.md)**.

**O que eu fiz hoje, porque não existia** (commitado e testado; **não deployado**):

- **Copiar cardápio de outra unidade** — painel da plataforma → Configurações → ➕ Nova loja →
  "Copiar cardápio de outra unidade". Medido na loja 18: **44 produtos, 59 grupos de complemento,
  639 itens, 43 insumos, 6 taxas**. A mão, isso não é tarefa. Vem cadastro e marca; **não** vem
  saldo de estoque, horário, nem o código do produto no iFood/99. Roda uma vez só, em loja vazia.
- **Campo do "ID do loja" da 99** em Integrações. A coluna existe desde a V67 e **nenhuma tela
  escrevia nela** — toda unidade nova ficava pela metade esperando eu abrir o banco.
- **Uma trava nova que vale por si:** a unicidade do código do marketplace passou a comparar os
  **dois** identificadores entre si. O ID numérico de uma loja igual ao APPShopID de outra **passava**
  — e o pedido real de uma cairia no painel da outra, calado.

**O que é seu, para a unidade sair do papel:**

1. 🔴 **Cadastrar o estabelecimento na 99** — <https://merchant.99app.com/pt-BR/store>. Tenha em
   mãos: CNPJ da Zirá, CPF/RG do responsável, endereço com CEP, telefone, **foto da fachada
   (obrigatória)**, foto de capa que **não repita** a de outra loja, cardápio em foto/PDF/QR e os
   dados bancários do CNPJ da Zirá. O micro-depósito de validação leva **até 2 dias úteis**.
2. 🔴 **Autorizar o app `BR_P_BoraHapp` e vincular** (caminho batido em 06/11), e **me trazer dois
   números**: o **ID do loja** (numérico) e o **APPShopID** que você digitou. Segredo nenhum: a
   credencial da plataforma já está certa desde 10/11.
3. 🟡 **Me dizer o nome da unidade, o endereço completo e o e-mail do responsável** — com o mesmo
   e-mail da Zirá ela entra no login dela, pelo seletor de loja.
4. 🟡 **Duas decisões de dinheiro:** esta unidade **entra na cobrança** (hoje nasce com 7 dias de
   cortesia; as irmãs vão até 24/01/2027)? E **qual a taxa de entrega** dos bairros dela — desde a
   v160, bairro fora da lista **recusa o pedido** em vez de cobrar R$ 0,00 em silêncio.

**O que eu NÃO sei, e por isso não está prometido aqui:** se a 99 deixa você mesmo criar a unidade
dentro da conta da Zirá ou se isso passa pelo comercial deles; se ela vai pedir documento do ponto
(o endereço é seu, o CNPJ é da Zirá); e qual o prazo de aprovação. Nenhum guia publica isso. Quando
você abrir o portal, eu leio a tela com você, como em 06/11.

**Um aviso que vem de graça com o recurso novo:** a 99 aceita **dois turnos no mesmo dia** e o Bora
guarda **um horário por dia**. Se esta unidade tiver turno partido, o Bora não representa hoje — é
ajuste de código, e eu só mexo nisso se você disser que ela precisa.

---

## 13/11/2026 — a v160 no ar, e a limpeza aplicada. 12 itens fecharam

**Estado medido**, não anotado: `api Up (healthy)`, **0 ERROR** no log, health 200 pela internet.
V71 e V72 aplicadas (**72 migrações** no total), o índice `uq_pedido_loja_chave_idempotencia`
criado. Backup antes de trocar o container: `bora-20261113-1013.dump`, 4,3 MB, **lido inteiro pelo
`pg_restore`**.

**O frontend sobe por outro caminho, e sem ele metade do conserto ficaria fora do ar** — é a
armadilha que me pegou em 28/10. Publicado também: os **5 arquivos** que eu mexi, e só eles (o
ensaio do script listou exatamente esses 5 de 98), com os **98 sha256 iguais** aqui e no servidor.
Conferido **baixando da internet**, não no meu disco: `Idempotency-Key` no `api.js`, `chaveDaVenda`
nos três JS, `avisoBairro` no `novo-pedido.html`, `nomeDaLoja` no `whitelabel.js`.

**A prova que eu mais queria, e que não é de teste:** 4 minutos depois do deploy, o 99Food da loja
1 — que leva 403 em toda consulta — tentou de novo e o `falhas_seguidas` dela **virou 1**,
enquanto as 5 lojas da Zirá seguiam com **0** e polling de 5 segundos atrás. O caminho novo está
rodando em produção, nos dois sentidos.

**O que eu NÃO consegui provar no ar:** lançar pedido pede login de lojista, e eu não entro em
conta de ninguém. A trava da venda duplicada está provada por **8 testes** no serviço e **4 na
fiação do controller** — esses 4 porque os 8 continuariam verdes se o cabeçalho nunca chegasse ao
serviço, e isso já custou aqui uma vez.

### Os três defeitos, e o que cada um ficou sendo

| o que era | o que ficou | prova |
|---|---|---|
| **A mesma venda gravada DUAS vezes.** `POST /api/pedidos` sem chave de idempotência: a resposta se perde na volta, o balconista clica "Finalizar" de novo, e a venda nasce duas vezes — estoque e insumo baixados duas vezes, cashback dobrado, faturamento inflado | Chave `Idempotency-Key` + índice único parcial (V71). O reenvio devolve **o mesmo pedido**. As duas telas que lançam venda (novo-pedido e Frente de Caixa) já mandam a chave | 8 testes novos; sem o cabeçalho nada muda (cardápio público, webhooks e integração de terceiro seguem igual) |
| **Bairro fora da lista saía R$ 0,00 calado.** E era pior do que a nota dizia: a taxa vinha do bairro do **cadastro**, não do bairro **deste pedido**; e quem pedia sem cadastro não pagava frete nenhum | O bairro vem do pedido, e bairro fora da lista volta **400 dizendo qual bairro** ficou de fora. Na tela, o aviso nasce ao lado do campo. **Não trava venda**: o campo "Taxa" do painel sempre vai no corpo, e cortesia continua possível | 9 testes novos. **O teste REPROVA no código antigo** — conferido desfazendo o conserto: "expected ResponseStatusException, but nothing was thrown" |
| **A loja que cai e continua VERDE.** `marcarPollingFalhou` gravava hora e mensagem e não mexia no status | Rebaixa CONECTADO → ERRO **no limite de 3 falhas seguidas** (V72). Não na primeira: ERRO custa 10 min de espera até a tentativa seguinte, e rebaixar num tropeço trocaria o silêncio por atraso em pedido real. Com o ciclo de 30 s, uma queda de verdade fica vermelha em ~1,5 min | 6 testes de integração contra um Postgres de verdade. **Reprova no código antigo**: "expected: \<ERRO\> but was: \<CONECTADO\>" |
| **A rede de segurança do nome da loja estava morta** (`whitelabel.js:45`) | O nome real chega na própria resposta de `/api/configuracao`, sem segunda chamada. E vai também para o `localStorage` — de onde saem a **comanda da cozinha**, o fechamento do caixa e o **recibo do motoboy**, que saíam "BoraHapp" esse tempo todo | — |
| **O log contava cada 401 do 99Food duas vezes** | As duas linhas de detalhe agora dizem **DETALHE** no texto. A linha do evento continua uma só | — |

**Medições do build:** 1388 testes unitários e 217 de integração, **0 falhas**. As duas migrações
novas rodaram num Postgres limpo durante os ITs.

### Limpeza de dados: **aplicada**, numa transação só

Rodou numa transação só, conferindo os números **antes** do `COMMIT`: **2 + 4 + 7 + 1 + 1 + 2
linhas**, e os seis contadores foram a **0**. Os controles no mesmo print mostraram que nada a mais
se mexeu: 43 pedidos (igual), 7 usuários ativos, 52 itens de pedido (eram 59, menos os 7 órfãos),
42 produtos ativos na loja 18 (eram 44, menos os 2 insumos), 13 formas de pagamento na loja 1 (eram
14). O que cada linha fez, tudo medido antes:

| item | medido | o que o script faz |
|---|---|---|
| insumos à venda no cardápio da loja 18 | produtos **145 (pacoca, R$ 2,50)** e **146 (leite condensado, R$ 3,00)**, os dois ativos | desativa os dois |
| contas de teste | **4 ativas**: 6 e 7 e 25 (GERENTE) e 20 (OPERADOR) | desativa as quatro |
| itens de pedido órfãos | **7**, todos da loja 1, R$ 281,10 em itens cujo pedido não existe mais | apaga |
| ficha técnica fantasma | `produto_insumo` id 2: produto 1 existe, **insumo 2 não existe** | apaga a linha |
| "Vale Refeicao" repetido | loja 1, ids **6 e 12** — as duas linhas são idênticas em tudo menos o id | apaga a 12 |
| lojas sem prazo | **19 e 20** com `acesso_ate = NULL` | alinhadas às irmãs da mesma cliente: **24/01/2027**, lido da loja 18 em vez de digitado |

### A ficha de abertura deixou de ser arquivo

Uma cliente preencheu as 8 páginas da ficha em PDF e **perdeu tudo**. Antes de culpar o arquivo, eu
medi o PDF: formulário de verdade (AcroForm), 422 campos, **sem senha, 0 campo somente leitura,
335 de 335 com aparência própria**, e escrever-salvar-ler devolve o valor. **O arquivo estava são.**
O que apaga é o aplicativo: a prévia do WhatsApp, do Gmail e do Drive **não grava nada no
arquivo**, e no navegador o botão de baixar costuma buscar o original em branco. Conferi também que
a ficha **não está publicada no site** (404 nos três caminhos, nenhum PDF na pasta do servidor) —
ou seja, ela recebeu por mensagem, que é exatamente o caminho onde se perde.

**No ar: [borahapp.com.br/ficha.html](https://borahapp.com.br/ficha.html)** — grava a cada tecla no
próprio aparelho, diz na tela a hora em que gravou, e quem volta lê *"você já tinha começado,
está tudo aqui"*. São **28 campos em vez de 422**: só o que a loja precisa para entrar no ar. No
fim, manda pelo WhatsApp com tudo escrito (ou copia, ou baixa). Nada sai do aparelho dela até
apertar enviar.

**Medido no navegador, em tela de 375 px:** 19 campos + 3 bairros + 2 formas de pagamento
sobreviveram ao recarregamento; com a ficha vazia o "Enviar" lista os 9 itens que faltam, pinta os
7 campos e **não navega**; o link do WhatsApp sai com 823 caracteres e o texto decodificado bate com
o da tela. E repeti o teste **na página publicada**, não só no meu computador.

**O PDF continua valendo** para quem preferir papel — só deixou de ser o único caminho.

### Dois achados novos de hoje, que a lista não tinha

- **Não são duas lojas sem prazo, são quatro.** Além da 19 e da 20, a **loja 1** (QA) e a **loja 17
  (Pizzaria Bella Napoli)** também estão com `acesso_ate = NULL`. As da Zirá eu alinho às irmãs
  porque é a mesma cliente e o mesmo contrato. **A da Pizzaria é sua**: eu não sei o prazo dela, e
  loja sem prazo some da cobrança sem ninguém notar.
- **"em homologação" não estava em 10 arquivos que importam — estava em 2.** Os outros 8 são
  relatórios e anotações antigas, que são registro e não documento de cliente. E ao medir o que
  escrever no lugar, achei que a própria nota estava otimista: os **7 pedidos reais do iFood**
  (19 a 30/09) são **todos da loja 1, a loja de teste do Bora** — nenhuma loja de cliente recebeu
  pedido de iFood ainda. E o **99Food tem 5 lojas autenticando e consultando pedido, com 0 pedidos
  recebidos**. Por isso os documentos ficaram com palavras diferentes: iFood **"No ar"**, 99Food
  **"Conectado"**.

### FECHADO hoje, com a prova

**"Em homologação" fora dos dois documentos que vão ao cliente.** A apresentação comercial e o
      gerador da ficha de cadastro. **PDF regenerado e conferido com extração de texto:**
      "homologa" → **0 ocorrências**, "No ar" → 1, "Conectado" → 1, nas 8 páginas.
      De quebra, dois números velhos da apresentação: "37 versões de banco" virou **70** (medido no
      `flyway_schema_history`) e "47 verificações automáticas antes de cada entrega" virou **1.388**
      — que é o que roda dentro do build da imagem. **Não somei os 217 testes de integração**: eles
      não rodam no deploy, e somar prometeria uma conferência que a entrega não faz.
      A data saiu de "30 de setembro" para **12 de novembro de 2026**.

### Não vale a pena fazer, e o número é o motivo

- **Os 5 pedidos apontando para cliente apagado: eu não toquei.** Todos da **loja 1** (QA), todos já
  ENTREGUE ou CANCELADO, e **nenhum deles guarda outra identificação** (telefone e endereço vazios).
  Zerar o `cliente_id` apagaria o único registro de que aquele pedido teve cliente, e não conserta
  nada: o código lê o cliente com `findByIdAndLojaId` e trata o vazio. Vai junto com a decisão da
  loja de QA, que é sua.
- **Os 7 itens órfãos não inflam relatório nenhum**, e isso eu medi em vez de supor: o único método
  que leria item de pedido sem passar pelo pedido é o `PedidoItemRepository.findByLojaId`, e ele
  **não tem nenhum chamador** no sistema. Apago por limpeza, não por defeito.

---

## Conferido contra a produção em 11/11/2026, 20h — item por item

Medição, não releitura de anotação. **Dos 17 itens que davam para medir, 15 continuam como
estavam, 1 mudou de número e 1 fechou.** Nada envelheceu para melhor sozinho.

| item | o que eu medi hoje |
|---|---|
| freio de login por cabeçalho | **FECHADO**: 8 logins com 8 `X-Forwarded-For` → 401×5 e depois **429** na 6ª. Não é contornável |
| iFood da loja 17 | `ativo=true`, **ultimo_polling = NUNCA**, token expirou **07/10/2026**, 0 pedidos |
| bairros da loja 18 | tem 6 (Centro, Jd Nova Esperança, Jd Tropical, Pq São Bento, Vila Hortência, Vila Mineirão). **"Jardim Montreal" e "Jardim Hungarês" não existem em loja nenhuma** |
| estoque nas lojas da Zirá | loja 18: 44 produtos, **2** com estoque. Lojas 19 a 22: 42 produtos cada, **0** |
| custo dos produtos | loja 18: 44 produtos, **0 com custo gravado** |
| insumos no cardápio | loja 18, categoria "mantimento": **2 produtos ATIVOS** no cardápio público |
| contas de teste | **4 ativas** (a nota dizia 5): 3 GERENTE + 1 OPERADOR |
| CNPJ das empresas | empresa 2 (Pizzaria Bella Napoli) **sem CNPJ**; as outras duas têm |
| taxa do PIX | `ASAAS_TAXA_PERCENTUAL = 0` no servidor; **loja 18 tem `split_percentual = 0.50`**, as outras 6 ficam no global, ou seja em zero |
| vencimento das lojas | 19 e 20 com `acesso_ate = NULL` (**nunca vencem**); 18, 21 e 22 vencem em 24–25/01/2027 |
| sujeira no banco | **7** `pedido_item` órfãos, **5** pedidos apontando para cliente apagado |
| forma de pagamento | loja 1: **"Vale Refeicao" x2** |
| loja de QA | loja 1 tem **28 dos 43 pedidos** do banco — é a maior "loja" da produção |
| taxa fora da lista | `PedidoService:89` devolve `BigDecimal.ZERO` para bairro fora da lista — confirmado no código |
| "em homologação" | aparece em **10 arquivos**, entre eles a apresentação comercial e o gerador da ficha de cadastro |

**Dois itens se cruzam e viram um defeito vivo:** a loja chamada **Zirá — Montreal** não tem o bairro
Montreal na própria lista de entrega, e `taxaPara` devolve **R$ 0,00 em silêncio** para bairro fora da
lista. Quem mora no bairro da própria loja recebe **de graça**, e nada acusa.

---

## 🔴 Agora

## Varredura de 10/11 — os 2 bloqueadores estão CONSERTADOS e no ar

Relatório inteiro, com os três níveis de confiança, em
[VARREDURA-2026-11-10.md](VARREDURA-2026-11-10.md). **15 agentes, aplicação inteira.** O QA de API
não havia liberado por causa de dois HTTP 500 no cardápio público. **Os dois subiram na v154**
(commit `08e3104`), às 15:29 de 10/11.

**Como eu provei, e não é "o teste passou":** subi a API de verdade contra um Postgres de verdade,
com o mesmo código que está no ar, e medi pelo HTTP:

| o que eu mandei | o que voltou |
|---|---|
| pedido com o código `PROVA10` | **200**, `promocao.usos` virou **1** |
| o mesmo código outra vez (teto é 1 uso) | **400 "Cupom inválido ou vencido"** — o teto agora fecha |
| endereço de **21.600** caracteres | **200**, gravado cortado em 500, pedido existe |
| bairro de 2.400 / nome de 1.800 | gravados em 100 e 160, pedido existe |

E os 5 testes novos foram **mutados um por um**: sem o conserto cada um fica vermelho (923 contra
500, 307 contra 100, 306 contra 160). Teste verde com cenário que não existe não prova nada — essa
foi a lição de 09/10 e é por isso que eu meço o teste antes de confiar nele.

- [x] ~~**Pedido com código de promoção dá 500 DEPOIS de gravar o pedido.**~~ **CONSERTADO e no ar
      na v154** (`08e3104`). O `DescontoService` passou a abrir a própria transação, curta, e o
      `try` ficou **fora** dela — engolir por dentro só mudaria o estouro de lugar, porque o commit
      estouraria no lugar dele. O javadoc do método sempre prometeu *"não faz o pedido falhar"*; era
      essa promessa que estava quebrada, no pior momento possível. Medido: 200, `usos = 1`, e a
      segunda tentativa recusada com 400.
      O texto original, do que foi medido antes:
      Medido pelo QA contra a API real: duas chamadas, dois pedidos gravados **com desconto**, e
      `promocao.usos` continuou **0**. O cliente vê erro e tenta de novo → **pedido duplicado**; e o
      limite de usos **nunca fecha** → desconto sem teto.
      **Mecanismo (um conserto quebrou outro):** `somarUmUso` é `@Modifying(flushAutomatically=true)`
      e o flush exige transação. O `POST /loja/{id}/pedido` perdeu o `@Transactional` de propósito
      (conserto de 26/10), e `DescontoService.contabilizarUso:107` roda no passo 2, fora do
      `tx.execute`. Estoura `TransactionRequiredException`.
      **Por que 1345 testes verdes não pegaram:** `DescontoNoCheckoutIT` é `@DataJpaTest` (roda
      DENTRO de uma transação) e o outro teste usa mock do repositório. É a lição de 09/10 de novo —
      os testes verificaram a lógica, não a premissa em volta.
      **Por que o mock não pegava:** o `PromocaoDaDescontoDeVerdadeTest` dubla o repositório, então
      nunca chega a exigir transação. O teste novo prova a **estrutura**, que é o que dá para provar
      com mock: um `inOrder` exige que a transação seja aberta **antes** do incremento. Quem tirar o
      `TransactionTemplate` reprova.

- [x] ~~**Endereço com mais de 500 caracteres no cardápio público perde o pedido inteiro.**~~
      **CONSERTADO e no ar na v154** (`08e3104`).
      **E era maior do que o QA mediu: eram TRÊS gravações, não uma.** Todas dentro da **mesma**
      transação que grava o pedido — então consertar só a linha que ele mediu deixaria o 500 de pé
      pela segunda recusa, com a venda perdida do mesmo jeito:
      1. `pedido.endereco_entrega` (varchar 500), em `PublicController` — a que o QA achou;
      2. `pedido.bairro_entrega` (varchar 100), a linha seguinte. **Não estava protegido por
         validação nenhuma:** a conferência contra a tabela de taxas só acontece quando a loja
         **tem** bairro cadastrado, e loja sem bairro cadastrado existe em produção — é justamente
         por isso que ela entrega de graça;
      3. `cliente.nome` (varchar 160) e `cliente.endereco` (varchar 500), dentro do
         `FidelidadeService.identificarPeloTelefone`, que roda no mesmo `tx.execute`. O endereço ia
         **sem nem um `trim()`**. Um **nome** de 200 caracteres derrubava a venda por aqui — caminho
         que o QA não chegou a testar.
      Medido depois do conserto: 21.600 caracteres de endereço → 200, gravado em 500, pedido existe.
      O texto original, do que foi medido antes:
      Medido pelo QA: 500 com `value too long for type character varying(500)`.
      `PublicController.java:576` grava `endereco.trim()` **sem** `LarguraDeColuna`; o caminho de
      marketplace (`PedidoService.java:418`) usa `encurtarAvisando`.
      **É regressão de defeito que este roteiro marca como resolvido:** o conserto da v126 cobriu o
      marketplace e deixou o cardápio — e o comentário do próprio código diz *"o Postgres recusava o
      INSERT e o PEDIDO INTEIRO se perdia, com o entregador a caminho"*. Mesmo estrago, no caminho
      onde o cliente de verdade digita.
      SUSPEITA não testada: `bairro_entrega` (varchar 100) tem o mesmo desenho na linha seguinte.
      — **a suspeita do QA estava certa, e eu confirmei medindo.**

- [x] ~~**A V68 transforma migração de dado em pré-condição de boot, e eu não posso editá-la.**~~
      **CONSERTADA e no ar na v155** (`cea9974`). Você autorizou o `flyway repair`; ele rodou às
      16:32 de 10/11 e a v155 subiu em seguida.
      **A prova é em banco VAZIO, que é onde o defeito morava:** os **211 ITs passam sem o
      `-Dspring.flyway.target=67`**, migrando até a V69, com as duas migrações saindo pelo caminho
      "nada a fazer". Ambiente novo do zero volta a subir.
      **Como eu conferi o repair em vez de confiar nele:** medi primeiro o checksum que o Flyway *da
      própria aplicação* calcula para o arquivo novo (`1768862649`), rodando os ITs contra um
      Postgres vazio — e usei a **V67 e a V69 como controle**: arquivos intocados, mesmo checksum
      nos dois lados. Logo eu tinha o valor esperado **antes** de mexer na produção. O repair
      (`flyway/flyway:10.10.0`, a mesma versão do jar) reparou **só a versão 68**, para exatamente
      esse valor. Diff da tabela inteira: **uma linha** mudou, as outras 68 idênticas, 69 linhas, 0
      falhas. Backup antes (`bora-20261110-1928.dump`, lido inteiro pelo `pg_restore`).
      **E a validação foi provada pela própria aplicação:** na subida da v155 o Flyway registrou
      *"Successfully validated 69 migrations"* e *"Schema is up to date. No migration necessary"* —
      ou seja, o texto novo da V68 **não tocou dado de produção**, e o próximo deploy não vai falhar
      na validação.
      **Um segundo defeito que ninguém tinha apontado:** os dois `UPDATE` de token estavam **fora**
      do bloco e rodavam sempre, inclusive nos caminhos de "nada a fazer". Em todo deploy futuro
      zerariam o token das integrações sem credencial própria, forçando um ciclo de login novo em
      produção sem motivo. Foram para dentro, e só rodam quando o segredo muda de fato.
      **Uma coisa que eu tinha escrito errado no próprio arquivo:** o comentário da V68 afirmava que
      `5764607707103889279` era *"o mesmo que está em `credencial.opendelivery.client-id`"*. Não era
      — aquele campo guardava o App ID do app de **teste**. Conferi 19 dígitos e o prefixo `5764607`
      e declarei identidade. Foi por causa dessa frase que a V68 saiu achando que bastava consertar o
      segredo. O arquivo agora registra o erro em vez de repetir a afirmação.
      **O que isso custou, e é o preço de eu ter escrito a guarda errada:** a produção foi corrigida
      pelo arquivo **antigo**, e nenhum banco vai executar o texto novo em cima dela. Quem garante
      que o novo está certo é o banco vazio — os ITs e um ambiente novo —, não a produção.
      O texto original, do que foi medido antes:
      Erro meu, de hoje. Três agentes confirmaram, dois por reprodução: com Postgres vazio a V68
      aborta e **todos os testes de integração falham** (o QA de API só conseguiu rodar os 211 ITs
      com `-Dspring.flyway.target=67`). Ambiente novo do zero também quebra.
      **A V69 já está corrigida** (commit `f8f82b9`), ensaiada em 3 cenários. A **V68 não pode ser
      editada**: está gravada como aplicada e o Flyway valida checksum — mudar o arquivo faz o
      próximo deploy falhar na validação. Consertar exige um **`flyway repair`** na produção.
      Recuperação de desastre a partir do backup **não** estava em risco em nenhum momento: o dump
      contém o `flyway_schema_history`, então a V68 é pulada na restauração (medido).

- [x] ~~**"Não consegui perguntar ao Asaas" é tratado como "o cliente não pagou".**~~
      **CONSERTADO e NO AR na v157** (`ea525f0`, backend) e no frontend publicado (`543fc72`). Teste novo, e o teste foi **mutado**: sem o conserto ele fica vermelho.
      O booleano virou três estados (`PAGO`, `NAO_PAGO`, `NAO_CONSEGUI_PERGUNTAR`). Quem fica sem
      resposta **não é cancelado**: segue em espera — fora do faturamento e fora da cozinha — e a
      rodada seguinte (5 min) pergunta de novo.
      **E havia um teste trancando o defeito**, com a justificativa *"melhor cancelar um checkout
      abandonado do que liberar comida de graça"*. A escolha nunca foi essa: não cancelar não libera
      nada. Adiar custa uma rodada; cancelar venda paga é irreversível. O teste foi reescrito com o
      motivo no lugar.
      O texto original:
      **"Não consegui perguntar ao Asaas" é tratado como "o cliente não pagou", e o pedido pago é
      cancelado.** Confirmado por mim: `PixService.cobrancaFoiPaga` devolve `false` no
      `catch (Exception e)` — timeout, 429, 5xx e chave revogada dão o mesmo que "não pago". O
      `CobradorDePixService` segue para `cancelarVencidos`, que cancela, devolve estoque e cashback e
      avisa o cliente do cancelamento. Conserto: separar "o Asaas disse que não pagou" de "não
      consegui perguntar"; no segundo caso, pular a rodada.

- [x] ~~**O caminho real do webhook do Asaas roda SEM transação.**~~
      **CONSERTADO e NO AR na v157** (`ea525f0`, backend) e no frontend publicado (`543fc72`). Teste novo, e o teste foi **mutado**: sem o conserto ele fica vermelho.
      O `@Transactional` foi para a sobrecarga de 6 parâmetros, a única que o controller chama.
      **Nenhum dos 60+ testes que chamam `processarWebhook` podia pegar isso:** todos chamam o
      serviço direto, sem proxy do Spring, e sem proxy a anotação não faz nada. O teste novo lê a
      anotação por **reflexão**, na assinatura exata do controller, e reprova sobrecarga nova sem
      anotação.
      O texto original:
      **O caminho real do webhook do Asaas roda SEM transação.** Confirmado por mim: o
      `@Transactional` da linha 380 aplica-se à sobrecarga de 5 parâmetros, cujo próprio javadoc diz
      *"o webhook de verdade NÃO usa esta sobrecarga"*. A de 6 parâmetros, que
      `AsaasWebhookController:117` chama, não tem anotação. Pagamento registrado sem acesso
      estendido, ou o contrário.

- [x] ~~**O 401 no polling não invalida o token em cache.**~~
      **CONSERTADO e NO AR na v157** (`ea525f0`, backend) e no frontend publicado (`543fc72`). Teste novo, e o teste foi **mutado**: sem o conserto ele fica vermelho.
      O 401 numa chamada de recurso passa a jogar o token fora, e a rodada seguinte reautentica.
      **Só 401 — o 403 de propósito não conta:** ele quer dizer "o token vale, o recurso é que não é
      seu", e jogar o token fora ali faria reautenticar a cada 30 s para sempre. Não é hipótese: a
      loja 1 responde 403 em produção hoje.
      Medido com **servidor HTTP de verdade**, não com mock do `RestClient`.
      O texto original:
      **O 401 no polling não invalida o token em cache, e a tela fica verde.** Confirmado por mim:
      o `catch` só grava hora e mensagem. Se o canal revogar o token antes do vencimento, o poller
      insiste com o token morto por até **1 h** na 99 e **6 h** no iFood. Ameaça direta ao 99Food das
      5 lojas da Zirá, que começou a funcionar hoje.
      **Armadilha de leitura:** `ultimo_polling_em` é gravado **também na falha** — "último polling
      21 s atrás" prova que *tentou*, não que *funcionou*.

- [x] ~~**O service worker derrubava as fontes do guia da Zirá.**~~ **CONSERTADO hoje** (`479f55f`).
      Medido pelo QA de tela em produção: `ERR_FAILED`, request de 0 byte, fontes vazias em
      `guia-zira.html` e `cardapio-folha.html`. O `sw.js` interceptava toda origem e a CSP
      `connect-src 'self'` bloqueava o fetch de dentro dele. **Eu reescrevi esse arquivo hoje e disse
      que o ERR_FAILED estava resolvido** — estava para mesma origem; para recurso de fora,
      continuava, e eu não conferi.

- [x] ~~**O segredo do JWT falha ABERTO, com um valor publicado no repositório.**~~
      **CONSERTADO e NO AR na v157** (`ea525f0`, backend) e no frontend publicado (`543fc72`). Teste novo, e o teste foi **mutado**: sem o conserto ele fica vermelho.
      Agora recusa a subida: vazio, valor de exemplo ou menos de 32 bytes. A mensagem diz o **nome**
      da variável e nunca o valor — e há teste para isso. O `RepetirPedidoService` usava o mesmo
      literal e também só avisava; passou a usar a mesma regra.
      **Conferido ANTES de commitar:** `BORA_JWT_SECRET` existe em produção, 64 bytes, não começa
      com `troque-`, e o processo no ar a enxerga. Sem essa conferência, este conserto derrubaria a
      API no deploy.
      O texto original:
      **O segredo do JWT falha ABERTO, com um valor publicado no repositório.** Confirmado por
      mim: sem `BORA_JWT_SECRET` a API sobe com `troque-este-segredo-...` e só emite um `log.warn`.
      Quem conhece o repositório forja token de qualquer usuário, inclusive do admin da plataforma. A
      variável existe em produção hoje (conferida pelo nome). **Neste projeto isso não é teórico:** já
      aconteceu a chave de cifragem parecer ausente porque `docker restart` não relê o `--env-file`.
      Conserto: recusar a subida se o segredo for o padrão. O CORS e o WhatsApp já falham fechados.

- [x] ~~**O card verde que mente.**~~
      **CONSERTADO e NO AR na v157** (`ea525f0`, backend) e no frontend publicado (`543fc72`). Teste novo, e o teste foi **mutado**: sem o conserto ele fica vermelho.
      O chip e a **linha sempre visível** passam a dizer COM ERRO, SEM BUSCAR ou AUTORIZAÇÃO
      VENCIDA — o problema sai de dentro do corpo, que nasce fechado. A promessa "os pedidos chegam
      sozinhos" só aparece sem erro, buscando nos últimos 5 min e com pedido já recebido. E
      "Recebendo pedidos" passou a vir com a **data do último**, porque o contador é acumulado desde
      sempre.
      **Achado novo, que ninguém tinha visto:** o `GET /api/integracoes` **não mandava
      `tokenExpiraEm`**, e o card depende dele. O aviso "a autorização do iFood venceu", escrito em
      25/10 para o caso da Pizzaria, lia `undefined` e **nunca aparecia**. O conserto de 25/10 estava
      inerte na tela para a qual foi feito.
      **Isto NÃO tem teste automático** — o projeto não tem runner de JS. A prova é a renderização no
      navegador, com 5 estados medidos, mais uma mutação que devolve o verde. Quem mexer aqui tem de
      abrir a tela.
      O texto original:
      **O card verde que mente, agora medido na tela.** Com `ultimoErro="HTTP 403"` e última busca
      há 3 h, o chip fica **verde**, a caixa diz *"A busca está rodando e não dá erro"* e o
      "Último erro" fica **335 px abaixo da dobra**. Com `pedidosRecebidos > 0` o cabeçalho vira
      "🟢 Recebendo pedidos" — contador acumulado desde sempre, não sinal de agora.
      Dá para consertar só no front, sem esperar o backend: se há `ultimoErro`, ou se
      `ultimoPollingEm` tem mais de ~5 min, trocar chip, linha e caixa.

- [x] ~~**O freio de login pode ser contornado por cabeçalho.**~~ **FECHADO em 11/11/2026 — e
      fechado MEDINDO, não relendo nota.** Oito tentativas de login em `https://borahapp.com.br`,
      através do Caddy, com e-mail inexistente e **oito `X-Forwarded-For` diferentes**:
      401, 401, 401, 401, 401, **429, 429, 429** — o freio travou na 6ª. Ou seja: o Caddy
      **descarta** o cabeçalho que o cliente manda (v2.11.4, sem `trusted_proxies`, os dois
      conferidos hoje no container), o balde é um só e **não dá para contornar**. O que o QA mediu
      era local, sem o Caddy na frente — como o próprio item suspeitava. Volta a importar no dia em
      que entrar `trusted_proxies`, um CDN ou outro proxy antes do Caddy; nesse dia o
      `FreioDeTentativas.origem` precisa pular tantos saltos quantos forem os proxies confiáveis.
      O texto original: O QA mediu local, sem o Caddy na
      frente: 6 erros com `X-Forwarded-For` diferentes e a 7ª com a senha certa **entrou**. O
      `FreioDeTentativas` lê o **último salto** por desenho, e o `Caddyfile` **não tem
      `trusted_proxies`**. O QA não reconferiu o comportamento real do Caddy — **vale medir**, porque
      é o freio que protege toda conta de lojista.

- [ ] **AWS Business Support+ custa R$ 162/mês** (43% da conta de R$ 373) e a própria API da AWS diz
      que o plano não dá acesso ao suporte. O custo total está **dentro do teto** de R$ 800, com
      folga de R$ 427. Decisão sua manter ou voltar ao Basic.

- [x] ~~**A apresentação comercial e a ficha de cadastro em PDF dizem que o iFood e o 99Food estão
      "em homologação"**~~ — **FEITO em 12/11/2026.** Os dois documentos corrigidos e o **PDF
      regenerado e conferido** com extração de texto: "homologa" → **0 ocorrências**.
      **E a própria nota estava otimista.** Ao medir o que escrever no lugar: os 7 pedidos reais do
      iFood (19 a 30/09) são **todos da loja 1, a loja de teste do Bora** — nenhuma loja de cliente
      recebeu pedido de iFood ainda; e o 99Food tem 5 lojas autenticando e consultando pedido com
      **0 pedidos recebidos**. Por isso os documentos não ficaram com a mesma palavra: iFood
      **"No ar"**, 99Food **"Conectado"**. Também não eram 10 arquivos que importam, e sim 2: os
      outros 8 são relatórios e anotações, que são registro, não documento de cliente.
      De quebra, dois números velhos do deck: "37 versões de banco" → **70** (medido no
      `flyway_schema_history`) e "47 verificações automáticas" → **1.388**, que é o que roda no build
      da imagem.

---

## ✅ Fechado em 08 e 10/11 — o 99Food da Zirá está funcionando

**Medido em 10/11/2026 às 14:57 UTC, no banco de produção** (não na tela, que já mentiu antes):

| Loja | Status | Token da 99 até | Último polling |
|---|---|---|---|
| 18 Montreal | CONECTADO | 16:28 | 21 s atrás |
| 19 Zona Norte | **CONECTADO** | 18:25 | 21 s atrás |
| 20 São Bento | **CONECTADO** | 18:25 | 21 s atrás |
| 21 Vila Hortência | **CONECTADO** | 18:25 | 21 s atrás |
| 22 Nova Esperança | **CONECTADO** | 18:25 | 21 s atrás |

`ultimo_erro` limpo nas cinco. Zero recusa de credencial depois do conserto (a última foi
14:50:21 UTC, antes dele). As quatro buscam pedido a cada 30 segundos.

**A causa eram DOIS campos errados, não um.** A credencial da plataforma era inteira do aplicativo
de **teste**: o App ID `5764607673624955027` no `client-id`, e no campo do segredo o **nome** do app
de teste (`BR_T_BoraHapp`, 13 caracteres) em vez de um segredo. Os dois errados e coerentes entre
si — por isso nenhuma verificação de "existe credencial salva?" pegava.

Nada precisou ser digitado, e **ninguém precisou colar o App Secret**: o par certo estava guardado
na linha da loja 18, e as duas migrações o extraíram de lá.

- **V67** (08/11) — grava o APPShopID no `merchant_id` das 5 e guarda o ID numérico em
  `shop_id_canal`; o webhook casa pelos dois.
- **V68** (10/11) — o segredo. Copia o texto cifrado da loja 18, sem ninguém ver o valor em claro.
- **V69** (10/11) — o App ID. Extrai da própria loja 18, por subtração do `merchant_id`.
- **v153** (commit `d87a98d`) — o `catch` do 401 passou a logar o que a 99 respondeu **e o
  `client_id` que saiu na chamada**. Foi essa linha que destravou o 99Food depois de dois meses.
- **v157** no ar (commit `ea525f0`, 18:41 de 10/11) — os 5 consertos do pente fino: PIX pago não é
  mais cancelado quando o Asaas não responde, o 401 do polling joga o token fora, o webhook do Asaas
  roda em transação, o JWT recusa a subida sem segredo de verdade, e o card de Integrações conta a
  saúde de agora. **Frontend publicado junto** (`543fc72`): os 98 arquivos com o mesmo sha256 no
  servidor.
  **E nele foi junto o `sw.js`, que estava commitado desde hoje de manhã e NUNCA tinha sido
  publicado** — eu havia dito que esse conserto estava feito, e estava só no repositório. Medido
  depois, em aba limpa: `guia-zira.html` e `cardapio-folha.html` com o service worker controlando,
  **zero erro no console** e as fontes carregando.
- **v156 não existe neste deploy.** Já havia uma imagem `v156` de 10 dias atrás, local e no servidor,
  fora de ordem; reusar a etiqueta sobrescreveria aquela imagem e atrapalharia um rollback.
- **v155** (commit `cea9974`, 16:34 de 10/11) — a V68 deixa de abortar em banco vazio, depois
  do `flyway repair`. Na subida, o Flyway validou as 69 migrações e **não executou nenhuma**.
  **O `-Dspring.flyway.target=67` não é mais necessário para rodar os ITs.**
- **v154** (commit `08e3104`, 15:29 de 10/11) — os dois bloqueadores do cardápio público. A
  V69 rodou neste deploy pelo caminho "nada a fazer", como eu havia medido antes de subir: o App ID
  já era o certo, e **nenhum token das 5 lojas foi zerado** (conferido depois, as 5 seguem
  CONECTADO).

**O que me custou dois meses, escrito aqui para não repetir:** eu conferi que o `client-id` da
plataforma tinha 19 caracteres e começava com `5764607`, e **declarei que era o App ID certo**. Os
dois App ID têm 19 dígitos e começam com `5764607`. Comparei um comprimento e chamei de identidade.
Pior: **o App ID errado já estava escrito nesta própria lista desde 06/11** — *"aponta para outro
aplicativo (`5764607673624955027`)"* —, e eu fui pela minha anotação em vez de medir. E nenhum log
mostrava o campo que saía na chamada, porque o `catch` descartava tudo.

A 99 responde **401 com corpo vazio**: logar só a resposta não resolveria nada. O que resolveu foi
logar o campo **enviado**.

---

## ✅ Fechado em 08/11 — o servidor voltou

- **IP estático definitivo: `56.126.177.18`** (o `18.230.57.33` e o `18.231.71.3` estão mortos).
  Site em 200, `/actuator/health` em `UP`, `api` e `caddy` de pé, 0 linha de `ERROR` no log.
- **Backup**: de 6 em 6 horas no servidor (verificado com `pg_restore`, não só `--list`), mais
  cópia diária para **`C:\bora-backups`** nesta máquina — 146 dumps aqui, o último de hoje 10:55.
  **Não vai para o OneDrive de propósito:** o dump tem telefone, endereço e CPF de todo cliente de
  toda loja.
- **Orçamento da AWS** ligado (US$ 45, avisos em 80% e 100%).
- Os scripts de deploy apontavam para o IP morto desde 06/11 — corrigidos em 10 arquivos.

---

## 🔴 Novos, medidos em 10/11

- [ ] 🔴 **Ligar MFA no usuário `adm` da AWS.** Ele tem `AdministratorAccess` **sem segundo fator**,
      numa conta que guarda telefone, endereço e CPF dos clientes de todas as lojas. (A chave que
      vazou em outubro, `AKIA5S2TU3Z5UVPCBVOV`, **já foi rotacionada** — conferido em 10/11: o `adm`
      tem só a `AKIA5S2TU3Z5ZBXWDVWM`, de 01/07.)

- [x] ~~**Quando o polling falha, o status NÃO é rebaixado — a loja fica verde.**~~
      **NO AR na v160, 13/11/2026.** Rebaixa CONECTADO → ERRO **no limite de 3 falhas seguidas**
      (V72, coluna `falhas_seguidas`). **Não na primeira**, e a razão é o preço: ERRO joga a
      integração na espera de 10 minutos do `mereceNovaTentativa()`, então rebaixar num tropeço
      trocaria o defeito de silêncio por um defeito de **atraso em pedido real**. Com o ciclo de
      30 s, uma queda de verdade fica vermelha em ~1,5 min. Só rebaixa quem está CONECTADO —
      descobri medindo que existe um **quinto status, `PRONTO`**, que o comentário da entidade nem
      citava, e `AGUARDANDO_AUTORIZACAO` virar ERRO apagaria a informação de que falta um passo no
      portal.
      **A prova no ar, e não só em teste:** 4 minutos depois do deploy, o 99Food da loja 1 — que
      leva 403 em toda consulta — tentou de novo e o `falhas_seguidas` dela **virou 1**, enquanto as
      5 lojas da Zirá seguiam com 0 e polling de 5 segundos atrás. O contador novo está rodando em
      produção. **6 testes de integração** contra um Postgres de verdade, e **reprovam no código
      antigo**: "expected: \<ERRO\> but was: \<CONECTADO\>".

- [x] ~~**O log conta cada 401 do 99Food duas vezes.**~~ **NO AR na v160, 13/11/2026.** As duas
      linhas de detalhe (a do Not Found e a da credencial recusada) agora dizem **DETALHE** no
      próprio texto, então não entram mais na conta de eventos. A linha do evento continua uma só:
      `grep -c "polling falhou para a loja"` conta falhas, não linhas — e segue valendo que essa
      frase também cobre o 403 da loja 1, que não é recusa de credencial.

---


- [x] ~~**99Food da Zirá: o vínculo não existe.**~~ **FEITO em 06/11.** As **5 lojas estão vinculadas
      em ambiente de produção** ao `BR_P_BoraHapp`, com token emitido na hora. O caminho e as
      provas estão em [PASSO-A-PASSO-99FOOD.md](PASSO-A-PASSO-99FOOD.md).

- [x] ~~**Gravar o APPShopID no `merchant_id` das 5 lojas.**~~ **FEITO em 08/11 (V67).** E o
      `merchant_id` NAO era o campo principal: a loja 18 tem `client_id` proprio, que vai cru
      para a 99 sem passar pelo `merchant_id` -- a V67 reescreve os dois. O texto original:

- [x] **Quando o servidor voltar: gravar o APPShopID no `merchant_id` das 5 lojas.** A 99
      documenta que `ClientId = AppID_AppShopId`. Nós mandávamos o **ID do loja** — por isso o 403.
      Não era bloqueio da 99, era defeito nosso.

      | Loja | APPShopID a gravar |
      |---|---|
      | 18 Montreal | `zira-acaiteria` |
      | 19 Zona Norte | `zira-zona-norte` |
      | 20 São Bento | `zira-sao-bento` |
      | 21 Vila Hortência | `zira-vila-hortencia` |
      | 22 Nova Esperança | `zira-nova-esperanca` |

      **Cuidado:** esse campo também roteia o webhook (`X-App-MerchantId`), e a documentação **não
      diz** qual dos dois valores a 99 manda nesse cabeçalho. Vou **guardar os dois** e casar por
      qualquer um — adivinhar aqui derruba pedido de verdade.

- [ ] **Avisar a Zirá que a Vila Hortência está "Temporariamente fechado" na 99.** Lido na tela em
      06/11. Status posto por alguém da loja, não é defeito — mas enquanto estiver assim ela não
      recebe pedido da 99.


- [x] ~~**06/11: a conta da AWS foi encerrada e o servidor caiu.**~~ **RESOLVIDO.** Instancia e
      banco de volta, IP estatico `56.126.177.18`, DNS apontado, site em 200 e health `UP`
      (conferido 10/11). **Continua pendente so o e-mail de cobranca** (ver abaixo): o alarme
      de orcamento NAO pega falta de pagamento. O original:

- [x] **06/11: a conta da AWS foi encerrada por falta de pagamento e o servidor caiu.**
      **Medido:** portas 22, 80 e 443 de `18.230.57.33` mudas; ping sem resposta; a credencial da
      AWS guardada no PC devolvendo `InvalidClientTokenId`. O e-mail de
      `billing-subscriptions@aws.com` às **10:23** confirmou: *"your Amazon Web Services account
      has been closed"*. Conta **933793947259**.
      **O painel enganava:** `dashboard.html` abria do cache do navegador, com TODOS os números em
      traço e o Termômetro travado em "Carregando…". Casca sem dados é servidor morto.
      **Resolvido pela metade:** o dono pagou; a tela de Pagamentos mostra **saldo R$ 0,00 e
      nenhum pagamento devido**. A AWS disse que a liberação leva **até 24 h**.
      **Falta:** confirmar que a instância do Lightsail voltou e que o Bora subiu junto.

- [x] ~~**Avisar a Zirá que as 5 lojas estão fora do ar.**~~ **NAO SE APLICA MAIS:** o cardapio
      das 5 esta no ar desde 08/11. Ficaram fora de 06/11 ~10:23 a 08/11 -- se voce nunca
      avisou, vale um recado dizendo que voltou. O original:

- [x] **Avisar a Zirá que as 5 lojas estão fora do ar.** Desde as ~10:23 de 06/11 o cardápio
      público das 5 unidades não abre, e pode ficar assim até 07/11. **É recado seu, e é agora** —
      elas não têm como saber, e cliente que tenta pedir e não consegue não volta.

- [x] ~~**Backup fora da AWS.**~~ **FEITO em 08/11, na metade que importa:** dump de 6 em 6 h
      no servidor + copia diaria para **`C:\bora-backups`** nesta maquina (146 dumps, o ultimo
      hoje 10:55), verificada com `pg_restore`. **NAO vai para o OneDrive de proposito** -- o
      dump tem telefone, endereco e CPF de todo cliente. **Falta o bucket S3:** o
      `BORA_BACKUP_S3` segue indefinido e o script avisa em todo backup. O papel IAM da
      instancia ja existe; falta bucket + politica de escrita, e nenhuma chave nova. O original:

- [x] **Backup fora da AWS — esta semana quase custou tudo.** O `BORA_BACKUP_S3` nunca foi
      definido, e o S3 fica na **mesma conta** que foi encerrada. Se a AWS tivesse apagado os
      recursos, o banco das lojas ia junto e **não havia cópia em lugar nenhum**. O e-mail avisa:
      passados 90 dias a conta não pode mais ser reaberta e a AWS apaga o que sobrou.
      **Proposta:** dump do Postgres todo dia, guardado **fora da AWS**. Me autorize e eu monto.

- [x] ~~**Alarme de cobrança na AWS.**~~ **METADE FEITA em 08/11:** orcamento "BoraHapp - custo
      mensal" (US$ 45, avisos em 80% real e 100% previsto). **ELE NAO PEGA FALTA DE PAGAMENTO**
      -- so gasto em excesso. O que pegaria o caso de 06/11 e um contato de cobranca num e-mail
      que voce LEIA; hoje vai para `app-bora@hotmail.com`. **Me diga qual e-mail voce le de
      verdade e eu ponho.** O original:

- [x] **Alarme de cobrança na AWS.** A produção morreu por falta de pagamento **sem ninguém
      perceber** — descobrimos 4 h depois, e por acaso. Dá para ligar aviso de orçamento e alerta
      de fatura em aberto, para o aviso chegar antes do corte, não depois.


- [ ] **Trocar a chave de produção do Asaas.** Eu vazei a chave na sessão do dia 30/10, por um erro
      meu (carreguei o `api.env` com `source` e a mensagem de erro imprimiu a linha). Ela cobra os
      seus lojistas.
      **Caminho:** Asaas → Integrações → API → gerar nova chave → trocar a linha `ASAAS_API_KEY=`
      em `/home/ubuntu/bora/api.env` → **recriar** o container (restart não basta).
      **Me peça a recriação e eu faço.** As cobranças e assinaturas que já existem continuam
      valendo: a chave é acesso, não dona do dado.

---

## 🔑 Para terminar a cifragem (ela já está ligada desde 30/10, 14:37)

- [ ] **1º — guardar a chave `BORA_SEGREDO_COLUNAS` no seu gerenciador de senhas.**
      **Nenhum backup do servidor contém o `api.env`** (conferido em 30/10). A chave existe num só
      lugar no mundo. Leia uma vez:

      ```bash
      ssh -i ~/.ssh/bora-lightsail.pem ubuntu@56.126.177.18 "grep '^BORA_SEGREDO_COLUNAS=' /home/ubuntu/bora/api.env"
      ```

- [x] ~~**2º — cifrar as credenciais que já estavam gravadas.**~~
      **FEITO em 11/11/2026, 13:11 UTC. 20 cifradas numa transação, em 1 segundo. Agora são 39
      cifradas e 0 em texto puro** nas 6 colunas que passam pelo cifrador.
      Por coluna: 6 `config_plataforma.valor`, 4 `client_secret`, 8 `webhook_token`,
      1 `access_token`, 1 `refresh_token`. Entre elas o `client-secret` do iFood **e** o da 99 da
      plataforma — as credenciais que autorizam pedido em nome de TODAS as lojas.
      **Sem o botão, e sem entrar na sua conta.** O endpoint da tela exige login de administrador,
      então a cifragem foi feita por fora, por um programa que usa o
      `SegredoGuardado.java` **do backend, conferido por md5** — nada de reimplementar cripto. Ele
      está no repositório, em `bora-landing/deploy/cifrar-credenciais/`, com o LEIAME.
      **Como eu soube que não ia estragar nada, antes de gravar:** a chave que eu tinha na mão
      **abriu os 19 valores que a própria API já havia cifrado**. O GCM autentica o conteúdo —
      chave errada não abre, estoura. Então era a chave da API, provado, sem precisar de cópia em
      texto puro para poder voltar atrás. Depois disso, cada um dos 20 foi cifrado e decifrado de
      volta em memória e tinha de voltar igual (isso pega o caminho silencioso do conversor: quando
      a cifra falha por dentro, ele **devolve o texto puro** e só grita no log).
      **Medido depois:** 2 segundos após o commit, as 5 lojas da Zirá e o iFood da loja 1 buscaram
      pedido normalmente, `ultimo_erro` vazio, **0 erro no log da API** — ela lendo as credenciais
      já cifradas. E rodar de novo acha 0: é idempotente.
      O texto original:
      **Medido em 10/11: sao 20.** Caminho: painel → Configurações → Plataforma →
      "Credenciais no banco" → "Cifrar o que já está gravado".

- [x] ~~**3º — a 21ª credencial: `loja.asaas_webhook_token`.**~~
      **FEITA em 11/11/2026: v158 no ar às 15:40 UTC (commit `8f88a65`), cifragem às 15:41.
      Agora são 40 cifradas e 0 em texto puro.** É a loja 18, Zirá — Montreal.
      **A prova de que a API lê o valor DECIFRADO, e não o `enc:v1:` cru**, foi um teste que
      distingue as duas coisas: mandei no webhook do PIX o próprio texto cifrado como token.
      Na v157 ele teria sido **aceito** (200); na v158 voltou **401 "Token inválido"** — a
      mensagem do próprio método, com um controle de loja inexistente respondendo
      "Loja não encontrada" para provar que o caminho chega lá. E o
      `/public/loja/18/cardapio` responde 200 com 41 KB, o que prova que o conversor decifra na
      leitura sem estourar. V70 aplicada (a coluna virou `text`), 0 erro no log.
      O texto original:
      **Faltava o deploy da v158** e rodar `rodar.sh aplicar` depois dele.
      Achada **durante** a cifragem das 20: varri o `information_schema` inteiro atrás de coluna
      com cara de segredo, justamente para não cifrar 20 e deixar a 21ª saindo no `pg_dump` de todo
      dia. É a única, e tem 1 valor gravado, em claro.
      Ela nunca teve `@Convert(SegredoGuardado)` — e **o teste de cobertura não podia pegar isso**,
      porque olhava o caminho inverso: cobrava que toda coluna *com* a anotação estivesse na lista
      do serviço, não que toda coluna de segredo tivesse a anotação. Coluna que nunca ganhou a
      anotação não entra em lista nenhuma e por isso não entrava em teste nenhum. O teste passou a
      cobrar os dois lados (commit `8f88a65`).
      **Está commitado e NÃO está no ar** — e aqui a ordem não é detalhe: **cifrar antes do deploy
      quebraria o aviso de PIX pago dessa loja, em silêncio**, porque a v157 leria o `enc:v1:...`
      cru e o compararia com o token que o Asaas manda. Primeiro a v158, depois o `aplicar`.
      A ferramenta já saiu do servidor.

- [ ] 🟠 **4º — os 66 dumps do servidor (e os 146 desta máquina) ainda têm as
      credenciais em TEXTO PURO.** Cifrar o banco não limpa backup nenhum: o dump das 15:40 de
      hoje — que eu restaurei num Postgres descartável para medir uma coisa — ainda traz o
      token da loja 18 em claro, e os do servidor vão até 27/10. Isso tem um lado bom (existe
      caminho de volta se a chave se perder) e um lado ruim (quem pegar um dump antigo pega as
      credenciais). Daqui para frente os dumps nascem cifrados; o que fazer com os antigos é
      decisão sua: apagar os anteriores a 11/11, ou guardá-los como se fossem a própria chave.

- [x] ~~**5º — regerar o webhook da loja 18 no Asaas.**~~ **DECIDIDO EM 11/11: fica como está.** Você clicou e eu medi: o token **não** trocou (valor byte a byte igual ao do dump das 20:32) e **nenhum request de navegador chegou ao servidor** (235 no Caddy em 60 min, todos de marketplace, sonda de saúde e do meu próprio deploy). O motivo estrutural: `blocoWebhook` em `recebimento.js:177` **não renderiza o botão** quando o sistema acha que o aviso está de pé — **não existe como girar um webhook_token que está funcionando**, nem pela tela nem por endpoint. Se um dia precisar rotacionar por vazamento, isso falta ser construído. O risco aqui é de 7 caracteres de 32, com o token inteiro já em claro nos dumps desta máquina. O texto original: Medindo o dump
      de controle eu imprimi os **7 primeiros caracteres** do token antigo dela (de 32). Não dá
      para usar 7 de 32, e o token completo já está em claro nos 146 dumps desta mesma máquina,
      então o risco a mais é praticamente nulo — mas foi contra a minha própria regra de nunca
      imprimir valor de segredo, nem em parte, e quem decide se isso basta para trocar é você.
      **O clique é seu, e não meu:** o `POST /api/recebimento/webhook` exige papel
      ADMINISTRADOR_LOJA e age sobre a loja do próprio login (`ctx.lojaId()`) — não existe
      caminho de ADMINISTRADOR_BORA para o webhook de uma loja, e eu não entro em conta de
      ninguém nem forjo token. Caminho: entrar como a loja 18 → **Recebimento** →
      **"Religar aviso de pagamento"**. O token novo nasce já cifrado.
      **Lendo esse fluxo para te dar o caminho, achei um defeito NELE, e ele está consertado
      (commit `ca3d774`):** a guarda que decidia se religar deu certo era
      `token == null || isBlank()`, o que funciona só na primeira vez. No religar o campo tem o
      token velho: se o Asaas recusa a criação, a exceção vai só para o log, o token velho
      continua ali, a guarda não dispara e você recebe 200 — **com o webhook antigo já apagado**,
      porque ele é removido ANTES da criação. O clique que existe para consertar o aviso de
      pagamento era capaz de apagá-lo e dizer que deu certo. Agora a guarda exige que o token
      tenha **mudado**, e a mensagem diz em que estado a loja ficou.

O 1º item continua seu: eu não leio nem guardo a chave.

---

## 🟠 Cadastro e operação — nada aqui é código

- [ ] **iFood da loja 17 nunca buscou um pedido.** Diz `conectado`, mas o token venceu em 07/10 e
      **não tem Merchant ID**. Nenhum pedido do iFood entra nessa loja.
      **Caminho:** Integrações → iFood → Conectar, e autorizar no portal.

- [x] ~~**99Food da Zirá: o vínculo não existe.**~~ **SUPERADO.** O vinculo foi feito em
      06/11 (as 5 autorizadas e vinculadas ao `BR_P_BoraHapp`) e as 5 estao buscando pedido
      desde 10/11 -- ver o bloco no topo desta lista. O 403 de 04/11 descrito abaixo tinha
      DUAS causas nossas somadas, nao falta de vinculo: o `merchant_id` levava o ID numerico
      no lugar do APPShopID (V67) e a credencial da plataforma era do app de teste (V68+V69).
      O texto original, que valia com o que se sabia naquele dia:

- [x] **99Food da Zirá: o vínculo não existe, e agora está PROVADO.** Em 04/11 li a tela do
      portal da 99 (você logado como **Superadministrador**, José Camilo) e gravei no Bora o código
      real de cada uma das 5 unidades. A 99 passou a responder, a cada consulta:
      `403 "User is forbidden to access this resource"`.
      **Isso é a prova que faltava.** Até ontem o canal da loja 18 usava o apelido inventado
      `zira-acaiteria`, a 99 devolvia lista vazia e o cartão ficava verde para sempre. O teste de
      token **não serve de prova**: a 99 devolve token até para um código que não existe. Quem
      separa é a consulta de pedidos — e ela diz 403.
      **Caminho (é seu, e agora dá para fazer):** você já está logado com o perfil certo. 99Food →
      Gerenciamento da loja → Vincular estabelecimento → **"Autorização de solicitação de lote"**
      gera um link; abra-o nessa mesma sessão e autorize as 5 para o app `BR_P_BoraHapp`
      (App ID `5764607707103889279`). O link vale 7 dias.
      **A loja 18 ficou ligada de propósito**, consultando a 99 a cada 30 s. No instante em que a
      autorização existir, o 403 vira 200 e o erro some sozinho — ela é o nosso termômetro.
      Se preferir, eu pauso.

      **Estado do lado do Bora em 04/11, conferido no banco — não falta nada aqui:** as 5 lojas
      estão com `ativo = true`, `auto_aceitar = true`, segredo de webhook gravado e o código de
      roteamento da 99 único em todo o sistema. O pedido da 99 chega por **webhook**
      (`POST /public/opendelivery/v1/newEvent`) e o Bora acha a loja pelo cabeçalho
      `X-App-MerchantId` — que é exatamente esse código. Lojas 19-22 ficaram em **ERRO** de
      propósito: nesse estado o Bora tenta de novo a cada 10 min, então elas se acertam **sozinhas**
      assim que o App Secret entrar. Ninguém precisa clicar em nada depois.

- [x] ~~**Colar o App Secret do `BR_P_BoraHapp`.**~~ **FEITO em 10/11, e voce nao precisou
      colar nada** (V68 + V69). **Esta lista estava CERTA e eu nao li:** o App ID errado
      (`5764607673624955027`) ja estava escrito aqui desde 06/11. Eram DOIS campos errados,
      nao um. A loja 1 passou a usar o app de producao, como este item avisava. O original:

- [x] **Colar o App Secret do `BR_P_BoraHapp` — é o que trava as lojas 19 a 22.** A credencial
      da plataforma salva em 09/10 aponta para outro aplicativo (`5764607673624955027`) e tem 13
      caracteres; é ela que a 99 recusa na loja 1 todo dia. O par que funciona está guardado dentro
      da loja 18, no app de produção. As lojas 19-22 não têm credencial própria: herdam a da
      plataforma, que está errada.
      **Caminho:** painel → Configurações → 🔑 Credencial do app BoraHapp nos marketplaces →
      99Food → App ID `5764607707103889279` + o App Secret (portal da 99, Gerenciamento de
      aplicativo → `BR_P_BoraHapp` → Ver detalhes).
      **Eu não digito segredo — esse colar é seu.** Um colar só resolve as quatro, e conserta a
      loja 1 de quebra. Aviso: a loja 1 passa a usar o app de produção em vez do de teste.

- [x] ~~**Confirmar qual unidade é a "Zona Norte" da 99.**~~ **RESOLVIDO em 06/11.** Li o
      endereço na tela do portal da 99: *R. Firmino Mineli, 751 - Jardim Hungares, 18075-700*.
      Bate com a **loja 19**. O código `5764608427259856166` está na loja certa. As 5 unidades
      agora casam 1 a 1 **medidas**, nenhuma por eliminação.

- [ ] 🔴 **Jardim Montreal e Jardim Hungarês não estão na lista de bairros de entrega.** O
      checkout **recusa** bairro fora da lista. Hoje, um cliente que mora na porta da loja 18 não
      consegue fechar pedido no cardápio. Os Correios dizem que a Rua Antenor Maciel 393 fica no
      **Jardim Montreal** (por isso a loja 18 mudou de nome em 04/11) e que a Rua Firmino Minelli
      fica no **Jardim Hungarês**. "Jardim Tropical" existe em Sorocaba — só não é onde a loja está.
      **É decisão sua, porque é preço:** me diga a taxa de cada um e eu cadastro nas 5.

- [x] ~~**A tela diz CONECTADO com 403 em toda consulta.**~~ **NO AR na v160, 13/11/2026** — é o
      mesmo conserto do item "quando o polling falha, o status não é rebaixado", acima, com a prova
      medida em produção. A loja 18 hoje está CONECTADO **sem erro nenhum** e buscando pedido a cada
      30 s; quem está em ERRO com o 403 é a loja 1, que é a de QA.

- [x] ✅ **PROVADO AO VIVO em 04/11, 13h08: a taxa de entrega entra no total do cardápio.** Até
      hoje isso só tinha sido **lido no código**. Pedido de teste real na loja 22
      (Zirá - Jardim Nova Esperança), que tinha **zero** pedidos:
      1 Água Mineral **R$ 3,50** + bairro Jardim Nova Esperança **R$ 7,00** = **R$ 10,50**.
      No banco: `taxa_entrega = 7.00`, `bairro_entrega = Jardim Nova Esperança`,
      `valor_total = 10.50`. Pedido 139, código CD-139.
      **E a recusa também foi provada:** com o bairro "Bairro Que Nao Existe" a resposta foi
      **400 — "Ainda nao entregamos nesse bairro"**, e a loja continuou com **1** pedido, não 2.
      Nada foi gravado.
      **Cancelado em seguida** (pedido 139, status CANCELADO): o cliente de teste voltou a
      `total_gasto = 0,00`, `qtd_pedidos = 0` e `cashback = 0,00`. A devolução funciona.

- [x] ✅ **Cashback DESLIGADO nas 5 lojas da Zirá — 04/11, por decisão do dono.** O teste tinha
      mostrado que os 3% saíam sobre **R$ 10,50**, o total **com** o frete (R$ 0,32 em vez dos
      R$ 0,11 que daria sobre o produto) — a loja devolvia dinheiro em cima do que pagou ao
      motoboy. Em vez de escolher a base de cálculo, o dono mandou desligar.
      **Feito:** `cashback_percentual` de **3% para 0%** nas lojas 18, 19, 20, 21 e 22. Zero é o
      próprio desligamento (não existe campo "ativo" separado). Cor, cor secundária, logo e nome
      ficaram intactos — o salvamento só grava o que vem preenchido.
      **Provado ao vivo**, não só no banco: pedido CD-140 na loja 22 voltou `cashbackNovo = 0.0`,
      e a taxa de entrega continuou entrando (R$ 10,50 com R$ 7,00 de frete). Cancelado em seguida.
      **Nenhum cliente perdeu saldo:** as 5 lojas tinham **zero** clientes com cashback acumulado.
      **Não toquei em cliente nenhum fora da Zirá:** Sorveteria da Rosa e Pizzaria Bella Napoli
      seguem com 5%.
      **O defeito do cálculo continua no código**, adormecido: se algum dia ligarem cashback em
      qualquer loja, ele volta a incidir sobre o frete. Para consertar de verdade precisa de deploy.

- [ ] **Nenhum dos 42 produtos das lojas novas controla estoque.** Tentei provar que o
      cancelamento devolve estoque e **não deu**: na loja 22, os 42 produtos estão com `estoque`
      vazio. Não é defeito do cancelamento — é que não há estoque para devolver. Veio assim da
      matriz (loja 18), junto com a falta de `custo` que já estava anotada.

- [x] ✅ **Rastro dos testes apagado da loja 22 — 04/11.** Os 2 pedidos de teste (CD-139 e CD-140,
      os dois já cancelados), seus 2 itens, as 2 linhas de histórico e o cliente
      "TESTE BORAHAPP - NAO ENTREGAR" saíram. **A loja 22 voltou a zero pedidos e zero clientes.**
      Usei o botão próprio da plataforma (limpeza de dados de teste), que apaga **só movimentação**
      e exige digitar o nome exato da loja. Conferido no banco depois: **42 produtos, 6 bairros,
      7 horários e a integração da 99 continuam no lugar**, com a cor e o cashback em 0%.
      Estoque: nada a devolver — os 2 pedidos já estavam cancelados (a própria limpeza os deixa de
      fora para não somar estoque que nunca saiu).
      **Nenhuma outra loja foi tocada:** as 7 vendas reais da loja 18 (até 01/11) e o pedido de
      07/09 da loja 20 continuam intactos.

- [ ] **99Food da loja 1 (Sorveteria da Rosa): agora e 403, nao mais 401.** **Medido em 10/11,
      depois da V68+V69:** ela **recebe token** da 99 -- prova de que a credencial esta certa --
      e leva `403 "User is forbidden to access this resource"` **com `request_id`** na busca de
      pedido. E a loja de teste do Bora, nao um estabelecimento vinculado ao app de producao:
      erro de autorizacao, nao de credencial. **Nao e defeito nosso.** Se um dia precisar falar
      com a 99 sobre ela, o `request_id` sai no log.
      **Atualizado em 13/11/2026:** desde a v160 ela aparece como **ERRO** na tela, com o 403 no
      motivo, em vez de verde — e o `falhas_seguidas` dela já conta as tentativas. Continua não
      sendo defeito nosso; o que mudou é que a tela passou a dizer a verdade. O texto original: Ativo, sem
      `client_secret`, e o polling volta recusado a cada 10 min. É problema **diferente** do de
      cima, e na loja de QA.
      **Caminho:** Configurações → 🔑 Credencial do app BoraHapp nos marketplaces.

- [x] ~~**(opcional) Fazer o aviso de "sem pedido" contar o tempo.**~~ **NO AR na v161,
      13/11/2026** (coluna `conectado_em`, V73).
      | até 48 h | 🟡 "Conectado há X, sem pedido ainda" |
      | passou de 48 h | 🔴 "Ligada há X e nenhum pedido entrou — confira o vínculo desta loja no iFood/99Food" |
      | sem data ainda | o texto de 30/10, intacto |

      **A nota acima estava errada num ponto, e eu só descobri medindo:** o `ultima_sync` **não** é
      gravado só quando um pedido entra. São quatro caminhos, e um deles — o webhook do PIX, no
      `PublicController` — não é pedido nenhum; e o `descontarRecebido` desconta o contador sem
      mexer na data. Medido na produção: **loja 18 com `ultima_sync` de 21/10 e contador 0**, e o
      PIX da loja 1 com data e contador zerado. Aquela coluna quer dizer "última coisa que chegou
      por aqui". *(O comentário do `integracoes.js` já desconfiava disso — só faltava para onde
      apontar.)*

      **Quem carimba a data é um lugar só: a primeira busca de pedido que deu certo.** `CONECTADO`
      é escrito em **oito** lugares do código; carimbar nos oito seria garantir que o nono
      esquecesse, calado. E não reinicia ao se levantar de um erro, de propósito: uma queda de dez
      minutos não desmente uma seca de três dias.

      **Sem preenchimento retroativo, e isso é escolha.** Não havia de onde tirar a data real das
      que já estavam ligadas; chutar `now()` faria a tela dizer "conectado há 1 minuto" para uma
      loja ligada desde 10/11 — trocaria "não sei" por uma mentira precisa.

      **A prova, medida no ar:** 43 segundos depois do deploy o relógio começou **sozinho** nas
      **6** integrações que de fato buscam pedido (o iFood da loja 1 e as 5 da Zirá no 99Food), e
      ficou **nulo** nas que não buscam (PIX, WhatsApp, Rappi, o iFood da loja 17) e na que está em
      ERRO — exatamente o desenho. Meia hora depois, a **busca andou 30 s e o carimbo não se
      mexeu**: o `coalesce` segurou em produção. 1392 testes unitários e **221** de integração, 0
      falhas, e os dois testes novos do relógio **reprovam sem o `coalesce`**.

- [x] **Bairros e taxa de entrega das 5 lojas: FEITO em 04/11.** O dono passou a tabela e eu
      apliquei: **15 bairros gravados, 0 falhas** — Centro R$ 8,00, Vila Hortência R$ 6,00 e
      Jardim Tropical R$ 5,00, a mesma tabela nas cinco, sem tempo informado. Conferido pela API,
      direto no banco (0 duplicatas de bairro por loja) e no **cardápio público das cinco**, que
      já devolve os três bairros com os preços. A loja de outro cliente ficou intacta.

- [x] **O cardápio público cobra o frete de verdade — e os 6 bairros estão no ar (04/11).**
      Medido no commit que está rodando (`698e7f5`, `PublicController` 529-539): quando a loja tem
      bairro cadastrado e o pedido é entrega, o servidor **recusa** em vez de zerar — bairro em
      branco dá *"Escolha o bairro da entrega para calcularmos a taxa"* e bairro fora da lista dá
      *"Ainda não entregamos nesse bairro"*. Com bairro válido a taxa entra no total e é gravada.
      (Eu havia dito que saía R$ 0,00 em silêncio: isso é de **outro** caminho, o do balcão.)
      Como aquilo bloquearia quem mora nos bairros de três das próprias lojas, o dono completou a
      tabela no mesmo dia. **As 5 lojas agora têm os mesmos 6 bairros:** Jardim Tropical R$ 5,00 ·
      Vila Hortência R$ 6,00 · Vila Mineirão R$ 7,00 · Parque São Bento R$ 7,00 · Jardim Nova
      Esperança R$ 7,00 · Centro R$ 8,00. Conferido no banco: 6 por loja, todos ativos, **0
      duplicatas em todo o sistema**, e a loja de outro cliente intacta com os 4 dela.

- [ ] **Pedido de teste na loja 22, agendado para hoje 04/11 às 13:07.** É a única prova que falta
      do frete: tudo o que eu afirmei sobre a cobrança veio de LER o código que está rodando, não
      de ver o dinheiro na tela. A 22 foi escolhida porque nasceu hoje e tem **zero pedidos** —
      nada se confunde com venda real. O roteiro do agendamento: pedido de ENTREGA com bairro
      "Jardim Nova Esperança" (R$ 7,00), conferir se o total = produto + 7,00 na resposta E no
      banco; depois um segundo pedido com bairro inexistente, que deve levar 400 sem gravar nada;
      e por fim cancelar o pedido de teste e conferir o estorno de estoque.
      **Atenção:** o agendamento vive só nesta sessão do Claude. Se ela fechar antes das 13h, o
      pedido de teste não acontece e alguém precisa pedir de novo.

- [x] ~~**No balcão/painel, bairro fora da lista sai R$ 0,00 em silêncio.**~~ **NO AR na v160,
      13/11/2026** — e eram **dois** defeitos no mesmo método, não um. Além do zero calado: a taxa
      saía do bairro do **cadastro**, não do bairro **deste pedido** (o atendente digita "entregar
      no Centro" e o frete vinha do bairro antigo), e `clienteId == null` devolvia zero antes de
      olhar qualquer coisa, então quem pedia **sem cadastro não pagava frete nenhum**.
      Agora o bairro vem do pedido, e bairro fora da lista (ou entrega sem bairro) volta **400
      dizendo qual bairro** ficou de fora. Na tela, o aviso nasce **ao lado do campo** que ele
      explica, em vez de o campo ir a 0,00 calado.
      **Não trava venda de balcão**, e isso foi medido antes de eu mexer: o campo "Taxa" do painel
      sempre vai no corpo (o `num()` do JS devolve 0 para vazio, nunca nulo), então o caminho do 400
      só alcança quem **não informou** a taxa. Cortesia e frete combinado continuam possíveis.
      **9 testes novos, e o teste REPROVA no código antigo** — conferido desfazendo o conserto:
      "expected ResponseStatusException, but nothing was thrown".

- [x] **Horário das 5 lojas igualado em 04/11.** A 18 tinha 13:00→23:00 nos sete dias e as outras
      quatro tinham 18:00→23:00, o padrão genérico do `provisionamento.semear`. O dono autorizou
      copiar: **4 lojas gravadas**, ensaio antes mostrando o "hoje" e o "ficaria" de cada uma.
      Conferido no banco: as cinco com 7 dias, 13:00→23:00, todos abertos, **0 dias repetidos**,
      e as lojas de outros clientes intactas (loja 1 em 09:00→23:59, loja 17 em 18:00→23:00).


- [x] ~~**Dois insumos estão à venda no cardápio público da Zirá**~~ **FEITO em 13/11/2026.**
      Produtos **145 (pacoca, R$ 2,50)** e **146 (leite condensado, R$ 3,00)** desativados.
      Conferido: 0 "mantimento" ativo, e a loja 18 foi de 44 para **42 produtos ativos**.
      E o cardápio público, baixado pela internet, saiu de 41.271 para **41.033 bytes** — os dois
      saíram da página de verdade, não só da tabela.

- [x] ~~**Cinco contas de teste ativas, três delas GERENTE.**~~ **FEITO em 13/11/2026** — eram
      **4**, não 5: `operador.qa@teste.com` e `gerente.qa@teste.com` e `gerente.test@qa.test`
      (GERENTE, que vê faturamento, custo, margem e lucro) e `opqa_plano@qa.test` (OPERADOR).
      As quatro desativadas. Conferido: **0 conta de teste ativa**, e sobraram 7 usuários ativos no
      total.

- [ ] **A loja 17 (Pizzaria Bella Napoli) não tem prazo de acesso.** `acesso_ate` vazio, que o
      código trata como "nunca vence" (`Loja.java:163`). Achado em 13/11 ao alinhar as lojas da
      Zirá: **não eram duas lojas sem prazo, eram quatro** — as duas da Zirá eu alinhei às irmãs
      porque é a mesma cliente e o mesmo contrato, e a loja 1 é a de QA do Bora. **Esta é sua: eu
      não sei o prazo da Pizzaria.** Loja sem prazo some da cobrança sem ninguém notar, que é o
      mesmo buraco do item do corte por falta de pagamento.
      **Caminho:** painel da plataforma → Lojas → liberar acesso (exige data futura, teto de 180 dias).

- [ ] **A empresa da Pizzaria está sem CNPJ** (empresa 2). Não quebra nada hoje porque a emissão
      fiscal está desligada — mas quebra no dia que ligar.

---

## 🟡 Decisões suas, sem pressa

- [ ] **A taxa de 2% do PIX não cobra de ninguém** (`ASAAS_TAXA_PERCENTUAL = 0`). Os fundadores
      deviam ser a exceção isenta; hoje todos são.
      As duas saídas se excluem: **ligar os 2%** exige mudar a `precos.html` primeiro, porque ela
      diz *"nunca uma porcentagem das suas vendas"*; **não ligar** deixa a copy correta e o split
      vira código que não se usa. Hoje a copy é verdadeira por acidente.

- [ ] **A loja de QA mora em produção.** A loja 1 ("Sorveteria da Rosa" / `BoraQATest`) tem **28 dos
      36 pedidos** e **R$ 759,41 de R$ 1.091,91**. Qualquer número agregado da plataforma é hoje,
      principalmente, ela. Limpar a movimentação, arquivar a loja, ou aceitar e lembrar disso ao
      ler relatório.

- [ ] **Decidir o caminho do modo offline** (internet da loja cai). O levantamento está pronto em
      [ESTUDO-OFFLINE-2026-10-30.md](ESTUDO-OFFLINE-2026-10-30.md): é viável, e o pedido de entrega
      **não para de entrar** quando a loja cai — ele fica na nuvem. O que para é o balcão e a
      visualização. Três caminhos; eu recomendo o A agora, depois a chave de idempotência, depois o
      B limitado ao PDV. **Antes de construir o B, me peça a medição de quantas vezes a internet
      caiu em cada loja** — é leitura de log e é ela que diz se vale.

- [x] ~~**Autorizar o conserto da venda duplicada**~~ **NO AR na v160, 13/11/2026.** Cabeçalho
      `Idempotency-Key` + **índice único parcial** `uq_pedido_loja_chave_idempotencia` (V71): o
      reenvio devolve **o mesmo pedido** em vez de gravar outra venda. As duas telas que lançam venda
      mandam a chave — `novo-pedido` sorteia uma por tela aberta, e a **Frente de Caixa** renova
      **depois** de a venda entrar, porque o balconista atende o próximo na mesma tela (renovar antes
      faria a segunda venda do dia não entrar).
      A trava é o **índice**, não a consulta: dois cliques quase juntos são duas requisições em
      paralelo, as duas procuram antes de qualquer uma gravar, as duas não acham — mesma lição da
      V65. E o `catch` do conflito mora **fora** da transação que falhou, por isso o serviço é uma
      classe separada: dentro do `PedidoService` a chamada não passaria pelo proxy do Spring e o
      `@Transactional` do `criar` simplesmente não valeria.
      **Sem o cabeçalho nada muda**: cardápio público, webhooks e integração de terceiro seguem pelo
      caminho de sempre.
      **O que eu NÃO consegui provar no ar:** lançar pedido pede login de lojista, e eu não entro em
      conta de ninguém. Provado por **8 testes** no serviço e, depois, por mais **4 na fiação do
      controller** — porque os 8 continuariam verdes se o cabeçalho nunca chegasse ao serviço, e
      isso já custou aqui uma vez (21/10). Esses 4 pegam o nome trocado: conferido com
      "X-Idempotency-Key", a resposta foi "expected: \<Idempotency-Key\>".

- [ ] **"Fechamento de Caixa" não guarda nada e não existe para ontem.** Não é defeito: é
      funcionalidade que não existe. O tamanho é decisão sua — um seletor de data (pequeno) ou um
      fechamento guardado e assinado (grande).

- [x] **As cinco unidades da Zirá: FEITAS em 04/11.** Executado por mim no painel, com o dono
      logado na janela do navegador. Ensaio antes, e releitura da produção depois:
      **10 operações, 0 falhas.** Estado conferido no ar:
      #18 Zirá - Jardim Tropical · Rua Antenor Maciel, 393 - Jardim Tropical · CEP 18053-458 · 44 produtos
      #19 Zirá - Vila Mineirão · Rua Firmino Mineli, 751 - Vila Mineirão · 42 produtos
      #20 Zirá - Parque São Bento · Rua Maria de Fátima Faria, 72 - Parque São Bento · 42 produtos
      #21 Zirá - Vila Hortência · Rua Dr. Pereira da Rocha, 94 - Vila Hortência · 0 produtos
      #22 Zirá - Jardim Nova Esperança · Rua Geraldo Aparecido Rodrigues, 401 - Jardim Nova Esperança · 0 produtos
      Todas em Sorocaba/SP. As duas novas foram vinculadas ao login da Maria Eduarda, como
      esperado. **Diferença de 1 dia a conferir:** a #18 vence 23/01/2027 23:59 e as duas novas
      vencem 24/01/2027 23:59 — eu pedi `ate=2027-01-24` e o servidor grava o fim daquele dia.
      Alinhar é uma chamada com `ate=2027-01-23`, se você quiser as cinco no mesmo minuto.


- [x] **Passo 2: o cardápio das duas lojas novas — FEITO em 04/11.** Aplicado por mim no painel,
      uma loja por vez, com ensaio antes. **70 passos em cada, 0 falhas.** Conferido duas vezes:
      pela API e, por fora dela, direto no banco em leitura.
      Cada uma das novas (#21 e #22) ficou com **42 produtos, 40 com foto, 59 grupos e 639 opções
      de adicional**, cor `#5B1A8B`, secundária `#FFD100`, cashback 3% e o logo — e **0 produto
      com preço diferente** da matriz. O cardápio público das duas responde 200 com as seções na
      mesma ordem da #18.
      Os dois "mantimento" (`leite condensado`, `pacoca`) **não vazaram**: seguem só na #18.
      Nenhuma opção de adicional das novas aponta para insumo de outra loja (medido: 0).
      **Diferença pequena que eu criei:** a #21 e a #22 ficaram com **13 seções fixadas** na
      `categoria_ordem`, contra 5 da matriz — o `GET /api/categorias` devolve todas as categorias
      em uso, e eu gravei todas. A ordem que o cliente vê é a mesma; sobrou uma linha órfã
      ("mantimento") apontando para categoria que não existe nessas lojas. Não atrapalha nada
      hoje. Limpar é um PUT com as 12 que existem, se você quiser.


- [ ] **Nenhum dos 44 produtos da loja 18 tem custo gravado** (medido 04/11: `custo IS NOT NULL` = 0).
      Sem custo não há margem real, e é por isso que o número que o lojista lê sai do jeito que sai.
      Não é conserto de código: é cadastro que alguém precisa preencher.

- [x] ~~**Duas das cinco lojas da Zirá nunca vencem.**~~ A 19 e a 20 estão com `acessoAte = NULL`, que
      o código trata como "sem prazo, nunca vence" (`Loja.java:163`). O roteiro das unidades **não
      mexe** nisso — não é hora de tirar acesso de loja que já existe. Mas é o mesmo buraco do item
      do corte por falta de pagamento: loja sem prazo some da cobrança sem ninguém notar. E não há
      porta para o contrário: nada no backend põe `acessoAte` de volta em `null`, `POST
      /admin-bora/lojas` grava sempre +7 dias e `liberar-acesso` exige data futura com teto de 180.
      **RESOLVIDO em 13/11/2026, e não eram duas: eram QUATRO.** A 19 e a 20 ficaram com
      **24/01/2027**, lido da loja 18 em vez de digitado — mesma cliente, mesmo contrato. Conferido
      depois: as cinco da Zirá com prazo, **0 sem**.
      **Mas a loja 1 (QA) e a loja 17 (Pizzaria Bella Napoli) também estão com `acesso_ate` vazio**,
      e isso a lista não tinha. **A da Pizzaria é sua:** eu não sei o prazo dela, e loja sem prazo
      some da cobrança sem ninguém notar.

---

## ⚪ Um "sim" seu e eu faço — eu não escrevo em produção sem autorização

- [x] ~~**7 itens de pedido órfãos**~~ **FEITO em 13/11/2026.** Todos da loja 1, R$ 281,10 em itens
      cujo pedido não existe mais. **E eles não inflavam relatório nenhum** — isso eu medi em vez de
      supor: o único método que leria item sem passar pelo pedido
      (`PedidoItemRepository.findByLojaId`) **não tem nenhum chamador** no sistema. Apagados por
      limpeza, não por defeito. Conferido: 0 órfãos, e 52 itens no total (eram 59).
- [ ] **5 pedidos apontando para cliente apagado** — **eu NÃO toquei, de propósito.** Todos da
      **loja 1** (QA), todos já ENTREGUE ou CANCELADO, e **nenhum guarda outra identificação**
      (telefone e endereço vazios). Zerar o `cliente_id` apagaria o único registro de que aquele
      pedido teve cliente e não conserta nada: o código lê com `findByIdAndLojaId` e trata o vazio.
      **Vai junto com a decisão da loja de QA, que é sua.**
- [x] ~~**1 linha de ficha técnica fantasma**~~ **FEITO em 13/11/2026.** Era a `produto_insumo` id 2
      do "Acai 500ml Atualizado" (loja 1): o produto existe, **o insumo 2 não existe**. Apagada.
      Conferido: 0 linhas de ficha apontando para produto ou insumo que não existe.
- [x] ~~**"Vale Refeicao" repetido na loja 1**~~ **FEITO em 13/11/2026.** Eram os ids 6 e 12, e as
      duas linhas eram **idênticas em tudo menos o id** — ficou a 6. Apagar a 12 não desamarrou
      pedido nenhum: `pedido.forma_pagamento` guarda o texto, não o id. A loja 1 foi de 14 para 13
      formas.
- [x] ~~**O nome da loja no painel tem uma rede de segurança que nunca pega**~~ (`whitelabel.js:45`).
      Medido em 31/10. Quando o lojista **apaga** o campo "nome de exibição", o painel cai no texto
      neutro do HTML em vez do nome da loja. A rede está morta por três motivos somados:
      `window.Bora` é sempre `undefined` (o `const Bora` do api.js não cria propriedade em
      `window`); o `boraUser` da sessão guarda só `{nome, papel, lojaId}`, **sem `lojaNome`**; e
      `lojaNome` só vem de dois endpoints, nunca do login normal.
      **NO AR na v160, 13/11/2026.** O nome real da loja agora chega na **própria resposta de
      `/api/configuracao`** (campo transiente `nomeDaLoja`), que essa tela já pede — sem segunda
      chamada e sem depender da sessão.
      **E a nota estava errada num ponto: isto TOCAVA papel impresso.** O `guardarTema` só guardava
      o `nomeExibicao`, então com o campo apagado a **comanda da cozinha**, o fechamento do caixa e
      o **recibo do motoboy** saíam "BoraHapp" enquanto a tela mostrava o nome certo. Agora o
      `localStorage` recebe o nome já resolvido, o mesmo que a tela usa.

---

## Onde estão as outras listas

Estas ficaram como **registro**, não como pendência — todas têm um aviso no topo apontando para cá:
`PENTE-FINO-SO-VOCE-PODE.md` (27/10), `DADOS-A-DECIDIR-2026-10-27.md`, `PENDENCIAS-2026-10-24.md`,
`SO-VOCE-PODE-FAZER.md` (24/10), `O-QUE-FALTA-VOCE-FAZER.md` (23/10) e
`PENDENCIAS-30-09-2026.md`. Se um item delas não aparece nesta página, é porque já foi fechado — a
prova de cada fechamento está no relatório do dia.

**E uma pasta, não uma lista:** `documentacao-erp/` tem os 22 documentos de requisitos do ERP
(17/11/2026). Não é pendência de produção — é projeto. O que falta fechar nela está na seção de
17/11 no começo desta página.
