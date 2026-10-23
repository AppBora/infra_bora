# Varredura da aplicação inteira — 18/10/2026

Nove agentes sobre todo o sistema: 177 arquivos Java, 50 migrations, 34 telas, 39 scripts do painel,
os scripts de deploy e o servidor. Cerca de 70 achados brutos.

**Como ler este arquivo.** Cada item traz, no fim, de onde vem a certeza:

- **MEDIDO POR MIM** — eu rodei e vi acontecer. É fato. (Mas veja o 0.1: um destes era medição pela
  metade. Quando a cadeia tem mais de um pedaço, meça o pedaço que importa, não o primeiro.)
- **MEDIDO PELO AGENTE** — o agente rodou código e colou a saída. Alta confiança, ainda não reconferi.
- **LEITURA** — está escrito no código. Confiança média: agente erra, e já errou duas vezes nesta leva.
- **SUSPEITA** — ninguém provou. Trate como pergunta, não como defeito.

Nada abaixo foi consertado, salvo onde está escrito **JÁ CONSERTADO**.

---

## 0. O que eu medi na produção, e vale como fato

### 0.1 O freio contra força bruta — ERRO MEU, CORRIGIDO EM 19/10

**Eu afirmei aqui que o freio não existia. Estava errado, e o erro foi meu.**

O que eu medi em 18/10: mandei uma chamada ao `/actuator/health` com `X-Forwarded-For: 203.0.113.99`
inventado e vi o valor **no log do Caddy**. Daí eu **concluí, sem medir**, que o Caddy repassava esse
valor para a aplicação — e escrevi isso como se tivesse medido.

O que eu medi em 19/10, de verdade: subi um `caddy:2.11.4` (a mesma versão da produção) com
`reverse_proxy` e sem `trusted_proxies`, e li o que a aplicação recebe:

```
curl -H "X-Forwarded-For: 1.2.3.4"               -> app recebeu '172.18.0.1'
curl -H "X-Forwarded-For: 203.0.113.99, 9.9.9.9" -> app recebeu '172.18.0.1'
```

O Caddy **descarta** o que o cliente manda e escreve só o IP que viu no socket. A lista chega com um
item, e ele é confiável. **O freio sempre funcionou** — a trava de 5 senhas erradas em 15 minutos e a
de 10 pedidos por minuto do cardápio estão de pé.

A mudança de código (ler o último item em vez do primeiro) **ficou**, mas como defesa, não como
conserto: com um item só, os dois são o mesmo. Ela passa a valer no dia em que alguém puser
`trusted_proxies` no Caddyfile, um CDN na frente, ou trocar o proxy. Os testes e o comentário no
código foram reescritos para dizer isso, em vez de alegar uma falha que não existe.

**A lição, que vale para o resto deste arquivo:** "o cabeçalho chegou ao proxy" não é "o cabeçalho
chegou à aplicação". Medir metade do caminho e narrar o caminho inteiro é exatamente o jeito de
produzir um achado falso com cara de fato.

### 0.2 A assinatura da Zirá foi deletada no Asaas — AÇÃO DO DONO, COM DATA

```
sub_cm8016j2p9r674d3 → status INACTIVE · deleted TRUE · valor 298,00
cobranças: 1  (pay_aj14zjq8wbcfqhfx · R$ 199 · RECEIVED_IN_CASH em 15/10)
```

No nosso banco: `CANCELADA`, `acesso_ate = 26/10/2026`. O corte está ligado
(`BORA_COBRANCA_CORTE_POR_ASSINATURA=true`). **A loja sai do ar em 26/10.** Os R$ 398 estão
registrados (duas linhas de R$ 199). Ela pagou e vai ser cortada.

Como morreu, não sei. Duas possibilidades, as duas no código: alguém clicou "Ativar assinatura"
(que cancela a antiga no Asaas antes de criar a nova — ver 3.1 e 3.2), ou alguém apagou no painel do
Asaas. **MEDIDO POR MIM.**

### 0.3 Os 2% do PIX não são cobrados de ninguém

`ASAAS_TAXA_PERCENTUAL=0` no servidor, e o split só é aplicado quando a taxa é maior que zero.
A Zirá tem `split_percentual = 0,50` na coluna dela, que não chega a valer. **MEDIDO POR MIM.**

### 0.4 Dois alarmes falsos que eu derrubei

- **Token do webhook do Asaas**: dois agentes marcaram como risco. Em produção ele **existe**
  (32 caracteres). Não se aplica.
- **Fuso horário**: vários achados diziam "a imagem roda em UTC". **Está errado, e o erro era meu** —
  eu repeti isso em mensagens e num commit. O `Dockerfile:30` define
  `JAVA_TOOL_OPTIONS="-Duser.timezone=America/Sao_Paulo"`. A API decide datas em horário de Brasília.
  O que roda em UTC é só o **build** da imagem, onde os testes acontecem. Todos os achados de fuso
  em código de produção caem.

---

## 1. Dinheiro errado na cara de quem opera, hoje

### 1.1 PDV mostra um total e grava outro quando usa cashback — **FECHADO (v118, 19/10)**
O caixa marca "usar cashback", a linha **Total** continua no preço cheio, e o servidor desconta.
O cliente paga o cheio **e** perde o saldo; a gaveta fica com mais do que o sistema diz.
`assets/js/pdv.js:57-60` (não refaz o total) · `:167-173` (não há listener no `usarCashback`) ·
`:147` (manda ao servidor) · servidor desconta em `PedidoService.java:233-242`.
A tela irmã `novo-pedido.js:161-171` faz a conta certa. **MEDIDO PELO AGENTE** (rodou no harness:
tela R$ 30,00, servidor gravaria R$ 24,00).

### 1.2 O mesmo no cardápio público — **FECHADO (21/10)**
Era verdade. `atualizarEntrega` agora desconta o cashback na conta da tela e mostra a linha
"Cashback" nela, e o `ckUsarCashback` ganhou listener. O cálculo é o espelho do servidor, inclusive
o teto: o resgate nunca zera a conta, para o pedido não ficar com total R$ 0,00 (o servidor guarda
`base - 0,01`). 8 testes novos. No ar em 21/10 (`cardapio.js` + `cardapio.html`, md5 conferido no
servidor e pelo Caddy).

### 1.3 Dashboard conta PIX não pago como faturamento; o Caixa não — **FECHADO (20/10)**
O número grande da primeira tela inclui checkout abandonado. `dashboard.js:18` (`isVenda` não olha
`aguardandoPagamento`), `:106-108`, `:58`, `:75`. O caixa faz certo em `caixa.js:47`.
**MEDIDO PELO AGENTE** (mesmos dois cards do `caixa.test.mjs`: dashboard R$ 80, caixa R$ 30).

**REPRODUZI POR MIM**, subindo as duas telas com os mesmos pedidos: R$ 30 pago + R$ 50 abandonado no
checkout dava **R$ 80 no Dashboard e R$ 30 no Caixa**. Confirmado.

**O agente não citou o `canais.js:17`**, que tem a mesma regra errada. Achei procurando a regra
espalhada, e o efeito dele é pior: é a tela que decide **qual canal vale a pena**, e contar checkout
abandonado inflava o cardápio próprio justamente contra o marketplace, que nunca tem PIX pendente.

**MEDIDO NA PRODUÇÃO, e isso corrige o tamanho do problema:** **zero** pedidos com PIX pendente agora,
e só **1 PIX já foi pago** em toda a base (R$ 26,90). A divergência era real no código, mas só
aparecia nos **30 minutos** entre o checkout abandonado e o cancelamento automático do
`CobradorDePixService` — por isso ninguém viu. E aparecia justamente **durante o serviço**, quando o
lojista olha o Dashboard de passagem. Com o PIX da Zirá no ar (v116), ia começar a acontecer.

**O conserto não foi copiar a condição certa para as outras duas — foi tirar a condição das telas.**
`boraEhVenda(p)` e `boraEsperandoPix(p)` vivem em `app.js` · as três telas de dinheiro usam a mesma
função · o Dashboard passa a **mostrar** quanto está esperando PIX, em vez de só exibir um número
menor (esse dinheiro não está perdido, está em trânsito — mesmo padrão do Caixa e do Relatórios) · o
aviso fica escondido quando não há pendência.

O servidor já estava certo nos três lugares (`somaReceita`, `contaPedidosValidos`,
`RelatorioService`), então **nada mudou no backend** e não houve deploy de API.

Testes: `o-que-conta-como-venda.test.mjs` (12) e `dashboard-e-caixa-fecham-entre-si.test.mjs` (8),
que sobe as duas telas e **compara os números**. O harness ganhou o `helpersDoApp()`, que carrega as
funções **de verdade** do `app.js` em vez de dublês — um dublê faria o teste medir a regra do dublê
enquanto a tela roda com a do arquivo, que é exatamente o defeito deste item. Frontend: 92 verdes. As
7 mutações que tentei são todas pegas. Commit `2d5f59a`.

### 1.3b Os meus próprios backups de deploy eram servidos publicamente — **LIMPO (20/10)**
Achado por mim ao conferir o deploy. O meu procedimento de deploy do frontend copia
`arquivo.js` → `.antes-arquivo.js` **dentro da pasta que o Caddy serve**. Medido: o Caddy serve
arquivos com ponto, então `https://borahapp.com.br/assets/js/.antes-app.js` devolvia **200** — eram
**13** cópias do código antigo em URL adivinhável.

**Não é vazamento de segredo** (é JavaScript de painel, que já é público), mas é código velho servido
de endereço estável, e a sujeira era minha, dos deploys de hoje. Movi os 13 para
`/home/ubuntu/backups-frontend/20261020/` — **movi, não apaguei**: a URL pública agora dá 404, os
arquivos continuam lá, e o painel segue de pé. O rollback de verdade é o git, que tem toda versão
commitada.

**A corrigir no procedimento:** o backup do deploy do frontend tem que nascer fora da pasta servida.

### 1.4 "Excluir pedido" não devolve cashback nem estoque — **FECHADO (v122, 20/10)**
É o botão oferecido para "pedido de teste ou lançado errado" — justo o caso em que tudo tem que
voltar. Apaga pedido, itens e histórico; não chama `fidelidade.estornar` nem `devolucao.devolver`.
Pior: apaga os itens primeiro, então depois nem dá para recalcular.
`PedidoService.java:536-546` · a lixeira aparece em todo card para GERENTE/ADMIN (`pedidos.js:135`).
**LEITURA.**

**MEDIDO POR MIM na produção, e o defeito DISPAROU.** O único rastro que o excluir não apagava é o
contador do cliente: dois clientes da **loja 1** (a de demonstração) têm `qtd_pedidos` maior que a
contagem real — **4 pedidos foram excluídos depois de contar**. Ambos chamados "Pedido de teste de
integracao", então foi QA, não loja de verdade. **Nenhum cliente real perdeu dinheiro.** Os dois
contadores continuam errados na base da loja 1; é limpeza de dado de teste, não conserto de código.

**A armadilha do conserto ingênuo, que eu quase caí:** chamar o estorno sempre troca um defeito por
outro. O caminho natural é **cancelar o pedido de teste e depois apagar** — e no cancelamento o
estorno já rodou. Devolver de novo somaria estoque e cashback **em dobro**. Esse defeito dá de graça
em vez de tirar, então ninguém reclama e ninguém descobre.

**Como ficou** (backend `905ebaf`, frontend `4846c69`, no ar em v122): devolve **antes** de apagar,
passando o status **que o pedido tinha** — o estágio é que decide o que volta, e pedido ENTREGUE
devolve só o cashback, porque a comida foi embora · pedido **já cancelado** não devolve de novo, mas
continua sendo apagado por completo · PIX gerado e não pago conta como venda **não** contabilizada ·
a exclusão virou `apagarDaLoja(id, lojaId)`, uma consulta, porque o estorno limpa o contexto do
Hibernate e `delete(entidade)` num objeto desanexado faz **merge** antes de apagar — funcionava por
acidente · o aviso da tela passa a dizer que o dinheiro volta, e diz a coisa certa no pedido já
cancelado.

Testes: `ExcluirPedidoDevolveOQueConsumiuTest` (11), `ApagarPedidoNaoVazaEntreLojasIT` (5),
`excluir-pedido-avisa.test.mjs` (5). Backend 484 + 67 de integração, frontend 72. As 7 mutações que
tentei são todas pegas.

### 1.4b Nenhum teste do caminho do deploy protegia as consultas SQL — **FECHADO (v122)**
**MEDIDO POR MIM, três vezes no mesmo dia.** Mutações dentro de uma `@Query` passavam com a suíte
inteira verde. A pior: trocar `and p.lojaId = :lojaId` por **`or`** na exclusão de pedido **apaga
todos os pedidos da loja** a cada clique na lixeira — e 481 testes passavam. Só o teste de integração
acusava, e os `*IT` são excluídos do `mvn test` (`pom.xml:34`) **e do build da imagem do deploy**,
porque precisam de um Postgres no ar.

Consertar caso a caso não resolvia: o próximo `@Modifying` cairia no mesmo buraco. O
`TodaConsultaQueEscreveFiltraPorLojaTest` lê **todas** as consultas de escrita do projeto e cobra o
filtro de loja ligado por `and`. Tem um teste extra que confere se ele está realmente achando as
consultas — sem isso, um regex quebrado faria os outros dois passarem medindo nada.

### 1.4c Duas consultas de escrita sem filtro de loja — **SEM BRECHA ABERTA, mas registrado**
Achei ao escrever o teste acima. `PedidoRepository.amarrarAoAcerto` e `PromocaoRepository.somarUmUso`
escrevem no banco sem cláusula de loja.

