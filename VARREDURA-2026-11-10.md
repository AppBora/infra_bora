# Varredura da aplicação inteira — 10/11/2026

**15 agentes, escopo ponta a ponta:** backend, frontend, landing, banco, deploy, produto, preços,
segurança, custo, usabilidade e o que o site afirma. Sem lista de arquivos no briefing, porque lista
vira teto em vez de ponto de partida.

As ações ficam em [PENDENCIAS.md](PENDENCIAS.md), que é a lista viva. Este arquivo é a **prova**.

## Como ler este relatório

Relatório de agente é **hipótese, não medição**. Em 09/10 os agentes acharam 9 defeitos reais, e em
outras rodadas vários achados eram falsos. Então aqui há três níveis, e a diferença importa:

- **CONFIRMADO** — eu medi pessoalmente, com arquivo e linha ou saída de comando.
- **CAIU** — o agente marcou, eu medi, e não é verdade. Fica registrado para não voltar.
- **RELATADO** — o agente mediu e deu arquivo:linha, eu **não** reverifiquei. É crível e não é prova.

---

## 1. CONFIRMADO por mim, em ordem de gravidade

### 🔴🔴 OS DOIS QUE IMPEDEM LIBERAÇÃO — achados pelo QA de API, confirmados por mim

O QA de API **não liberou** a aplicação, e com razão. Os dois são HTTP 500 no cardápio público, que é
onde o cliente final está, e os dois estão no ar na v153.

#### A. Pedido com código de promoção dá 500 **depois** de gravar o pedido, e o uso nunca é contado

Medido pelo QA contra a API real (local): `POST /public/loja/2/pedido` com `"cupom":"LIM1"` devolveu
**500 nas duas chamadas**. No banco ficaram os pedidos 36 e 37, **ambos com o desconto aplicado**, e
`promocao.usos` continuou **0** — o limite de 1 uso nunca fecha.

O cliente vê erro e tenta de novo: **pedido duplicado**. E a loja concede desconto sem limite.

**Mecanismo, confirmado por mim — um conserto quebrou outro:**

- `PromocaoRepository.somarUmUso` é `@Modifying(clearAutomatically = true, flushAutomatically = true)`.
  O flush **exige transação ativa**.
- `DescontoService.contabilizarUso:107` o chama sem `@Transactional`.
- O `POST /loja/{lojaId}/pedido` **perdeu o `@Transactional` de propósito** — conserto de 26/10, para
  que a recusa no meio do laço de itens não deixasse pedido pela metade. A transação que restou é o
  `tx.execute` do passo 1.
- `contabilizarUso` roda no passo 2, **fora** desse `tx.execute`. Sem transação, o flush estoura:
  `TransactionRequiredException: cannot reliably process 'flush' call`.

**Por que 1345 testes verdes não pegaram** — e esta é a lição de 09/10 outra vez:
`DescontoNoCheckoutIT` é `@DataJpaTest`, que **roda dentro de uma transação**, e
`PromocaoDaDescontoDeVerdadeTest` usa **mock do repositório**. Nenhum dos dois exercita o caminho
real, que é justamente o que não tem transação. Os testes verificaram a lógica; a premissa em volta
dela é que estava errada.

Conserto: `@Transactional` em `contabilizarUso` (chamada de outro bean, então o proxy se aplica), ou
somar o uso dentro do `tx.execute`.

#### B. Endereço com mais de 500 caracteres no cardápio público perde o pedido inteiro

Medido pelo QA: 500 com `value too long for type character varying(500)` no insert de
`pedido.endereco_entrega`.

`PublicController.java:576` grava `p.enderecoEntrega = endereco.trim()` **sem passar por
`LarguraDeColuna`**. O caminho de marketplade (`PedidoService.java:418`) usa `encurtarAvisando`.

**É regressão de um defeito que o roteiro marca como resolvido.** O conserto da v126 cobriu o
caminho de marketplace e deixou o do cardápio — e o comentário do próprio código, no caminho
consertado, diz: *"o Postgres recusava o INSERT e o PEDIDO INTEIRO se perdia, com o entregador a
caminho"*. É o mesmo estrago, no caminho onde o **cliente de verdade** digita o endereço.

SUSPEITA do QA, não testada: `bairro_entrega` (varchar 100) tem o mesmo desenho na linha seguinte.

### 1.1 🔴 Minhas migrações V68 e V69 transformavam migração de dado em pré-condição de boot

**Erro meu, de hoje.** As duas tinham `IF v_quantas <> 1 THEN RAISE EXCEPTION`. O tech-lead
**reproduziu**: subiu um Postgres vazio e rodou um IT, que falhou com
`Migration of schema "public" to version "68" failed ... V68 abortada: ... e achei 0`.

Dano medido:

