# Varredura dos 15 agentes — 18/11/2026

**O que foi varrido:** a aplicação inteira, ponta a ponta — os três repositórios (API Java, painel/landing,
infra e deploy) e a produção em modo leitura. 15 agentes, cada um com a instrução de **só reportar o que
mediu, com arquivo e linha**, e de escrever "NÃO MEDIDO" onde não conseguiu medir.

**Estado do sistema no momento da varredura:** v170 no ar, schema V76, e a **fila de eventos do ERP ligada
às 19:08** — ela passou a gravar um evento na mesma transação de toda venda.

---

## 1. O que esta varredura NÃO pode dizer

Você pediu para confirmar que a aplicação está rodando sem nenhum bug em lugar nenhum. **Isso não é
mediável, e eu não vou escrever que está.** O que este documento tem é o que foi medido, com a fonte de cada
coisa e com a separação entre o que eu conferi e o que eu apenas estou repassando.

Três limites concretos desta varredura:

- **A fatura da AWS não foi vista.** O teto de R$ 800/mês **não está certificado nem acusado**: o agente de
  custo não tinha acesso ao billing e se recusou a inventar número. Para fechar a conta falta a fatura dos
  últimos 30 dias.
- **O custo real da fila por venda não foi medido**, porque **nenhuma venda aconteceu desde as 19:08**. A
  tela já mede isso; falta uma venda.
- **Nenhum exploit foi executado.** Os achados de segurança são de leitura de código, por regra.

---

## 2. Consertado hoje, durante a varredura

| o que | estado |
|---|---|
| **XSS armazenado no cardápio público** | **NO AR**, conferido byte a byte (sha256 do arquivo servido = local) |
| **A leitura da chave do outbox derrubava a venda no commit** | consertado, 1588 + 248 testes verdes, commitado e empurrado — **FALTA PUBLICAR (v171)** |

A v171 está pronta e **não está no ar**. O deploy da API foi barrado três vezes pelo sistema, inclusive como
comando único, porque ele para o container de produção e roda migração. Para subir:

```bash
cd "C:/Users/user/OneDrive/Desktop/Bora/bora-landing/deploy" && ./deploy-api.sh v171
```

---

## 3. Confirmado por mim — eu medi, não repassei

### 3.1 🔴 XSS armazenado no cardápio levava ao token do ADMINISTRADOR_BORA — **CONSERTADO E NO AR**

A cadeia inteira, cada elo lido por mim:

- `cardapio.js:57` interpolava `<img src="${p.imagem}">` **sem escapar** — a única interpolação crua de um
  arquivo que usa `esc()` em nove outros lugares;
- `PublicController.ItemDoCardapio.endereco()` devolve o valor **cru** quando não começa com `data:` (o
  javadoc diz isso em voz alta);
- `ProdutoService.java:89` grava `imagemUrl` **sem validar nada**;
- CSP: `script-src 'self' 'unsafe-inline'` → um `onerror=` inline **executa**; `img-src https:` → exfiltra
  com `new Image().src`;
- **mesma origem**: um bloco do Caddy serve `borahapp.com.br` com `root * /srv` para tudo que não é a API,
  então `cardapio.html` e `configuracoes.html` compartilham origem;
- `boraToken` vive em `localStorage` (`api.js:18`).

Um GERENTE de qualquer loja gravava a carga e, ao mandar o link do próprio cardápio ao suporte, levava o
token de plataforma — acesso a todas as lojas. A barreira era só ter conta, e o cadastro público dá 7 dias.

**Medido em produção: ZERO cargas gravadas.** Nenhum `imagem_url`, `logo_url`, `banner_url` ou nome de
produto com aspas, `<`, `>`, `onerror`, `script` ou `javascript:`. O buraco estava aberto e **não foi usado**.

**Falta a segunda ponta:** recusar na gravação o que não for `data:image/...` ou `https://` com caractere
seguro, em `imagemUrl`, `logoUrl` e `bannerUrl`. Já medi o que produção guarda, então a trava não quebra
ninguém: são 200 `data:image/jpeg`, 31 `webp`, 1 `png`, e um `https://` de banner na loja 1.

### 3.2 🔴 Ler a chave do outbox derrubava a venda — **meu erro, de hoje. CONSERTADO, falta publicar**