**Não é brecha:** medi os chamadores, e os ids vêm de leituras já filtradas —
`entregasParaAcerto(lojaId, ...)` em `AcertoEntregadorService:71` e `resolver(lojaId, codigo, total)`
em `DescontoService:56`. Nenhuma das duas aceita um id que não tenha passado pela loja.

**O que falta é defesa em profundidade:** se amanhã alguém chamar esses métodos por outro caminho,
nada no SQL impede. Corrigir exige mudar as assinaturas e os chamadores, então estão na lista de
exceções do teste, cada uma com o porquê escrito. **Não fiz** — é decisão do dono.

### 1.5 Saldo de cashback é lido-somado-gravado em Java, sem trava — **FECHADO (v129, 21/10)**
Era verdade. Toda mexida no saldo saiu do Java e virou SQL, no mesmo molde do estoque:
`registrarVenda`, `debitarSeTiver`, `creditar` e `desfazerVenda`. As duas que **gastam** carregam
`and coalesce(cashback, 0) >= :usado` — é o banco que recusa gastar o que não tem.

Quem gasta e não consegue recebe **409 "o seu saldo de cashback mudou enquanto você fechava o
pedido"**, e isso é deliberado: o desconto já saiu do total que o cliente vai pagar quando a linha
roda, então gravar o pedido daria desconto que ninguém pagou. Os dois chamadores estão em transação,
então o pedido inteiro é desfeito. Com resgate zero (webhook de pagamento, pedido de marketplace)
nunca estoura.

Três assimetrias de propósito, cada uma com teste: **devolver** nunca é recusado (foi a venda que
não aconteceu), o **estorno** nunca estoura (senão o lojista não conseguiria cancelar pedido nenhum),
e o `desfazerVenda` usa `greatest(0, ...)` nas três colunas que diminui — se a loja mudou o
percentual entre a venda e o cancelamento, a conta pode dar negativo, e saldo negativo virava
desconto impossível na próxima compra.

16 testes contra Postgres de verdade (`SaldoDeCashbackEhAtomicoIT`), inclusive duas transações
simultâneas disputando o mesmo saldo.

---

## 2. Estoque

### 2.1 Pedido de marketplace não baixa estoque nenhum — **FECHADO (v119, 20/10)**
iFood, 99 e Rappi: o canal que mais vende é o único que não mexe na prateleira. O custo do item
também fica em branco, então CMV e margem ignoram toda venda de marketplace.
`PedidoService.java:313-325` — o item nasce só com descrição, quantidade, preço e subtotal.
Raiz: `dto/InboundOrder.java:48` não tem `produtoId`. O gancho vem no payload e é jogado fora: o
iFood manda `externalCode` ("7470") e a 99 também ("PIZZA-CAL"). **LEITURA** (dois agentes, separados,
chegaram ao mesmo ponto).

**MEDIDO POR MIM na produção em 20/10**, antes de consertar: dos **15** itens de pedido de
marketplace gravados, **14 estão sem `produto_id` e sem `custo_unitario`**. São 7 pedidos de iFood, o
último em 30/09 — a janela da homologação, não venda de cliente. O conserto chega antes do volume.

**O que o agente não viu, e mudava o conserto:** casar pelo nome não funcionaria. O
`MarketplaceNormalizer` monta o campo `nome` para a TELA, colando complemento e observação
(`"Açaí 500ml (+ Granola) — obs: sem cebola"`). Isso não bate com `produto.nome` em nenhum item com
adicional — numa açaiteria, quase todo item. Foi preciso levar um `nomeLimpo` separado no DTO.

**Como ficou** (backend `78d154d`, frontend `3309d68`, no ar em v119):
`produto.codigo_externo` (V51, índice único parcial por loja) · `resolverProduto` casa pelo código,
depois pelo nome limpo sem acento/caixa/espaço, **exato** — nome ambíguo não casa, porque baixar o
estoque do produto errado é pior que não baixar nenhum · casou: grava `produto_id`, consome a ficha
e usa o custo dela, senão baixa o produto · **não casou: o pedido entra igual e sai um WARN** — comida
vendida nunca pode ser recusada · Produtos ganhou o campo "Código no iFood / 99", com 409 e o nome do
produto dono quando o código repete.
Testes: `EstoqueDoMarketplaceTest` (13) e `CodigoDoMarketplaceNaoRepeteTest` (7); backend 429 verdes,
frontend 53. As 51 migrações aplicadas num Postgres 16 limpo e o índice conferido nos três casos.

### 2.2 Nada checa estoque antes de vender — **FECHADO (v120, 20/10)**
O saldo vai a negativo sem limite. Uma chamada do cardápio pode levar um produto a −4950
(50 itens × 99). `ProdutoRepository.java:32-34` e `InsumoRepository.java:19-21` não têm
`and estoque >= :qtd`. Varredura do backend por checagem de esgotado: **uma** ocorrência, e é
tradução de texto de erro da 99. **LEITURA.**

**MEDIDO POR MIM na produção em 20/10**, antes de consertar: **nenhum** dos 123 produtos controla
estoque (todos com `estoque` nulo), e os únicos insumos vivem na **loja 1**, a de demonstração, onde
`Polpa de Acai Organico` está em **−11,5** por teste de QA. **Zero** itens vendidos com ficha. Ou
seja: o defeito nunca machucou loja de verdade, porque ninguém ligou controle de estoque ainda. Mas o
manual do lojista manda cadastrar estoque, e o problema nasce no dia em que ele obedecer.

**A regra não é a mesma nos três canais**, e o que decide é **quem está com o produto na mão**:
- **cardápio público** — o cliente não tem nada na mão: **recusa**, 409 nomeando o produto. Era por
  aqui que vinha o −4950.
- **balcão** — o operador está com o açaí na mão: **deixa vender** e avisa. Travar a venda com o
  cliente na frente é pior que o saldo negativo, que pelo menos denuncia a contagem errada.
- **marketplace** — já aceito no iFood, com o entregador a caminho: **nunca recusa**, e avisa.

**Como ficou** (backend `cd209ae`, frontend `da4e36b`, no ar em v120): `baixarEstoqueSeTiver` e
`consumirSeTiver` com a cláusula **no banco** — duas vendas simultâneas leriam o mesmo saldo e as duas
passariam · estoque **nulo devolve 1**, de propósito, senão o cardápio inteiro pararia de vender ·
`consumirSeTiver` e `mexerNoEstoque` separados, porque devolução de cancelamento nunca pode ser
recusada por falta de saldo · o endpoint do pedido do cardápio virou **`@Transactional`**, que é
pré-requisito: sem isso, recusar o terceiro item deixava pedido órfão e o estoque dos dois primeiros
já baixado · o menu marca **esgotado antes**, para o cliente não montar o carrinho e levar a notícia
no fim · o nome do **insumo** fica no log do lojista e não chega ao cliente.

**Provado no ar**, sem escrever nada: no cardápio da loja 1, `Acai 500ml Atualizado` (ficha ligada ao
insumo negativo) volta `esgotado: true`; `Produto com Ficha QA` (4800 g para uma ficha de 100 g) volta
`false`. Na loja 18, os 33 produtos trazem o campo e **nenhum** vem `true` — correto, porque nenhum
controla estoque.

**ACHADO SOBRE O PRÓPRIO CONSERTO:** apaguei a cláusula SQL das duas consultas e a suíte de 451
passou **verde** — só o IT acusou, e os `*IT` são excluídos do `mvn test` (pom.xml:34) e do build da
imagem do deploy. A trava mais importante não tinha proteção no caminho que o deploy percorre. Por
isso o `CadaCanalDecideSozinhoSobreEstoqueTest` também lê a consulta no fonte. As 7 mutações que
tentei são todas pegas agora.

**O QUE FICOU DE FORA, e é do dono decidir:** o aviso do balcão vai só para o **log**. Quem opera a
loja não lê log, então na prática ele não vê. Posso fazer o aviso aparecer na tela depois da venda
("Açaí 500ml ficou com estoque negativo") — é mais trabalho e muda a resposta da API. E o item 2.3
abaixo continua aberto: salvar um produto ainda sobrescreve o estoque.

### 2.3 Salvar um produto sobrescreve o estoque com o número velho da tela — **FECHADO (v121, 20/10)**
O lojista abre Produtos às 18h, a loja vende 12 durante a noite, ele corrige só o preço às 21h — e as
12 baixas somem. Sem log, sem aviso.
`assets/js/produtos.js:41-47` (o payload sempre inclui `estoque`) · `:74` (preenche do array
carregado uma vez) · `ProdutoService.java:57` (`p.estoque = dados.estoque` sem condição — compare com
a linha 59, onde a foto é protegida). Mesma coisa no insumo. **LEITURA.**

**MEDIDO POR MIM, e é mais largo que o relatado.** O mesmo cano tem dois sentidos:

1. O que o agente viu: o formulário de Produtos manda `estoque` sempre, com o número carregado na
   abertura da tela.
2. **O que o agente não podia ver, porque eu criei hoje:** as telas de **Estoque** e **Contagem**
   ajustam estoque mandando o **cadastro inteiro** de volta pelo mesmo `PUT /api/produtos/{id}`. O
   cadastro que elas conhecem não tem todos os campos — nenhuma das duas manda `codigoExterno`. Como
   o `atualizar` gravava esse campo sem condição, **cada ajuste de estoque apagaria o código do
   marketplace que entrou na v119**, e com ele a baixa de estoque dos pedidos de iFood/99. Um conserto
   meu quebrando outro conserto meu, no mesmo dia.

**Por que separei em vez de proteger campo por campo:** eram duas operações passando pela mesma
requisição — "editar o cadastro" e "dizer quanto tem na prateleira". Enquanto compartilharem o cano,
qualquer tela com cadastro incompleto apaga o que não conhece, e o próximo campo que alguém adicionar
cai no mesmo buraco. Separando, o cadastro **não tem como** mexer no estoque.

**Como ficou** (backend `ee325da`, frontend `9798b4f`, no ar em v121):
`PUT /api/produtos/{id}/estoque` e `PUT /api/insumos/{id}/estoque`, com `DEFINIR` (valor contado;
nulo = para de controlar) ou `AJUSTAR` (soma no banco, recusa ficar negativo) · `definirEstoque` mexe
em **uma** coluna, porque um `save()` da entidade grava a linha toda · `atualizar` não toca mais em
estoque, e a **criação** continua aceitando a quantidade inicial · `DEFINIR` sempre vence, mesmo com
venda no meio: o lojista andou na prateleira e contou · `atualizarProduto` foi **removido** do
`api.js` — enquanto o atalho existir, alguém usa de novo.

**Provado no ar:** o jar que está rodando tem o DTO e os dois endpoints; os 5 arquivos JS servidos
têm as funções novas e **zero** ocorrências do atalho antigo; sem erro no log.

Testes: `SalvarCadastroNaoApagaEstoqueTest` (17), `EstoqueNaoPerdeBaixaIT` +11,
`estoque-nao-volta-pelo-cadastro.test.mjs` (9). Backend 470 + 62 de integração, frontend 67.
De novo as 2 mutações de SQL passaram verdes na suíte e só o IT acusou — por isso o teste também lê a
`@Query` no fonte. As 6 mutações que tentei são todas pegas.

### 2.4 Estoque e Contagem fazem "ler, somar e gravar" no navegador — **FECHADO EM PARTE (v121)**
O `+1` do ajuste rápido é "grava 31" com base no que a tela leu antes. Na Contagem é por desenho: o
lojista conta 20 minutos e aplica — tudo que vendeu nesse tempo some.
`estoque.js:9-13` · `contagem.js:31-37`. **LEITURA.**

**O que fechou junto com o 2.3:** o `+` e o `−` do ajuste rápido agora mandam o **delta** e a conta é
do banco (`somarAoEstoque`). Dois cliques rápidos contam os dois, e o número da lista não entra na
conta.

**O que NÃO é defeito e fica como está, por decisão:** o valor absoluto da Contagem e o campo
"definir" **vencem de propósito**, mesmo que tenha havido venda entre a leitura e o clique. O lojista
andou na prateleira e contou — o número dele é a verdade. Chamar isso de defeito seria inverter o
sentido de uma contagem física.

**O que sobrou, pequeno:** a Contagem decide *quais* produtos mudaram comparando o valor digitado com
o `p.estoque` da lista carregada. Se o valor digitado coincidir com o número velho e o real tiver
mudado, aquele produto é pulado. Não perde dado — só deixa de corrigir um item. **MEDIDO POR MIM na
leitura do código, não visto acontecer.**

### 2.5 Excluir um insumo deixa a ficha fantasma e o produto para de baixar — **FECHADO (v129, 21/10)**
Era verdade, e os dois lados foram fechados:

**Não deixa mais criar fantasma.** Excluir um insumo que está em alguma ficha é **recusado**, e a
mensagem diz **em quais produtos** ele está — é a informação que falta para decidir, senão o lojista
fica adivinhando qual receita mexer. Insumo que não está em ficha nenhuma continua sendo excluído.

**E a fantasma que já existe para de mentir.** Ficha com **todos** os insumos apagados devolve
`null`, não zero: o produto passa a se comportar como produto **sem** ficha — baixa o próprio
estoque, grava `consumiuFicha = false`, e o cancelamento devolve a unidade certa. Ficha
**parcialmente** fantasma consome o que existe (aí `consumiuFicha = true` é verdade) e **avisa no
log**, porque o custo fica menor do que deveria.

**Medido na produção em 21/10:** existe uma ficha fantasma hoje — loja 1 (Sorveteria da Rosa),
produto "Acai 500ml Atualizado", linha para o insumo 2, que não existe. É o caso parcial: a outra
linha (insumo 1) está viva. O estoque está correto; o que está errado é o **custo** desse produto,
que ignora 0,2 de um insumo apagado — em 26 vendas já registradas. O insumo não existe mais, então
o custo antigo é irrecuperável. **Item do dono:** tirar essa linha da ficha do produto no painel,
ou pôr no lugar o insumo que faz as vezes dela.