- **Todos os testes de integração (`*IT`) estão quebrados desde a V68.** Eram verdes até a V67.
- **Ambiente novo do zero** (sem dump) quebra na V68.
- **A V69 não estava no `flyway_schema_history`** — eu a apliquei à mão às 14:55:16, depois do
  deploy. O próximo deploy a executaria, e o token da loja de referência vence de hora em hora: se o
  deploy caísse na janela entre vencimento e renovação, a API não subiria.

**Corrigido na V69** (commit `f8f82b9`): aborta só com **ambiguidade** (mais de uma fonte); com zero
fontes avisa e sai. Os dois `UPDATE` de token foram para dentro do bloco e só rodam quando o App ID
muda — antes zerariam token em todo deploy futuro, sem motivo. Ensaiado contra a produção nos três
cenários, em `BEGIN/ROLLBACK`: valor já certo (não toca token), loja sem token, e banco vazio.

**A V68 não pode ser editada:** já está gravada como aplicada e o Flyway valida checksum
(`flyway.enabled: true`, sem `validate-on-migrate` desligado). Mudar o arquivo faz o próximo deploy
falhar na validação. Consertar exige um `flyway repair` na produção — **decisão do dono**.

**O que eu disse errado:** afirmei "1343 testes passando com as duas migrações". O surefire
**exclui `**/*IT.java`** (`pom.xml:56`), então os testes que rodam Flyway **nunca rodaram**. O número
estava certo e a cobertura que ele sugeria, não.

### 1.2 🔴 "Não consegui perguntar ao Asaas" é tratado como "o cliente não pagou", e o pedido pago é cancelado

- `PixService.cobrancaFoiPaga` devolve `false` no `catch (Exception e)` — timeout, 429, 5xx ou chave
  revogada dão o mesmo resultado que "não pago".
- `CobradorDePixService` trata esse `false` como não pago e segue para `cancelarVencidos`, que
  cancela o pedido, devolve estoque e cashback e avisa o cliente do cancelamento.

Cenário: o webhook da loja falhou, o cliente **pagou**, e na varredura de 5 minutos o Asaas estava
instável. O pedido pago vira CANCELADO.

Conserto: separar "o Asaas afirmou que não pagou" de "não consegui perguntar". No segundo caso,
pular a rodada e gritar no log.

### 1.3 🔴 O caminho real do webhook do Asaas roda SEM transação

`AssinaturaService`: o `@Transactional` da linha 380 aplica-se à sobrecarga de **5** parâmetros
(linha 389) — cujo próprio javadoc diz *"**O webhook de verdade NÃO usa esta sobrecarga**"*. A de
**6** parâmetros (linha 394), que é a que `AsaasWebhookController:117` chama, **não tem anotação**.

Efeito: `registrarPagamento`, `ativarLoja` e `repo.save(a)` gravam cada um na sua transação. Falha
no meio deixa pagamento registrado sem o acesso estendido, ou o contrário. O reenvio do Asaas cura
parcialmente — enquanto ele continuar reenviando.

(Checagem minha: em Java, anotação seguida de comentário ainda se aplica ao método seguinte, então eu
duvidei do agente. Medi as três assinaturas e a chamada do controller: ele estava certo.)

### 1.4 🔴 O 401 no polling não invalida o token em cache — e a tela fica verde

O `catch` do polling só chama `marcarPollingFalhou` (hora + mensagem). Não zera `accessToken` nem
`tokenExpiraEm`. Se o canal revogar o token antes do vencimento, o poller insiste com o token morto
por até **1 hora** na 99 e **6 horas** no iFood, e o status segue CONECTADO.

Isso ameaça diretamente o 99Food das 5 lojas da Zirá, que começou a funcionar hoje.

Conserto: no `catch`, em 401/403, zerar `accessToken` e `tokenExpiraEm` para forçar reautenticação.

**Armadilha de leitura, que vale guardar:** `ultimo_polling_em` é gravado **também na falha**. "Último
polling 21 s atrás" prova que *tentou*, não que *funcionou*. A medição de hoje só acertou porque
olhou `ultimo_erro` junto.

### 1.5 🟠 O segredo do JWT falha ABERTO, com um valor que está publicado no repositório

`JwtService.java:24`: sem `BORA_JWT_SECRET` a aplicação sobe com
`troque-este-segredo-em-producao-com-no-minimo-32-bytes!!` e só emite um `log.warn`.

Quem conhece o repositório forja JWT com `sub` = id de qualquer usuário. O papel vem do banco, então
forjar o id de um `ADMINISTRADOR_BORA` vale a plataforma inteira. A mesma chave assina os links
públicos de status e de repetir pedido.

Neste projeto isso **não é teórico**: já aconteceu a chave de cifragem parecer ausente porque
`docker restart` não relê o `--env-file`. Em produção a variável existe hoje (conferido pelo nome).

Conserto: recusar a subida se o segredo for o padrão ou tiver menos de 32 bytes. O CORS e o WhatsApp
já falham fechados — o padrão existe, só não foi aplicado aqui.