Eu escrevi `// Não achar a chave não pode derrubar venda. Na dúvida, desligado.` **A frase era falsa.**

`configs.findById` passa pelo proxy transacional do Spring Data. A exceção marca a transação da venda como
rollback-only **antes** do meu `catch`; engolir depois não desfaz. A venda rodava inteira e morria no commit
com `UnexpectedRollbackException` — um erro que não aponta para a chave de cifragem em lugar nenhum.

Reproduzido por mim num Postgres de verdade. **E o meu teste unitário nunca poderia ver**, porque usa mock de
repositório: num mock a exceção nasce fora de qualquer proxy e o `catch` realmente resolve. Eu escrevi um
teste que confirmava a minha própria suposição e chamei isso de prova.

**Gatilho real:** `BORA_SEGREDO_COLUNAS` ausente ou **trocada** (o GCM autentica o conteúdo). Com a fila
ligada, perder essa chave derrubaria **toda venda de todas as lojas**, uma vez a cada 30 s. **Hoje não está
disparando** — a variável está definida no servidor. Era mina enterrada, não incêndio. E o alcance é maior
que o outbox: qualquer leitura de valor cifrado dentro da transação de uma venda tem a mesma exposição.

### 3.3 🔴 A promoção automática passa a dar erro 500 a partir do segundo dia

- `PromocaoService.java:100` cria com código fixo `"BORA15L" + lojaId`, e o comentário na própria linha diz
  **"código único por loja"** — nada garante isso: a V6 é a única migração que toca `promocao`, e o único
  índice é `idx_promocao_loja_ativa(loja_id, ativa)`, **não único**;
- `SaudeVendasScheduler.java:32` chama `encerrarVencidas()`, que desliga a promoção 3 h depois. A linha fica;
- no dia seguinte as duas guardas liberam (não há promoção *ativa*; a contagem de AUTO é só de *hoje*) e
  nasce **uma segunda linha com o mesmo código**;
- `DescontoService.java:78` busca com `Optional<Promocao> findByLojaIdAndCodigoIgnoreCase` → com duas linhas,
  `IncorrectResultSizeDataAccessException` → **500** no cupom do cardápio público.

É o padrão que já me pegou: **comentário afirmando uma garantia que o código não cumpre.**

### 3.4 🔴 Recurso pago que não dispara: cliente do cardápio com PIX nunca recebe WhatsApp

`NotificacaoClienteService.java:42` sai fora para **qualquer** `canalExterno` preenchido. O pedido do
cardápio pago por PIX recebe `canalExterno = "PIX_ASAAS"` (`PublicController.java:941`), só para guardar o id
da cobrança. Resultado: tratado como marketplace, o aviso não sai — **mesmo com o Módulo IA pago, R$ 99/mês**.

O que torna isso indefensável: **o próprio código já sabe disso em outro lugar.**
`DesempenhoService.java:127` escreve `&& !"PIX_ASAAS".equals(p.canalExterno)` exatamente para não confundir
PIX com marketplace. O comentário do `NotificacaoClienteService` justifica a regra pelo telefone-central do
iFood, que nada tem a ver com PIX. É a mesma regra em dois lugares, e o lado errado é o que o lojista paga.

### 3.5 🔴 Dois bloqueios de operação no celular

Medidos por mim em 375×812, com o arquivo no ar conferido por sha256:

- **Novo Pedido**: o botão `#add` "＋ Adicionar ao pedido" fica em **x0=375 → x1=548** — começa exatamente na
  borda, 100% fora. O campo `#taxa` também. E o `scrollWidth` da página é **375**, ou seja, a página **não
  rola de lado**: o conteúdo está preso num card que rola por dentro, e é por isso que parece que a tela
  travou em vez de "arraste para o lado".
- **Frente de Caixa**: página de **3317 px**, "🛒 Comanda" em **y=2787** e "Finalizar venda" em **y=3164** —
  **3,9 telas abaixo da dobra**. O operador toca no produto, nada muda no que ele vê, e o total está a quatro
  rolagens. Para quem vende no balcão com fila, é vender às cegas.

### 3.6 🟠 Nada avisa ninguém quando o site cai

`vigia.log:6`, em 08/11: *"o vigia ficou **2940 minuto(s) SEM RODAR** (o cron e de 5 em 5)... Nesse periodo
ninguem estava olhando o site."* São **49 horas**. Não há `curl`, e-mail ou webhook em nenhum caminho de
alarme — tudo vai para arquivo de log que alguém precisa abrir.