### 2.6 Complemento nunca baixa estoque — **FECHADO (v130, 21/10) — era decisão, e o dono decidiu**
Não era defeito: `complemento_item` tinha só `(id, loja_id, grupo_id, nome, preco)` — sem campo de
estoque e sem ligação com insumo. Numa açaiteria metade do valor da venda está nos adicionais, e nada
disso saía do estoque nem entrava no custo. O modelo não comportava, então o caminho mudava o que o
lojista cadastra, e a escolha era dele.

**Das três saídas que eu trouxe, ele escolheu ligar o adicional ao INSUMO** (e não dar estoque próprio
ao adicional). O motivo da escolha importa para quem mexer nisto depois: a mesma granola está na
ficha técnica dos produtos **e** nos adicionais. Dois lugares para contar a mesma granola nunca fecham
entre si — e pelo insumo o consumo reaproveita o caminho que já existe, já é atômico no banco e já
recusa venda sem estoque.

**O que está no ar:**

- **V55**: `insumo_id` e `quantidade numeric(14,4)` no `complemento_item`, com **chave estrangeira**.
  A FK é deliberada e é a diferença em relação a `produto_insumo`, que não tem nenhuma — e foi
  exatamente isso que produziu a ficha fantasma do item 2.5. O serviço recusa primeiro, com a
  mensagem boa; a FK é a rede embaixo. Conferido na produção: a migração rodou, a FK existe, e os
  **1202 adicionais que já existiam estão com insumo nulo** — nada mudou para eles.
- **Os dois campos andam juntos.** Sem um deles, os dois ficam nulos, que é o padrão "adicional que
  não mexe no estoque" e é o comportamento de tudo que foi cadastrado antes.
- **Cardápio público consome RECUSANDO**, e a mensagem fala do adicional: *"O adicional 'Granola'
  acabou. Tire ele do pedido ou escolha outro."* Dizer "o produto esgotou" mandaria o cliente embora
  de uma venda que ainda dá para fazer sem o extra — o açaí tem.
- **Balcão consome SEM recusar**: o operador está com o copo na mão. Mas o saldo negativo fica
  escrito no log, que era o que faltava no item 2.2.
- **Cancelar devolve**, com a lista **gravada no item** — não relida do cadastro. Os adicionais são
  apagados e recriados a cada gravação do produto, com ids novos; reler pelo id devolveria o insumo
  de **outro** adicional. Devolver granola na conta do leite em pó é pior que não devolver: os dois
  números ficam errados e nada denuncia. A regra de *quando* devolver é a mesma do insumo da ficha:
  depois que a cozinha começou, a granola foi para o copo.
- **Reabrir** (item 2.7) consome de novo, e não recusa: a venda está paga.
- **Excluir insumo usado por adicional é recusado**, dizendo quais adicionais usam.
- **O custo do adicional soma no custo do item**, mas custo nulo continua nulo: nulo quer dizer
  "não cadastrado", e não "de graça", e é nesse campo que se olha quando a margem não fecha.
- **Na tela**, a unidade do insumo aparece ao lado da quantidade — sem ela o lojista digita 30 pensando
  em gramas num insumo cadastrado em quilo, e o estoque derrete 1000x mais rápido. E a tela **avisa**
  quando o insumo foi escolhido e a quantidade ficou vazia, que é o erro mais silencioso dali: salva,
  diz "✅ Salvo!", e não baixa nada.

**Achado por mutação, e é o terceiro do dia no mesmo tema:** apagar o insumo do `new Escolhido` do
`ComplementoService` passou com **99 testes verdes**, incluindo todos os que eu tinha acabado de
escrever para o adicional. Os dois canais **mockam** o `aplicar`, então nenhum teste exercitava o
método real — com essa mutação nada consumiria insumo de adicional nunca, e a suíte ficaria verde.
Medindo, a lacuna era maior e anterior a mim: **o `aplicar` não tinha teste nenhum** — nem do
acréscimo de preço, nem do mínimo/máximo, nem da recusa de complemento de outro produto, que é a
linha que impede o pedido de chegar com o adicional "de graça" direto no corpo da requisição.

65 testes novos (702 no `mvn test`, 102 nos ITs, 129 no frontend), **20 de 20 mutações mortas**.

**Item do dono:** cadastrar o insumo nos adicionais que controlam estoque (Produtos → 🧩
Complementos). Até ele fazer isso, nada muda — adicional sem insumo segue como sempre.

### 2.7 PIX pago depois do cancelamento não rebaixa o estoque — **FECHADO (v129, 21/10)**
Era verdade, mas **medir mostrou que o conserto óbvio estava errado** e que o estrago era maior do
que a varredura dizia.

Rebaixar o estoque sozinho deixaria o pedido em `CANCELADO`, e o `alterarStatus` recusa sair de
estado final: o lojista que quisesse preparar teria que lançar **outro** pedido — que baixa o
estoque por conta própria. Rebaixar ali tiraria em dobro. E o dano real não era o estoque: **o
cliente pagava e a cozinha nunca via o pedido.** A única pista era um texto na aba de cancelados.

Então o pedido **reabre**: volta a `RECEBIDO`, aparece no quadro, o estoque sai aqui, e o histórico
fica na observação que a cozinha lê no card ("REABERTO: o PIX foi pago depois do cancelamento"). Se
o lojista não puder atender, ele cancela de novo — e o cancelamento devolve estoque e cashback pelos
caminhos que já existem. O `rebaixarDeNovo` é o espelho exato do `devolver`, inclusive na marca
`consumiuFicha`, e nunca recusa por falta de estoque: a venda está paga.

Nunca aconteceu na produção (medido: zero pedidos com "pago APÓS o cancelamento"), então é
preventivo.

**E apareceu um terceiro defeito ao escrever os testes:** a tela de acompanhamento dizia "pago"
comparando o **texto** do `formaPagamento` com `"PIX (pago)"`. Pago depois do cancelamento o texto é
outro — então a tela do cliente, que pergunta a cada 5 segundos (`cardapio.js:447`), **nunca**
confirmava. Dinheiro na conta, pedido na cozinha, e o cliente olhando "aguardando pagamento". Agora
lê `pagoEm`, que no `Pedido` é gravado só pelos dois caminhos de PIX pago (medido). Esse texto não é
novo; o que mudou é que agora o pedido reabre, e deixar o cliente no escuro passou a ser o erro mais
visível dos três.

---

## 3. Cobrança da plataforma

### 3.1 Clicar "Ativar assinatura" de novo apaga a fatura atrasada — **FECHADO (v123, 20/10)**
`AssinaturaService.java:66-103`: só sai cedo se o status for ATIVA. Com PENDENTE, INADIMPLENTE ou
CANCELADA, **cancela a assinatura antiga no Asaas** e cria outra com vencimento em `hoje + 7`.
Teste grátis infinito, e o caminho está aberto justamente para quem está bloqueado
(`BloqueioPorAssinaturaFilter.java:200-202` libera `/api/assinatura`). **CONFERIDO POR MIM na leitura.**

### 3.2 Cancela no Asaas, falha ao criar a nova, e a loja fica sem cobrança — **FECHADO (v123, 20/10)**
Mesmo método: cancela primeiro, cria depois, tudo numa transação. Se a criação falhar, o nosso banco
faz rollback e volta a apontar para a assinatura antiga — que **lá fora já morreu**. O painel diz que
está tudo certo. **É o estado exato em que a Zirá está hoje** (ver 0.2). **CONFERIDO POR MIM.**

**MEDIDO NA PRODUÇÃO em 20/10:** a loja 18 (Zirá) está **CANCELADA** no nosso banco, com id de
assinatura, e a assinatura está `deleted: true` no Asaas. É o estado 3.2. As lojas **17, 19 e 20 não
têm assinatura nenhuma** — nunca assinaram.

**A regra agora** (os dois itens eram o mesmo método):
- **ATIVA ou PENDENTE** → devolve a que existe, sem tocar no Asaas e sem nem consultar a rede.
  Clicar de novo não cria cobrança nem move vencimento. PENDENTE entra aqui porque a assinatura e a
  primeira fatura já existem; recriar dava mais 7 dias.
- **INADIMPLENTE com a assinatura VIVA** → **recusa (409)**, e a mensagem diz **como pagar**. Recusar
  sem dar caminho deixaria o lojista bloqueado sem ação possível — o único botão que ele tinha era
  justamente o que apagava a dívida.
- **Assinatura que não existe mais no Asaas** → cria outra. Sem isto a Zirá ficaria **sem nenhuma
  forma de voltar a pagar**.
- **Asaas indisponível** → 503, nada é alterado.
- A **cortesia de 7 dias vale uma vez**, na primeira assinatura. Reassinando, o vencimento é amanhã.
- A ordem virou **cria, depois cancela**. Entre "cobrado em dobro" e "sem cobrança nenhuma", dobro é
  melhor: dobro é visível e dá para estornar, zero é invisível. E o id órfão fica **gravado** (V52),
  não numa linha de log que rotaciona.

O `estadoDaAssinatura` é **tri-estado** de propósito: VIVA, NAO_EXISTE, INDISPONIVEL. "Não consegui
falar com o Asaas" **não é** "a assinatura não existe", e confundir os dois é exatamente o defeito
3.2.

A tela de Planos ganhou **"Pagar a fatura"**, com o link que o servidor busca no Asaas, o valor e o
vencimento — e avisa quando há cobrança em duplicidade.

**ACHADO MEDINDO A PRODUÇÃO, num conserto meu:** como a assinatura da Zirá está deletada, o meu código
mandaria cancelar o que já morreu, o cancelamento falharia, e ele anunciaria **cobrança em
duplicidade que não existe**. Alarme falso é pior que silêncio, porque ensina a ignorar o alarme.
Agora só cancela o que está **vivo**, e o Asaas é consultado uma vez só. **Eu tinha escrito um teste
aceitando o comportamento errado**; ele virou o contrário.

Testes: `ReativarAssinaturaNaoApagaFaturaTest` (19) e `EstadoDaAssinaturaNoAsaasTest` (14), este
contra um `HttpServer` de verdade — os dois ramos de maior consequência (erro de rede e
`deleted: true`) **sobreviveram às primeiras mutações** porque o `AsaasClient` estava dublado.
Backend 517 + 67 de integração, frontend 100. As 52 migrações aplicadas num Postgres 16 limpo, e a
V52 confirmada na produção. As 12 mutações que tentei são todas pegas. Commits `992cb5f` e `a977b5b`.

**O QUE ISSO NÃO RESOLVE, e continua sendo do dono:** a Zirá precisa que alguém **clique** em
reativar para a cobrança dela voltar a existir. O conserto garante que esse clique agora funcione
(cria assinatura nova, vencimento amanhã, sem apagar nada) — mas o clique é dela ou seu. Ver 0.2.

### 3.3 Estorno e chargeback não mexem no acesso — **FECHADO (v124, 21/10)**
`AssinaturaService.java:173-177` trata estorno antes de tudo e sai da função. A assinatura continua
ATIVA e `acesso_ate` continua NULL. Paga, usa, pede estorno, recebe de volta e **fica com acesso sem
prazo para sempre**. Dá para repetir todo mês. **CONFERIDO POR MIM.**

**MEDIDO NA PRODUÇÃO em 21/10:** o corte está **LIGADO** (`BORA_COBRANCA_CORTE_POR_ASSINATURA=true`,
confirmado no log da subida) e a carência é de 10 dias — então `acesso_ate` realmente derruba a loja.
Quem lê isso é `Loja.acessoVencido()`, usado em três lugares: `BloqueioPorAssinaturaFilter:66`,
`PublicController:810` e `RegraDeAcesso:70`.

**FUI NA DOCUMENTAÇÃO em vez de deduzir.** O Asaas tem **oito** eventos de estorno e contestação
(docs.asaas.com/docs/payment-events, conferido em 21/10); o código tratava **três**, e tratava os três
igual. Não são a mesma coisa:

| evento | o que faz agora |
|---|---|
| `PAYMENT_REFUNDED` | **corta** (INADIMPLENTE + carência) |
| `PAYMENT_CHARGEBACK_REQUESTED` | **corta** |
| `PAYMENT_RECEIVED_IN_CASH_UNDONE` | **corta** — e não era tratado nem para o faturamento; é o espelho do pagamento manual da v115 |
| `PAYMENT_PARTIALLY_REFUNDED` | **não corta**, e não tira a mensalidade inteira do faturamento (ver 3.6) |
| `PAYMENT_REFUND_IN_PROGRESS` | **não corta**: é intenção, e o `REFUND_DENIED` existe porque pode não sair |
| `PAYMENT_REFUND_DENIED` | nada: o dinheiro fica |
| `PAYMENT_CHARGEBACK_DISPUTE` | nada: o chargeback já cortou, e reprocessar reiniciaria a carência |
| `PAYMENT_AWAITING_CHARGEBACK_REVERSAL` | **devolve o acesso** e a mensalidade: a disputa foi ganha |

Sem o último, o conserto trocaria "não cortar quem deve" por "cortar quem não deve". A carência é
definida **uma vez**, e sem saber de qual loja é o dinheiro **não corta ninguém**.

Testes: `EstornoCortaOAcessoTest` (21), dois deles travando a lista de eventos contra a documentação.
Backend 538 + 67 de integração. As 10 mutações que tentei são todas pegas — **duas sobreviveram
primeiro, e os dois testes fracos eram meus**: a disputa caindo no `marcarEstorno` passava verde, e o
teste do "sem loja não corta ninguém" só dublava a loja 18, então um mutante que chutasse `lojaId = 1`
passava. Commit `985e404`.