### 1.6 🟠 O Caddyfile ainda tem o IP morto como primeiro nome do bloco

`bora-landing/deploy/Caddyfile:1` — `18-230-57-33.nip.io, borahapp.com.br, www.borahapp.com.br`.
Está assim no repositório **e** no servidor.

**Medido, e menos grave do que o agente disse:** zero linhas de erro de ACME no log do Caddy, e o
certificado de `borahapp.com.br` é válido (02/11/2026 → 31/01/2027). O Caddy ainda tem certificado
daquele nome e segue consultando a renovação. O risco é a renovação falhar na janela de dezembro e
gerar ruído — não há queda hoje.

### 1.7 🟠 20 credenciais de terceiros em texto puro no banco

Por coluna: 9 `webhook_token`, 4 `client_secret`, 4 de `config_plataforma`, 1 `access_token`,
1 `refresh_token`. Entre elas o **`client-secret` do iFood da plataforma, 99 caracteres em claro** —
a credencial que autoriza pedido em nome de **todas** as lojas. Sai em todo `pg_dump`, inclusive nos
146 dumps que estão no PC.

Eram 28 em 30/10; 8 se cifraram sozinhas ao serem regravadas no uso. O conserto é um clique:
**Configurações → Plataforma → "Cifrar o que já está gravado"**, idempotente. É do dono porque exige
login de administrador.

---

## 2. CAIU — achados que eu medi e não se sustentam

### 2.1 "O corte por falta de pagamento pode estar desligado desde 06/11"

**Falso.** A API logou na subida da v153, às 14:49:44 UTC:
`Corte por falta de pagamento: LIGADO (loja com acesso vencido fica fora do ar)`. A variável existe
no `api.env`. O agente marcou como SUSPEITA e pediu conferência — comportamento certo.

### 2.2 "`CREDENCIAL-99FOOD-LOJA-1.md` versionado pode conter segredo"

**Falso.** Nenhum valor com cara de segredo: o maior token do arquivo tem 19 caracteres, que é o App
ID (público). É documento de diagnóstico. Não há nada para rotacionar.

### 2.3 "O webhook do PIX reabre pedido cancelado e rebaixa estoque em reenvio"

**Falso no que importa.** Reabrir é **deliberado e documentado** (varredura de 21/10, item 2.7): o
cancelamento devolveu o estoque, então reabrir tem de baixar de novo. E o `jaCancelado` se
autolimita — no reenvio o status já não é CANCELADO, então não baixa duas vezes. Fica só um detalhe
menor: `pagoEm` é sobrescrito a cada aviso.

### 2.4 "A recuperação de desastre está quebrada pela V68"

**Falso.** Dois agentes afirmaram isso. Medi: o dump `-Fc` **contém `flyway_schema_history` com
dados**, então restaurar o backup traz o histórico, a V68 consta como aplicada e o Flyway a pula. O
que quebra é banco **vazio** (teste, ambiente novo do zero), não restauração.

### 2.5 "O orçamento da AWS de US$ 45 vai disparar sozinho" — verdadeiro, mas o motivo muda a ação

O gasto recorrente real é ~US$ 66,7/mês, então o alerta dispara mesmo com tudo normal. Mas a causa é
o **AWS Business Support+ a US$ 29/mês** (R$ 162, 43% da conta), que ninguém está usando — a API de
suporte responde que o plano não dá acesso. Trocar o orçamento sem decidir o Support+ é remendo.

---

## 3. RELATADO pelos agentes, não reverificado por mim

Cada item tem arquivo:linha no relatório do agente. Crível, não é prova.

### Dinheiro e pedido perdido