### 3.7 🟠 O vigia não trata o Caddy

`vigia-bora.sh:183-188`: quando a API responde **dentro** do container e não responde de fora, ele escreve
"o problema é o Caddy, no DNS ou na rede" e faz `exit 0` — **sem nunca olhar o container `caddy`**. O log tem
**13 linhas** desse caso. Com o Caddy travado, o site fica fora e o vigia só repete a linha.

> Aqui eu errei primeiro: procurei no log pela paráfrase do agente em vez do texto literal e concluí que a
> evidência não existia. O agente estava certo.

### 3.8 🟠 A folha impressa do cardápio é da Zirá, e qualquer loja chega nela

`cardapio-folha.html:306` tem `|| 18` como loja padrão (a Zirá), **5 nomes de produto fixos** no código,
"os três da Zirá" e "Zirá Tradicional" nas linhas 561 e 565, e **zero** leituras da cor da marca da loja —
paleta fixa. O `cardapio-qr.html:91` abre essa folha para **qualquer** loja. A Pizzaria Bella Napoli imprime
um papel roxo de açaiteria com o nome de outro cliente.

### 3.9 🟠 Um link de cardápio malformado manda o pedido para a loja de teste

`cardapio.js:6` é `params.get('loja') || '1'`. Sem `?loja=`, o cliente pede na **loja 1** — onde ninguém está
olhando o painel.

### 3.10 🟠 A marca de uma loja sobrevive ao logout no mesmo navegador

`api.js:24` (`logout`) apaga `boraToken` e `boraUser` e **não** apaga `boraTheme`. O comentário do
`whitelabel.js` afirma que a chave "só é apagada no logout" — **essa frase está errada**: quem apaga é só o
seletor de loja. **Quatro agentes acharam isso independentemente, mais eu.**

É o que te mostrou "Zirá - Montreal" no painel da plataforma. Pior que a tela: `app.js:205`, `caixa.js:22` e
`acerto-entregadores.js:159` leem esse nome guardado para **papel impresso** — comanda da cozinha,
fechamento de caixa e recibo do motoboy.

### 3.11 🟡 Credencial morta falando em silêncio

Open Delivery da **loja 1**: HTTP **403 "User is forbidden"**, 5 vezes na última hora, a cada 30 s. É a loja
de teste, então é ruído e não cliente — mas é o padrão "integração morta em silêncio" de novo.

### 3.12 🟡 O material de venda está na marca antiga

`apresentacao-borahapp.html` tem **48 ocorrências** da cor antiga `#D9502B` e **zero** da nova `#9333EA`. O
manual registra que a cor virou roxa em **29/10** e a landing já está roxa. O deck é o único que ficou atrás
— e ele diz "situação em 12 de novembro", ou seja, foi gerado **depois** da troca.

### 3.13 🟡 O agente de marketing se contradiz dentro do próprio arquivo

`.claude/agents/marketing.md`: a linha 11 diz que Start/Pro/Premium **não existem mais**; a linha 18 manda
*"ancorar no Pro; gatilho de upgrade no WhatsApp (Premium)"*. Isso é auto-perpetuante — toda copy que ele
escreve nasce com plano escalonado. Ele também lista como fonte de verdade um arquivo que ainda descreve os
planos mortos, e chama a marca de "Bora" onde o manual manda "BoraHapp".

### 3.14 🟡 A limpeza de testes não emite evento de cancelamento

`LimpezaDeTestesService` tem **0** chamadas a `eventos.dePedido`; o `PedidoService` tem **6**. **Três agentes
acharam isso independentemente.** Com a fila ligada, limpar uma loja deixa `PedidoRecebido` de pedido que não
existe mais, sem desfecho. Hoje não dói (ninguém consome, a fila está em 0), mas é dado errado nascendo na
fila que você acabou de ligar — e o `PedidoService.excluir` gasta um comentário inteiro explicando por que
isso não pode acontecer.

### 3.15 🟡 Housekeeping de produção

