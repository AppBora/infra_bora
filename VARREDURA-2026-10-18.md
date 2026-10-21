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

### 1.2 O mesmo no cardápio público
`assets/js/cardapio.js:281-291` não inclui cashback no total; os listeners de `:457-458` não cobrem
o `ckUsarCashback`. No PIX o QR sai certo e se corrige; no "na entrega" o cliente separa o dinheiro
errado. **LEITURA.**

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

### 1.5 Saldo de cashback é lido-somado-gravado em Java, sem trava
Dois checkouts do mesmo cliente ao mesmo tempo gastam o mesmo saldo duas vezes. É o defeito do
estoque que já foi consertado, agora no cashback. `FidelidadeService.java:168-177` e `:242-253` ·
`ClienteRepository` não tem nenhum `@Modifying` · `Cliente` não tem `@Version`.
O jeito certo já existe no projeto: `ProdutoRepository.java:31-37`. **LEITURA.**

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

### 2.5 Excluir um insumo deixa a ficha fantasma e o produto para de baixar — calado
`InsumoService.java:47-49` apaga só o insumo; `produto_insumo` não tem chave estrangeira. Depois,
`consumirFicha` devolve **ZERO** em vez de `null` (`:96-108`), e como os dois canais fazem
`if (custoFicha == null) baixarEstoque(...)`, a baixa do produto **não roda** — e o item é gravado
com `consumiuFicha = true`, mentindo. **LEITURA.**

### 2.6 Complemento nunca baixa estoque — não existe onde
`ComplementoItem` tem `id, lojaId, grupoId, nome, preco`. Sem campo de estoque, sem ligação com
insumo (`V20__complementos.sql`). Numa açaiteria metade do valor está nos adicionais. Não é um `if`
esquecido: o modelo não comporta. **LEITURA — e é decisão de produto, não bug.**

### 2.7 PIX pago depois do cancelamento não rebaixa o estoque
O caminho trata o caso e até reconsome o cashback de propósito (`PublicController.java:736`), mas não
refaz a baixa de estoque. Se o lojista preparar o pedido (e vai, o dinheiro está na conta), a comida
sai e o estoque segue contando. **LEITURA.**

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

### 3.4 Dois pagamentos manuais no mesmo dia: o segundo some
Sem cobrança aberta no Asaas, a chave do registro é `"manual:" + lojaId + ":" + dia`, e
`registrarPagamento` descarta id repetido em silêncio. A tela diz "Pagamento registrado".
`AssinaturaService.java:282` e `:308`. **Os R$ 398 da Zirá são duas mensalidades.** **CONFERIDO POR MIM.**

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

### 4.1 O painel faz 3 varreduras da loja inteira a cada 6 segundos
`PedidoService.java:553-559` — as três contas não têm corte de data. Com 26 mil pedidos: **615 ms e
~325 MB de leitura por atualização**, por loja aberta. Dois índices resolvem: medido, **615 ms → 0,4 ms**.
**MEDIDO PELO AGENTE.**

### 4.2 `endereco_entrega` é varchar(255) e recebe o endereço que precisou de 500
O **mesmo valor** do marketplace vai para dois lugares no mesmo método: `PedidoService.java:456`
corta em 500 (coluna de 500); `:329` grava sem corte numa coluna de 255. A V37 largou
`cliente.endereco` para 500 justamente por causa desse endereço. O INSERT é recusado e **o pedido do
marketplace inteiro se perde**. `ddl-auto: validate` não pega tamanho.
**MEDIDO PELO AGENTE** (`ERROR: value too long for type character varying(255)`).

### 4.3 Excluir produto com complementos dá erro 500
`complemento_grupo` tem FK para produto sem `ON DELETE`, e `ProdutoService.java:64-66` é um delete
seco. Pega justamente os produtos para os quais os complementos existem. **MEDIDO PELO AGENTE.**

### 4.4 Observação longa no pagamento manual quebra o registro
`pagamento_assinatura.descricao` é varchar(200), já nasce com o nome da loja, e a observação é
**concatenada** sem validar tamanho. É a função que você ainda precisa usar. **MEDIDO PELO AGENTE.**

### 4.5 Erro do marketplace sem corte em `ultimo_erro varchar(500)`
`IfoodClient.java:277` e `:486` gravam sem cortar. O pior: as duas linhas estão **dentro do
tratamento de erro** — se o UPDATE estoura, a falha nunca é registrada e a tela mostra a loja como se
nada tivesse acontecido. **MEDIDO PELO AGENTE** (o estouro) · **SUSPEITA** (se o iFood manda mensagem
desse tamanho).