| # | Achado | Onde |
|---|---|---|
| 3.1 | Pedido de marketplace que falha ao importar só deixa `log.warn`: repete a cada 30 s para sempre, o pedido real nunca entra e o painel segue verde | `MarketplacePoller.java:245-258` |
| 3.2 | Cancelar/avançar pedido no painel **não chega ao marketplace** quando a integração está em ERRO, e nada é registrado. Cliente do iFood espera por pedido cancelado só aqui | `IntegracaoService.java:296-298` |
| 3.3 | Cancelamento vindo do marketplace não tem a trava de concorrência que o painel tem: o mesmo CANCELLED pelo poller **e** pelo webhook pode devolver estoque e cashback em dobro | `PedidoService.java:474-490` |
| 3.4 | O cardápio público **não tem idempotência**: resposta perdida no 4G → cliente toca de novo → dois pedidos, estoque em dobro, duas cobranças PIX | `PublicController.java:435-782` |
| 3.5 | "Zero não é vazio" em pedido de marketplace: total R$ 0,00 (voucher do canal) é substituído pela soma dos itens, inflando faturamento e cashback | `PedidoService.java:410` |
| 3.6 | O estorno de cashback usa o percentual de **hoje**, não o da venda | `FidelidadeService.java:265-281` |
| 3.7 | O cancelamento devolve estoque pela ficha técnica **de hoje**; produto excluído = insumo que nunca volta | `InsumoService.java:612-627` |
| 3.8 | Pedido de marketplace pode **andar para trás** (evento atrasado tira de SAIU_PARA_ENTREGA e devolve a PRONTO) | `PedidoService.java:512-535` |
| 3.9 | A venda do PDV são **duas chamadas**: se a segunda falha, o pedido fica RECEBIDO com estoque baixado e o KDS manda preparar algo já entregue | `pdv.js:210-215` |
| 3.10 | O "lucro" e a "margem" do Desempenho **não descontam a comissão do marketplace**. Com o 99Food entrando nas 5 lojas da Zirá, cada R$ 100 por lá aparece com ~R$ 23 a mais de lucro | `DesempenhoService.java:189-190` |
| 3.11 | Item de pedido da 99 que não casa com o cadastro entra com **custo nulo e sem baixa de estoque**, só com `AUDITORIA.warn` | `PedidoService.java:383-409` |
| 3.12 | Reativar usuário **burla o limite de 15** do plano (a checagem só existe na criação) | `UsuarioService.java:110-116` |
| 3.13 | Cortesia de 7 dias **reciclável**: quem já tem conta cria loja nova e ganha mais 7 dias, sem limite por e-mail ou CNPJ | `SignupController.java:88-114` |
| 3.14 | O Módulo IA é vendido a R$ 99 com "proteção de custo", mas só 1 das 3 funções tem teto. `importarCardapio` chama a Anthropic sem limite mensal nem de tamanho | `IaService.java:187-213` |
| 3.15 | A isenção dos fundadores no split do PIX **não está gravada em lugar nenhum**: a V27 só isentou quem tinha `preco_mensal`, que não está em uso. Ligar os 2% cobraria de todos | `V27__split_por_loja.sql:7` |

### A promoção automática

| # | Achado | Onde |
|---|---|---|
| 3.16 | Os códigos de promoção são fixos (`BORA15`, `BORA15L<id>`) e **não há unicidade** em (loja, código). A busca do checkout devolve `Optional`, então duas linhas com o mesmo código provavelmente dão **500 no checkout** | `PromocaoRepository.java:18`, `V6__create_promocao.sql:17` |
| 3.17 | A promoção "automática" **não avisa ninguém**: só grava a linha e loga. O cardápio público não exibe promoção ativa. É um desconto de 15% que ninguém sabe que existe — e ela consome a única vaga do dia, bloqueando a manual | `PromocaoService.java:109` |
| 3.18 | O job roda a cada 30 min com `lojas.findAll()`, **sem olhar horário nem estado da loja**. Pode abrir promoção às 00:30 para loja fechada e queimar a cota do dia | `SaudeVendasScheduler.java:36-43` |
| 3.19 | O termômetro **mistura canal próprio com marketplace**. Queda no 99 responde com cupom no cardápio próprio, que não resolve nada no marketplace e canibaliza a venda sem comissão | `PedidoRepository.java:92-95` |
| 3.20 | Os 4 tipos de promoção da tela ("Frete grátis", "Combo do dia", "Última hora") são todos tratados como **% no carrinho**. "Frete grátis" não zera frete | `promocoes.html:28`, `DescontoService.java:80` |

### Segurança

| # | Achado | Onde |
|---|---|---|
| 3.21 | O freio de login é por `email|IP`, então **password spraying** (uma senha comum contra milhares de e-mails) nunca passa de 1 erro por chave. Não há teto por IP | `FreioDeTentativas.java:13-14` |
| 3.22 | Trocar ou redefinir a senha **não derruba os tokens já emitidos**: quem roubou um token segue entrando por até 24h | `AuthController.java:79-97` |
| 3.23 | O `webhookToken` do marketplace sai **em claro na API** e viaja na query string | `IntegracaoService.java:176-177` |
| 3.24 | O webhook do Asaas compara token com `String.equals`, não em tempo constante. O do PIX e o do WhatsApp já usam comparação segura | `AsaasWebhookController` |
| 3.25 | `/webhooks/{canal}` não confere `ativo` nem `podeOperar`: **loja suspensa por falta de pagamento continua recebendo pedido** por esse caminho | `WebhookController.java:33-46` |
| 3.26 | O `esc()` do frontend não escapa aspa simples; com CSP `unsafe-inline` e JWT em `localStorage`, qualquer XSS futuro leva o token do dono | `caixa.js:5` e outros |
| 3.27 | Admin da loja principal pode trocar senha e papel de usuário de rede, e o papel é global | `UsuarioService.java:136-141` |