### 3.3b O webhook do Asaas não estava assinado nos eventos de estorno — **RESOLVIDO (21/10, autorizado pelo dono)**
**MEDIDO POR MIM em 21/10**, lendo a conta (só leitura). A conta tem dois webhooks:

- **`Bora producao`** → `PAYMENT_CONFIRMED`, `PAYMENT_DELETED`, `PAYMENT_OVERDUE`, `PAYMENT_RECEIVED`
- **`BoraHapp PIX - loja 1`** → `PAYMENT_CONFIRMED`, `PAYMENT_RECEIVED`

**Nenhum dos 8 eventos de estorno está assinado. E nenhum evento de assinatura (`SUBSCRIPTION_*`)
também.** Duas consequências, e as duas importam:

1. **O defeito 3.3 nunca disparou de verdade** — ninguém ganhou acesso de graça por estorno, porque o
   aviso de estorno nunca chegou. O conserto é necessário, mas é **preventivo**.
2. **O conserto fica inerte até alguém marcar esses eventos no painel do Asaas.** O mesmo vale para o
   tratamento de `SUBSCRIPTION_DELETED`, que já existia e também nunca foi exercitado — o que explica
   parte de por que a situação da Zirá passou em branco.

Marcar os eventos é **mudar a configuração da conta de cobrança do dono** — ele **autorizou** em
21/10 e eu fiz pela API.

**Como foi feito, e o risco que precisou ser contornado.** A API devolve `hasAuthToken: true` mas
**não devolve o token**, e a documentação não diz se o `PUT` substitui o objeto inteiro. Se o token
fosse apagado, a nossa aplicação passaria a responder **401** a todo aviso — e com
`sendType: SEQUENTIALLY` a fila inteira trava e **nenhum pagamento é registrado**. Como o token está
no `api.env`, reenviei-o explicitamente no `PUT`: fica seguro nas duas hipóteses.

Antes de escrever, guardei o estado em `~/backups-asaas/webhooks-antes-20261021.json` no servidor.

**Resultado, conferido depois:** `Bora producao` foi de **4 para 12** eventos, com os **8** de estorno
presentes, **nenhum evento perdido**, e `url`, `email`, `enabled`, `sendType`, `apiVersion`,
`hasAuthToken`, `interrupted` e `penalizedRequestsCount` **idênticos** aos de antes.

O webhook **`BoraHapp PIX - loja 1` ficou intacto de propósito**: ele aponta para
`/public/pix-webhook/1`, que trata pagamento de **pedido de cliente**, não a cobrança da plataforma.

**Provado no ar, sem efeito em nada:**
- aviso com o token certo → **200** `{"received":true}`; com token errado → **401** (a tranca é real,
  e o token que o Asaas guarda é o que a aplicação espera)
- um `PAYMENT_REFUNDED` de cobrança inexistente → **200**, com os dois avisos certos no log
  ("não está no nosso faturamento" e "não achei a loja; o ACESSO NÃO FOI CORTADO") e **nenhuma loja
  tocada**. Isso importa porque, com fila sequencial, uma exceção no caminho novo travaria todos os
  avisos de pagamento
- conferido no banco depois: as 5 lojas com o mesmo `acesso_ate` e os 2 pagamentos com **zero**
  estornos

**O que FICOU de fora, e continua sendo decisão do dono:** nenhum evento de **assinatura**
(`SUBSCRIPTION_*`) está assinado, então o tratamento de `SUBSCRIPTION_DELETED` — que já existia e
corta o acesso quando a assinatura é cancelada — continua **inerte**. Não marquei porque é outra
decisão, com outra consequência: passaria a cortar loja cuja assinatura seja cancelada, e a da Zirá
está nesse estado. Preciso primeiro conferir como o Asaas expõe a assinatura de evento de assinatura
(o endpoint `/webhooks` não mostra nenhuma).

### 3.4 Dois pagamentos manuais no mesmo dia: o segundo some — **FECHADO (v125, 21/10)**
Sem cobrança aberta no Asaas, a chave do registro é `"manual:" + lojaId + ":" + dia`, e
`registrarPagamento` descarta id repetido em silêncio. A tela diz "Pagamento registrado".
`AssinaturaService.java:282` e `:308`. **Os R$ 398 da Zirá são duas mensalidades.** **CONFERIDO POR MIM.**

**MEDIDO NA PRODUÇÃO em 21/10, e isso CORRIGE o que o item sugeria.** A loja 18 tem **dois** registros
de R$ 199 no mesmo dia (15/10), somando os R$ 398 — **nada se perdeu**:

| chave | valor | dia |
|---|---|---|
| `manual:18:2026-10-15` | R$ 199 | 15/10 |
| `pay_aj14zjq8wbcfqhfx` | R$ 199 | 15/10 |

Foi **sorte**: um dos dois achou cobrança aberta no Asaas e ficou com o id de lá, então as chaves não
colidiram. **Hoje a assinatura dela está deletada no Asaas** — não há cobrança aberta, e o próximo par
de registros no mesmo dia colidiria. O conserto chegou antes.

**Os dois erros opostos.** Chave única resolve a perda, mas abre a porta para o clique duplo contar
duas vezes — e contar receita que não entrou é tão ruim quanto perder a que entrou. Pelo dado não há
como distinguir, então **quem decide é o dono**:
- mesmo dia e **mesmo valor** → recusa com 409 e pede confirmação explícita;
- mesmo dia e **valor diferente** → são dois pagamentos, registra sem perguntar;
- confirmado → registra com chave própria, e nada é descartado em silêncio.

A chave virou `manual:18:2026-10-15:1`, `:2`, `:3` — **legível de propósito**: quem conferir o
faturamento à mão enxerga a loja, o dia e qual registro daquele dia. Um UUID resolveria a colisão e
tornaria a conferência impossível. Fechado também o outro caminho para a mesma perda: id do Asaas que
já está no nosso faturamento agora cai na chave manual em vez de descartar.

**DOIS DEFEITOS MEUS, achados pelos próprios testes:** o `chaveManualLivre` tinha um retorno
antecipado que devolvia `:1` **sempre** — reintroduzindo o descarte silencioso; e meu dublê contava o
`save` de atualização (o da observação) como registro novo, então um pagamento parecia dois.

**A mutação "o controller ignora a confirmação" passou com os 28 testes de serviço VERDES**, e o
efeito era o pior possível: o dono confirma e o servidor devolve 409 para sempre, sem como registrar
o segundo pagamento. **Teste de serviço não cobre fiação de controller.** Daí o
`ConfirmacaoDoSegundoPagamentoChegaAoServicoTest`.

Testes: `DoisPagamentosNoMesmoDiaTest` (15), `ConfirmacaoDoSegundoPagamentoChegaAoServicoTest` (7),
`script-dentro-do-html.test.mjs` (6). Backend **561**, frontend **106**. As 7 mutações que tentei são
todas pegas. Commits `ed32c4f` e `989a738`.

### 3.4b O script dentro das páginas HTML não tinha teste nenhum — **FECHADO (21/10)**
A suíte do frontend cobria só `assets/js/*.js`. O **`configuracoes.html`** tem centenas de linhas de
script inline — o painel da plataforma inteiro: suspender loja, entrar como suporte, registrar
pagamento recebido — e **nada olhava para ele**. Eu mesmo quebrei uma string ali (um `
` que virou
quebra de linha de verdade) e só descobri conferindo à mão.

O `script-dentro-do-html.test.mjs` compila o script inline de **toda** página, e tem um teste que
confere se ele está realmente achando os scripts — sem isso, um regex quebrado faria o resto passar
medindo nada.

### 3.5 Carência de 10 dias não vale para quem nunca pagou
`AssinaturaService.java:196-200`: a carência só é dada quando `acesso_ate` está NULL. Loja nova nasce
com os 7 dias de cortesia preenchidos, então `PAYMENT_OVERDUE` **não dá carência nenhuma**. O teste
que garante a carência monta a loja com `acesso_ate` nulo — estado que o sistema nunca cria.
**LEITURA** (é o tipo de teste verde sobre premissa que não acontece).

### 3.6 Estorno parcial apaga a mensalidade inteira do faturamento
`estornadoEm` é tudo-ou-nada e nunca é limpo. Um estorno de R$ 10 tira os R$ 199 do mês. E
`PAYMENT_CHARGEBACK_REQUESTED` é só um **pedido** — se a plataforma ganhar a disputa, o dinheiro some
do faturamento para sempre. `PlataformaController.java:923-928`. **LEITURA.**

### 3.7 Subconta vira ATIVO com a conta bancária ainda pendente
`AsaasSubcontaService.java:408-414`: quando o Asaas manda o resumo `general`, decide só por ele e
nunca olha `bankAccountInfo`. O comentário do próprio método diz que oferecer PIX com a conta em
análise "deixaria o cliente pagando para uma conta que nao pode sacar". É o estado da loja 18 hoje.
**LEITURA.**

### 3.8 Módulo IA fica ligado de graça quando o Asaas recusa
`PlataformaController.java:698-699` grava `moduloIa = true` **antes** de tentar a cobrança. Se a
sincronização falhar, o recurso é liberado e a mensalidade continua no valor antigo. Não há retry,
nem fila, nem rotina que compare `assinatura.valor` com `loja.precoComModulos()`. R$ 99/mês. **LEITURA.**

### 3.9 Split só sai pela subconta, e a tela diz que sai de todo mundo
`PixService.java:167` exige `viaSubconta`. Loja que recebe pela chave legada nunca paga os 2%.
E `PUT /lojas/{id}/split` responde `efetivo: "2%"` sem olhar se a loja tem subconta
(`PlataformaController.java:764`). Some-se a isso o 0.3 acima. **LEITURA.**

---

## 4. Banco de dados

> O agente aplicou as **50 migrations num Postgres de verdade** (zero erros, 29 tabelas, 72 índices) e
> carregou **800 mil pedidos** para medir com `EXPLAIN ANALYZE`. Os números abaixo são dele, medidos.

### 4.1 O painel faz 3 varreduras da loja inteira a cada 6 segundos — **FECHADO (v128, 21/10)**
`PedidoService.java:553-559` — as três contas não têm corte de data. Com 26 mil pedidos: **615 ms e
~325 MB de leitura por atualização**, por loja aberta. Dois índices resolvem: medido, **615 ms → 0,4 ms**.
**MEDIDO PELO AGENTE.**

**MEDI EU MESMO**, num Postgres 16 com 26 mil pedidos e distribuição realista (quase tudo encerrado,
um punhado ativo agora):

| consulta | quem chama | antes | depois |
|---|---|---|---|
| contagem "em preparo" | Dashboard, 8 s | 8,6 ms | 0,40 ms |
| contagem "saiu para entrega" | Dashboard, 8 s | 9,9 ms | 0,27 ms |
| contagem "entregues na última hora" | Dashboard, 8 s | 8,0 ms | 0,32 ms |
| os pedidos **abertos** de qualquer dia | **KDS, 6 s** | 9,3 ms | 0,35 ms |

As três do Dashboard viram **Index Only Scan** (não tocam na tabela): o total por atualização cai de
**26,5 ms para 1,0 ms**. Custo: **616 kB** de índice numa tabela de 14 MB.

O agente mediu 615 ms; eu medi 41 ms com a distribuição dele e 26,5 ms com uma realista. Mesma forma,
magnitude diferente — meu container é local e com cache quente, e o disco do Lightsail é mais lento.

**TRÊS COISAS QUE O ITEM NÃO DIZIA, e que medir mostrou:**
1. A terceira contagem **já tinha** corte de data; o que faltava era índice.
2. A varredura de **6 segundos não é a do Dashboard** (que é de 8 s) e sim a do **KDS**, que usa
   **outra** consulta — e ela **não** seria resolvida pelos dois índices.
3. Essa consulta do KDS era `status NOT IN (encerrados)`, uma **negação**, e nenhum btree serve
   negação.

Um índice parcial `where status not in (...)` servia o KDS em 0,23 ms **com valores literais** — mas o
Postgres **não consegue provar** que `status not in ($1,$2)`, como o Hibernate manda, implica aquele
predicado quando o plano é genérico: medido, **15,9 ms**. Em vez de depender dessa heurística, a
consulta virou **lista positiva** (`status in (ABERTOS)`), servida pelo índice comum **sempre** —
conferido em 6 execuções seguidas, inclusive depois do limite em que o Postgres troca para plano
genérico.

**O preço dessa troca, e o enum tem SETE valores:** a negação pegava status novo de graça, a lista
positiva não. Eu quase deixei o **`CONFIRMADO`** de fora — o status que o marketplace usa entre o
aceite e o preparo — e pedido nesse estado **desapareceria da vista da cozinha**, calado. O
`AbertosMaisEncerradosCobremTudoTest` reprova se os dois conjuntos deixarem de cobrir o enum inteiro,
e o `QuadroNaoCarregaBaseInteiraTest` cobra que o quadro peça **todos** os abertos (estreitar a lista
passava verde antes).

**No ar:** V54 aplicada, os dois índices existem na produção (16 kB cada). O plano de hoje para a
consulta do KDS é **Seq Scan em 0,049 ms** — e está **correto**: com 32 linhas, varrer é mais rápido
que indexar. Os índices entram em ação conforme a tabela crescer. **O ganho hoje é zero, de propósito.**