### 4.6 Índice duplicado e três índices que ninguém usa
`idx_pedido_item_pedido` (V7) e `idx_pedido_item_loja` (V15) são o **mesmo índice**, 24 MB cada com
800 mil itens, mantidos em todo insert. Sem uso: `idx_pedido_bairro_entrega` (V48),
`idx_loja_nao_excluida` (V30), `ix_pagamento_assinatura_loja` (V41). **MEDIDO PELO AGENTE.**

### 4.7 Outros
- O índice do acerto desperdiça a coluna do meio porque a consulta usa `lower(trim(entregador))`:
  381 ms para achar 338 linhas.
- `select loja_id, max(criado_em) group by loja_id` do painel da plataforma: **Seq Scan, 408 ms**.
- N+1 no balancete (3 consultas por loja) e no desempenho (5 por loja).
- Apagar cliente deixa pedido órfão (dívida já assumida em comentário).

---

## 5. Marketplaces

- **5.1** Integração do iFood que cai em ERRO **nunca volta sozinha** — passa a ser consultada a cada
  10 min em vez de 30 s, e a loja some do aplicativo. A 99 tem a cura; o iFood não.
  `IfoodClient.java:276,485` vs `OpenDeliveryClient.java:254-258`. **LEITURA.**
- **5.2** O status que a loja muda aqui pode nunca chegar lá, e ninguém é avisado. O `boolean` de
  retorno é descartado (`IntegracaoService.java:285`). Na 99 a ordem é obrigatória, então um passo
  perdido trava todos os seguintes. **LEITURA.**
- **5.3** Aceite que falhou e a loja tocou no card: nunca mais é reenviado
  (`MarketplacePoller.java:248`), e o aviso some em 30 segundos. **LEITURA.**
- **5.4** Renovação do token: o iFood mata o anterior antes de a gente gravar o novo
  (`IfoodClient.java:272-283`). Falha no meio = loja reautoriza do zero, sem ninguém detectar. **LEITURA.**
- **5.5** O poller grava a linha inteira e desfaz o que o lojista acabou de salvar. **LEITURA.**
- **5.6** O que o iFood muda lá fora não chega aqui — só cancelamento. Pedido entregue pelo
  entregador do iFood fica congelado no painel para sempre. **LEITURA.**
- **5.7** Pedido com `isTest: true` entra como venda de verdade (`isTest` não aparece em nenhum .java),
  e o "Simular pedido" cria pedido que **não dá para cancelar**. **LEITURA.**
- **5.8** Taxa do marketplace entra como receita da loja mesmo quando o marketplace fica com ela.
  **LEITURA** no código · **SUSPEITA** no tamanho.
- **5.9** WhatsApp: a assinatura prova que veio da Meta, não de qual loja. Quebra na **segunda** loja
  que ligar o robô. **LEITURA.**

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
- **7.4** "Despachar rota" falha em silêncio — `catch (e) {}` vazio, e despacha o bairro inteiro sem
  confirmação (`entregas.js:18-21`). **LEITURA.**
- **7.5** PDV: complemento que não carrega grava lista vazia no cache e o produto passa a vender pelo
  preço base até recarregar a página (`pdv.js:86-92`). **LEITURA.**
- **7.6** Importar cardápio multiplica o preço por 100 quando vem com ponto: "12.50" vira 1250
  (`produtos.js:146`). **LEITURA.**
- **7.7** Produto e entregador desativados **voltam a ligar** quando alguém edita (`ativo: true` fixo
  no payload), e não existe como desativar pelo painel. **LEITURA.**
- **7.8** A promoção morre no 20º uso (limite fixo no código) e não há como encerrá-la — o endpoint
  existe, a tela não usa. **LEITURA.**
- **7.9** Celular: 11 telas sobrescrevem o empilhamento do CSS com estilo em linha; Entregas monta
  tabela de 6 colunas sem contêiner de rolagem; o CSS não tem nenhuma regra abaixo de 700px. **LEITURA.**
- **7.10** Imprimir caixa e recibo do motoboy não fazem nada com pop-up bloqueado — a função
  compartilhada já trata isso, essas duas não. **LEITURA.**
- **7.11** Listas vazias virando tela em branco (Ajustes, últimos pedidos do Dashboard). **LEITURA.**
- **7.12** Não dá para corrigir o cadastro de um cliente: só existe excluir, e excluir leva o cashback
  e o histórico junto, sem avisar. O endpoint de editar existe. **LEITURA.**

**Cobertura de teste das telas:** as 34 têm cobertura estática (sintaxe, arquivo que existe, ordem do
`api.js`, `requireAuth`). Teste de **comportamento** existe para **uma**: `caixa.html`. As que mexem em
dinheiro e não têm nada: `pdv`, `produtos`, `novo-pedido`, `cardapio`, `acerto-entregadores`.

---

## 8. Segurança