**O que a segurança conferiu e está limpo:** isolamento entre lojas sem nenhuma falha (toda busca por
id passa por `findByIdAndLojaId`), o filtro JWT reconsulta o banco a cada requisição, deny-by-default
correto, CORS falha fechado, Swagger desligado, "omitir o campo em vez de negar a tela" aplicado,
upload com validação de mime e limite.

### Frontend e usabilidade

| # | Achado | Onde |
|---|---|---|
| 3.28 | O link de acompanhamento do cliente **trava para sempre** em "Pedido não encontrado" a qualquer erro do servidor (502 num deploy, 429, 500): `clearInterval` e nunca se recupera. Só 404 deveria encerrar | `acompanhar.html:84,109-112` |
| 3.29 | A caixa verde "Conectado — os pedidos chegam sozinhos" **não olha `ultimoErro`**, e "🟢 Recebendo pedidos" usa contador acumulado desde sempre. Loja parada há 3 dias segue verde, e a "última consulta" aparece sem data | `integracoes.js:191,195,489-495` |
| 3.30 | Rede ruim vira **"Failed to fetch" em inglês** no `alert()` de ~57 chamadas, inclusive no "Finalizar venda" do PDV e no cardápio público que o cliente final vê | `api.js:29-30` |
| 3.31 | A coluna "Margem" de Produtos usa o custo do **cadastro**; a venda usa o custo da **ficha técnica**. Dois números diferentes para a mesma coisa, e é por essa coluna que o lojista decide preço | `produtos.js:9-13` |
| 3.32 | O tema da loja **sobrevive ao logout**: num computador compartilhado, a loja B entra com nome, logo e cores da loja A — e a comanda impressa sai com o nome errado | `api.js:24` |
| 3.33 | "Erro 500" e "Internal Server Error" vão crus para o lojista, sem dizer o que fazer | `api.js:47-49` |
| 3.34 | `theme-color` do painel é o roxo do Bora fixo em todas as telas; o cardápio público faz certo. E o manifest usa outro roxo, diferente do `app.js` | `app.js:346` |
| 3.35 | O cashback do `novo-pedido` usa regra diferente do servidor (mostra R$ 0,00, servidor cobra R$ 0,01) — a mesma regra copiada em 3 lugares, com um esquecido | `novo-pedido.js:193` |

### Produto, regra e documentação

| # | Achado | Onde |
|---|---|---|
| 3.36 | O **banner** é salvo, servido e vendido como diferencial, e **nenhuma tela o exibe**. E não dá para remover: campo vazio manda `null` e o backend ignora `null` (idem cor secundária, logo e nome) | `ConfiguracaoLojaService.java:77` |
| 3.37 | Excluir pedido ENTREGUE é a **única correção possível** (ENTREGUE não cancela), não pede motivo, apaga o histórico de status, e o único rastro é um log de aplicação. Um GERENTE derruba o faturamento sem trilha consultável | `PedidoService.java:894,906-911` |
| 3.38 | GERENTE gerencia integrações e **vê o token do webhook**, mas o `PERMISSOES.md` diz que isso é do ADMINISTRADOR_LOJA. Código e documento divergem | `IntegracaoService.java:67,73,90` |
| 3.39 | O SLA de atraso é **tabela fixa dentro do JS** (Balcão 12, Site 30, iFood 40), sem tela e sem vir do servidor. E **trocar o entregador zera o relógio** e some o alerta de atraso | `app.js:103-105`, `PedidoService.java:643` |
| 3.40 | A mensagem do limite de usuários manda "Faça upgrade" para um plano que **não existe** | `PlanoService.java:63-64` |
| 3.41 | O balconista fixa o frete livremente, inclusive 0, sem alçada e sem registro de quem deu a cortesia — e o acerto do entregador depende dessa taxa | `PedidoService.java:277-283` |
| 3.42 | `shop_id_canal` é **só-leitura para o produto**: nada o escreve além da V67. Uma 6ª loja da 99 conectada depois não terá o campo, então o fallback do webhook que a V67 prometeu não existe para ela | `IntegracaoCanal.java:36` |
| 3.43 | Nenhuma constraint `CHECK` no banco e só 12 FKs para 31 tabelas. Já existe dado órfão: 7 `pedido_item` sem pedido, 5 pedidos apontando para cliente apagado, 1 item apontando para produto excluído | `pg_constraint` |
| 3.44 | O roteamento do webhook da 99 usa `findFirst` **sem unicidade** em `(canal, merchant_id)`. Dois lojistas com o mesmo valor fariam o pedido de um cair na loja do outro, sem erro | `OpenDeliveryWebhookController.java:194-198` |

### Documentação que mente (o tech-lead tinha razão: é pior que documentação ausente)