Testes: `AbertosMaisEncerradosCobremTudoTest` (6) e `OLacoDoPainelUsaIndiceIT` (8) — este carrega 6 mil
pedidos e **lê o plano** do Postgres, porque índice é promessa, não garantia: quem decide usar é o
planejador, e índice entregue e ignorado é pior que nenhum. Backend **596** + **80** de integração. As
4 mutações que tentei são todas pegas. Commit `7d6ac7f`.

**Dois tropeços meus no próprio teste:** a carga cobria 4 dias, "hoje" era 13% da tabela, e o
planejador varria de **propósito** — o teste reprovava por um motivo que não era o defeito; e o
`prepare` não passa pelo `createNativeQuery` do Hibernate, precisou de JDBC cru.

### 4.2 `endereco_entrega` é varchar(255) e recebe o endereço que precisou de 500 — **FECHADO (v126, 21/10)**
O **mesmo valor** do marketplace vai para dois lugares no mesmo método: `PedidoService.java:456`
corta em 500 (coluna de 500); `:329` grava sem corte numa coluna de 255. A V37 largou
`cliente.endereco` para 500 justamente por causa desse endereço. O INSERT é recusado e **o pedido do
marketplace inteiro se perde**. `ddl-auto: validate` não pega tamanho.
**MEDIDO PELO AGENTE** (`ERROR: value too long for type character varying(255)`).

**CONFERIDO POR MIM na produção, e ERAM TRÊS, não um.** Medi cada gravação do payload externo, uma por
uma. As larguras reais eram: `endereco_entrega` **255** contra `cliente.endereco` **500**;
`bairro_entrega` **100** e `id_externo` **120**, as duas **também sem corte**. O `upsertCliente`
cortava tudo. O agente citou só o endereço.

**NUNCA DISPAROU:** nenhum pedido tem `endereco_entrega` preenchido e o maior endereço de cliente da
base tem **43** caracteres. É preventivo, e chega antes do volume de marketplace.

**Como ficou** (backend `20c6e39`, no ar em v126, V53 confirmada na produção):
- **V53** iguala `pedido.endereco_entrega` a `cliente.endereco` (500) e `id_externo` a
  `cliente.id_externo` (160) — a assimetria era gratuita;
- os três passam a **cortar**, e quem corta **avisa no log** com o pedido, o campo, o tamanho original
  e o **texto completo** (a única cópia do que o marketplace mandou);
- **cortar e não recusar**, porque endereço cortado em 500 ainda dá para entregar e pedido que não
  existe no painel, não;
- as larguras viraram constantes em `LarguraDeColuna`, num lugar só.

**O teste que fecha a classe:** o `LarguraDasColunasBateComOBancoIT` compara **cada** constante com a
largura **real** do banco. Migração que mude a largura sem atualizar a constante reprova, e o
contrário também. É a única forma de o descasamento aparecer antes da produção — **nem o Hibernate nem
teste com mock enxergam largura**. Ele também trava que `pedido_item.descricao` continue `TEXT`: ela
leva nome + complementos + observação desde a v119, e a maior da produção já tem **327** caracteres,
acima de qualquer `varchar(255)`.

**Dois tropeços meus:** a mutação "o corte para de avisar" passou **verde** na primeira rodada — o
conserto cortava calado, e perder o fim de um endereço faz o entregador descobrir na rua; e o meu
`larguraNoBanco()` estourou com `NullPointerException` justamente no caso que o teste existe para
cobrir (coluna `TEXT` devolve largura **nula**, e `Stream.findFirst()` não aceita elemento nulo).

Testes: `EnderecoLongoNaoPerdeOPedidoTest` (13) e `LarguraDasColunasBateComOBancoIT` (5). Backend
**574** + **72** de integração. As 53 migrações aplicadas num Postgres 16 limpo, e a conversão em
produção não perdeu nada (32 pedidos, 8 com id externo, intactos). As 7 mutações que tentei são todas
pegas.

### 4.3 Excluir produto com complementos dá erro 500 — **FECHADO (v131, 21/10)**
Era verdade, e **conferi na produção**: `complemento_grupo_produto_id_fkey` é a única chave
estrangeira que aponta para produto, com `confdeltype = 'a'` (NO ACTION). Apagar produto que tem
adicional cadastrado dava **500** — e pega justamente os que mais vendem numa açaiteria.

**A outra metade, que a varredura não citou:** `produto_insumo` é o contrário — *não tem* chave
estrangeira. O delete seco passava e deixava as linhas da ficha técnica apontando para um produto que
não existe. É a ficha fantasma do item 2.5, pelo outro lado.

Apagar produto agora leva junto os complementos (opções antes dos grupos) e a ficha técnica, em
transação. **O histórico não é tocado, e isso foi medido:** `pedido_item` não tem FK para produto e o
relatório por produto agrupa pela `descricao` gravada no item, não pelo nome do cadastro. Pedido
antigo continua no relatório com o nome que o produto tinha no dia da venda — por isso apagar não
precisa ser recusado.

O IT começa provando a **premissa**: ele apaga do jeito antigo e exige que o banco recuse. Sem isso,
o resto poderia estar passando porque a chave estrangeira não existe mais.

### 4.4 Observação longa no pagamento manual quebra o registro — **FECHADO (v131, 21/10)**
Era verdade, e **a consequência é pior do que a varredura diz**. O método é `@Transactional`: o
Postgres recusando o UPDATE não corta o texto, **desfaz o registro inteiro do pagamento**. Você
digitaria uma observação um pouco mais longa, veria um erro, e o dinheiro que acabou de receber não
entraria no faturamento da plataforma. É a função que você usa para dar baixa no que recebe fora do
Asaas.

A conta: `loja.nome` é varchar(160) e a descrição é varchar(200). O nome sozinho pode ocupar 160 dos
200, sobrando 37 para a observação.

**Quem perde espaço é a observação, não o nome.** O nome identifica esse dinheiro no faturamento; a
observação é contexto extra e fica com o que sobrar. Sem espaço nenhum, o nome fica sozinho e a
observação inteira vai para o log — melhor um registro certo com a nota no log que nota completa e
pagamento nenhum.

### 4.5 Erro do marketplace sem corte em `ultimo_erro varchar(500)` — **FECHADO (v131, 21/10)**
**Medindo, a varredura errou o número.** Dos **cinco** lugares que gravam a coluna, só **um** estava
de fato sem limite: `IfoodClient:277`, na renovação do token, com o `e.getMessage()` cru. O `:486`
que ela também acusou passa por um corte em 400 mais uma mensagem curta — cabe em 457 dos 500. Os
outros três cabiam por corte em 400 ou por serem texto fixo.

**Mas a parte grave da varredura está certa, e vale para todos os cinco:** a gravação acontece
*dentro do tratamento de erro*. Se ela estoura, a falha nunca é registrada e a tela de Integrações
mostra a loja como se nada tivesse acontecido — o pior lugar possível para um estouro. "Seguro por
sorte" não é seguro, então os cinco passam pelo cortador agora, incluindo o do `MarketplacePoller`,
onde o id do pedido vem de fora e não tem tamanho garantido.

O cortador é o mesmo da v126 (`LarguraDeColuna`), que o `LarguraDasColunasBateComOBancoIT` compara
com a largura **real** do banco — as duas colunas novas entraram nessa conferência.

### 4.6 Índice duplicado e três índices que ninguém usa — **FECHADO (v131, 21/10), com correção**
**Os números desta linha não são da produção.** Ela tem 5 lojas, 32 pedidos e **46 itens de pedido**,
e os índices de `pedido_item` têm **16 kB** — não "24 MB cada com 800 mil itens". E "ninguém usa" veio
do contador `idx_scan`: nessa escala o Postgres faz varredura sequencial e **está certo**, então zero
uso não diz nada sobre o índice — diz que a tabela é pequena. Jogar fora por esse motivo seria tirar
justamente o índice que vai fazer falta quando houver dado.

**A regra que eu apliquei: sai o índice que NENHUMA forma de consulta do código pode usar.**

| Índice | Decisão | Por quê |
| --- | --- | --- |
| `idx_pedido_item_loja` (V15) | **saiu** | definição idêntica à do `idx_pedido_item_pedido` (V7): `(loja_id, pedido_id)`. É o mesmo índice escrito duas vezes — não depende de escala nem de contador. |
| `idx_loja_nao_excluida` (V30) | **saiu** | índice pela **chave primária** com filtro parcial. Busca por id já usa a pkey, e nenhum SQL filtra `excluida_em` — o `arquivada()` é método Java, decidido depois de carregar a loja. |
| `idx_pedido_bairro_entrega` (V48) | **saiu** | o agrupamento por bairro acontece **no navegador** (`entregas.js:62`), sobre a lista que a tela já carregou. Nenhum SQL filtra nem agrupa pela coluna. |
| `ix_pagamento_assinatura_loja` (V41) | **virou `(loja_id, pago_em)`** | **não era inútil, era incompleto.** A única consulta que filtra essa tabela por loja filtra também a data (a que distingue clique duplo de segundo pagamento de verdade). Só `(loja_id)` fazia o banco ler todas as mensalidades da loja e filtrar a data depois. |
| `idx_pedido_aguardando`, `idx_pedido_entregue_em`, `idx_pedido_loja_status`, `idx_pedido_loja_cliente` | **ficaram** | zero uso hoje, mas cada um casa com uma consulta real (PIX pendente, janela de entrega, quadro por status, último pedido do cliente). |

Conferido na produção depois do deploy: os cinco que tinham que sair saíram, os oito que tinham que
ficar ou entrar estão lá com a definição certa.

### 4.7 Outros — **FECHADO (v131, 21/10)**
Os tempos desta linha (381 ms, 408 ms) também não são da produção — vieram de uma carga do agente que
eu não tenho como conferir. Montei a minha dentro do `IndicesQueServemIT` (4 mil pedidos espalhados
por ~166 dias) e medi com `EXPLAIN ANALYZE` no Postgres de verdade. As quatro dívidas eram reais:

- **O índice do acerto desperdiçava a coluna do meio.** As duas consultas comparam
  `lower(trim(entregador))`, e função sobre a coluna impede o uso do índice naquela posição — o banco
  usava só o prefixo `loja_id` e filtrava o resto linha por linha. Virou índice de **expressão**, na
  mesma forma que as consultas escrevem, e **parcial** em `acerto_id is null`, que é a condição das
  duas e a mais seletiva que existe aqui. O IT exige que o plano use o índice **e** que a expressão
  indexada seja a que a consulta compara: se alguém mudar a consulta, o plano voltaria a varrer em
  silêncio.
- **O último pedido por loja era um `group by` da tabela inteira** para desenhar uma coluna da tela.
  Virou subconsulta por loja — poucas lojas, cada `max` uma busca no índice. **Eu ia criar um índice
  `(loja_id, criado_em)` aqui**, e medir os índices da produção mostrou que ele já existe
  (`idx_pedido_loja`): o que faltava era a **consulta**, não o índice. Criar teria sido exatamente o
  defeito do 4.6 que esta mesma migração conserta.
- **O balancete fazia 3 consultas por loja.** Numa rede de 30 lojas, 90 consultas para desenhar uma
  tabela. Virou uma, agrupada. O que o IT prova não é a velocidade: é que os **números não mudaram** —
  receita, válidos e cancelados, comparados um a um com as três consultas antigas sobre o mesmo
  cenário. Número que muda sozinho é pior que consulta lenta.
- **Apagar cliente deixava pedido apontando para o nada.** Agora desamarra o vínculo na mesma
  transação, e o log diz quantos pedidos continuaram no histórico. O histórico fica: a venda
  aconteceu, entrou no faturamento, e o pedido guarda telefone e endereço próprios (V48).

**O N+1 do "desempenho" (5 consultas por loja) NÃO foi feito.** É o `AgenteRedeService`, e lá o laço
não é só de consultas: ele carrega os pedidos e os itens de cada loja para calcular ruptura de
estoque e cancelamentos em memória. Transformar em consulta agregada é reescrever o cálculo, não
trocar uma consulta — e mexer em cálculo sem ter o número de antes para comparar é como eu mudaria o
painel sem perceber. Fica registrado como item separado.

---

## 4.8 O defeito que EU criei hoje, achado ao medir o 4.7 — **FECHADO (v131, 21/10)**
Medindo o pedido órfão, apareceu uma interação com o meu próprio conserto do item 1.5, de poucas
horas antes.

Quando o saldo de cashback virou SQL, **"zero linha mexida" passou a cobrir duas coisas diferentes**:
saldo que não cobre (disputa de verdade, que tem que recusar o pedido) e **cliente que não existe
mais** (não há o que debitar). Antes do 1.5 era um `findByIdAndLojaId(...).ifPresent(...)` — cliente
apagado era silêncio. Depois, passou a estourar **409**.

O caminho que isso quebra é de dinheiro: um **PIX pago depois do cancelamento**, num pedido que usou
cashback, de um cliente que o lojista apagou no meio, devolvia 409 ao webhook do Asaas — e o Asaas
reenvia enquanto não recebe 200. **O pagamento nunca seria registrado.**

Consertado nas duas pontas: o serviço pergunta se o cliente existe (uma consulta a mais, **só quando
a primeira falha**, e há teste cobrando isso), e apagar cliente passou a desamarrar os pedidos. As
duas são necessárias — a do serviço cobre os pedidos que já estão órfãos na base.

---

## 5. Marketplaces