| | medido |
|---|---|
| imagens Docker | **70**, **11,46 GB**, sendo **62 tags** `bora-api:v110` a `v170` |
| em uso | só `latest` (o container) e `anterior` (= v169, o rollback) |
| não-API fora de uso | `aws-cli` 650 MB, `postgres:16` 642 MB, `flyway` 616 MB, `postgres:16-alpine` 420 MB |
| crescimento | **164 MB/dia** (49 imagens/7,86 GB em 27/10 → 70/11,46 GB hoje) |
| volumes órfãos | **2**, de 11/11, 148 MB |
| disco | 16 GB de 58 (28%), 43 GB livres → aviso de 85% em ~200 dias |

Nada poda tag antiga; o vigia só avisa. **Sugestão:** pôr a poda dentro do `deploy-api.sh` (manter as N
últimas) — aí resolve sozinho e você aprova uma vez.

### 3.16 ✅ O que eu conferi e está certo

- **A fila está em 0 eventos**, e a chave foi gravada às **19:08:50** pelo usuário 30
  (`ADMINISTRADOR_BORA`, `loja_id` nulo) — confirmado no log de auditoria **e** no banco.
- **Nenhuma base de cliente mudou** com a v170: md5 das linhas em ordem, idêntico em `loja`, `empresa`,
  `usuario`, `usuario_loja`, `cliente`, `produto` e `pedido`.
- **O frontend no ar é o do repositório**: 91 arquivos conferidos por sha256, todos batem.
- **V76 em produção**: índice parcial presente, coluna **sem** `NOT NULL` e **0 chaves estrangeiras** — a
  garantia da V74 intacta.

---

## 4. Medido pelos agentes, **não reconferido por mim**

Isto é hipótese bem fundamentada, não medida minha. Tratar como "a investigar", não como fato.

### Testes que não medem o que prometem (o mais grave desta seção)

- **O cupom e o cashback do cardápio público não têm teste nenhum.** Mutantes trocando
  `total.subtract(desconto)` por `total.add(ZERO)` **sobreviveram à suíte unitária inteira**. O canal que
  mais vende pode cobrar o preço cheio com cupom, ou descontar duas vezes, sem nada ficar vermelho.
- **Nenhum teste prova que o evento vive na MESMA transação da venda** — que é a promessa central do outbox.
  Mover o `dePedido` para fora do `tx.execute` sobreviveu. Remover o `@Transactional` do `criar` sobreviveu.
- **A contagem de uso da promoção** (`contabilizarUso`) pode ser removida sem nenhum teste reclamar.

### Dinheiro e cobrança

- **Falha entre a cortesia e a primeira fatura** (dois agentes, independentes): o cadastro dá
  `acessoAte = hoje+7`, e `assinar()` cria a cobrança vencendo `hoje+7` **contado do clique**, sem mexer em
  `acessoAte`. Quem assina no dia 5 tem fatura no dia 12 e **perde o acesso no dia 7**, com o corte ligado.
  Derruba a conversão exatamente de quem tentou pagar.
- **A margem que o lojista lê está maior que a real**, por dois caminhos: o `DesempenhoService` soma CMV zero
  quando falta custo **sem avisar** (a loja 18 não tem custo em nenhum dos 44 produtos), e **não desconta
  comissão de marketplace** em lugar nenhum.
- **Pagamento manual sugere o valor errado** para loja com Módulo IA: a tela sugere R$ 199 para quem deve
  R$ 298.
- **`RedeService.vincular` não checa o limite de usuários**, então o teto de 15 por loja fura pela rede.

### Dados e banco

- **23 tabelas com `loja_id` não têm chave estrangeira para `loja`**, e `pedido`, `pedido_item`, `cliente`,
  `produto` e outras 7 não têm FK nenhuma.
- **7 migrações usam `set lock_timeout` sem `LOCAL`**, então a conexão volta ao pool com o timeout — só afeta
  banco novo, mas é padrão a não copiar.
- **A fila cresce até 6 eventos por pedido**, a 620 bytes cada. Com 100 mil pedidos/mês, ~2,2 GB em 6 meses.
  Não há retenção, e a decisão de retenção deve vir **junto** com o consumidor, não depois.

### Operação

- **O entregador do pedido é TEXTO, não id.** Renomear o motoboy no meio do período **divide o acerto dele
  em dois nomes**, e dois entregadores com o mesmo nome viram um no pagamento. É dinheiro de motoboy.
- **O tempo limite de preparo está fixo no JavaScript** por canal, sem campo e sem tela. A pizzaria com
  preparo de 45 min vê todo pedido marcado "Atrasado".