| # | Achado |
|---|---|
| 3.45 | O comentário da **V68** afirma que o App ID da plataforma era `5764607707103889279` — e a V69 prova que era `5764607673624955027`, o app de teste. A V68 repete o mesmo erro de "comparar e afirmar identidade" que a V69 confessa. **E ela não pode ser editada.** |
| 3.46 | O mascaramento do segredo no meu conserto de hoje cobre **só 401 e 404**. 400, 403, 5xx e timeout caem em `catch (Exception e)` → `resumo(e)` = `getMessage()` cru, que no RestClient costuma trazer o corpo da resposta. Padrão aplicado num lugar e não nos outros — o mesmo tipo de falha que eu acabei de consertar |
| 3.47 | A mensagem que o lojista lê no `ultimo_erro` diz "confira o App Shop ID desta loja e o App Secret da plataforma" — e a causa real de hoje foi o **App ID**, que a mensagem não cita |
| 3.48 | O comentário do `sw.js` diz que o cache "guarda dois arquivos de propósito", e o código guarda **toda** resposta ok de mesma origem. E o precache aponta para `styles.css?v=20260623` quando as 31 páginas pedem `?v=20261023` — código morto |
| 3.49 | O javadoc do `SegredoGuardado` diz que os dumps vão "para uma pasta sincronizada pelo OneDrive". A decisão registrada é **nunca OneDrive**, e o backup vai para `C:\bora-backups` |
| 3.50 | `O-QUE-FALTA-VOCE-FAZER.md:135` ainda tem o IP morto — a correção "em 10 arquivos" deixou esse de fora. E o IP literal está repetido em 5 scripts, que é como ele apodreceu duas vezes |
| 3.51 | Não há **nenhum teste** para o código do 401/404 que eu escrevi hoje (`grep` por `corpoDoErro` em `src/test` = 0). O mascaramento do segredo e o formato do log não são cobertos |

### O que o site e o material de venda afirmam

A regra de 09/10 mandava conferir isso nos dois sentidos, e o agente achou. **A landing pública está
alinhada** no iFood e no 99Food — o erro de "em homologação" migrou para onde o cliente também vê:

| # | Achado | Direção |
|---|---|---|
| 3.52 | A **apresentação comercial** (`apresentacao-borahapp.html:515-519`) diz iFood e 99Food "Em homologação", "situação em 30 de setembro". O iFood recebe pedido real desde 19/09 e o 99Food está em 5 lojas desde hoje | SUBESTIMA |
| 3.53 | A **ficha de cadastro do cliente** (PDF, `gerar_ficha_cadastro.py:524-525`) repete "Em homologação". Esse PDF vai para o cliente e ainda não está commitado | SUBESTIMA |
| 3.54 | O maior bloco de promessa demais é o **WhatsApp**: a landing diz "o pedido entra sozinho, sem ninguém redigitar nada" (`index.html:106-107`) e a demo mostra o robô da Meta legendado como "WhatsApp Business". O guia da Zirá admite que "o robô não anota pedido". Nenhuma loja usa | PROMETE |
| 3.55 | A tela de **Integrações do painel** diz "Conecte iFood, 99Food, Rappi, Uber Eats" — e o próprio backend diz "Hoje funcionam iFood e 99Food". A Rappi está parada | PROMETE |
| 3.56 | A mesma tela e o **manual** mandam o lojista "colar as credenciais (Merchant ID / Client ID / Secret) e copiar a URL de Webhook" — para iFood e 99Food ele **não cola nada**: o campo é somente leitura "Definido pelo suporte" | ERRADO |
| 3.57 | `pedidos.js:60` diz "Este texto é enviado AO CLIENTE no WhatsApp" (motivo de cancelamento). Só sai com Módulo IA + WhatsApp ativo, que nenhuma loja tem | PROMETE |
| 3.58 | Start/Pro/Premium seguem vivos em **6 arquivos**, inclusive `PERSONALIZACAO_WHITE_LABEL.md` (uma das fontes de verdade) e `.claude/agents/marketing.md:18`, que diz "ancorar no Pro" — contradizendo a linha 11 do próprio arquivo. **O agente de marketing lê isso** | ERRADO |
| 3.59 | `SITE_INSTITUCIONAL_...COPY.md` é o brief da landing e contradiz a landing no ar: "garantia de 30 dias" (o site diz 7), iFood/99Food "ainda não está no ar", "relatórios em PDF/Excel" (só existe CSV) | CONFUSO |
| 3.60 | Preço do Módulo IA: `precos.html:84` diz "combinamos o preço"; `PLANOS_SAAS.md`, a apresentação e a ficha dizem +R$ 99/mês | CONFUSO |
| 3.61 | Teste grátis: a landing dá a entender cobrança automática no fim; `termos.html:37` diz que **não há** cobrança automática e o **acesso é pausado** até o lojista assinar. As páginas não falam do acesso pausado | CONFUSO |
| 3.62 | "PIX online no ar" e "Cardápio por foto no ar": SUSPEITA. O único PIX real foi 1, na loja de demonstração, em 08/07; o cardápio por foto depende de uma chave no servidor que nenhum documento registra como posta | SUSPEITA |