- **5.1** Integração do iFood que cai em ERRO **nunca volta sozinha** — **FECHADO (22/10)**. O
  polling bem-sucedido limpava a mensagem de erro e deixava o **status** em `"ERRO"`
  (`IfoodClient.java:328-330`). Quem está em ERRO não passa pelo `prontaParaSincronizar()`: é tentada
  só pelo caminho espaçado, uma vez a cada 10 minutos (`IntegracaoCanal.ESPERA_APOS_ERRO_MIN`). Então
  **uma** falha qualquer — o iFood fora do ar por um minuto — prendia a loja no ciclo de 10 minutos
  **para sempre**, mesmo com o polling voltando a funcionar na tentativa seguinte. E o polling é o
  batimento que mantém a loja **online** no aplicativo: 30 s → 10 min é o restaurante aparecendo e
  desaparecendo do app. A 99 (`OpenDeliveryClient`) já fazia o reset desde o início.
  Testes: `IfoodSaiDoErroSozinhoTest` (8), contra um iFood falso de verdade (`HttpServer` local), e o
  que eles travam não é o texto do status — é **por qual porta o ciclo a enxerga depois**
  (`prontaParaSincronizar()` / `mereceNovaTentativa()`). **LEITURA.**
- **5.2** O status que a loja muda aqui pode nunca chegar lá — **FECHADO (22/10)**. O `boolean` de
  retorno era descartado (`IntegracaoService.java:294`). Na 99 a ordem é obrigatória, então um passo
  perdido trava todos os seguintes: o pedido congela lá dentro enquanto aqui aparece como entregue, e
  o cliente vê "em preparo" depois de ter recebido a comida.
  Agora grava no `ultimo_erro` da integração — que é o que a tela de Integrações mostra — dizendo
  qual status, de qual pedido e de qual marketplace, mais a consequência ("lá dentro ele continua no
  status anterior"). **Não estoura** (o status já mudou aqui; parar a cozinha por causa de um aviso
  recusado trocaria um problema de informação por um de operação) e **não marca a integração como
  ERRO** — isso a jogaria na fila de 10 minutos do 5.1, transformando um problema pequeno num grande.
  Testes: `OstatusQueOmarketplaceRecusouApareceTest` (9). **LEITURA.**
- **5.3** Aceite que falhou e a loja tocou no card — **JÁ ESTAVA CONSERTADO** antes desta varredura, e
  a varredura não viu. `reenviarAceiteSeFaltou` + a coluna `pedido.aceite_enviado_em` (V48) existem, e
  `AceiteQueFalhaNaoSePerdeTest` cobre os dois lados. **Nada a fazer.**
- **5.4** Renovação do token: o iFood mata o anterior antes de a gente gravar o novo —
  **FECHADO (22/10)**, no que dava para fechar. O estado **não tem conserto**: se a gravação falhar, o
  token novo se perde e o antigo já está morto. O que mudou é a mensagem — antes isto subia como erro
  genérico de banco, agora diz exatamente o que aconteceu e que a loja precisa **reautorizar o iFood
  em Integrações**, e a integração consta como ERRO. Detalhe que custou: o `falha(..., i)` normal
  gravaria no banco **dentro do catch** de um `repo.save` que acabou de estourar — a segunda exceção
  substituiria a mensagem útil pelo erro de banco cru, que é exatamente a reclamação do item. Por isso
  passa `null`, e há teste cobrando que o repo é chamado **uma** vez. **LEITURA.**
- **5.5** O poller grava a linha inteira e desfaz o que o lojista acabou de salvar —
  **FECHADO (22/10)**. O ciclo carrega as integrações no início (`findByAtivoTrue`, **fora** de
  transação) e gravava `repo.save(i)` até **25 segundos** depois: a linha **inteira**, com os valores
  velhos de todas as colunas. O que o lojista salvasse nesse meio tempo era desfeito sem aviso —
  desligar a integração, tirar o aceite automático, colar uma credencial nova. Ele salvava, via
  "salvo" na tela, e o valor voltava sozinho no ciclo seguinte: é o tipo de defeito que faz o lojista
  achar que o sistema "não salva" e parar de mexer.

  Agora cada escrita toca **só as colunas de quem escreve**: `marcarPollingOk`,
  `marcarPollingFalhou`, `marcarErro`, `marcarAviso` e `contarPedidoRecebido`, todas filtrando por
  loja também — id trocado por engano vira UPDATE de **zero linhas** em vez de escrever na integração
  de outra loja. O contador passou a somar **no banco**: era leitura-soma-escrita em cima de um valor
  velho, e dois pedidos no mesmo ciclo contavam **um**.

  **A armadilha que quase me pegou:** token **não** pode ir por esse caminho. Aquelas colunas passam
  pelo cifrador (`@Convert SegredoGuardado`) e **UPDATE em JPQL não chama conversor** — gravaria a
  credencial em texto puro, criando o furo do item 8.4 noutro lugar. Elas continuam indo pela
  entidade, mas pela linha **relida**, não pela cópia velha do ciclo.

  Testes: `OpollerNaoDesfazOqueOlojistaSalvouIT` (12) **contra Postgres de verdade** — com mock eu
  provaria que chamei outro método; o que precisa ser provado é o que ficou na linha, coluna por
  coluna. O primeiro teste prova a **premissa**: com `save` da entidade velha a edição do lojista
  realmente desaparece. E o banco me corrigiu num ponto: eu pus `coalesce` no contador por causa do
  `Integer` nulo, e a **coluna é NOT NULL** — o caso não existe, e isso ficou medido em vez de
  escrito. **LEITURA.**
- **5.6** O que o iFood muda lá fora não chega aqui — **FECHADO (22/10)**, e a varredura estava certa
  **só sobre o iFood**. De tudo o que o canal avisa, o Bora tratava pedido novo e cancelamento; o
  resto era confirmado ao marketplace e jogado fora. Com a **entrega do próprio marketplace** isso
  congelava o pedido no painel no status que a loja clicou por último, para sempre — quem sabe onde o
  motoboy está é o iFood, e ninguém na loja tem como saber que chegou.

  **O que medir corrigiu:** a 99 (Open Delivery) **já tinha isto** pelo webhook, para `PICKED_UP` e
  `DELIVERED` (`OpenDeliveryWebhookController`), e `PedidoService.avancarPorMarketplace` já existia.
  Quem ficou de fora foi o iFood, que anda por **polling** — por isso o conserto é no poller, não num
  canal só.

  Agora `DISPATCHED`/`DSP`, `CONCLUDED`/`CON` e `READY_TO_PICKUP`/`RTP` avançam o pedido aqui — **só
  para frente**, nunca recuando nem reabrindo encerrado, e **sem** devolver o status para o canal
  (contar de volta a novidade que ele acabou de dar seria eco). Evento que eu não reconheço vai para o
  **log**, de propósito: é assim que a produção me ensina os nomes de verdade, em vez de eu adivinhar
  no código. E nome que eu tenha errado vira no-op, não corrupção, porque o avanço nunca recua.

  O cliente final **não** recebe WhatsApp nisso: `notificarFase` sai na primeira linha para pedido de
  marketplace, porque o telefone que vem no payload é a central do iFood (aprendido no 1º pedido real,
  19/09). Testes: `OcanalAvancaOpedidoAquiTest` (9). **LEITURA.**
- **5.7** Pedido com `isTest: true` entrava como venda de verdade — **MARCADO (22/10)**, não excluído.
  `isTest` não aparecia em nenhum `.java` (conferido em 22/10/2026): pedido de teste baixava estoque,
  somava no faturamento e entrava no CMV. E pedido de teste acontece justamente na **homologação**, que
  é quando o lojista está começando e olhando os números pela primeira vez.
  Agora ele entra com `*** PEDIDO DE TESTE DO <CANAL> -- NAO PREPARE, E CANCELE DEPOIS DE VALIDAR ***`
  na **frente** da observação (sem apagar a do cliente), e com linha no log de auditoria. Lê `isTest`,
  `test` e `testOrder`, booleano ou texto. **Não recusa o pedido**, de propósito: a homologação do
  iFood exige que a integração aceite e faça o pedido de teste andar.
  **O que NÃO foi feito, e é decisão sua:** ele **continua contando no faturamento**. Tirar exige
  coluna nova em `pedido` (o cálculo de receita não olha a origem: filtra por status e por PIX
  pendente, nada mais). Marcar é reversível; mexer na sua conta sem você saber, não.
  Testes: `PedidoDeTesteEntraMarcadoTest` (8), incluindo o risco do outro lado — marcar venda de
  verdade como teste faria a loja **cancelar um pedido pago**, que é pior que o defeito original.
- **5.8** Taxa do marketplace entra como receita da loja — **CONFIRMADO no código, MEDIDO no tamanho,
  e VISÍVEL (22/10)**. O faturamento é `sum(valorTotal)`, e para pedido de marketplace `valorTotal` é
  o `total.orderAmount` do payload: o **bruto** que o cliente pagou, **taxa de entrega incluída**.
  Quando quem entrega é o marketplace, essa taxa é dele.

  **O tamanho, medido na produção em 22/10/2026:** 7 pedidos de iFood, R$ 104,00 somados, **R$ 10,00**
  de taxa dentro — e são todos os pedidos de teste de setembro. Nenhuma loja tem marketplace no ar.
  Então **hoje não há dinheiro em jogo**: há a hora certa de arrumar, antes de haver.

  O dado de **quem entrega** já vinha no payload (`delivery.deliveredBy`) e o normalizador já o lia —
  mas só para escrever "Entrega pelo iFood" na **observação**, que é texto e nenhuma conta alcança. A
  V58 passa a gravar (`pedido.entrega_pelo_canal`; nulo = não informado, e **nulo não é false**:
  `false` afirma que a loja recebeu a taxa). O relatório devolve `taxaDoMarketplace` **ao lado** do
  faturamento, e a tela mostra embaixo dele — só quando existe, para loja de balcão não ganhar ruído.

  **O que NÃO foi feito, e é decisão sua:** o faturamento **continua sendo o bruto**. Descontar a taxa
  muda um número que você olha todo dia, e há teste cobrando que ele continue bruto — se um dia você
  pedir o líquido, esse teste falha e conta que a mudança foi deliberada.

  Testes: `QuemFicouComAtaxaDeEntregaTest` (16), incluindo o pedido **real** da loja de teste guardado
  em 19/09 (`deliveredBy: MERCHANT` — não é suposição), e 4 testes de tela.
- **5.9** WhatsApp — **a varredura errou a conclusão, e o furo real era outro. FECHADO (22/10).**
  A varredura dizia que o App Secret único "quebra na **segunda** loja que ligar o robô".
  **Não quebra:** o `lojaId` vem do caminho da URL (`/public/whatsapp-webhook/{lojaId}`), não da
  assinatura, então cada loja tem o seu endereço e as duas funcionam. O App Secret é da plataforma de
  propósito — é um aplicativo Meta só, com os números das lojas dentro. Há teste disso agora, para a
  conclusão errada não voltar.
  **O furo que existia de verdade:** a assinatura prova que o corpo veio da Meta, e mais nada — ela
  não amarra o corpo à loja do endereço. Um corpo **legítimo** da loja A, reenviado para o endereço da
  loja B, era aceito como evento da B: o robô responderia ao cliente da A com o nome e o cardápio da
  B, pelo número comercial da B. Quem tem o corpo assinado é qualquer um no caminho que o tenha visto
  uma vez, e o id da loja está na URL pública do cardápio.
  O conserto compara o `value.metadata.phone_number_id` que a Meta manda com o `clientId` da
  integração (que é onde o Phone Number ID da loja já estava guardado). Evento sem metadata **passa** —
  ainda existem avisos sem ela, e recusar o que não se entende deixaria o robô mudo, que atinge todo
  cliente de boa-fé. Testes: `OavisoDoWhatsAppEhDoNumeroDaLojaTest` (8).

**Bloco 5 fechado por inteiro** (5.1 a 5.9) em 22/10/2026.

**Rodada de mutação da onda 6 (5.5, 5.6, 5.8):** 17 mutantes, **16 mortos**. O 17º
(`o_token_nao_rele_a_linha`) é **equivalente** — a guarda de id nulo não é alcançável, porque quem
chega lá veio do banco. Está registrado no javadoc do método em vez de coberto por um teste inventado:
teste verde de cenário impossível não prova nada. **Dois sobreviveram na primeira passada e os dois
eram lacuna minha de verdade:** eu não testava o `RTP` abreviado (só a forma por extenso), e não
testava a **fiação** do normalizador até o pedido gravado — as duas pontas medidas e o meio solto, que
é a mesma lição de sempre vista de outro ângulo.

**Rodada de mutação da onda 5:** 17 mutantes, **17 mortos**. Um sobreviveu na primeira passada e
valeu a pena: eu havia testado "corpo torto" com o `entry` errado, e aí o caminho principal estoura no
mesmo lugar — o `catch` de fora devolve 200 de qualquer jeito, e trocar o `catch` de dentro por um
`throw` não mudava **nada de observável**. Só com o `metadata` torto (e o resto do corpo bom) o
caminho principal funciona e dá para medir a diferença: com o conserto o cliente é respondido, com o
mutante o robô emudece. O teste foi reescrito.

---

## 6. Fluxo do pedido

- **6.1** Pedido PIX **entregue** vira CANCELADO sozinho 30 min depois, sem nada no histórico. O
  cliente recebe "pedido cancelado" depois de ter recebido a comida. `CobradorDePixService.java:146-168`
  não olha o status. **LEITURA.**
- **6.2** O endereço do pedido e o "é retirada" **nunca chegam na tela**: `PedidoCard` não tem as três
  colunas da V48. O motoboy lê o endereço do cadastro — exatamente o que a V48 foi criada para
  resolver. E o painel nunca manda `tipoEntrega`: **todo pedido de balcão nasce ENTREGA**. **LEITURA.**
- **6.3** Pedido PIX não pago marcado como entregue entra no acerto do motoboy. **LEITURA.**
- **6.4** Entrega sem motoboy escolhido sai do acerto para sempre, sem aviso. A KDS e o quadro deixam
  avançar até ENTREGUE e não têm seletor. **LEITURA.**