- **8.1** O freio — **JÁ CONSERTADO**, ver 0.1.
- **8.2** **Rebaixar alguém não tira o poder por 24h.** O papel sai do token, nunca do banco
  (`JwtAuthFilter.java:78`). O filtro **reconsulta** o banco para `ativo` e para o vínculo com a loja,
  e o papel ficou de fora. Um administrador demitido ainda troca a senha de todo mundo — inclusive de
  quem o rebaixou — e recupera o acesso. Contorno que já funciona hoje: **desativar** em vez de
  rebaixar. **LEITURA.**
- **8.3** O balconista vê o faturamento da loja no Dashboard (`/api/vendas/termometro` sem
  `requirePapel`), e o custo de produtos e insumos em quatro endpoints. As telas irmãs exigem papel.
  **LEITURA.**
- **8.4** `config_plataforma.valor` **não passa pelo cifrador** — o `client_secret` do iFood e da 99 da
  plataforma está em texto puro no banco e nos 30 dumps da pasta sincronizada. Vale **mesmo com**
  `BORA_SEGREDO_COLUNAS` ligada. `entity/ConfigPlataforma.java:22-23`. **LEITURA.**
- **8.5** CORS com `*` e `allowCredentials: true` (`config/WebConfig.java:22-27`). Limitado porque a
  sessão é Bearer em localStorage, não cookie. **LEITURA** · depende de `BORA_CORS_ORIGINS` no
  servidor, que eu não li.
- **8.6** Um estranho escreve no cadastro de cliente da loja pelo cardápio público (endereço em
  branco). Não dá para **ler** dado de cliente por aí. **LEITURA.**
- **8.7** Logo e banner de loja suspensa continuam no ar — o único endpoint público que não chama
  `lojaAtiva`. **LEITURA.**
- **8.8** Token do webhook comparado com `equals` (vazamento por tempo). O projeto já faz certo em
  dois outros lugares. Prioridade baixa. **LEITURA.**

**O que foi procurado e NÃO existe:** vazamento entre lojas. O agente varreu os 29 repositórios método
por método e os 70 `findById` de controller e service. Todo acesso a dado de loja é filtrado por
`loja_id`. **Esse é o achado mais importante do relatório de segurança, e é uma boa notícia.**

---

## 9. Operação e deploy

- **9.1** **5 rotinas agendadas e 4 threads** (`application.yml:10`). A quinta fica na fila — e a que
  pode ficar é o `MarketplacePoller`, sem o qual **o restaurante some do iFood**. **LEITURA** (a conta
  das 5 e das 4 é fato; o atraso real não foi medido).
- **9.2** **O deploy pode deixar o site no chão sem rollback.** Se o `docker run` do passo 8 falhar, o
  `set -e` mata o script antes do passo 9 e não existe mais container chamado `api`. E o vigia faz
  `docker restart api`, que falha, e ele apaga o marcador de falha de todo jeito — alterna para sempre
  sem consertar. **LEITURA.**
- **9.3** `recuperarClientes` não tem teto quando o WhatsApp não responde: o contador só sobe no ramo
  de sucesso. Com 2.000 clientes e timeout, ~7 horas — **dentro de uma transação** quando chamado pelo
  painel. **LEITURA.**
- **9.4** `reconciliarSubcontas` conversa com o Asaas **dentro** de uma transação e grava no meio,
  travando a linha da loja. É o mesmo defeito já consertado no cobrador de PIX. **LEITURA.**
- **9.5** `importarCardapio` segura uma conexão do pool (de 20) por até 64 s falando com a Anthropic.
  **LEITURA.**
- **9.6** PIX pago para um `paymentId` desconhecido: 200 e **nenhum log**. Dinheiro na conta, nenhum
  pedido, nenhum rastro. **LEITURA.**
- **9.7** O vigia reinicia a API quando o problema é o **banco** (o health agrega o indicador do RDS),
  e o deploy faz rollback de código bom pelo mesmo motivo. **LEITURA** · **SUSPEITA** sobre o health
  agregar mesmo.
- **9.8** **Um dump cortado passa pelas duas conferências e é anotado como "ok".** A assinatura `PGDMP`
  está no começo do arquivo; o que falta é o fim. O que fecharia: `pg_restore --list`. **LEITURA.**
- **9.9** No pior caso se perdem **~28 horas** (dump às 06:15, cópia para fora às 10:00). A última
  restauração testada foi em 29/09, na mão. **MEDIDO PELO AGENTE** (nos horários do `copias.log`).
- **9.10** Os 30 dumps em `backups-bora\` têm o banco inteiro — telefone, endereço, CPF — numa pasta
  sincronizada com a nuvem. No servidor nascem `600` de propósito; a proteção não atravessa a cópia.
- **9.11** A trava que impede duas renovações de token simultâneas é **dentro da JVM**. Quem subir uma
  segunda instância derruba a autorização do iFood de todas as lojas. O `application.yml:27` planeja
  essa segunda instância. **LEITURA.**

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