---

## 4. Custo — dentro do teto

**R$ 373/mês medido**, folga de R$ 427 até o teto de R$ 800. Projeção: 20 lojas não mudam nada;
50 lojas com hardware maior dão R$ 554. Quem estoura o teto é ligar alta disponibilidade no banco
(R$ 745), não o número de lojas.

O maior item é o **AWS Business Support+ a R$ 162/mês** (43% da conta), que ninguém usa.

Dois pontos de performance que escalam: o poller faz um `UPDATE` por integração a cada 30 s
(~290 mil/dia com 50 lojas, só para mexer um timestamp), e a revalidação da foto do produto lê
~450 kB do banco para devolver 304.

---

## 5. Os QAs

Os dois rodaram em **somente leitura**: nenhum login, nenhum pedido de teste, nenhum cadastro. Isso
não é timidez — em 18/10 um mutante de inserção sujou a produção quatro vezes. O custo é que boa
parte do roteiro voltou como **NÃO EXECUTADO**, e isso está dito item por item.

### 5.1 QA de tela — CONFIRMADO por mim e já consertado

**As fontes do `guia-zira.html` nunca carregavam.** O QA mediu em produção: `ERR_FAILED` no console,
request de 0 byte, `document.fonts` vazio, títulos caindo para serif. Desregistrar o service worker
fazia o mesmo CSS carregar (13.976 bytes).

Causa: o `sw.js` interceptava **toda origem**. O pedido passava a ser feito pelo `fetch()` de dentro
do service worker, e a CSP `connect-src 'self'` bloqueia esse fetch; o cache não tem cópia de outra
origem, o catch relança, o navegador aborta.

A checagem de origem já existia uma linha adiante — mas decidia só **se grava no cache**. Eram duas
decisões diferentes com a mesma condição, e eu tinha tratado uma.

**E eu reescrevi esse arquivo hoje dizendo que o ERR_FAILED estava resolvido.** Para navegação de
mesma origem, estava. Para recurso de fora, continuava, e eu não conferi. Atingia o
`guia-zira.html` — o documento que vai para a equipe da loja — e o `cardapio-folha.html`.
Corrigido no commit `479f55f`.

### 5.2 QA de tela — o card verde que mente, agora medido na tela

O QA montou o estado real (`CONECTADO`, `ultimoErro="HTTP 403"`, última busca há 3h) e mediu o que o
lojista vê:

- **Card fechado:** chip verde "CONECTADO". O erro **não aparece em lugar nenhum**.
- **Card aberto, sem pedido:** o texto diz *"A busca está rodando e não dá erro"*, e o "Último erro"
  fica **335 px abaixo da dobra** numa janela de 812.
- **Card aberto, com pedido:** *"🟢 Conectado — os pedidos chegam sozinhos"*, com o 403 no rodapé.
- Com `pedidosRecebidos > 0`, o cabeçalho vira **"🟢 Recebendo pedidos"** — e esse é um contador
  acumulado desde sempre, não um sinal de agora.

A tela contradiz a si mesma, e as 5 lojas da Zirá dependem disso desde hoje.