- **6.5** Qualquer operador troca o motoboy de um pedido já entregue, com texto livre, sem papel
  exigido e sem histórico (`PedidoService.java:478-483`). **LEITURA.**
- **6.6** A máquina de status aceita qualquer pulo e qualquer volta. Uma aba velha re-clicando o botão
  manda "está sendo preparado" depois do pedido ter saído. **LEITURA.**
- **6.7** "Recebeu dinheiro" do acerto é R$ 0,00 para todo pedido do cardápio — o cardápio não
  pergunta dinheiro ou cartão, grava "Na entrega", e o acerto procura a palavra "DINHEIRO". **LEITURA.**
- **6.8** O motivo do cancelamento que a equipe digita vai **inteiro** para o cliente, no WhatsApp e na
  tela de acompanhar. O prompt não avisa isso. **LEITURA.**
- **6.9** Retirada despachada na KDS: o cliente que está no balcão recebe "saiu para entrega".
- **6.10** Cadastrar cliente no painel não procura pelo telefone: nasce o segundo cadastro e o
  cashback racha. Não há índice único em `(loja_id, telefone)`. **LEITURA.**

---

## 7. Telas

- **7.1** **A cozinha não vê a observação do pedido.** O dado chega no navegador; o cartão do KDS não
  o desenha (`kds.js:16-30`). "Sem cebola" não chega em quem monta. **LEITURA.**
- **7.2** **Cache**: 26 das 34 páginas pedem `app.js?v=20260930`, e o arquivo mudou em 18/10. Três
  arquivos são pedidos com **duas versões diferentes** ao mesmo tempo. **LEITURA.**
- **7.3** Dashboard engole queda de rede: números congelados, sem a faixa de "sem conexão"
  (`dashboard.js:140`). Pedidos e KDS fazem certo. **LEITURA.**
- **7.4** "Despachar rota" falha em silêncio — **JÁ ESTAVA FECHADO** em onda anterior, conferido no
  código em 23/10: há confirmação antes (dizendo que cada despacho avisa o cliente no WhatsApp) e as
  falhas são coletadas por pedido, com aviso de quantos saíram e quais não. **Nada a fazer.**
- **7.5** PDV: complemento que não carrega grava lista vazia no cache e o produto passa a vender pelo
  preço base até recarregar a página (`pdv.js:86-92`). **LEITURA.**
- **7.6** Importar cardápio multiplica o preço por 100 quando vem com ponto: "12.50" vira 1250
  (`produtos.js:146`). **LEITURA.**
- **7.7** Produto e entregador desativados **voltam a ligar** quando alguém edita (`ativo: true` fixo
  no payload), e não existe como desativar pelo painel. **LEITURA.**
- **7.8** A promoção morre no 20º uso e não há como encerrá-la — **FECHADO (23/10)**. Duas coisas no
  mesmo lugar. O `limiteUsos: 20` era **fixo no código da tela**, sem campo e sem aviso: loja que faz
  50 pedidos numa noite via o cupom parar de valer no meio e não tinha como descobrir por quê. Agora
  há campo — vazio ou zero = **sem limite**, que é o que o servidor já entendia nos dois lugares onde
  confere — e a lista diz quantos usos **faltam**, em vermelho quando restam 3 ou menos.

  E o `PATCH /api/promocoes/{id}/encerrar` existia no servidor **desde o início** sem nenhuma tela
  chamar: promoção só terminava vencendo ou batendo o limite. Agora tem botão, com pergunta antes —
  quem está com o código na mão perde o desconto na hora, e não dá para reabrir pela tela. Testes:
  `promocao-nao-morre-no-vigesimo-uso` (9). **LEITURA.**
- **7.9** Celular — **FECHADO (23/10), e medido no navegador de verdade**, em 375x812.

  **ANTES**, em `relatorios.html`: a página ficava com **495px** de largura dentro de uma tela de 375.
  Quatro grades declaradas em `style="..."` ignoravam o empilhamento da folha — uma seguia com 2
  colunas (163,6 + 163,6) e dois blocos tinham 458 e 479px, mais largos que o telefone.
  **DEPOIS**: página 375 = janela 375 nas **14** telas que têm grade em linha (eram 11 na varredura;
  contei 14), e as grades viraram uma coluna de 347,2px.

  **A causa, e por que o conserto é o que é:** estilo em linha vence qualquer regra de folha,
  **inclusive dentro de media query** — o bloco de 900px que já existia nunca valeu nessas telas. E o
  menor ponto de quebra era 900px: abaixo dele, ou seja em **todo celular** (360 a 430px), não havia
  regra nenhuma. A única coisa que vence estilo em linha é `!important`, e é por isso que a ausência
  dele ali não seria detalhe de estilo: a regra existiria e não faria nada, parecendo consertada.
  Reescrever as 14 telas tirando o estilo de dentro do HTML seria mais arriscado e não mudaria nada
  para quem usa.

  Tabela larga agora rola **dentro do cartão** em vez de empurrar a página (Entregas monta 6 colunas),
  e botão ganhou área de toque de 44px. Testes: `o-painel-cabe-no-celular` (8) — estruturais, e eu sei
  o que isso não prova: eles não medem pixel, porque medir pixel exige navegador e não há um na suíte.
  O que provam é a **relação**: toda tela com grade em linha está coberta por uma regra que vence
  estilo em linha, no ponto de quebra do telefone. **LEITURA.**
- **7.10** Imprimir caixa e recibo do motoboy não fazem nada com pop-up bloqueado — a função
  compartilhada já trata isso, essas duas não. **LEITURA.**
- **7.11** Listas vazias virando tela em branco — **JÁ ESTAVA FECHADO** em onda anterior, conferido
  no código em 23/10: as quatro listas de Ajustes e os últimos pedidos do Dashboard têm texto de lista
  vazia, e o Dashboard carrega o comentário do próprio item. **Nada a fazer.**
- **7.12** Não dá para corrigir o cadastro de um cliente: só existe excluir, e excluir leva o cashback
  e o histórico junto, sem avisar. O endpoint de editar existe. **LEITURA.**

**Cobertura de teste das telas:** as 34 têm cobertura estática (sintaxe, arquivo que existe, ordem do
`api.js`, `requireAuth`). Teste de **comportamento** existe para **uma**: `caixa.html`. As que mexem em
dinheiro e não têm nada: `pdv`, `produtos`, `novo-pedido`, `cardapio`, `acerto-entregadores`.

---

## 8. Segurança

- **8.1** O freio — **JÁ CONSERTADO**, ver 0.1.
- **8.2** **Rebaixar alguém não tira o poder por 24h** — **FECHADO (v127, 21/10)**. O papel saía do
  token, nunca do banco (`JwtAuthFilter.java:78`). O filtro **reconsultava** o banco para `ativo` e
  para o vínculo com a loja, e o papel ficou de fora. Um administrador demitido seguia trocando a
  senha de todo mundo — inclusive de quem o rebaixou — e recuperando o acesso. Contorno de então:
  **desativar** em vez de rebaixar. **LEITURA.**

  **O conserto é de uma linha e custa ZERO consulta:** o registro do usuário já estava carregado ali.
  Na verdade **economiza uma** — havia dois `findById` do mesmo registro na mesma requisição (um para
  `ativo`, outro para a loja principal).

  **Medi as três coisas que poderiam quebrar antes de mexer:** `usuario_loja` **não tem papel
  próprio** (conferido na entidade), então o papel do usuário vale em qualquer loja da rede; **todo**
  token sai de `JwtService.gerar(Usuario)`, que lê `u.getPapel()`, então ler do banco é só a versão
  mais atual da **mesma** informação, nunca uma divergência de desenho; e `papel` é **NOT NULL** com
  padrão OPERADOR, com os 13 usuários da produção todos com papel.

  O `daPlataforma` também passou a vir do banco: administrador da plataforma rebaixado tem que passar
  a valer como usuário de loja na requisição seguinte, e aí as checagens de suspensão e de vínculo
  valem para ele. E papel nulo passa a **não autenticar** — falhar fechado é o certo, e sem isso o
  `requirePapel` daria um 403 confuso em vez de recusar a sessão.

  Testes: `RebaixarTiraOPoderNaHoraTest` (15), com `JwtService` **de verdade** — o token é assinado e
  lido como em produção. Cobrem rebaixar, promover, o admin da plataforma rebaixado, e tudo que **não
  podia mudar**: desativado, usuário apagado, loja suspensa, vínculo revogado, token de outra chave, e
  o suporte alcançando loja suspensa. Backend **589** verdes. As 5 mutações que tentei são todas
  pegas. Commit `df7154d`.

  **O que provei na produção e o que não:** sem token → 401, token mal formado → 401, assinatura falsa
  → 401, **nenhum 500** e nenhum erro no log; o conserto conferido dentro do jar. O caso **positivo**
  (token válido autentica) está provado nos 15 testes contra o filtro real, **não** na produção — o log
  do Caddy não mostra nenhuma requisição `/api/` desde a troca, porque ninguém está com o painel
  aberto, e eu não crio sessão de ninguém. **Vale o dono abrir o painel uma vez para confirmar.**
- **8.3** O balconista vê o faturamento da loja no Dashboard — **FECHADO (23/10)**. Duas portas. O
  **termômetro** (`/api/vendas/termometro`) devolve o faturamento das últimas 24h e a média esperada,
  em reais, e não tinha checagem de papel nenhuma — enquanto Relatórios, Desempenho e Rede, que
  mostram a mesma coisa, todos exigem. E a **lista de produtos** devolvia o `custo` de cada item: a
  tela não desenha, mas ele chega no navegador, então bastam as ferramentas do desenvolvedor para ler
  o custo do cardápio inteiro, e com ele a margem da loja.

  **O conserto é diferente nos dois, de propósito.** No termômetro a ação inteira é número de dono:
  bloqueia (403), e a tela esconde o painel em vez de deixar o 403 virar "indisponível". Na lista de
  produtos **não**: a Frente de Caixa é do balconista e precisa de nome, preço e estoque — barrar a
  consulta tiraria o PDV de quem trabalha nele. Ali se **omite o campo**, e há teste cobrando que o
  resto da lista continua chegando. Insumos e ficha técnica bloqueiam: ali a lista inteira é custo.

  Entrou `AuthContext.temPapel`/`podeVerNumeroDeDono`, e a distinção vale para o futuro:
  `requirePapel` para quando a **ação** é proibida, `temPapel` para quando o que muda é o **conteúdo**
  da resposta. Testes: `NumeroDeDonoNaoSaiParaObalcaoTest` (12) e 6 de tela. **LEITURA.**
- **8.4** `config_plataforma.valor` **não passa pelo cifrador** — o `client_secret` do iFood e da 99 da
  plataforma está em texto puro no banco e nos 30 dumps da pasta sincronizada. Vale **mesmo com**
  `BORA_SEGREDO_COLUNAS` ligada. `entity/ConfigPlataforma.java:22-23`. **LEITURA.**
- **8.5** CORS com `*` e `allowCredentials: true` — **o furo descrito NÃO existe na produção, e o
  defeito real é outro. FECHADO (23/10).** Li o servidor: `BORA_CORS_ORIGINS` **está definida**, com
  três origens (o domínio, o www e o nip.io), e um preflight de `evil.example.com` contra o servidor
  de verdade volta **403, sem nenhum cabeçalho Access-Control**. Medi antes de consertar.

  **O defeito real é o padrão:** `getOrDefault(..., "*")`. Um deploy que esqueça a variável —
  servidor novo, arquivo de ambiente trocado — abre a API para qualquer site **com credenciais, em
  silêncio**, e nada na tela denuncia. Falhar aberto num item de segurança é o padrão errado. Agora o
  padrão é **localhost** (serve o desenvolvimento, não serve ninguém na internet) e a falta da
  variável aparece no log em voz alta — mesma regra do App Secret do WhatsApp e da chave de cifragem.
  Testes: `OcorsNaoFalhaAbertoTest` (6), que rodam num JVM sem a variável, logo medem o caminho do
  padrão. **LEITURA.**
- **8.6** Um estranho escreve no cadastro de cliente pelo cardápio público — **FECHADO (23/10)**.
  Isto já estava fechado **em parte**: antes, quem digitasse o telefone de um cliente **reescrevia** o
  endereço cadastrado dele; o conserto de então passou a só completar o que estava em branco.

  Só que "em branco" também é porta. Telefone de cliente não é segredo — está no grupo do bairro, no
  comprovante, na agenda de muita gente. Um estranho gravava o endereço **dele** no cadastro de um
  cliente que estava sem endereço, e a próxima entrega da loja para aquele cliente ia para lá.

  Agora o cardápio **não escreve endereço em cadastro que já existe** — e não se perde nada: desde a
  V48 o endereço da entrega fica no **próprio pedido**, que é o que o motoboy lê. Nome em branco
  continua sendo completado (nome não manda comida para lugar nenhum). Testes:
  `OcardapioNaoEscreveNoCadastroTest` (7). **LEITURA.**
- **8.7** Logo e banner de loja suspensa continuam no ar — **FECHADO (23/10)**, e eram **três**
  endpoints, não um: logo, banner e as **fotos dos produtos**. Loja suspensa, arquivada ou com prazo
  vencido tinha o cardápio devolvendo 404 e a marca dela continuava sendo servida pela infraestrutura
  da plataforma. Duas coisas erradas: a incoerência (página meio carregada em quem tem o link antigo
  é pior que página que não carrega) e a plataforma seguir hospedando a imagem de quem não paga. Há
  teste cobrando que a marca e o cardápio respondem **igual**. Testes:
  `LojaSuspensaSaiDoArInteiraTest` (6). **LEITURA.**