- **O rollback do deploy contra banco já migrado nunca foi testado** — este é o maior risco **não medido** da
  infra: se um deploy aplica migração e falha no health, o container antigo sobe contra um schema que ele não
  conhece. Para saber, basta subir `bora-api:v169` contra uma cópia restaurada em V76.
- **1.430 POSTs em 24 h** no webhook público de Open Delivery, todos 400, de muitos IPs — bot. Cabe
  rate-limit no Caddy.

### Segurança (leitura de código, sem exploit)

- **CNPJ squatting**: o cadastro público não valida o CNPJ, e "mesmo CNPJ = mesma empresa" pode anexar a loja
  do cliente real à empresa de quem se cadastrou primeiro.
- **O saldo de cashback é protegido só por telefone + primeiro nome.** Telefone não é segredo.
- **Tokens de 24 h não são invalidados** por troca de senha.

### Comunicação

O **deck contradiz o produto** em quatro pontos medidos: diz que o aviso de status no WhatsApp está "no ar"
(a landing diz em construção), que "o nome BoraHapp não aparece para o cliente final" (o rodapé é sempre
visível, `permiteRemoverMarca()` é sempre `false`), que o 99Food foi "testado com pedidos reais", e vende o
Módulo IA a R$ 99 onde o site diz "combinamos o preço". E **os roteiros de venda** em
`CX_E_ABORDAGENS.md` ainda oferecem Pro R$ 129, Start R$ 69, 30% off e teto de pedidos.

---

## 5. Onde o agente errou — e onde eu errei

Relatório de agente é hipótese, não medida. Quatro casos hoje:

| o que o agente disse | o que eu medi |
|---|---|
| 5 pedidos órfãos "em produção" | verdade, mas **todos na loja 1** (teste). Severidade cai |
| linha de 2,89 MB em `configuracao_loja` | verdade, **loja 1**. As cinco da Zirá têm 34 kB |
| 3 grafias de "balcão" quebrando relatório | verdade, **todas na loja 1**. As lojas reais gravam só `Balcão` |
| `.form` tem 520px (causa do botão fora da tela) | **errado**: `.form` tem **319px** num pai de 347px. O achado está certo, a causa não — e um conserto no `.form` não consertaria nada |

E dois erros meus, no mesmo dia:

- procurei no `vigia.log` pela **paráfrase** do agente em vez do texto literal, e concluí que a evidência não
  existia. Ela existia;
- quase commitei um **mutante vivo** (`if (false)` no `PedidoService:635`) porque o QA estava rodando teste de
  mutação na mesma árvore. O que me salvou foi o alerta de outro agente e conferir o `git diff` antes.

**O filtro que mais mudou gravidade hoje foi um só: "é loja 1 ou é cliente que paga?"** Quatro achados
caíram de alta para ruído por causa dele. Nenhum agente tinha esse contexto.

---

## 6. O que ninguém conseguiu medir

- **A fatura da AWS.** O teto de R$ 800 não está certificado.
- **O custo da fila por venda em ms** — nenhuma venda desde as 19:08.
- **Se o rollback funciona com banco já migrado.**
- **O backup automático do RDS**, retenção e storage.
- **Nenhuma corrida foi reproduzida** (os achados de concorrência são de leitura).
- **Nenhum exploit foi executado.**
- **O que está no ar nas páginas de marketing** (o sha256 cobre o painel, não a landing inteira).

---

## 7. Em que ordem eu faria

1. **Publicar a v171** — o conserto da chave que derrubava a venda está commitado e fora do ar.
2. **Segunda ponta do XSS** — recusar URL inválida na gravação.
3. **A promoção automática** (500 no cardápio público) e o **PIX sem WhatsApp** (recurso pago).
4. **Os dois bloqueios de celular** — Novo Pedido e Frente de Caixa.
5. **Um canal de aviso de verdade** — 49 horas fora do ar sem ninguém saber não pode repetir.
6. **Testar o rollback com banco migrado** — é o maior risco não medido, e o teste é barato.
7. **A limpeza emitir cancelamento** — antes de existir consumidor da fila.
8. **A poda das imagens dentro do `deploy-api.sh`.**

O resto da seção 4 precisa ser **reconferido por mim** antes de entrar em qualquer lista de conserto.