Pontos exatos: `integracoes.js` na `card()` (~187), a caixa sem pedido (~467-472, a frase "não dá
erro" é fixa) e a caixa verde (~484).

### 5.3 QA de tela — veredito por seção

| Seção | Resultado |
|---|---|
| 1 (entrar, sair, trocar de loja) | 1.1 PASSOU. 1.2 a 1.13: **NÃO EXECUTADO** (login/escrita) |
| 29 (cardápio público, loja 17, 375px) | 29.1, 29.4 e 29.12 **PASSOU** — a conta do complemento fechou em R$ 77,90, o máximo de borda desmarca a anterior, e loja fechada trava o botão. Os outros 12: NÃO EXECUTADO (exigem fechar pedido) |
| 31 (guia e ajuda) | 31.2 e 31.3 PASSOU (com o achado 5.1). 31.1, 31.4, 31.5: NÃO EXECUTADO |
| 32 (celular, 375px) | 32.1 **PASSOU medido**: `scrollWidth` = 375 nas 29 telas, zero com rolagem lateral. 32.2, 32.3, 32.5, 32.7 passaram em parte. 32.4 e 32.6 NÃO EXECUTADO (exigem toque real e fechar pedido) |
| 2 a 24, I-A, I-B | **NÃO EXECUTADO** — exigem login e escrita |
| Regressão | **zero itens de regressão puros rodaram** |

Também medido e limpo: as 33 páginas e seus JS/CSS respondem 200, sem 404; o `sw.js` no ar é o
`borahapp-v2`; HTML e JS com `Cache-Control: no-cache`; e o Dashboard com o servidor fora do ar
mostra o banner vermelho dizendo que os números não são de agora — a armadilha de "casca sem dados"
que confundiu o diagnóstico em 06/11 não aparece mais.

**Dois achados menores:** Relatórios mostra um `!` nu no Faturamento quando a API falha
(`relatorios.js:153`), sem frase e sem banner; e `cardapio.html?loja=99999` mostra "Carregando…" e
"Loja não encontrada" ao mesmo tempo.

**Um aviso de processo que vale ler:** o QA notou que `configuracoes.html:182` traz, **dentro da tela
do lojista**, o diagnóstico interno *"o 99Food da loja 1 … client_secret de 13 caracteres"*. É texto
de plataforma vazando para quem não deveria vê-lo, e além disso ficou desatualizado hoje — a causa
real era o App ID. SUSPEITA: o QA não abriu a aba Plataforma (exige papel de administrador).

### 5.4 QA de API, regra e permissão — **não liberou**

**Como rodou, que é o que dá valor ao "passou":** em produção, só **6 GET sem login**
(`/actuator/health` 200, `/viva` 200, `/api/health` 401, `/api/integracoes` 401,
`/admin-bora/clientes` 401, `/admin-bora/config` 401). Todo o resto rodou **local**, contra o jar da
árvore atual, com Postgres 16 descartável, contas que ele mesmo criou, um servidor **falso** da 99Food
em Python, e com a cifragem e o corte por falta de pagamento **ligados**, como em produção.

Então **"PASSOU" significa "executei contra a API local real"** — não significa "passou em produção".

**Números:** 99 itens executados — **97 PASSOU, 2 FALHOU**, 33 NÃO EXECUTADO. Dos 130 itens de
regressão, rodou **54**.

**Os 2 FALHOU são os dois bloqueadores no topo deste relatório.**

**Terceira confirmação independente do problema da V68:** ele só conseguiu rodar os 211 testes de
integração com `-Dspring.flyway.target=67`. Sem isso, os 211 dão erro. *"O comando de rodar ITs
documentado no `pom.xml` não funciona hoje."* Logo, **a V68 e a V69 não foram exercitadas por ele**.

**Mais dois achados que pedem decisão, não bloqueiam:**

- **E.6:** dois "Recebi o pagamento" simultâneos → um 200 e outro **500** (duplicate key), em vez do
  409 que pergunta. Não duplicou o pagamento, mas o usuário vê erro cru. Aconteceu em 2 de 3 rodadas
  com 2 threads; no ritmo humano o 409 funciona.
- **1.5 — o freio de login pode ser contornado:** local, sem o Caddy na frente, 6 erros com
  `X-Forwarded-For` diferentes e a 7ª tentativa com a senha certa **entrou**. O `FreioDeTentativas`
  lê o **último salto** do cabeçalho por desenho, então o freio só segura se o Caddy sobrescrever o
  cabeçalho — e o `Caddyfile` **não tem `trusted_proxies`**. O QA não reconferiu o comportamento real
  do Caddy. Vale medir, porque é o freio que protege toda conta de lojista.

**Observações de permissão que ele mediu de passagem:** o `GET /admin-bora/lojas` devolve a entidade
`Loja` inteira (inclui `asaasSubcontaId`, `asaasWalletId`, `asaasOnboardingUrl`) — só o admin de
plataforma vê, mas é mais dado do que a tela precisa. E o **GERENTE vê o `webhookPath` com o token em
claro** (25.8).

**Efeito colateral que ele avisou, e é justo registrar:** ao testar o webhook do WhatsApp com
assinatura válida, a aplicação local chamou o `graph.facebook.com` com credencial falsa e levou 401.
Sem efeito, mas foi uma chamada de rede a terceiro. E um container Postgres que não era dele
desapareceu durante a primeira corrida, derrubando-a.

---

## 6. O que esta varredura NÃO cobriu

Isto é parte do resultado, não rodapé.

- **Tudo que exige login ou escrita em produção.** Os dois QAs rodaram em somente leitura: nenhum
  pedido de teste, nenhum cadastro, nenhum login. Os itens do roteiro que precisam de sessão
  autenticada voltaram como **NÃO EXECUTADO**.
- **Os testes de integração**, que estão quebrados desde a V68 (item 1.1). A suíte de 1343 testes
  que passa **não os inclui**.
- **Nenhum pedido real do 99Food** foi observado entrando. As 5 lojas autenticam e buscam; o
  primeiro pedido real ainda não chegou. O item 3.11 (item que não casa com o cadastro) só se mede
  quando chegar.
- **O que depende de variável de ambiente do servidor** foi conferido só pelo nome, nunca pelo valor.
- **A latência dos marketplaces** e o limite de carga real da instância.
- O agente de FinOps **não teve acesso SSH** (o classificador negou), então RAM, CPU, o que ocupa os
  13 GB de disco e o tamanho do banco não foram medidos.