- **8.8** Token do webhook comparado com `equals` — **FECHADO (23/10)**. Eram **dois** lugares com
  `equals` e **três** que já faziam certo, cada um com a sua cópia do código. Agora há um lugar só
  (`security/Segredos`), e nulo recusa **inclusive contra nulo**: integração sem segredo cadastrado
  aceitando chamada sem segredo é o webhook aberto para qualquer um, e esse não é ataque de
  laboratório, é um `curl`.

  **O que não dá para cobrir por teste, e está registrado no código:** a mutação que troca
  `MessageDigest.isEqual` por `equals` **sobrevive** — os dois devolvem a mesma resposta, o que muda é
  o **tempo**, e tempo não dá para afirmar numa asserção sem criar um teste que passa e falha sozinho.
  A propriedade está garantida pela escolha da função, e é por isso que existe **um** lugar: um lugar
  é fácil de reler e julgar. Testes: `SegredoSeComparaEmTempoConstanteTest` (9). **LEITURA.**

**Bloco 8 fechado por inteiro** (8.1 a 8.8) em 23/10/2026.

**Rodada de mutação da onda 7:** 19 mutantes, **18 mortos**; o 19º é o do 8.8, acima. **Três coisas
que a rodada pegou, e as três eram minhas:** (1) a primeira versão do teste do 8.3 **mockava** o
`AuthContext` pedindo `thenCallRealMethod` — varargs não repassa, o mock não estourava, e **cinco
testes passaram verde medindo nada**; trocado pelo `AuthContext` de verdade com a sessão no
`SecurityContext`. (2) Um mutante de **inserção** deixou `Segredos.java` mutado em produção **duas
vezes**, porque o original fica sendo substring do mutado e a restauração não reconhece que houve
mutação; restaurado à mão e a definição corrigida para **trocar** a linha em vez de inserir antes
dela. (3) Um mutante do 8.6 **não compilava** (return inalcançável) e apareceu como "morto" —
mutante que não compila não prova nada.

**O que foi procurado e NÃO existe:** vazamento entre lojas. O agente varreu os 29 repositórios método
por método e os 70 `findById` de controller e service. Todo acesso a dado de loja é filtrado por
`loja_id`. **Esse é o achado mais importante do relatório de segurança, e é uma boa notícia.**

---

## 9. Operação e deploy

- **9.1** 5 rotinas agendadas e 4 threads — **FECHADO na onda 3** (commit `d4bde25`): são 6 rotinas e
  **8** threads. As duas de sobra são para a próxima, porque thread parada não custa nada e rotina na
  fila custa a loja fora do aplicativo. **LEITURA.**
- **9.2** **O deploy pode deixar o site no chão sem rollback.** Se o `docker run` do passo 8 falhar, o
  `set -e` mata o script antes do passo 9 e não existe mais container chamado `api`. E o vigia faz
  `docker restart api`, que falha, e ele apaga o marcador de falha de todo jeito — alterna para sempre
  sem consertar. **LEITURA.**
- **9.3, 9.4 e 9.5** são o **mesmo defeito em três lugares** — **FECHADOS (23/10)**:
  `@Transactional` em volta de um método que faz chamada HTTP. A transação — e a conexão do pool, que
  tem 20 — fica presa pelo tempo de resposta de outra empresa, e o PostgreSQL não limpa versões
  antigas das linhas tocadas enquanto ela viver.

  **9.3** tinha ainda um segundo defeito no mesmo laço, e é o pior dos três: o `break` olhava
  `enviados`, que só subia no ramo de **sucesso**. Com o WhatsApp fora do ar, nenhum envio dava certo,
  o contador ficava em zero, o `break` nunca disparava e o laço percorria a **base inteira** — um
  tempo limite de HTTP por cliente. Agora o teto conta **tentativa**: falha também gasta cota, e é
  isso que faz o laço terminar. Sem transação em volta, cada envio gravado fica gravado — se a 40ª
  falhar, as 39 que **saíram de verdade** não podem ser desfeitas, porque já aconteceram no mundo.

  **9.4** falava com o Asaas uma vez por loja, com gravação no meio, travando a linha da loja.
  **9.5** segurava a conexão por até 64 s falando com a Anthropic; agora a IA responde **fora** da
  transação e só a gravação dos produtos entra numa, curta — a atomicidade do "ou entra o cardápio
  inteiro, ou não entra nada" fica preservada.

  **E o teste achou um QUARTO caso que a varredura não listou:** ele não trava só os três, varre o
  projeto procurando o padrão — e encontrou `AsaasSubcontaService.status()`, a tela de Integrações,
  que segurava uma conexão do pool a **cada abertura**, com a linha da loja travada esperando o Asaas.
  Testes: `ChamadaDeForaNaoMoraDentroDaTransacaoTest` (7). **LEITURA.**
- **9.6** PIX pago para um `paymentId` desconhecido — **FECHADO (23/10)**. Era um `ifPresent` seco:
  pagamento confirmado para um id que não casa com pedido nenhum devolvia 200 e **não deixava rastro
  em lugar nenhum**. O dinheiro entrou na conta do lojista, não há pedido, e ninguém tem como ligar
  uma coisa na outra depois. Acontece de verdade: pedido apagado, cobrança criada e o pedido perdido
  antes de gravar, cliente pagando um link antigo.

  Agora há linha de auditoria com a loja, o id do pagamento, o evento e o **valor** — é o que permite
  conciliar na mão. Continua devolvendo **200 de propósito**: o Asaas reenvia o que não recebe 200, e
  reenviar não vai fazer o pedido aparecer. Testes: 3 casos novos em
  `PedidoReabreNoWebhookDoPixTest`, incluindo o risco do outro lado — avisar em **todo** pagamento
  faria o log de auditoria virar ruído, e aí o caso que importa se perde no meio. **LEITURA.**
- **9.7** O vigia reinicia a API quando o problema é o banco — **FECHADO (23/10)**, e a **SUSPEITA
  virou medição**: um teste contra a aplicação de verdade pergunta ao registro de indicadores do
  Spring e confirma que o `/actuator/health` **inclui o componente `db`**. Em produção o endpoint não
  mostra detalhes (e não vai mostrar), então essa era a única forma honesta de saber.

  Entrou o grupo **`viva`** (só o `ping`): o vigia pergunta pelo **processo**, que é a única pergunta
  que justifica um reinício — reiniciar não conserta banco, e a cada reinício as requisições em voo
  morrem. O `/actuator/health` cheio continua existindo e continua sendo o que o **deploy** olha, onde
  agregar o banco está certo: versão que não fala com o banco não serve.

  Mais duas coisas no vigia: se a API responder **dentro** do container e não de fora, ele **não**
  reinicia — o problema é o Caddy, o DNS ou a rede. E quando o processo volta mas o health cheio
  continua DOWN, ele escreve que o que está fora é **depois** da API, em vez de dar o caso por
  resolvido. O deploy passou a imprimir um diagnóstico antes do rollback dizendo se o processo subiu:
  sem isso, RDS fora do ar aparecia como "a versão nova não ficou sadia" e mandava procurar defeito em
  código bom. Testes: `OvigiaOlhaOprocessoNaoObancoIT` (5). **LEITURA.**
- **9.8** **Um dump cortado passa pelas duas conferências e é anotado como "ok".** A assinatura `PGDMP`
  está no começo do arquivo; o que falta é o fim. O que fecharia: `pg_restore --list`. **LEITURA.**
- **9.9** Janela de perda e restauração nunca testada — **a metade que é minha está FECHADA (23/10)**.

  **O ensaio de restauração virou rotina.** Backup que ninguém restaura é esperança, e restaurar uma
  vez em setembro não diz nada sobre o dump de hoje. O `ensaio-de-restauracao.sh` restaura o dump mais
  novo num Postgres descartável e **conta as linhas** das tabelas que importam, mais a versão do
  schema — dump que restaura vazio não é backup. Rodado contra a produção hoje: **5 lojas, 13
  usuários, 125 produtos, 32 pedidos, schema V57**. Roda aos domingos, longe dos horários de dump para
  nunca pegar arquivo pela metade. Nada toca o banco de produção: o destino é um container novo, com
  senha local, apagado no fim inclusive se der erro.

  **A janela caiu de 24h para ~6h**: o dump passou a ser de 6 em 6 horas. Medido antes de mexer:
  3,3 MB por dump, 14 dias de retenção, 56 arquivos, ~185 MB num disco com **48 GB livres**.

  **O que continua sendo seu:** não existe cópia para **fora** feita pelo servidor — `BORA_BACKUP_S3`
  não está definida, e o próprio backup avisa isso em voz alta a cada execução. A segunda perna hoje é
  a cópia para o seu computador. Um bucket S3 e um usuário IAM são da sua conta AWS.
- **9.10** Dumps com dado pessoal em pasta sincronizada — **FECHADO para o que vem (23/10); o que já
  está lá é sua decisão.** Medido: **53** dumps (a varredura dizia 30), **171 MB**, dentro de
  `C:\Users\user\OneDrive\Desktop\Bora\backups-bora` — cada um com o banco inteiro, telefone,
  endereço e CPF de todo cliente de todas as lojas. No servidor nascem `600` de propósito; a proteção
  não atravessa a cópia.

  O destino agora é `C:\bora-backups`, pasta local, fora de qualquer sincronização — a função de
  "segunda perna" continua valendo, só não está mais na nuvem de terceiro. **Os 53 arquivos antigos
  continuam no OneDrive:** mover ou apagar dado de cliente já copiado é sua decisão, e o log de cada
  cópia volta a avisar enquanto houver algum lá.

  Duas coisas a mais que apareceram medindo: o script de cópia morava **dentro da pasta ignorada pelo
  git**, então a única cópia dele estava fora de controle de versão — e é um script de operação; foi
  para `bora-landing/deploy` e a tarefa agendada do Windows foi reapontada. E a conferência dele usava
  a assinatura `PGDMP`, que **não prova nada** sobre o arquivo estar inteiro (item 9.8); agora o
  tamanho é comparado com o do servidor.

  **A boa notícia que também medi:** `backups-bora/` **está** no `.gitignore` e o git rastreia **zero**
  dumps — nunca houve vazamento por esse caminho.
- **9.11** A trava da renovação de token é dentro da JVM — **FECHADO (23/10)**. O `synchronized`
  continua, e resolve de graça a disputa entre as 8 threads do poller e as requisições do painel
  dentro **deste** processo. O que ele não resolve é uma **segunda instância**, e o `application.yml`
  planeja uma.

  No iFood isso é grave de um jeito específico: ele **invalida o refresh token anterior** quando emite
  o novo. Duas instâncias renovando ao mesmo tempo matam o token uma da outra, e a loja precisa
  reautorizar do zero — **todas as lojas de uma vez**, porque todas renovam no mesmo ciclo, de forma
  silenciosa, e só aparece quando os pedidos param de chegar.

  A V59 traz um **arrendamento de 2 minutos** no banco: quem consegue gravar a marca renova; quem não
  consegue espera, relê a linha e usa o token que o outro gravou. É arrendamento e não
  `select for update` de propósito — a renovação fala com o iFood, e segurar lock de banco durante
  chamada HTTP é exatamente o defeito dos itens 9.3, 9.4 e 9.5.

  **O que medir corrigiu no diagnóstico:** na 99 (Open Delivery) o risco **não existe** — lá o token
  sai de `client_credentials`, que não invalida o anterior, e o cliente nem guarda refresh token. Por
  isso o arrendamento está só no iFood. Testes: `OtokenNaoEreNovadoEmDobroTest` (7). **LEITURA.**

**Blocos 7 e 9 fechados** em 23/10/2026 — **com isto, a varredura inteira está fechada.**

**Rodada de mutação da onda 8:** 29 mutantes (22 de código, 7 de tela), **28 mortos**. O que sobreviveu
era **código redundante meu**: uma guarda de string vazia no limite da promoção que o `parseInt` já
cobria — tirei a linha em vez de deixar o que nenhum mutante consegue quebrar. **Uma lacuna
registrada:** não há mutante para a asserção de atomicidade do `importarCardapio`, porque tirar o
`tx.execute` exige mexer nos dois extremos do lambda e o arpão aplica uma troca só; a primeira
tentativa não compilou e apareceu como "morto" — e mutante que não compila não prova nada.

**O arpão ganhou a guarda que faltava:** ele agora **recusa mutante de inserção**. Esse tipo deixou
arquivo de produção mutado **quatro vezes** nesta sessão, sempre pelo mesmo motivo — o texto original
continua dentro do mutado, e a restauração não reconhece que houve mutação. Agora falha na hora de
aplicar, não depois. (Na mesma rodada ele recusou um mutante meu pelo novo critério, meia hora depois
de eu o ensinar.)

**O que está bom e foi verificado:** todo cliente HTTP tem tempo limite (5 fábricas, 6 consumidores,
varredura completa); log sem dado pessoal nem segredo; log com teto de 100 MB; desligamento gracioso
coerente de ponta a ponta; os passos 1 a 6 do deploy; a cópia do backup para fora funciona (19
execuções, nenhuma falha); o Caddy cobre a janela do deploy.

---

## 10. Decisões que são do dono, não minhas

1. **A Zirá, antes de 26/10.** Refazer a assinatura é ação na conta financeira.
2. **Os 2% do PIX.** Se era para cobrar, não está cobrando desde sempre.
3. **Integrações é do gerente ou só do administrador?** O `PERMISSOES.md` diz administrador; o código
   deixa o gerente. Hoje o menu segue o código.
4. **Complemento com estoque** — hoje o modelo não comporta. É construir, não consertar.
5. **Base do split**: hoje incide sobre o pedido inteiro, frete incluído, e não incide sobre o
   cashback. Qual é a regra certa?
