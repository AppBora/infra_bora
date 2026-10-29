# Pente fino final da aplicacao inteira — 29/10/2026

**15 agentes**, um por fatia, cobrindo a aplicacao ponta a ponta: landing, painel, backend,
banco, infra, marketplaces, pagamentos, testes e processo de negocio. **Cada achado passou
por 2 ceticos** instruidos a derruba-lo, com ordem de derrubar na duvida.

| | |
|---|---|
| achados brutos | **78** |
| sobreviveram aos ceticos | **44** |
| derrubados | **34** |
| graves (alta) | **7** |
| medios | 23 |
| baixos | 14 |

**Travas que todos tiveram:** sem deploy, sem escrita no banco, nenhuma chamada autenticada ao
iFood ou a 99, e so reportar o que mediram com arquivo:linha ou comando e saida.

**A primeira rodada perdeu 9 das 15 fatias** por timeout e conexao recusada; elas foram
refeitas numa segunda leva, que completou as 9 sem erro. O numero acima ja e o das duas.

---

## GRAVE — mexe em dinheiro, em pedido ou em acesso (7)

### 1. Criar usuario, trocar papel e redefinir senha: zero teste nas duas camadas, incluindo a trava de escalada de privilegio

**Fatia:** A qualidade dos proprios testes

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/UsuarioService.java (criar:43, atualizarPapel:70, definirSenha:96, definirAtivo:110, parsePapel:124-132) e C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/assets/js/usuarios.js`

**O que:** O caminho inteiro de administracao de acesso da loja nao tem teste de comportamento em nenhuma das duas camadas. Entre o que fica sem rede: o guarda de escalada de privilegio em parsePapel (UsuarioService.java:127-129, `if (p == Papel.ADMINISTRADOR_BORA) throw FORBIDDEN` -- a loja nao pode se promover a admin da plataforma); os 5 `ctx.requirePapel("ADMINISTRADOR_LOJA")` das linhas 38, 44, 71, 81, 97 e 111; o minimo de 8 caracteres da senha (linhas 47 e 99); e o impedirAlvoProprio que evita o admin mexer no proprio papel (linha 72).

**Como foi medido:** Cruzei os 188 arquivos de src/main/java/br/com/bora com src/test/java por nome de classe (`grep -rl "\bUsuarioService\b" src/test/java`): 0 arquivos. Confirmei com `grep -rn "UsuarioService\|AuthController" src/test/java --include=*.java`: nenhuma linha. No frontend, `grep -rl "usuarios.js\|definirSenha\|atualizarPapel" testes/`: nenhum arquivo. usuarios.js so e alcancado pelo estatico.test.mjs, que confere compilacao e requireAuth -- nao comportamento.

**Impacto:** Se o guarda de parsePapel cair numa refatoracao, um ADMINISTRADOR_LOJA passa a poder se promover a ADMINISTRADOR_BORA -- o papel que RebaixarTiraOPoderNaHoraTest:194 prova que entra em loja suspensa e atravessa a checagem de suspensao. Seria acesso de plataforma concedido pela propria loja, e nenhum teste do projeto acenderia.

### 2. O cardápio público lê ~600 kB de foto em base64 do Postgres em cada abertura e joga tudo fora

**Fatia:** Consultas, N+1 e custo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/controller/PublicController.java:210-211 (a consulta) e :258 (onde o valor é descartado); C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/repository/ProdutoRepository.java:20; C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/entity/Produto.java (coluna imagem_url, @Column(columnDefinition="TEXT"))`

**O que:** O cardápio público chama `produtos.findByLojaIdAndAtivoTrueOrderByCategoriaAscNomeAsc(lojaId)`, que devolve a entidade `Produto` INTEIRA — inclusive `imagemUrl`, que guarda a foto do produto como data URL em base64 dentro da coluna TEXT. Logo depois, na linha 258, o JSON troca esse conteúdo por um endereço: `m.put("imagem", enderecoDaImagem(lojaId, p.id, p.imagemUrl))`, e `enderecoDaImagem` devolve "/public/loja/N/produto/N/imagem" para tudo que começa com "data:". Ou seja: o base64 sai do banco, viaja até a aplicação, é hidratado em String no heap e é descartado sem nunca ir para o cliente. O conserto para isso JÁ EXISTE no mesmo repositório, para o painel: a projeção `resumoDaLoja` (ProdutoRepository.java:146-151) seleciona campo por campo e troca a foto por `case when p.imagemUrl is null or p.imagemUrl = '' then false else true end`. O cardápio público é o único caminho que ficou de fora dela.

**Como foi medido:** Baixei o cardápio das 4 lojas que respondem 200 e somei, com curl, uma por uma, as fotos que o endpoint público serve (o `servirImagem`, PublicController.java:348-378, decodifica o base64 da própria coluna, então o tamanho binário prova o conteúdo da coluna): loja 18 → 40 imagens, 451.183 bytes binários, ou seja ≈601 kB depois do base64 (451.183 x 4/3); loja 19 → 451.183 bytes; loja 20 → 451.183 bytes; loja 17 → 0 imagens. Tempo de resposta de /public/loja/N/cardapio, 5 medidas cada: loja 17 (18 produtos, 0 fotos) 0,067 / 0,075 / 0,097 / 0,073 / 0,081 s; loja 18 (44 produtos, 40 fotos) 0,139 / 0,120 / 0,111 / 0,133 / 0,126 s; linha de base /public/loja/18/marca (1 consulta) 0,087 / 0,084 / 0,078 / 0,058 s. Também medi que a resposta sai sem cache nenhum: `Cache-Control: no-cache, no-store, max-age=0, must-revalidate`, `Expires: 0` — toda abertura paga o preço inteiro.

**Impacto:** ≈601 kB lidos do Postgres e alocados no heap por abertura do cardápio de cada loja da Zirá (1,8 MB somando as três), e a resposta sai em ~126 ms contra ~78 ms da loja sem foto e ~75 ms da linha de base. É a tela mais aberta do sistema (todo cliente, toda visita) e a única sem cache. O custo cresce com o tamanho das fotos que o lojista subir, não com o número de pedidos.

### 3. PIX que expira e e pago depois: a baixa de estoque nunca acontece, e o cancelamento seguinte devolve em dobro

**Fatia:** Estoque, insumo e ficha tecnica

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/EstornoDaVendaService.java:79 e :254-281 (statusAntesDoCancelamento e rebaixarDeNovo); C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/CobradorDePixService.java:200-213; C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/controller/PublicController.java:911`

**O que:** rebaixarDeNovo (o unico caminho que rebaixa estoque quando um pedido cancelado volta a valer) decide o que rebaixar lendo statusAntesDoCancelamento(p), que procura no log_status a ultima linha com status_novo = 'CANCELADO'. O CobradorDePixService, que e justamente quem cancela o PIX expirado, grava o pedido direto (pedidos.save na linha 209) e NAO escreve nenhuma linha de log_status. Logo, no unico caso para o qual o rebaixarDeNovo foi escrito -- o proprio javadoc dele diz "Um unico caso: o PIX do cardapio expirou, o pedido foi cancelado ... e DEPOIS o dinheiro entrou" -- statusAntesDoCancelamento devolve null, cai no ramo da linha 273, loga "NADA foi baixado de novo" e devolve 0. O estoque e o insumo que o cancelamento devolveu nunca saem outra vez, embora a comida va sair. Pior: o pedido reaberto fica RECEBIDO e a mensagem gravada na observacao manda o lojista "cancelar de novo" se nao for atender; esse segundo cancelamento chama devolver(p, RECEBIDO, ...) e devolve o estoque UMA SEGUNDA VEZ -- a polpa volta duas vezes ao pote para um acai que saiu uma.

**Como foi medido:** grep -rn "new LogStatus()|logs.save|setStatusNovo" em bora-fase-3-backend-java/src/main/java devolveu TRES escritores, todos no PedidoService (linhas 489, 524 e 962: cancelarPorMarketplace, o avanco vindo do entregador e o registrarLog do alterarStatus). grep -n "LogStatus|logs." no CobradorDePixService.java nao devolveu NENHUMA linha. Li o bloco de cancelamento do cobrador (linhas 200-213): define status CANCELADO, pedidos.save(p) e devolucao.devolver(p, anterior, false), sem log. Li statusAntesDoCancelamento (EstornoDaVendaService.java:79-90): varre o historico e so guarda statusAnterior quando statusNovo == CANCELADO; sem linha nenhuma, anterior fica null e o metodo retorna null. Li rebaixarDeNovo (:254-281): com statusAntes null, loga e retorna 0 antes de tocar em qualquer item. Confirmei tambem por que isso passou nos 1238 testes: OpedidoReabertoNaoBaixaEstoqueDuasVezesTest mocka o repositorio de log e injeta um historico montado a mao (linhas 107, 203 e 227 fazem when(logs.findByLojaIdAndPedidoIdOrderByDataHoraAsc(...)).thenReturn(historico)), e a linha 188 chega a afirmar que historico vazio deve resultar em 0 -- o teste mede a simetria com um cenario que a producao nunca produz.

**Impacto:** Dinheiro e estoque, no canal que mais vende. Todo PIX de cardapio que expira em 30 minutos e cai depois (caso que o PublicController trata explicitamente, logo acontece) entrega comida sem nenhuma baixa de insumo nem de produto: o estoque fica maior do que a prateleira e o CMV do mes nao conta o ingrediente, inflando a margem do relatorio que o dono usa para decidir preco. E se o lojista seguir a instrucao da propria observacao do pedido e cancelar de novo, o estoque e devolvido pela segunda vez -- estoque inventado e silencioso.

### 4. Toda venda de balcão cai na linha "entregas sem motoboy escolhido" do Acerto Motoboy

**Fatia:** O processo de negocio ponta a ponta

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/repository/PedidoRepository.java:344-350 (entregasSemMotoboy); bora-fase-2-frontend/assets/js/pdv.js:202-214; bora-fase-3-backend-java/src/main/java/br/com/bora/service/AcertoEntregadorService.java:68-78`

**O que:** A consulta que monta a linha "(entregas sem motoboy escolhido)" filtra por status=ENTREGUE, acertoId nulo e entregador nulo/vazio — e NÃO filtra `tipo_entrega`. A Frente de Caixa grava `tipoEntrega:'RETIRADA'` e imediatamente chama `mudarStatus(id,'ENTREGUE')`, sem entregador nenhum. Resultado: cada venda de balcão satisfaz os três filtros e entra nessa linha, somando o `valorTotal` dela na coluna que a tela chama de "Recebeu outras" / "Total entregue" (acerto-entregadores.html:31-32) e que o serviço criou justamente para dizer que aquele dinheiro "esta fora da conta". O filtro era possível: `Pedido.ehRetirada()` existe e já é usado no próprio `alterarStatus`.

**Como foi medido:** Li a @Query de `entregasSemMotoboy` (PedidoRepository.java:344-350): as quatro condições são lojaId, status=ENTREGUE, acertoId is null, entregador null/vazio, mais a janela por entregueEm — nenhuma menção a tipoEntrega. Li pdv.js:202-214, que monta o pedido com `tipoEntrega: 'RETIRADA'` e logo depois `await Bora.mudarStatus(ped.id, 'ENTREGUE')`, sem passar entregador. Li Pedido.java: `taxaEntrega` nasce BigDecimal.ZERO e `entregador` fica nulo. Li AcertoEntregadorService.java:72-78, onde a linha é montada com `taxas` e `total` vindos direto dessa consulta.

**Impacto:** Numa loja com PDV, a tela de acerto do motoboy mostra todo dia a receita de balcão como dinheiro de entrega sem responsável — e o recibo impresso (acerto-entregadores.js, cabeçalho "Total entregue") sai com esse valor. O alarme que foi criado para achar entrega perdida fica afogado no faturamento do balcão: o lojista ou ignora a linha (e aí ela não serve para nada) ou vai cobrar de alguém um dinheiro que está no caixa dele.

### 5. Botao desabilitado fica identico ao habilitado: a folha de estilo nao tem regra para .btn:disabled

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `bora-fase-2-frontend/assets/css/styles.css (unica regra :disabled e a da linha 181, .btn-finish:disabled); casos medidos: pedidos.html:27 #diaSeguinte, relatorios.html:74 #lpLimpar, produtos.html:129 #catOrdemSalvar, configuracoes.html #btnCifrar`

**O que:** A classe .btn nao tem nenhum estilo de estado desabilitado. Quando o JavaScript marca o botao como disabled, ele continua com a cor cheia, com a mao de clicar no cursor e com a regra .btn:hover{filter:brightness(1.07)} ainda casando. Nada na tela muda. O caso mais feio e o botao vermelho "Apagar a movimentacao" em Relatorios: nasce disabled direto no HTML e fica igualzinho a um botao vermelho pronto para ser clicado.

**Como foi medido:** No navegador, em pedidos.html, comparei os dois botoes de navegar o dia, um ao lado do outro: #diaAnterior {disabled:false, bg:rgb(229,231,235), color:rgb(17,24,39), opacity:'1', cursor:'pointer'} e #diaSeguinte {disabled:TRUE, bg:rgb(229,231,235), color:rgb(17,24,39), opacity:'1', cursor:'pointer'} -- os quatro valores visiveis sao iguais. O print de 375px mostra o '<' e o '>' indistinguiveis. Depois percorri document.styleSheets inteiro procurando seletor com 'disabled': voltou uma unica linha, "styles.css?v=20261023 :: .btn-finish:disabled". Em relatorios.html o outerHTML e <button class="btn" id="lpLimpar" disabled="" style="background:#dc2626"> e o computado deu opacity '1', cursor 'pointer', filter 'none'.

**Impacto:** O lojista clica e nao acontece nada. Ele clica de novo, e de novo, e conclui que a tela travou -- foi exatamente assim que os defeitos mais caros desta aplicacao se manifestaram. Em Relatorios ele acha que vai apagar a movimentacao e nao apaga; em Produtos acha que salvou a ordem das categorias e nao salvou.

### 6. O @Modifying esta colado na consulta errada: marcarAceiteEnviado (UPDATE) estoura em TODA chamada, e o "confirmo" vai para o canal a cada 30 segundos

**Fatia:** iFood, 99 e OpenDelivery

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/repository/PedidoRepository.java:354-377 (cadeia: MarketplacePoller.java:478-479, 252-257, 350-354, 450-456, 218-233)`

**O que:** Na linha 354 esta o javadoc "Grava que o marketplace aceitou o aceite automatico. So a coluna da marca, nada mais." e na 355 o @Modifying(clearAutomatically=true, flushAutomatically=true). Mas entre a anotacao e o metodo que ela descreve foi inserido, em 27/10 (commit 45e20d2), um OUTRO metodo com javadoc proprio: o SELECT semAceiteConfirmado (@Query "select p from Pedido p ...", devolve List<Pedido>, linhas 368-374). Em Java a anotacao cola na PROXIMA declaracao. Resultado medido no arquivo: (a) semAceiteConfirmado, que e um SELECT, ficou com o @Modifying; (b) marcarAceiteEnviado (linha 375: @Query "update Pedido p set p.aceiteEnviadoEm = :agora where p.id = :id and p.lojaId = :lojaId", devolve int) ficou SEM @Modifying nenhum. O git mostra que o UPDATE tinha a anotacao desde 14/10 (bf811b6) e a perdeu no commit de 27/10.

**Como foi medido:** 1) Li o arquivo com `sed -n '336,382p' ... | cat -A`, que mostra a ordem exata: comentario (354), @Modifying (355), javadoc do SELECT (356-367), @Query select (368), semAceiteConfirmado (372), @Query update (375), marcarAceiteEnviado (376) -- sem @Modifying. 2) `git show 45e20d2 -- src/main/java/br/com/bora/repository/PedidoRepository.java` e `git log -S "marcarAceiteEnviado(@Param"` confirmam quem inseriu o que e quando. 3) Medi o comportamento das bibliotecas com javap nos jars que o projeto usa (pom.xml: spring-boot-starter-parent 3.3.1): `javap -c -p -cp spring-data-jpa-3.3.1.jar org.springframework.data.jpa.repository.query.AbstractJpaQuery` mostra que o seletor de execucao testa isStreamQuery, isProcedureQuery, isCollectionQuery (-> CollectionExecution), isSliceQuery, isPageQuery e SO DEPOIS isModifyingQuery; sem @Modifying e sem retorno de colecao, cai em SingleEntityExecution. `javap -c -p ... 'JpaQueryExecution$SingleEntityExecution'` mostra uma unica chamada: `jakarta/persistence/Query.getSingleResult()`. `javap -c -p -cp hibernate-core-6.5.2.Final.jar org.hibernate.query.spi.AbstractSelectionQuery` mostra getSingleResult() -> list(); `javap ... org.hibernate.query.sqm.internal.QuerySqmImpl` mostra que doList() chama verifySelect(), e verifySelect() chama SqmUtil.verifyIsSelectStatement e relanca como IllegalStateException. Ou seja: JPQL de update executado por SingleEntityExecution estoura, sempre. 4) `grep -rln "marcarAceiteEnviado|semAceiteConfirmado" src/test/` devolve 2 arquivos, e os dois usam mock(PedidoService.class) -- nenhum teste chama o repositorio de verdade, por isso os 1238 testes passam.

**Impacto:** O aceite nunca fica marcado. Em MarketplacePoller:478-479 o `confirm` VAI para o iFood/99 (enviarStatus devolve true) e, na linha seguinte, marcarAceiteEnviado estoura: a excecao sobe por criarPedido/tratarEvento e e capturada em processar (252-257), que entao NAO coloca o evento em paraConfirmar -- o evento nunca e confirmado no canal e volta no ciclo seguinte. No ciclo seguinte criarPedido ve jaImportado e chama reenviarAceiteSeFaltou (450-456), que ve aceiteEnviadoEm nulo e status RECEBIDO e manda `confirm` DE NOVO; e retentarAceites (218-233) faz o mesmo por 120 minutos, ate 10 por ciclo. Isto e exatamente o "confirm em dobro" que o proprio codigo diz ter custado o primeiro pedido real de 19/09, agora em laco de 30 segundos -- o risco que o codigo nomeia como bloqueio de conta. O pedido ENTRA (a excecao e depois da criacao e do contador), mas a coluna aceite_enviado_em de pedido de marketplace deve estar nula em 100% dos pedidos desde 27/10, o que e um jeito de conferir isso no banco sem tocar em nada.

### 7. Quando a 99 pergunta se pode cancelar, a falha do "aceito" e engolida e o pedido e cancelado so aqui

**Fatia:** iFood, 99 e OpenDelivery

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/service/marketplace/OpenDeliveryClient.java:477-505 e service/marketplace/MarketplacePoller.java:334-342`

**O que:** OpenDeliveryClient.responderPedidoDeCancelamento (linha 477) e `void` e chama `post(i, orderId, "acceptCancellation", null)` na linha 479 DESCARTANDO o retorno. O `post` (linha 490) captura HttpStatusCodeException e Exception e devolve false (linhas 500 e 503) -- nao relanca. O javadoc do proprio `post`, na linha 489, diz: "@return true se a 99 aceitou; false na falha, para o chamador saber que ha o que reenviar" -- e o chamador nao olha. No MarketplacePoller:339-340 a sequencia e `client.responderPedidoDeCancelamento(...)` e, logo depois, `if (aceitar) pedidos.cancelarPorMarketplace(...)`, sem condicionar ao sucesso. Como nada estoura, tratarEvento retorna normal e o evento entra em paraConfirmar (linha 251) e e confirmado na 99.

**Como foi medido:** Leitura direta dos dois arquivos nas linhas citadas (OpenDeliveryClient 477-505, MarketplacePoller 334-342 e 245-260). Contrastei com enviarCancelamento do mesmo arquivo (linhas 424-446), que no mesmo cenario RELANCA de proposito -- o comentario dele na linha 428 diz "aqui a falha NAO pode ser so logada: quem chama so cancela no Bora se a 99 aceitar, senao o pedido fica cancelado aqui e ativo la".

**Impacto:** O cliente pede o cancelamento no app da 99; o pedido e cancelado no Bora (com devolucao de estoque e de cashback, via cancelarPorMarketplace), o evento e confirmado, e a 99 nunca recebe o "aceito". La o pedido segue ATIVO e o cliente segue cobrado/esperando. Nao ha aviso na tela (nao passa por ultimo_aviso) e nao ha retentativa: o evento ja foi confirmado. E o mesmo estrago que o projeto fechou no caminho do cancelamento pedido pela loja, aberto no caminho do cancelamento pedido pelo cliente.

---

## MEDIO (23)

### 1. Percentual de cashback e aliquota de imposto: a gravacao e os limites nao tem teste em nenhuma camada

**Fatia:** A qualidade dos proprios testes

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/ConfiguracaoLojaService.java (atualizar:34, aliquotaImposto:52-56, cashbackPercentual:66-72) e C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/assets/js/configuracoes.js`

**O que:** ConfiguracaoLojaService.atualizar e quem grava o percentual de cashback que TODO pedido usa para creditar saldo, e a aliquota que entra nos relatorios. Ele valida cashback entre 0 e 50 (linhas 67-71) e aliquota entre 0 e 100 (linhas 53-55). Nenhum teste exercita esse metodo, e nenhum teste do frontend carrega configuracoes.js. O unico teste do projeto que toca o campo apenas o LE como fixture: CancelamentoDevolveCashbackTest.java:63 faz `cfg.cashbackPercentual = new BigDecimal("5")`.

**Como foi medido:** `grep -rl "\bConfiguracaoLojaService\b" src/test/java` -> 0 arquivos. `grep -rn "cashbackPercentual\|aliquotaImposto" src/test/java --include=*.java` -> uma unica linha, CancelamentoDevolveCashbackTest.java:63, que e atribuicao de fixture, nao exercicio da validacao. `grep -rl "configuracoes.js" testes/` no frontend -> nenhum arquivo. Li o metodo atualizar inteiro.

**Impacto:** Se a guarda de limite quebrar (ou o campo passar a chegar como zero quando veio vazio -- erro que a memoria do projeto registra duas vezes no mes, "Zero NAO e vazio"), a loja passa a creditar cashback errado em cada venda e o relatorio passa a calcular imposto errado, sem nenhum teste acendendo. E dinheiro que sai da loja a cada pedido.

### 2. Um pagamento confirmado apaga o motivo LIBERACAO/PAGAMENTO_MANUAL, e a guarda que protege a Zirá deixa de reconhecê-la

**Fatia:** Asaas, PIX, assinatura e corte de acesso

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/AssinaturaService.java:397-402 e :1023-1029, contra a guarda de :1047-1062`

**O que:** No PAYMENT_CONFIRMED/PAYMENT_RECEIVED a linha 401 faz prazoDeAcesso(lojaId, null, MotivoDoAcesso.ASSINATURA). prazoDeAcesso (:1023-1029) sobrescreve as duas colunas sem olhar o que havia antes: acesso_ate vira NULL e acesso_motivo vira ASSINATURA, por cima de LIBERACAO ou de PAGAMENTO_MANUAL. A partir daí prazoSemEncurtar (:1047) não acha mais o motivo intocável nem data para comparar (acesso_ate é NULL) e cai no caso 3: grava hoje + 10 dias. Sequência: loja com LIBERACAO até 23/01/2027 → paga uma mensalidade pelo Asaas → atrasa a seguinte → PAYMENT_OVERDUE (:419-426) → acesso passa a vencer em 10 dias. A liberação de até 180 dias que o dono concedeu desaparece sem nada no log dizendo que foi substituída.

**Como foi medido:** Li as duas funções e a guarda. prazoDeAcesso não tem condicional nenhuma — são três atribuições diretas (:1025-1027). A guarda de prazoSemEncurtar depende do valor de acesso_motivo (:1051-1054) e de acesso_ate != null (:1057), e a linha 401 zera os dois. O javadoc de prazoAoReativar (:922-938) descreve exatamente esse acidente para o caminho suspender+reativar, e foi fechado lá; o caminho do pagamento continua gravando por cima.

**Impacto:** Acesso da única cliente real. É a mesma classe de defeito que a v139/26-10 vieram fechar, por uma porta que não foi coberta: a marca que protege a loja é apagada por um evento normal de cobrança, não por decisão de ninguém.

### 3. taxa_entrega não tem UNIQUE por bairro, e a consulta que cobra o frete é um findFirst sem ordem

**Fatia:** Banco e as 64 migracoes

**Onde:** `bora-fase-3-backend-java/src/main/resources/db/migration/V12__operacao_delivery.sql:2-10 · src/main/java/br/com/bora/repository/TaxaEntregaRepository.java:10 · src/main/java/br/com/bora/service/OperacaoService.java:37-45 · src/main/java/br/com/bora/controller/PublicController.java:472-475 · src/main/java/br/com/bora/service/PedidoService.java:88-89`

**O que:** A tabela `taxa_entrega` nasce na V12 com PRIMARY KEY só em `id` e um índice NÃO-único `idx_taxa_loja(loja_id)`. Não existe nenhuma constraint UNIQUE em (loja_id, bairro) — conferi com grep por `unique` nas 64 migrações e a tabela não aparece em nenhuma. O `OperacaoService.salvarTaxa` (linha 37-45) cria linha nova sempre que `t.id == null`, sem procurar bairro já cadastrado: só valida `bairro` não-vazio. As duas leituras que decidem DINHEIRO são `findFirstByLojaIdAndBairroIgnoreCaseAndAtivoTrue` (TaxaEntregaRepository:10) — `findFirst`, sem nenhum `OrderBy`, ou seja LIMIT 1 sem ORDER BY, que no Postgres devolve linha arbitrária.

**Como foi medido:** Li V12__operacao_delivery.sql inteira (CREATE TABLE taxa_entrega sem UNIQUE, só `CREATE INDEX idx_taxa_loja ON taxa_entrega(loja_id)`). Rodei `grep -n -i "unique" *.sql` no diretório das 64 migrações: as únicas linhas são V10 (integracao_canal), V14 (assinatura), V23 (cupom), V28 (pedido), V32 (empresa), V34 (ia_analise_rede), V41 (pagamento_assinatura), V4 (usuario.email), V51 (produto), V62 (configuracao_loja), V64 (categoria_ordem) — taxa_entrega não está. Li o corpo de `salvarTaxa` e os 3 chamadores de `findFirstByLojaIdAndBairroIgnoreCaseAndAtivoTrue` com grep -A6 -B4.

**Impacto:** Dois cliques em "salvar" com o mesmo bairro (ou uma aba repetida) deixam duas linhas ativas para "Centro". A partir daí: (1) o frete cobrado no cardápio público (PublicController:475) e o frete do pedido do painel (PedidoService:89) passam a ser o de uma das duas linhas, escolhida pelo Postgres, e não há como o lojista saber qual — ele edita a taxa que vê na tela e o cliente continua pagando a outra; (2) `findByLojaIdAndAtivoTrueOrderByBairroAsc` alimenta a lista de bairros do cardápio, então o mesmo bairro aparece duas vezes no seletor do cliente. Só a loja 1 tem taxa por bairro hoje, então o alcance atual é uma loja — mas é a única que cobra frete por bairro.

### 4. cliente não tem UNIQUE nenhum: a deduplicação por telefone e por id do marketplace é só read-then-insert em Java

**Fatia:** Banco e as 64 migracoes

**Onde:** `bora-fase-3-backend-java/src/main/resources/db/migration/V43__telefone_do_cliente_so_digitos.sql (inteira) · V29__cashback_por_loja.sql:12 · V35__cliente_do_marketplace.sql:6 · src/main/java/br/com/bora/service/PedidoService.java:542-557 · src/main/java/br/com/bora/service/ClienteService.java:143-149`

**O que:** `pedido` ganhou na V28 um índice ÚNICO parcial `uq_pedido_canal_externo (loja_id, canal_externo, id_externo)` exatamente para o evento repetido não virar segunda linha. `cliente` tem o mesmo problema e ficou só com índices NÃO-únicos: `idx_cliente_loja_telefone(loja_id, telefone)` (V29:12) e `idx_cliente_externo(loja_id, canal_externo, id_externo)` (V35:6). A V43 normalizou o telefone para só dígitos com um UPDATE, mas não deduplicou nada nem criou constraint — e o UPDATE dela pode ter criado a colisão que ela descreve: "(15) 99999-0001" virando "15999990001" numa loja que já tinha "15999990001". A dedup toda está em Java e é ler-depois-inserir: `PedidoService.upsertCliente` (542-557) faz `findFirstByLojaIdAndCanalExternoAndIdExterno`, depois `findFirstByLojaIdAndTelefone`, e se os dois derem vazio faz `new Cliente()`; `ClienteService.recusarTelefoneRepetido` (143-149) faz o mesmo no painel. Os dois `findFirst` não têm `OrderBy`.

**Como foi medido:** Li V43 inteira (só o UPDATE de regexp_replace e um COMMENT; nenhum CREATE UNIQUE, nenhum DELETE de duplicata). Rodei `grep -n -i "unique" *.sql` nas 64 migrações: nenhuma linha menciona a tabela `cliente`. Li `ClienteRepository.java` inteiro (linhas 9-115: nenhum método de dedup atômica para INSERT; a única operação atômica é o UPDATE de cashback). Li `upsertCliente` (PedidoService:542-557) e `recusarTelefoneRepetido` (ClienteService:143-149).

**Impacto:** É exatamente o defeito que a V43 descreve no próprio comentário e que ela não fechou no banco: dois cadastros para a mesma pessoa, e o cashback acumulado preso num deles. O caminho para a duplicata está aberto em dois lugares: (a) um checkout do cardápio e um pedido do marketplace chegando juntos para o mesmo telefone — as duas transações leem vazio e as duas inserem; (b) a própria normalização da V43 em qualquer base que tivesse o telefone gravado dos dois jeitos. Com duas linhas, `findFirst` sem ORDER BY serve uma delas por sorte: o cliente ganha cashback num cadastro e gasta no outro, e quem cobre a diferença é o lojista. Não medi se existe duplicata na base hoje — isso exigiria consulta na produção, que não fiz (regra 3). O que está medido é que o banco não impede.

### 5. N+1 no cardápio público: uma consulta por produto só para marcar "esgotado"

**Fatia:** Consultas, N+1 e custo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/controller/PublicController.java:265-266 (dentro do `lista.stream().map(p -> {` que abre na linha 249); a consulta por produto está em C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/InsumoService.java:538, e a consulta por linha de ficha em InsumoService.java:541`

**O que:** Dentro do laço que monta cada produto do cardápio: `boolean esgotado = (p.estoque != null && p.estoque < 1) || !insumos.fichaDaParaFazer(lojaId, p.id, 1);`. O `fichaDaParaFazer` (InsumoService.java:536-550) faz `fichas.findByLojaIdAndProdutoId(lojaId, produtoId)` — uma consulta — e depois, para cada linha da ficha, `insumos.findByIdAndLojaId(pi.insumoId, lojaId)` — outra consulta por linha. O curto-circuito do `||` nunca economiza nada na produção: o comentário do próprio código, 4 linhas acima (PublicController.java:263-264), diz que `estoque` é nulo em todos os produtos da produção, e `estoque == null` deixa a primeira parte falsa, então a chamada acontece sempre. Logo acima, no MESMO método (linhas 231-243), os complementos já são resolvidos do jeito certo, com `findByLojaIdAndProdutoIdIn` e `findByLojaIdAndGrupoIdIn` — o padrão para consertar isto já está escrito dez linhas antes.

**Como foi medido:** Li o código das duas pontas (PublicController.java:249-270 e InsumoService.java:536-550) e contei os produtos pelo que a API devolve: `/public/loja/18/cardapio` → 44 produtos, loja 19 → 42, loja 20 → 42, loja 17 → 18 (contados com python sobre o JSON baixado). Contei também as consultas fixas do método, lendo linha por linha: lojaAtiva, posicoesDaLoja, produtos, marcaDaLoja, integracaoPix, abertaAgora, taxas, grupos de complemento, itens de complemento — cerca de 10. Então na loja 18 são 44 consultas de ficha contra ~10 de tudo o resto. O índice idx_prodinsumo_loja_prod ON produto_insumo(loja_id, produto_id) existe (V56 e anteriores), então cada uma é busca por índice e não varredura — o custo é de ida-e-volta, não de plano ruim. Não consegui medir o milissegundo isolado dessas 44 consultas: ele está dentro dos ~48 ms de diferença entre a loja 18 e a linha de base, misturado com a leitura do base64 do achado 1, e eu não toquei no banco para separar.

**Impacto:** 44 das ~54 consultas de uma abertura do cardápio da Zirá existem só para preencher um booleano que, hoje, é sempre `false` (nenhum produto aparece esgotado em nenhuma das 4 lojas — conferi no JSON). Cresce linearmente com o catálogo do lojista, na rota pública e sem freio de cache.

### 6. A assinatura ainda chama o Asaas com uma conexão do banco na mão (até 42 s de uma das 20)

**Fatia:** Consultas, N+1 e custo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/AssinaturaService.java:106 (@Transactional assinar) com as chamadas HTTP em :139, :157 e :174; :326 (@Transactional sincronizarValorComMotivo) com a chamada em :336; :1097 (@Transactional cancelarPorAdministracao) com a chamada em :1110. Os tempos limite estão em C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/TempoLimite.java:25-26 e o pool em C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/resources/application.yml:34`

**O que:** `assinar()` é @Transactional e, dentro da transação, faz até três chamadas HTTP em sequência ao Asaas: `asaas.criarCliente` (139), `asaas.criarAssinatura` (157) e `asaas.cancelarAssinatura` (174). `sincronizarValorComMotivo` é @Transactional e chama `asaas.atualizarAssinatura` (336) — e esse é chamado por clique de administrador em PlataformaController.java:739 e :769, passando pelo proxy do Spring, logo a transação vale. O javadoc do TempoLimite.java diz, com estas palavras, que chamada externa dentro da transação é o defeito já consertado no PIX do cardápio e repetido em outros pontos; no checkout público (PublicController.java:385) e no cobrador de PIX o conserto está feito, aqui não. Detalhe que medi e que vai no sentido contrário: a rotina horária `reconciliarValorDaMensalidade` (AssinaturaService.java:285-296) chama `sincronizarValorComMotivo` por auto-invocação dentro da mesma classe, então o proxy do Spring não entra e o @Transactional não vale naquele caminho — por acidente, é o único que NÃO segura conexão. O `repo.save(a)` da linha 347 é explícito, então a gravação não se perde.

**Como foi medido:** Rodei um script próprio que, para cada @Transactional, varre o corpo do método até fechar as chaves e procura chamada aos clientes externos (scratchpad/tx2.py); ele apontou exatamente as linhas 139, 157, 173-174, 333, 336, 557-560, 1106 e 1110 de AssinaturaService.java, e nenhum outro arquivo. Li as três ocorrências no código para confirmar que a chamada está dentro do mesmo bloco. O custo máximo vem dos números escritos: TempoLimite.java:25-26 define CONECTAR = 4 s e LER = 10 s, ou seja 14 s por chamada no pior caso, x3 chamadas em `assinar()` = até 42 s; application.yml:34 define maximum-pool-size 20 e :37 connection-timeout 10000, então a 21ª requisição concorrente falha em 10 s.

**Impacto:** Enquanto o Asaas estiver lento, cada assinatura ou sincronização de valor em curso prende 1 das 20 conexões por até 42 s — e o pool é compartilhado com o painel, o KDS e os marketplaces. A frequência é baixa (clique de administrador, não rota pública), e é por isso que não marquei alta; mas é a mesma classe de defeito que o projeto já tratou como grave em dois outros lugares, e aqui ficou.

### 7. Qualquer um na internet pode criar loja no Bora sem limite nenhum

**Fatia:** Controllers e contratos da API

**Onde:** `controller/SignupController.java:53-76 (POST /public/signup)`

**O que:** O endpoint publico de cadastro de loja nao tem teto por origem. A unica trava e freio.conferir(chave) na linha 76, e essa chave e e-mail+IP (FreioDeTentativas.chave, linha 64-66) e so conta tentativa ERRADA (freio.errou). No caminho de e-mail que ainda nao existe - que e exatamente o caminho que cria loja nova - freio.errou nunca e chamado, e mudar o e-mail a cada chamada ja gera uma chave nova de qualquer jeito. Resultado: um unico IP, trocando o e-mail, cria loja atras de loja sem ser barrado nunca. Cada chamada grava loja + usuario + vinculo + empresa e roda ProvisionamentoService.semear, que insere 1 configuracao + 4 formas de pagamento + 6 motivos + 7 horarios: cerca de 20 linhas por chamada. E cada loja nasce com acessoAte = agora + 7 dias (SignupController.java:163), ou seja, entra na lista de clientes da plataforma como loja em teste ativo.

**Como foi medido:** Li SignupController.java inteiro: a unica chamada ao freio e 'freio.conferir(chave)' na linha 76; no bloco de e-mail novo (linhas 107-127) nao ha freio.errou nem freio.acertou. Li FreioDeTentativas.java: LIMITE=5 so vale depois de errou() (linhas 37-56), e chave() concatena e-mail+origem (linha 64). Comparei com FreioDoCardapio.java, que o projeto usa nos outros endpoints publicos: pedido() marca por ORIGEM pura ('ped-min|'+origem, 10/min e 30/hora), consultaDeSaldo() 20/min, codigoDeDesconto() 30/min - o signup e o unico endpoint publico de escrita sem esse teto. Procurei trava fora do codigo: 'grep -n rate_limit|limit|signup bora-landing/deploy/Caddyfile' nao devolveu nada, e 'grep -rn signup --include=*.java' no pacote br.com.bora nao achou nenhum filtro alem do proprio controller.

**Impacto:** Um script enche o banco de lojas e usuarios falsos e suja a tela de clientes da plataforma (GET /admin-bora/clientes) e o faturamento previsto, porque cada loja falsa aparece como cliente em teste de 7 dias. Para separar o que e cliente de verdade do que e lixo o dono tem de olhar linha por linha. Nao ha perda de dinheiro nem de pedido, e nao vi sinal de que isso tenha acontecido - e exposicao aberta, nao estrago feito.

### 8. O Caddy serve o diretorio .git do painel: config, index, log de commits e objetos baixam com 200

**Fatia:** Docker, Caddy, deploy, backup e vigia

**Onde:** `bora-landing/deploy/Caddyfile:52-59 (bloco handle: root * /srv + file_server, sem nenhuma regra escondendo dotfiles)`

**O que:** A pasta servida do painel contem um .git e o file_server do Caddy o entrega inteiro. Nao e so o config: o /.git/index (5307 bytes) lista todos os caminhos versionados, o /.git/logs/HEAD entrega o nome e o E-MAIL do committer, e os objetos sao baixaveis um por um a partir do /.git/refs/heads/main -- ou seja, da para reconstruir a arvore daquele snapshot por URL. Nenhum arquivo do .git foi posto ali por deploy nenhum: o deploy-frontend.sh manda `git ls-files`, que nunca inclui .git. Ele veio de um clone ou copia feita na mao no servidor e esta la desde entao.

**Como foi medido:** curl -s -o /dev/null -w '%{http_code}' em cada caminho: /.git/config 200 (e o corpo mostra remote origin = https://github.com/AppBora/front_bora.git), /.git/HEAD 200 21b, /.git/index 200 5307b, /.git/logs/HEAD 200 572b (corpo: 'AppBora <...@gmail.com> 1782824496 -0300 commit (initial): Frontend Bora (HTML/CSS/JS) - pronto para deploy'), /.git/refs/heads/main 200 41b -> a2ad10f15a216fe23db817dccd53a822263779f3, /.git/COMMIT_EDITMSG 200 51b, /.git/description 200 73b. Com o hash montei /.git/objects/a2/ad10f15a216fe23db817dccd53a822263779f3 -> 200, 171 bytes: o objeto do commit baixa. (Listagem de diretorio nao: /.git/ da 404, porque o file_server esta sem `browse`.)

**Impacto:** O estrago de codigo-fonte e pequeno, e eu conferi antes de gritar: https://github.com/AppBora/front_bora responde 200 sem autenticacao, entao o repo e publico e o fonte do painel ja era publico de qualquer forma. O que sobra e: o e-mail do dono exposto numa URL fixa, a identidade do repositorio e a mensagem de commit entregues de graca a qualquer scanner (sondar /.git/ e a primeira coisa que bot faz), e -- o que importa mais -- a prova de que a pasta de onde o painel e servido guarda arquivos que nenhum deploy colocou e que ninguem esta conferindo. No dia em que esse repo virar privado, ou em que alguem commitar um arquivo de configuracao nele, isso vira vazamento sem ninguem mexer em nada.

### 9. Com um 'api-anterior' sobrando, o rollback do deploy apaga o container bom e devolve a versao de DOIS deploys atras

**Fatia:** Docker, Caddy, deploy, backup e vigia

**Onde:** `bora-landing/deploy/deploy-api.sh:122 (rename), :155 (a limpeza com `|| true`), :98-101 (o que o rollback faz)`

**O que:** O passo 8 faz, no servidor e com `set -e`: `docker stop -t 30 api` e depois `docker rename api api-anterior`. Esse rename FALHA se ja existir um container chamado api-anterior -- e a limpeza que deveria garantir que ele nao existe esta na linha 155, `docker rm api-anterior >/dev/null 2>&1 || true`, com o `|| true` engolindo a falha em silencio (e sem -f, entao ela falha se o container estiver de pe por qualquer motivo). Quando o rename falha, o `set -e` do heredoc sai nao-zero, o `if !` da linha 117 dispara e o rollback() roda. So que o container chamado `api` nesse instante e o ANTIGO, bom, apenas parado -- e a primeira coisa que o rollback faz e a linha 98: `docker rm -f api`. Ele destroi a versao boa. Em seguida a linha 99 renomeia o `api-anterior` sobrante (que e a versao de dois deploys atras) para `api`, a linha 100 a sobe, e a 101 retagueia `bora-api:anterior` para `:latest`.

**Como foi medido:** Li a sequencia completa do heredoc nas linhas 117-127 e a funcao rollback nas linhas 92-114, e o caminho de sucesso na linha 155. O encadeamento e so codigo: `docker rename` com nome de destino ocupado retorna erro, o heredoc tem `set -e` na linha 118, e o rollback comeca por `docker rm -f api`. NAO VERIFIQUEI no servidor se existe um api-anterior sobrando hoje -- nao entrei por ssh (regra 3), entao a condicao de disparo e possivel e nao esta comprovada como presente.

**Impacto:** O script promete 'rollback automatico se ela nao ficar sadia' (cabecalho, linha 3) e aqui ele faz pior que nao rollbackar: rollbacka DUAS versoes, apagando o container que estava bom, e anuncia 'rollback feito: a versao anterior esta de volta e SADIA' (linha 107) se a versao antiga passar no health -- o que ela provavelmente passa. Producao volta com codigo velho e com o deploy dizendo que deu tudo certo, que e exatamente o tipo de mentira que custou os dois dias de 26/10. O conserto e baratissimo: um `docker rm -f api-anterior` antes do rename no passo 8, ou checar a existencia e abortar ANTES de parar o container bom.

### 10. O portao dos Termos no deploy diz medir 'a pagina publicada' e mede o arquivo do checkout

**Fatia:** Docker, Caddy, deploy, backup e vigia

**Onde:** `bora-landing/deploy/deploy-api.sh:46-51 + bora-fase-3-backend-java/src/test/java/br/com/bora/controller/VersaoDosTermosTest.java:33`

**O que:** O passo 2 do deploy anuncia 'a data dos Termos no codigo bate com a pagina publicada?' e para isso roda o VersaoDosTermosTest. O teste nao fala com o site: a linha 33 e `Paths.get("..", "bora-landing", "termos.html")`, ou seja, o arquivo no disco do checkout. O proprio deploy-frontend.sh:27 registra que 'Nao sobe a landing (bora-landing/ e outro repositorio, publicado a parte)' -- entao o arquivo do checkout e a pagina publicada sao duas coisas que podem divergir, e o portao so ve uma.

**Como foi medido:** Li deploy-api.sh:46-51 e VersaoDosTermosTest.java:33 (nenhuma leitura de rede no teste; os imports sao java.nio.file). Conferi as tres pontas hoje e elas BATEM: TermosService.java:52 `VERSAO_VIGENTE = "2026-10-04"`, grep no bora-landing/termos.html -> 'Última atualização:</b> 4 de outubro de 2026', e curl https://borahapp.com.br/termos.html (200) -> 'Última atualização:</b> 4 de outubro de 2026'. Confirmei tambem que o portao de fato RODA no deploy (nao se pula): o assumeTrue da linha 41 depende de `../bora-landing/termos.html`, e com o cwd do surefire em bora-fase-3-backend-java esse caminho resolve para o arquivo que existe (ls: 6266 bytes).

**Impacto:** Nao ha divergencia em producao agora -- por isto a gravidade e media e nao alta. O defeito e o portao nao poder pegar o caso que ele mesmo nomeia: alguem muda o texto, commita a landing e a constante juntas, o deploy-api passa verde, e a landing nao e publicada. A partir dai cada aceite gravado aponta para uma data que o lojista nunca viu na tela -- e o documento em questao e o que fala de pagamento, suspensao e reembolso (javadoc do teste, linhas 18-21). Fechar e uma linha: comparar com o que o curl traz de borahapp.com.br/termos.html, nao com o disco.

### 11. No cardapio publico, o cashback do pedido anterior continua descontando na tela do pedido seguinte

**Fatia:** O codigo das telas

**Onde:** `bora-fase-2-frontend/assets/js/cardapio.js:519 (o unico reset apos gravar), 272 e 276 (declaracoes), 399-404 (desconto mostrado), 515 (o que vai no corpo)`

**O que:** O `confirmarPedido` faz `cart = []; atualizarBarra();` na linha 519 e nada mais. As variaveis `saldoCashback` (linha 272) e `cupomAplicado` (276), o visto `#ckUsarCashback` e a caixa verde `#ckCashback` ficam exatamente como estavam. O cliente que faz um 2o pedido na MESMA pagina (caminho que a tela oferece de proposito: o botao `okVoltar`, com o comentario "o cliente pode querer pedir mais" em cardapio.js:627) reabre o checkout, o `abrirCheckout` (337) chama `atualizarEntrega`, e o `descontoDoCashback` (398-404) usa o `saldoCashback` VELHO -- o saldo de antes do 1o pedido ter gasto ele. A tela mostra "- R$ X" e um total menor; o corpo sai com `usarCashback: true` (515) e o servidor aplica o que AINDA existe. O `verCashback` (426) nao roda de novo porque so escuta blur/change de `#ckTel` e `#ckNome`, e o cliente nao mexe nesses campos no 2o pedido.

**Como foi medido:** Li o caminho inteiro e grepei todas as atribuicoes: `grep -n "saldoCashback|cupomAplicado|ckUsarCashback" cardapio.js` devolve escrita em saldoCashback apenas nas linhas 272, 434, 438 e 447 (declaracao e dentro do verCashback) -- nenhuma no confirmarPedido. O lado do servidor confirma que ele NAO recusa, so aplica menos: PublicController.java:642-647, `resgate = fidelidade.resgatePossivel(lojaId, clienteId, total); if (resgate.signum() > 0) { total = total.subtract(resgate); }` -- saldo zerado da resgate 0, sem erro nenhum. O proprio arquivo documenta esse exato defeito no cupom e o conserto de 26/10 (cardapio.js:502-513), mas a correcao nao alcancou o gemeo do cashback.

**Impacto:** Preco na tela diferente do preco cobrado, na tela do cliente final. O cliente confirma um pedido vendo, por exemplo, R$ 26,00 e o pedido e gravado por R$ 36,00; ele so le o valor certo depois, no texto de confirmacao. E o pior defeito possivel nesta tela, pelas palavras do proprio comentario da linha 511.

### 12. A tela de Desempenho monta as datas em UTC: depois das 21h ela perde o dia 1 do mes e o "Hoje" devolve zero

**Fatia:** O codigo das telas

**Onde:** `bora-fase-2-frontend/assets/js/desempenho.js:9 e :10`

**O que:** `const hoje = () => new Date().toISOString().slice(0, 10);` e `const primeiroDoMes = () => { const d = new Date(); d.setDate(1); return d.toISOString().slice(0, 10); };`. O `toISOString()` converte para UTC; no Brasil (UTC-3), das 21h a meia-noite a data UTC ja e a de amanha. Esses dois valores entram nos campos `#ini`/`#fim` na abertura da tela (linhas 195-196) e nos botoes "Mes" e "Hoje" (191-192), e vao direto na consulta `/api/desempenho?inicio=&fim=` (linha 136).

**Como foi medido:** Rodei as duas funcoes com o relogio em 29/10/2026 22:30 America/Sao_Paulo (node, scratchpad/t.js): saida `hoje() = 2026-10-30` e `primeiroDoMes() = 2026-10-02`. No servidor, DesempenhoController.java:27-28 le as duas como LocalDate e DesempenhoService.java:64-69 usa a faixa INCLUSIVA em America/Sao_Paulo (`inicio.atStartOfDay(ZONE)` ate `fim.plusDays(1)`), logo inicio=02/10 deixa o dia 1 inteiro de fora. Comparei com as telas que acertam: pedidos.js:33, canais.js:55-56, entregadores.js:52 e rede-analise.js:7 descontam o `getTimezoneOffset()` ou usam getters locais.

**Impacto:** Depois das 21h -- justamente o horario de pico de acaiteria e pizzaria -- o botao "Hoje" consulta amanha e a tela escreve "Nenhuma loja vendeu no periodo" com a loja vendendo; e a abertura da tela (e o botao "Mes") deixa o dia 1 de fora de faturamento, CMV, imposto, custo fixo, lucro e margem, sem nada avisar. E a tela em que o dono le lucro para decidir. Agrava que o servidor ja tem o padrao certo (DesempenhoService:65-66 usa LocalDate.now(ZONE)): se a tela nao mandasse nada, o numero sairia correto.

### 13. O "Fechamento de Caixa" não guarda nada e não existe para ontem

**Fatia:** O processo de negocio ponta a ponta

**Onde:** `bora-fase-2-frontend/caixa.html (26 linhas, sem seletor de data); bora-fase-2-frontend/assets/js/caixa.js:50-56; bora-fase-3-backend-java/src/main/java/br/com/bora/service/PedidoService.java:127-136 (board); bora-fase-3-backend-java/src/main/java/br/com/bora/service/RelatorioService.java:186-204 (saída)`

**O que:** A tela é uma vista viva: chama `Bora.board()` sem parâmetro (que traz o dia corrente mais os pedidos abertos de outros dias) e filtra pelo dia do navegador. Não há seletor de data na tela, não existe tabela de fechamento em migração nenhuma (varri db/migration até V64; a única linha com "caixa" é a palavra "caixa de aceite" num comentário da V40) e nada é gravado ao imprimir. O relatório não cobre o buraco: a saída do `RelatorioService.gerar` tem porDia, porCanal, porProduto e porEntregador — não tem quebra por FORMA DE PAGAMENTO, que é exatamente o número com que se confere a gaveta.

**Como foi medido:** Li caixa.html inteiro: nenhum `input type=date`, subtítulo fixo "Resumo do dia". Li caixa.js:50-56: `const board = await Bora.board(); const hoje = board.filter(p => ehHoje(p.criadoEm))`, e `ehHoje` compara `toDateString()` com a data do navegador. Li api.js:64 (`board(dia, desde)`) e PedidoService.board (:127-136): sem argumento, `inicio = hoje` no fuso de São Paulo. Rodei `ls db/migration` e `grep -rln "caixa" db/migration/` → só V40, e lá a palavra é "caixa de aceite". Li as chaves do mapa devolvido por RelatorioService.gerar (linhas 186-204): não há forma de pagamento.

**Impacto:** Depois de imprimir o fechamento, nenhum número fica guardado: um cancelamento ou uma confirmação de PIX minutos depois muda a tela e não há registro do que foi fechado nem de quem fechou. E para conferir o dinheiro de ontem — ou de qualquer dia fechado errado — não existe caminho no sistema: nem a tela de caixa (só hoje) nem o relatório (não quebra por forma de pagamento) respondem.

### 14. O Desempenho nao cobra o Modulo IA: o lucro sai R$ 99/mes maior do que e

**Fatia:** Os servicos que mexem em dinheiro

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/service/DesempenhoService.java:150`

**O que:** A parcela "mensalidade" do custo e `rateio(l.precoEfetivo(), dias)`. O `precoEfetivo()` (Loja.java:149-152) devolve so o plano/preco negociado; quem soma o add-on pago e o `precoComModulos()` (Loja.java:163-165), que acrescenta PRECO_MODULO_IA = R$ 99,00 quando `moduloIa` e true. Resultado: para loja com Modulo IA ligado, a tela de Desempenho debita R$ 199 de mensalidade (rateada) quando a loja paga R$ 298, e o lucro e a margem % saem maiores do que a realidade.

**Como foi medido:** Li DesempenhoService.java:150 (`BigDecimal mensalidade = rateio(l.precoEfetivo(), dias);`) e Loja.java:163-165. Rodei `grep -rn "precoComModulos|precoEfetivo"` em src: TODO o caminho de cobranca usa precoComModulos (AssinaturaService.java:137, :157, :293, :334; PlataformaController.java:741, :773) e o comentario do PlanoService.java:85-88 diz com estas palavras que "Esta classe usava precoEfetivo(), que nao inclui o Modulo IA" — o mesmo defeito ja foi corrigido ali. DesempenhoService:150 e a unica chamada a precoEfetivo() fora da tela da plataforma (que manda o flag moduloIa separado, PlataformaController.java:232-234). A coluna existe e nasce false (V19__modulo_ia.sql: `modulo_ia BOOLEAN NOT NULL DEFAULT FALSE`). Nenhum teste cobre isto: em OpixABANDONADOnaoCOBRAcustoTest.java:164-180 a parcela "mensalidade" entra na soma mas nunca e comparada com um valor esperado.

**Impacto:** A loja com Modulo IA ligado le, na tela de Desempenho, um lucro R$ 99/mes maior do que o real (R$ 23,10 numa consulta de 7 dias, R$ 99 no mes fechado) — e e exatamente o numero em que o dono se baseia para decidir preco e corte de custo. NAO afeta a cobranca: o Asaas cobra o valor certo. Nao consegui medir quantas lojas estao com o Modulo IA ligado hoje, porque isso exige ler o banco de producao e eu nao li.

### 15. Cancelar de novo o pedido reaberto pelo PIX tira do cliente um cashback que ele nunca ganhou

**Fatia:** Os servicos que mexem em dinheiro

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/service/PedidoService.java:699 (e o mesmo em :894) + EstornoDaVendaService.java:122 + FidelidadeService.java:265-284`

**O que:** Quando o PIX cai DEPOIS do cancelamento, o webhook reabre o pedido e so RE-CONSOME o resgate; ele nao chama `registrar`, de proposito (PublicController.java:913-921). Entao esse pedido nunca gerou cashback novo, nem total_gasto, nem contagem de pedido. Mas, ao cancelar de novo, o `alterarStatus` decide `vendaJaContabilizada = !p.pagamentoPendente()` (PedidoService:699) — e depois da reabertura `aguardandoPagamento` e false e `pagoEm` esta preenchido, logo da TRUE. Com true, o `estornar` desfaz uma venda que nunca foi contabilizada: `desfazerVenda` (ClienteRepository.java:110-115) faz `cashback = greatest(0, cashback + usado - credito)`, `total_gasto - :pago` e `qtd_pedidos - 1`, com `credito = valorTotal * percentual`. O proprio javadoc do parametro (EstornoDaVendaService.java:110-114) manda NAO usar `p.pagamentoPendente()` para decidir isso.

**Como foi medido:** Segui a cadeia no codigo, arquivo por arquivo: PublicController.java:667 e :681 (pedido com PIX nasce aguardandoPagamento=true e so debita o resgate, sem registrar venda); CobradorDePixService.java:201-213 (cancela em 30 min e chama devolver com `false`, devolvendo o resgate — correto); PublicController.java:863-921 (o PIX cai, pedido volta para RECEBIDO, `aguardandoPagamento=false`, `pagoEm=now`, e no ramo `jaCancelado` chama SO `fidelidade.consumir`); o teste PedidoReabreNoWebhookDoPixTest.java:184-185 prova isso (`verify(fidelidade).consumir(...)` e `verify(fidelidade, never()).registrar(...)`), e o comentario dele na linha 179 diz "esta ainda pode ser cancelada de novo"; PedidoService.java:699 e :727 (segundo cancelamento com vendaJaContabilizada=true); FidelidadeService.java:270-283 (com true, `taxa = percentual/100` e `credito = pago * taxa`, e passa `pago` e `pedidos=1`). Conta fechada com os numeros do proprio teste (cashbackUsado R$ 5,00, pedido R$ 40,00, 5%): o cliente recebe +5,00 e e debitado em 2,00 de saldo que veio de OUTRA compra — volta so R$ 3,00 dos R$ 5,00 que gastou. Nenhum teste cobre o segundo cancelamento: `grep -rn "vendaJaContabilizada" src/test` nao traz nada.

**Impacto:** Dinheiro do cliente da loja, tirado em silencio. No caminho que o proprio sistema recomenda ao lojista (a observacao e o log dizem "Se nao for atender, cancele de novo" e "o cancelamento devolve estoque e cashback"), o cliente recebe de volta menos cashback do que gastou, e o historico dele fica errado para baixo: o total gasto perde o valor do pedido e a contagem de pedidos perde 1 — numeros que nunca foram somados. O `greatest(0, ...)` impede saldo negativo, so isso. Precisa da sequencia PIX do cardapio -> cancelado -> pago depois -> cancelado de novo (ou excluido, por PedidoService.java:894, que decide do mesmo jeito).

### 16. O Desempenho cobra cashback de 100% do faturamento, mas o sistema so credita a quem tem cliente identificado

**Fatia:** Os servicos que mexem em dinheiro

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/service/DesempenhoService.java:141-143`

**O que:** A parcela de custo "cashback" e `faturamento * cashbackPercentual / 100`, sobre o faturamento INTEIRO da loja. So que cashback de verdade so e creditado quando ha cliente: `FidelidadeService.registrar` sai na primeira linha com `if (clienteId == null) return;` (FidelidadeService.java:310), e no pedido de marketplace o credito e desligado quando nao ha telefone de pessoa (`fidelidade.registrar(..., telReal != null)`, PedidoService.java:428). Venda de balcao sem cliente escolhido — que a propria tela de PDV permite (pdv.js:200 manda `clienteId: null` quando ninguem foi selecionado) — nao gera um centavo de cashback e ainda assim e cobrada no custo.

**Como foi medido:** Li DesempenhoService.java:141-143 (`cashback = faturamento.multiply(pctCashback).divide(100, 2, HALF_UP)`), FidelidadeService.java:309-310 e PedidoService.java:428. Conferi na tela que isso e exibido como valor em dinheiro, nao como estimativa: desempenho.js:62 imprime `${num(l.cashback)}` numa coluna da tabela por loja, e desempenho.js:35 rotula o cartao "Custo total" como "CMV, entrega, cashback, imposto, fixo e mensalidade". Nao consegui medir a proporcao de pedidos sem cliente na producao: isso exige ler o banco, e eu nao li.

**Impacto:** O custo total do periodo sai maior e o lucro MENOR do que o real, na direcao oposta ao aviso de margem que a tela ja da. Numa loja que vende muito no balcao sem identificar o cliente, o erro e de 5% (percentual padrao) de todo esse faturamento. O javadoc da classe descreve o calculo como esta, entao e divergencia entre o numero mostrado e o dinheiro que sai de verdade, nao contradicao interna — por isso media e nao alta.

### 17. O botao que fecha a venda no cardapio publico tem 1,98:1 de contraste

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `bora-fase-2-frontend/assets/css/styles.css:225 (.menu-bar .send) e ajuda.html:9`

**O que:** Texto branco sobre o verde do WhatsApp (#25d366). A razao e 1,98:1, bem abaixo dos 4,5:1 exigidos para texto de 15px. E o botao "Finalizar pedido" do cardapio digital, o ultimo clique antes de o pedido virar dinheiro. O mesmo par aparece no botao "Falar com o suporte" da tela de Ajuda.

**Como foi medido:** Abri cardapio.html em 375px, cliquei de verdade no '+' do primeiro item para a barra inferior sair do display:none, e medi o elemento renderizado: button#send.send, color rgb(255,255,255), background rgb(37,211,102), font-size 15px, font-weight 900 -> razao calculada 1,98. Em ajuda.html, a.btn #ffffff/#25d366 a 16px/700 -> 1,98.

**Impacto:** O cliente final le o cardapio no celular, muitas vezes na rua com sol na tela. O botao que fecha o pedido e justamente o menos legivel da pagina.

### 18. Os botoes que empurram o pedido no quadro tem texto branco sobre cor clara demais

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `bora-fase-2-frontend/assets/css/styles.css:69 (.kcol-head .pill) e :95 (.kacts .adv) e :293 (.kacts .ok); as cores vem de assets/js/pedidos.js:7-14`

**O que:** A cor de cada coluna do quadro e usada como fundo do botao de avancar e do contador, sempre com texto branco. Medido sobre as cores reais declaradas em pedidos.js: Cozinha #f59e0b = 2,15:1, Aguardando #3b82f6 = 3,68:1, Saiu #a855f7 = 3,96:1, Entregue #22c55e = 2,28:1, Cancelados #94a3b8 = 2,56:1. Nenhum chega aos 4,5:1. O botao "Aceitar" (.kacts .ok, verde #22c55e) fica em 2,28:1.

**Como foi medido:** Rodei o medidor de contraste sobre a tela pedidos.html renderizada em 375px, lendo a cor computada de cada elemento e o fundo efetivo do ancestral: "button.ok #ffffff/#22c55e 2.28 12px/800 'Aceitar'", "button.adv #ffffff/#3b82f6 3.68 12px/800 'Despachar ->'", "button.adv #ffffff/#a855f7 3.96 12px/800 'Entregar ->'", "button.adv #ffffff/#22c55e 2.28 12px/800 'Concluido'", "span.pill #ffffff/#f59e0b 2.15 13px/800".

**Impacto:** Sao os botoes que movem o pedido do recebido ate o entregue, com letra de 12px. O balcao usa celular, muitas vezes com a tela suja e pouca luz; errar o botao de 'Aceitar' custa o pedido.

### 19. O cinza #94a3b8 esta em 86 lugares e da 2,56:1 sobre branco

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `86 ocorrencias de 'color:#94a3b8' em 37 arquivos do bora-fase-2-frontend; os que mais doem: assets/js/novo-pedido.js:209, assets/js/entregas.js, assets/js/crm.js, login.html, cadastro.html`

**O que:** Esse cinza da 2,56:1 sobre branco e 2,40:1 sobre o fundo #f6f7fb -- reprova em qualquer tamanho. Nao e so texto decorativo: em novo-pedido.js:209 e a frase que ENSINA o passo obrigatorio ("Nenhum item ainda -- monte o produto acima e clique em Adicionar ao pedido"); em Entregas e o endereco do cliente; no CRM e o telefone do cliente; no login e no cadastro e o "Nao tem conta?" ao lado do link de criar conta.

**Como foi medido:** Medi o renderizado em varias telas: novo-pedido.html "b #94a3b8/#ffffff 2.56 13px/700 'Adicionar ao pedido'"; entregas.html "small #94a3b8/#ffffff 2.56 10.83px 'Av. Teste, 900'"; crm.html "small #94a3b8/#ffffff 2.56 10.83px '(15) 98103-4318'"; login.html "div.login-foot #94a3b8/#ffffff 2.56 12px 'Nao tem conta?'"; pdv.html "div.cart-empty #94a3b8/#ffffff 2.56 14px 'Toque em um produto para comecar'". A contagem de 86 veio de grep -rio 'color:\s*#94a3b8' nos .html/.css/.js, sem os .bak.

**Impacto:** Justamente as instrucoes que foram escritas para destravar o lojista (o aviso do 'Adicionar ao pedido') sao as menos visiveis da tela. E o endereco de entrega e o telefone do cliente ficam no cinza mais fraco da pagina.

### 20. Na tela que o cliente olha esperando o pedido, o rodape esta em 1,48:1

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `bora-fase-2-frontend/acompanhar.html:20 (.rodape{color:#cbd5e1})`

**O que:** O texto do rodape e #cbd5e1 sobre o cartao branco: 1,48:1, praticamente invisivel. E onde fica escrito "Atualiza sozinho" e, quando a loja deixa a marca ligada (linha 44 do mesmo arquivo), "Atualiza sozinho · BoraHapp" -- a unica assinatura do Bora na tela que o consumidor final mais olha.

**Como foi medido:** Abri acompanhar.html em 375px e o medidor devolveu "div#rodape.rodape #cbd5e1/#ffffff 1.48 12px/400 'Atualiza sozinho'". O print da tela confirma: o texto some no branco do cartao.

**Impacto:** O cliente nao le que a tela se atualiza sozinha e fica apertando F5 ou ligando para a loja. E a marca BoraHapp, que e o unico canal de divulgacao gratuito do produto, nao e lida por ninguem.

### 21. A tela de Produtos manda o lojista para Configuracoes buscar a migracao por foto, que ja mora na propria tela de Produtos

**Fatia:** Usabilidade e fluxo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/produtos.html:89-93 (o ponteiro) contra produtos.html:68-78 (o bloco de verdade, na mesma tela)`

**O que:** Produtos tem DOIS textos contraditorios sobre a mesma funcao. O bloco real esta em produtos.html:68-78 (`id="impFotoBloco"`, revelado por produtos.js:429-431 quando /api/ia/status diz que a loja contratou o modulo). Trinta linhas abaixo, um paragrafo visivel diz: "Tem o cardapio so em foto? A migracao por foto ... fica em Configuracoes", com link para configuracoes.html#cardIA. O destino desse link e um `<details id="cardIA" hidden>` (configuracoes.html:334) que, quando abre, diz na linha 356: "A migracao por foto MUDOU DE LUGAR em 25/10/2026: esta em Produtos -> Importar cardapio". O ponteiro e circular e esta errado.

**Como foi medido:** Li produtos.html:68-78 e produtos.html:89-93 no mesmo arquivo. Li produtos.js:420-431 e confirmei que o bloco e desescondido na propria tela de Produtos quando `/api/ia/status` responde `contratado`. Li configuracoes.html:334 (`id="cardIA" hidden`) e configuracoes.html:356 (o texto que devolve o lojista para Produtos), e configuracoes.js:1214-1215, que registra que a fiacao saiu de la.

**Impacto:** A loja que TEM o modulo (a Zira, loja 18, e a unica -- esta escrito em produtos.html:61-63) tem o botao na tela e e mandada embora dele; a loja que NAO tem o modulo clica e cai num acordeao escondido onde nao ha nada. E a porta de entrada de cliente novo: cadastrar o cardapio inteiro a mao em vez de mandar uma foto. O paragrafo e mostrado a todas as lojas, com modulo ou sem.

### 22. No celular o menu inteiro vira 26 icones sem rotulo numa faixa que rola de lado

**Fatia:** Usabilidade e fluxo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/assets/css/styles.css:16 (`.navtx{display:none}`, dentro do @media(max-width:900px) que comeca na linha 4) e C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/assets/js/app.js:118-154 (BORA_NAV) com app.js:161-162 (renderNav)`

**O que:** Abaixo de 900px a barra lateral vira barra inferior fixa (`.side{position:fixed;bottom:0}`, `.nav{display:flex;overflow-x:auto}`) e o rotulo de cada item e escondido (`.navtx{display:none}`), sobrando so o emoji. Para um ADMINISTRADOR_LOJA o BORA_NAV tem 26 itens, e o renderNav gera `<a>` sem title nem aria-label -- nao sobra texto nem para o leitor de tela. Entre os 26 icones, tres sao de dinheiro e quase iguais no celular (💰 Fechar Caixa, 💵 Acerto Motoboy, 💳 Frente de Caixa) e dois sao de grafico (📈 Relatorios, 💹 Desempenho).

**Como foi medido:** Contei os itens do BORA_NAV com `sed -n '119,157p' assets/js/app.js | grep -c 'href:'` -> 26. Li styles.css:4-17 (o bloco mobile completo) e confirmei `.navtx{display:none}`, `.navic{font-size:18px}`, `.nav a{padding:9px 11px}`, `.nav{gap:4px}` e `.navic{width:20px;flex:0 0 20px}`. Pelos proprios valores do CSS, cada link ocupa ~46px (20 do icone + 22 de padding + 4 de gap): 26 x 46 = ~1200px de faixa dentro de uma tela de 375px, cerca de 3 telas de rolagem lateral. Li app.js:161-162 e confirmei que o `<a>` gerado nao leva title nem aria-label.

**Impacto:** A promessa do produto e operar tudo no celular, e e no celular que o lojista fecha o caixa no fim da noite. Para achar "Fechar Caixa" ele rola a faixa as cegas e, chegando la, escolhe entre tres emojis de dinheiro parecidos -- errar leva para o Acerto do Motoboy ou para a Frente de Caixa. Sem rotulo e sem aria-label, quem usa leitor de tela nao navega o painel no celular.

### 23. Com aceite automatico ligado, o "Confirmar" do painel nao manda nada ao canal -- e tira o pedido da fila de retentativa para sempre

**Fatia:** iFood, 99 e OpenDelivery

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/service/marketplace/IfoodClient.java:533-534 e 648-650; OpenDeliveryClient.java:383-385 e 404-406; repository/PedidoRepository.java:368-371; MarketplacePoller.java:453`

**O que:** verbo() devolve null para "CONFIRMADO" quando autoAceitar e true (`case "CONFIRMADO" -> Boolean.TRUE.equals(i.autoAceitar) ? null : "confirm"`, IfoodClient:650 e OpenDeliveryClient:405) e enviarStatus trata verbo nulo como sucesso (`if (verbo == null) return true;`, IfoodClient:534 e OpenDeliveryClient:385). As duas retentativas do aceite exigem status RECEBIDO: a @Query de semAceiteConfirmado (PedidoRepository:370, `and p.status = ...StatusPedido.RECEBIDO`) e reenviarAceiteSeFaltou (MarketplacePoller:453, `if (p.status != RECEBIDO) return;`). alterarStatus nao grava aceiteEnviadoEm em nenhum lugar (confirmado por grep: so MarketplacePoller:479 chama marcarAceiteEnviado).

**Como foi medido:** Leitura das linhas citadas nos quatro arquivos; `grep -rn "marcarAceiteEnviado"` em service/ e controller/ para confirmar que o unico ponto de gravacao e o poller.

**Impacto:** Depois de um aceite automatico que falhou, o pedido fica RECEBIDO no painel. Se o lojista clicar "Confirmar" (o que e o reflexo natural ao ver o aviso "Aceite do pedido X recusado; sera reenviado"), o status local vai para CONFIRMADO, NADA e enviado ao canal, e o pedido sai das duas filas de retentativa de forma definitiva. O canal nunca recebe a confirmacao: no iFood ele cancela sozinho por falta de aceite depois de a cozinha preparar; na 99, como o proprio projeto documenta, a ordem dos status e obrigatoria e todos os passos seguintes desse pedido tambem sao recusados. Importante: hoje este caso fica mascarado pelo achado 1 (o poller martela `confirm` em laco), entao ele aparece de verdade quando o achado 1 for corrigido.

---

## BAIXO (14)

### 1. O CSS ainda se descreve como laranja, e as seções escuras continuam com o acento antigo

**Fatia:** A landing e a pagina de vendas

**Onde:** `bora-landing/assets/site.css:4-5 (comentário do topo) e as linhas 132, 226, 242 e 484`

**O que:** O comentário que abre o arquivo diz "Paleta: laranja (comida, urgência) + verde (dinheiro, economia). O roxo do produto fica no painel — aqui ele competia com o preço na hora da decisão." Treze linhas abaixo, a linha 18 declara o contrário: "A cor da marca e ROXA desde 29/10/2026". Além do comentário, sobraram acentos laranja em papéis que são de MARCA, e não os três que o próprio comentário das linhas 20-27 lista como exceção de alerta (etiqueta pendente, selo "em obra" e o lado "sem o BoraHapp"): section.escura .kicker = #F0A88C (linha 132), .nota-demo b = #F0A88C (484), .controle b = #FFC9AE (226) e .resultado .perda = #FF9B76 (242), todos hex soltos, sem token.

**Como foi medido:** Li site.css:1-40 e 224-243. Listei os hex do arquivo que não pertencem à paleta declarada no :root e conferi onde cada um é usado. Na prática isso pinta de salmão as tarjas "Veja acontecendo" e "Faça a conta" (index.html:105 e 195) e "Comissão x mensalidade" (precos.html), além do rótulo dos controles da calculadora.

**Impacto:** Nenhum efeito sobre venda, pedido ou acesso — é consistência de marca e manutenção. O risco real é o comentário do topo: quem abrir esse arquivo primeiro lê que a marca é laranja e que roxo é coisa do painel, e pode desfazer a virada de 29/10 sem perceber.

### 2. Nome e categoria de produto não têm teto em lugar nenhum, e as colunas têm 160 e 80

**Fatia:** Banco e as 64 migracoes

**Onde:** `bora-fase-3-backend-java/src/main/resources/db/migration/V1__create_core_tables.sql:3 · src/main/java/br/com/bora/service/ProdutoService.java:69-70 e 215-219 · bora-fase-2-frontend/produtos.html:12-13`

**O que:** `produto` nasce na V1 com `nome varchar(160)` e `categoria varchar(80)`. O `ProdutoService.atualizar` faz `p.nome = dados.nome; p.categoria = dados.categoria;` (linhas 69-70) sem nenhum corte, e o `validarNome` (linha ~215) só recusa nulo/vazio — não olha tamanho. No formulário, `<input id="nome" required>` e `<input id="categoria">` (produtos.html:12-13) não têm `maxlength`. Nenhuma das duas colunas está no `LarguraDeColuna`, que é o lugar onde este projeto centraliza largura de coluna justamente porque o `ddl-auto: validate` não confere largura.

**Como foi medido:** Li V1 linha 3 (`create table produto(... nome varchar(160), categoria varchar(80) ...)`). Li `LarguraDeColuna.java` inteiro: as constantes são de pedido, cliente, pagamento_assinatura e integracao_canal — `produto.nome` e `produto.categoria` não aparecem. Li `ProdutoService.atualizar` (65-87) e `validarNome` (215-219). Rodei `grep -n "maxlength" produtos.html`: só 2 ocorrências, `codigoExterno` (60) e `catPara` (60, o campo de renomear categoria) — os campos `nome` e `categoria` não têm.

**Impacto:** Nome de combo com mais de 160 caracteres, ou categoria com mais de 80, faz o Postgres recusar o INSERT/UPDATE ("value too long for type character varying") e o lojista leva 500 ao salvar o produto, com o formulário perdido. Não é perda de venda nem de dado — é recuperável encurtando o texto — e por isso marco baixa. Registro porque é a mesma classe que perdeu um pedido na v126 e porque o próprio arquivo ao lado no mesmo formulário (`catPara`, maxlength=60) mostra que a equipe já limita em outros campos. Observação: `catPara` em 60 é mais estreito que os 80 de `produto.categoria` e de `categoria_ordem.nome`, então é seguro — só inconsistente.

### 3. O comentario diz que a comparacao do token do PIX virou tempo constante, e a linha logo acima ainda usa equals

**Fatia:** Controllers e contratos da API

**Onde:** `controller/PublicController.java:829-833 (POST /public/pix-webhook/{lojaId}) e controller/AsaasWebhookController.java:60`

**O que:** No webhook que confirma pagamento PIX ha dois caminhos de autenticacao. O caminho legado (linha 832-833) usa Segredos.iguais, que compara em tempo constante. O caminho da subconta white-label (linha 829-830), que e o que vale para as lojas novas, ainda usa 'token.equals(loja.asaasWebhookToken)'. O comentario 'Item 8.8: comparacao em tempo constante. O equals parava no primeiro caractere diferente' esta na linha 831 - entre os dois - e lido de cima para baixo da a entender que os dois caminhos foram arrumados. Foi um so. O mesmo sobrou em AsaasWebhookController.java:60 ('if (!token.equals(header))'), que e o webhook da assinatura do proprio Bora.

**Como foi medido:** grep -n em todo o pacote br.com.bora: apareceram exatamente 2 comparacoes de segredo com equals (PublicController.java:830 e AsaasWebhookController.java:60) contra 2 com Segredos.iguais (PublicController.java:833 e IntegracaoService.java:264). Li as linhas 819-836 de PublicController.java e vi o comentario do item 8.8 na linha 831, logo abaixo do equals da linha 830. Li security/Segredos.java: o javadoc dele afirma que 'dois ficaram com equals' e que agora ha um lugar so para isso - os dois que ficaram sao justamente estes.

**Impacto:** Quem confirma um pagamento PIX falso marca o pedido como pago (p.pagoEm, p.aguardandoPagamento=false) e, se ele estiver cancelado, o REABRE e manda para a cozinha. Mas para chegar la precisa acertar o token da loja, e descobrir um token de 32+ caracteres medindo tempo de resposta pela internet e pouco pratico - a propria varredura do projeto classificou isso como prioridade baixa. O que importa aqui e menos o risco e mais o comentario: quem reler este arquivo vai concluir que o conserto do item 8.8 esta inteiro, e ele nao esta.

### 4. O balconista pode ler o faturamento recuperado pelo Modulo IA

**Fatia:** Controllers e contratos da API

**Onde:** `controller/IaController.java:81-84 (GET /api/ia/recuperacao/resumo) e service/IaService.java:151-168`

**O que:** O endpoint devolve 'valorRecuperado', que e a soma de pedido.valorTotal dos clientes que voltaram a comprar em 30 dias (IaService.java:165). Isso e numero de dono. A unica trava e exigirModulo(lojaId) (IaService.java:62-70), que confere so se a loja pagou o add-on - nao confere papel nenhum. O endpoint irmao, POST /api/ia/recuperar, tem ctx.requirePapel("ADMINISTRADOR_LOJA", "GERENTE") no controller (IaController.java:76), e as outras telas que mostram faturamento tambem (RelatorioService.java:59, DesempenhoService, RedeService.balancete:117, VendasController.termometro). Este ficou sem.

**Como foi medido:** Li IaController.java linhas 26-100: 'resumoRecuperacao' e o unico metodo do controller que mexe em dinheiro e nao tem requirePapel. Li IaService.resumoRecuperacao (linhas 151-168): a primeira linha e exigirModulo(lojaId) e a ultima e Map.of(..., "valorRecuperado", valor). Li exigirModulo (linhas 62-70): so testa Boolean.TRUE.equals(l.moduloIa) e devolve 403 se nao. Nenhuma chamada a ctx em todo o caminho.

**Impacto:** Hoje nao vaza nada: moduloIa nasce false na entidade (Loja.java:31) e a migracao V19__modulo_ia.sql criou a coluna com DEFAULT FALSE, entao o endpoint devolve 403 para todo mundo. O furo abre no dia em que o dono liberar o Modulo IA para uma loja: dali em diante um OPERADOR dessa loja le o faturamento recuperado chamando o endereco direto, sem precisar de tela. E o mesmo defeito do item 8.3 que foi fechado nos outros lugares.

### 5. Pedido do cardapio com numero mal escrito devolve 500 em vez de 400

**Fatia:** Controllers e contratos da API

**Onde:** `controller/PublicController.java:428, 522 e 523 (POST /public/loja/{lojaId}/pedido)`

**O que:** Tres leituras do corpo sao feitas sem protecao: a linha 428 faz um cast direto de body.get("itens") para List (se vier texto, ClassCastException), a linha 522 faz Long.valueOf(String.valueOf(it.get("produtoId"))) e a linha 523 faz Integer.parseInt(...). Nenhuma esta em try/catch e nao existe tratador global de excecao no projeto. Como nao e ResponseStatusException, a resposta sai 500 com rastro de pilha. Note que o proprio metodo protege outras coisas direito (itens nulo, vazio ou acima de 50 -> 400; quantidade fora de 1..99 -> 400); o que falta e so o caso de o valor nao ser numero.

**Como foi medido:** grep -n nos controllers por parse cru: PublicController.java:428, 522, 523 (e, menor, CupomController.java:56 com LocalDate.parse da validade, PlataformaController.java:317 e 342 com LocalDate.parse, estes dois so alcancaveis pelo admin da plataforma). Confirmei que nao ha rede de seguranca: 'grep -rn "ControllerAdvice|RestControllerAdvice|ExceptionHandler"' em todo br.com.bora nao devolveu nada. Que isto conta como defeito neste projeto esta medido no proprio teste do dono: src/test/java/br/com/bora/service/AfichaNaoCRIAinsumoAoVenderTest.java:135-142, 'textoQUEnaoEHnumeroDA400_eNAO500', com o comentario 'Antes: NumberFormatException subia crua -- HTTP 500 com rastro de pilha'.

**Impacto:** Nao corrompe dado: as linhas 522-523 rodam dentro do tx.execute, e o TransactionTemplate desfaz tudo em qualquer RuntimeException, entao nao sobra pedido pela metade nem estoque baixado. O estrago e so o 500 com pilha no log de um endpoint aberto na internet, em vez de um 400 dizendo qual campo esta errado. A tela do cardapio monta produtoId e quantidade a partir do proprio menu, entao cliente normal nao chega aqui - so quem monta a chamada a mao.

### 6. Na Frente de Caixa, a recarga do saldo de cashback depois da venda e engolida; a venda seguinte pode oferecer saldo que nao existe mais

**Fatia:** O codigo das telas

**Onde:** `bora-fase-2-frontend/assets/js/pdv.js:224`

**O que:** `try { clientes = await Bora.clientes(); atualizarCashback(); } catch (e) {}` -- se essa recarga falhar, o array `clientes` fica com o saldo de ANTES da venda e nada e dito. O `descontoDoCashback` (pdv.js:30-39) le `c.cashback` desse array. Na venda seguinte, se o balconista escolher o mesmo cliente e marcar o visto, a tela mostra um desconto que o servidor nao vai conceder, e o total exibido fica menor que o cobrado.

**Como foi medido:** Li pdv.js:224 (catch vazio, com comentario "saldo de cashback atualizado") e pdv.js:30-39 (a fonte do numero e `clientes.find(...).cashback`). A linha 221 faz `$('usarCashback').checked = false`, o que exige um ato novo do balconista -- e por isso o risco e menor que no cardapio -- mas nao refresca o saldo. Mesma familia do achado 1, em outro arquivo.

**Impacto:** Total na tela diferente do cobrado na venda de balcao, so quando a recarga falha. Dinheiro, mas com gatilho estreito (precisa da falha de rede entre duas vendas do mesmo cliente).

### 7. Duvida: o Novo Pedido decide "estou cadastrando cliente novo" perguntando ao layout, exatamente o que o comentario do arquivo proibe

**Fatia:** O codigo das telas

**Onde:** `bora-fase-2-frontend/assets/js/novo-pedido.js:344 (contra o comentario em novo-pedido.js:64-67)`

**O que:** A linha 344 e `if ($('novoClienteBox').style.display !== 'none') clienteId = await criarClienteInline();`. Trinta linhas antes, o `alternarNovoCliente` guarda essa decisao na variavel `criandoCliente` com o comentario: "O estado fica aqui, nao no style: decidir regra de negocio perguntando ao layout quebra calado assim que alguem trocar display por uma classe". O ponto que grava o pedido faz justamente isso, e ignora a variavel.

**Como foi medido:** Li novo-pedido.js:64-72 e :343-344. Hoje NAO quebra, e conferi por que: novo-pedido.html:32 traz `<div id="novoClienteBox" style="display:none;...">` em estilo inline, entao `.style.display` vale 'none' na abertura. Reporto como duvida/fragilidade, nao como defeito ativo: trocar esse `display:none` por uma classe CSS -- o tipo de limpeza que se faz num dia de cores -- faria todo pedido cair em `criarClienteInline()` e morrer com "Informe o nome do cliente novo".

**Impacto:** Nenhum hoje. Se o inline style sair do HTML, a tela de Novo Pedido para de lancar qualquer pedido, e a mensagem de erro aponta para o campo errado -- por isso vale trocar a linha pela variavel que ja existe.

### 8. No relatorio, "0 entregas" aparece com dinheiro ao lado, porque os dois numeros vem de conjuntos diferentes

**Fatia:** Os servicos que mexem em dinheiro

**Onde:** `bora-fase-3-backend-java/src/main/java/br/com/bora/service/RelatorioService.java:171-177 (e a tela em bora-fase-2-frontend/assets/js/relatorios.js:92-95)`

**O que:** No bloco por entregador, `entregas` soma 1 so quando o status e ENTREGUE (`inc(m, "entregas", p.status == StatusPedido.ENTREGUE ? 1 : 0)`), mas `valor` soma o `valorTotal` de TODO pedido nao cancelado com aquele entregador, em qualquer status. A tela imprime os dois juntos: `${o.entregas} entregas · ${money(o.valor)}`. Pedido com motoboy atribuido e ainda em SAIU_PARA_ENTREGA (ou em preparo, porque `definirEntregador` permite atribuir antes, PedidoService.java:631-648) entra no dinheiro e nao na contagem.

**Como foi medido:** Li RelatorioService.java:171-177 e relatorios.js:92-95 (o template da linha e a ordenacao por `entregas`). O comentario do bloco diz "entregas concluidas", mas a soma do valor nao filtra status nenhum — conferi o codigo, nao o comentario.

**Impacto:** Linha do tipo "0 entregas · R$ 240,00" no ranking de entregadores, e o ranking ordena por um dos dois numeros. Ninguem paga por esta tela — o acerto do motoboy usa outra consulta, que filtra ENTREGUE e acerto em aberto (PedidoRepository.java:134-141) e esta correta —, entao nao ha dinheiro errado saindo; e leitura confusa de um numero de dinheiro.

### 9. Tres respingos da escala violeta antiga sobreviveram dentro de rgba()

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `bora-fase-2-frontend/acompanhar.html:18, assets/css/styles.css:53, assets/js/onboarding.js:18`

**O que:** A troca para o roxo pegou todos os hexadecimais, mas nao pegou tres cores escritas em rgba(124,58,237,...), que e o #7C3AED (violeta-600, a marca velha). O pior e o acompanhar.html: a linha 14 pinta a bolinha do passo atual com var(--marca,#9333ea) -- roxo novo -- e a linha 18 faz o halo pulsante AO REDOR DA MESMA BOLINHA com rgba(124,58,237,.35). Sao dois roxos diferentes no mesmo elemento. Os outros dois sao o anel de foco da busca do quadro de pedidos (styles.css:53) e a sombra de passar o mouse nos passos do onboarding.

**Como foi medido:** grep -rnE '124\s*,\s*58\s*,\s*237' nos .html/.css/.js voltou exatamente esses 3 lugares, e nenhum hex da escala violeta. Confirmei que renderiza: no acompanhar.html criei um <div class='passo atual'><div class='bola'> e li o computado em 6 amostras -> boxShadow sempre 'rgba(124, 58, 237, 0.35) 0px 0px 0px 0px'. Em pedidos.html percorri document.styleSheets e li a regra viva: ".board-search input:focus {outline: none; border-color: var(--primary); background: rgb(255,255,255); box-shadow: rgba(124, 58, 237, 0.12) ...}" -- a borda ja usa a cor nova e a sombra ainda usa a velha, na mesma declaracao.

**Impacto:** Nada quebra, mas o halo da bolinha e o anel de foco saem num roxo que nao e mais o da marca -- e no acompanhar a loja que tem cor propria fica com um halo violeta Bora em volta da bolinha da cor dela.

### 10. O aviso de estoque baixo em Insumos tem 2,15:1

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `bora-fase-2-frontend/assets/js/insumos.js:16`

**O que:** Quando o insumo fica abaixo do minimo, a quantidade e pintada de #f59e0b (ambar) sobre fundo branco, com um aviso de triangulo junto. A razao e 2,15:1. O caso de estoque ZERO usa #dc2626 e da 4,0:1, que tambem nao chega aos 4,5:1 -- mas e bem melhor que o do estoque baixo.

**Como foi medido:** Abri insumos.html em 375px e o medidor devolveu "b #f59e0b/#ffffff 2.15 13px/700 '2 kg (aviso)'". A linha que gera isso e: color:${estoque<=0 ? '#dc2626' : baixo ? '#f59e0b' : '#0f172a'}.

**Impacto:** O ambar foi escolhido justamente para chamar atencao, e e o texto mais apagado da linha -- o lojista passa o olho na lista e nao ve que o insumo esta acabando. Depois falta queijo no meio do movimento.

### 11. A letra do produto sem foto no PDV tem 1,42:1 e some do azulejo

**Fatia:** Telas renderizadas, contraste e celular

**Onde:** `bora-fase-2-frontend/assets/css/styles.css:159 (.prodtile .pf-vazia)`

**O que:** Produto sem foto cadastrada ganha um quadrado com a inicial do nome em #cbd5e1 sobre #f8fafc. Sao 1,42:1 -- abaixo ate do limite de 3:1 que valeria para texto grande (28px/900).

**Como foi medido:** Abri pdv.html em 375px com o cardapio real da loja de demonstracao e o medidor devolveu "div.pf.pf-vazia #cbd5e1/#f8fafc 1.42 28px/900 'A'" (limite aplicado: 3,0 por ser texto grande).

**Impacto:** No PDV o operador escolhe o produto batendo o olho no azulejo. Com a inicial invisivel, os produtos sem foto viram todos um quadrado cinza igual, e ele precisa ler o nome pequeno embaixo em cada um.

### 12. Excluir produto pergunta so "Excluir produto?" -- nao diz o nome nem que a ficha tecnica e os complementos vao com ele

**Fatia:** Usabilidade e fluxo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/assets/js/produtos.js:117`

**O que:** `window.__del = async id => { if (!confirm('Excluir produto?')) return; ... }`. A exclusao no servidor apaga, na mesma transacao, os grupos de complemento, as opcoes de cada grupo e a ficha tecnica inteira do produto -- e o aviso nao cita nada disso nem o nome do produto que vai embora. A propria tela sabe do efeito: o comentario em produtos.html:24-26 diz que excluir "leva a ficha tecnica e os complementos", e produtos.html:95-99 registra que montar a ficha numa acaiteria com 35 produtos e 43 insumos sao centenas de cliques. O botao ✕ fica colado no ✏ de editar, na mesma celula, com 5px 9px de padding.

**Como foi medido:** Li produtos.js:117. Li ProdutoService.java:199-214 (C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/ProdutoService.java) e confirmei no codigo, nao so no javadoc: `opcoes.deleteByLojaIdAndGrupoIdIn`, `grupos.deleteByLojaIdAndProdutoId` e `fichas.deleteByLojaIdAndProdutoId` antes do `repo.delete(alvo)`. Comparei com o padrao que o proprio projeto ja usa em clientes.js:100-109 (nomeia o cliente, diz que o cashback vai embora e sugere o ✎) e em cupons.js:21. Li produtos.js:28-33 e confirmei que ✏ e ✕ ficam na mesma celula com padding 5px 9px.

**Impacto:** Um toque errado no celular, na coluna de botoes pequenos, apaga sem aviso a ficha tecnica que custou centenas de cliques -- e, sem ficha, vender deixa de baixar insumo nenhum do estoque. O lojista le "Excluir produto?", clica OK achando que esta tirando um item do cardapio (que e o que a caixinha "Aparece no cardapio" faz sem perder nada) e so descobre depois.

### 13. No cadastro de produto a categoria e texto livre, sem a lista das categorias que a propria tela ja carregou

**Fatia:** Usabilidade e fluxo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/produtos.html:13`

**O que:** `<div class="field"><label>Categoria</label><input id="categoria"></div>` -- input de texto puro, sem `list=`, sem `<datalist>` e sem nenhuma sugestao. A lista das categorias existentes esta na mesma pagina: renomear-categoria.js:45-57 monta um `Map` delas a partir dos produtos carregados e preenche o `<select id="catDe">`. O risco esta documentado na propria tela, em produtos.html:81-83: "uma letra errada em um deles fazia esse produto virar uma categoria sozinha no cardapio do cliente".

**Como foi medido:** Li produtos.html:13 e procurei por datalist/list= em produtos.html, produtos.js e renomear-categoria.js -- nenhuma ocorrencia. Li renomear-categoria.js:45-57 e confirmei que a lista de categorias e derivada dos produtos que a tela ja tem na mao. Li produtos.html:81-83 e produtos.js:60 (`categoria: $('categoria').value.trim()`, nenhuma normalizacao).

**Impacto:** "Bebidas" e "bebida" viram duas secoes no cardapio que o cliente le, e um produto fica sozinho numa secao propria. O conserto depois existe (a caixa Renomear categoria), mas e trabalho que nao precisava acontecer: a armadilha continua armada no ponto em que o lojista digita, e e ele quem descobre o erro olhando o cardapio publico.

### 14. A tela que o cliente acompanha sempre mostra o passo "Saiu para entrega -- a caminho de voce", mesmo quando o pedido e de retirada

**Fatia:** Usabilidade e fluxo

**Onde:** `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/acompanhar.html:53-60 (a lista FASES, fixa) e C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/controller/PublicController.java:794-814 (o que o status devolve)`

**O que:** A linha do tempo da tela publica e uma constante com seis fases, entre elas `{ st:['SAIU_PARA_ENTREGA'], ic:'🛵', t:'Saiu para entrega', s:'A caminho de voce' }`, e a tela nao consulta o tipo de entrega -- porque o endpoint nao manda: o `statusPedido` devolve codigo, status, pago, loja, criadoEm e motivoCancelamento, e nada de tipoEntrega. O cliente escolhe retirada no proprio cardapio (cardapio.html:78, e cardapio.js:497 manda tipoEntrega RETIRADA), entao o caso e comum. Alem disso, quando o pedido e CANCELADO a tela mostra o aviso e faz `return` sem `clearInterval` (acompanhar.html:73-77), e segue batendo no servidor a cada 5 segundos; e o estado de erro "Pedido nao encontrado" (linha 89) nao oferece nenhuma saida -- nem voltar ao cardapio, nem o telefone da loja.

**Como foi medido:** Li acompanhar.html:53-61 (FASES e ORDEM, constantes) e acompanhar.html:78-84 (o render usa so o indice do status). Li PublicController.java:794-814 e listei os campos do mapa de resposta: codigo, status, pago, loja, criadoEm, motivoCancelamento -- nao ha tipoEntrega. Li cardapio.html:78 e cardapio.js:497 para confirmar que o cliente consegue pedir retirada pelo link. Li acompanhar.html:73-77 (CANCELADO sai por return, sem clearInterval, ao contrario da linha 84 que limpa no ENTREGUE) e acompanhar.html:88-90.

**Impacto:** Quem pediu para buscar na loja le "a caminho de voce" e fica esperando em casa -- o mesmo efeito do achado 1, agora pelo lado do cliente, e some mesmo que o quadro de Pedidos seja corrigido (a tela marcaria o passo como concluido). Pedido cancelado deixa o celular do cliente consultando o servidor para sempre. E quem abre um link velho ou torto ve "Pedido nao encontrado" sem nenhum caminho de volta.

---

## O que os ceticos DERRUBARAM (34)

Isto tem valor proprio: sao alarmes que nao viraram tarefa.

- **A imagem que aparece no WhatsApp ainda é a laranja — o site já é roxo** (A landing e a pagina de vendas)
- **Sem robots.txt, o Google pode indexar as telas internas do painel no mesmo domínio da página de vendas** (A landing e a pagina de vendas)
- **No celular o menu do topo some inteiro, e não há nada no lugar** (A landing e a pagina de vendas)
- **Duas páginas se contradizem sobre onde o lojista envia os documentos para receber por PIX** (A landing e a pagina de vendas)
- **Dúvida: a página diz que o preço do Módulo IA é combinado, mas o sistema soma R$ 99 fixos** (A landing e a pagina de vendas)
  - DERRUBADO. Os tres pilares do achado caem quando se le o resto do caminho.

1) "Nao ha como gravar um valor combinado — para honrar um preco diferente alguem precisa mexer no preco_mensal da loja inteira" — o preco_mensal POR LOJA e exatamente o mecanismo oficial de preco negociado, nao um desvio. P
- **Pedido de retirada no quadro de Pedidos so avanca por "Despachar" -- e a tela de Entregas manda fazer o contrario** (Usabilidade e fluxo)
  - DERRUBADO: existe guarda no servidor, no mesmo arquivo que o autor diz ter conferido, e ela barra exatamente o caminho alegado.

1) O servidor RECUSA PRONTO->SAIU_PARA_ENTREGA para retirada. bora-fase-3-backend-java/src/main/java/br/com/bora/service/PedidoService.java:661-668, dentro de `alterarStat
- **Erro de login mostra "Credenciais invalidas" cru, enquanto a mesma tela traduz esse texto no outro formulario** (Usabilidade e fluxo)
  - A mecanica que o autor descreve existe, mas o "defeito" e comportamento intencional e documentado em tres lugares, e o remedio que ele propoe seria uma regressao de seguranca.

O que confirmei da mecanica (para nao ser injusto com ele): bora-fase-3-backend-java/src/main/java/br/com/bora/controller/A
- **DUVIDA: os graficos do Dashboard ficaram presos no roxo do Bora e ignoram a cor da loja** (Telas renderizadas, contraste e celular)
  - Li o CSS, o JS e o commit que escreveu esses gradientes. O gradiente fixo existe, mas o achado como esta escrito nao se sustenta em tres pontos:

1) A PREMISSA E FALSA ("o painel inteiro veste a cor dela e so os dois graficos ficam roxos"). Na MESMA tela do dashboard.html ha varios elementos com rox
- **O bloco inteiro de Recebimento PIX desaparece calado quando a consulta falha** (O codigo das telas)
  - O codigo e como o autor descreveu, mas o impacto nao se sustenta: nos dois caminhos alcancaveis o vazio e inofensivo ou correto.

1) O que CONFIRMEI lendo: `C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/assets/js/recebimento.js:196-199` — `async function render(){ let d; try{ d = await Bo
- **Nao ha como apagar o banner da loja pelo painel: o campo vazio vai como null e o servidor ignora null** (O codigo das telas)
  - DERRUBADO pelo impacto: o `bannerUrl` NAO aparece em nenhuma tela — nem do lojista, nem do cliente final. Grep por "banner" (case-insensitive) em todo o bora-fase-2-frontend (html/js/css) devolve ocorrencias SO em bora-fase-2-frontend/configuracoes.html:118 (o input) e bora-fase-2-frontend/assets/js
- **O servidor pode cobrar taxa de entrega num pedido de RETIRADA (hoje a tela segura)** (Os servicos que mexem em dinheiro)
  - Li o codigo e o caminho nao existe para ninguem, e o que sobra e contrato documentado, nao brecha.

1) Nao ha terceiro chamador. `PedidoService.criar(NovoPedidoRequest)` so e chamado de bora-fase-3-backend-java/src/main/java/br/com/bora/controller/PedidoController.java:41-42 (grep por `NovoPedidoReq
- **Duvida: a regra de "venda" no SQL e a do Java nao sao identicas, e o teste que diria isso esta mockado** (Os servicos que mexem em dinheiro)
  - Derrubado: o estado divergente e inalcancavel, e eu fechei a ultima porta que o autor nao olhou.

O que confirmei igual ao autor (lendo o codigo):
- PedidoRepository.java:94, :109, :145, :160, :299-303, :348 — todos os SQL filtram so `(p.aguardandoPagamento is null or p.aguardandoPagamento = false)`
- **Webhook PIX da subconta compara o token com `equals` (o ramo irmão, logo abaixo, já usa tempo constante)** (Seguranca e isolamento entre lojas)
  - DERRUBADO — não por erro de leitura do autor (os fatos dele batem), mas porque o caminho de ataque NÃO é alcançável, e o que resta é cosmético.

O QUE EU CONFIRMEI (a favor dele, para registro honesto):
1. PublicController.java:829-830 usa mesmo `token.equals(loja.asaasWebhookToken)`; 831-833 usa `S
- **DUVIDA: as origens de CORS são separadas por vírgula sem `trim()`** (Seguranca e isolamento entre lojas)
  - DERRUBADO: o mecanismo existe no código, mas o impacto alegado é inalcançável — em produção o painel e a API ficam na MESMA origem, então nenhuma chamada do painel passa pelo CORS.

1) O que confirmei do mecanismo (o autor leu certo essa parte)
C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend
- **Quem paga uma vez "fora do Asaas" ganha acesso sem prazo para sempre — e nenhum evento do Asaas consegue mais impor data** (Asaas, PIX, assinatura e corte de acesso)
  - DERRUBADO. Quatro furos, todos lidos no código (C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/).

1) EXISTE caminho que apaga o PAGAMENTO_MANUAL — e é o caminho normal da loja. service/AssinaturaService.java:398-402 (`PAYMENT_CONFIRMED`/`PAYMENT_RECEIVED`) fa
- **RegraDeAcesso.podeOperar não olha loja.ativo: assinatura cancelada fecha o cardápio e deixa a loja online no iFood/99** (Asaas, PIX, assinatura e corte de acesso)
  - DERRUBADO. Li os quatro pontos citados, a entidade, os dois filtros e o teste. A mecânica que o autor descreve existe (podeOperar realmente não lê `ativo`), mas as três pernas que fazem disso um defeito de severidade "Pedido" caem uma por uma:

1) O comportamento é INTENCIONAL E DOCUMENTADO no lugar
- **Webhook PIX: o ramo da subconta usa equals simples e aceita token vazio dos dois lados** (Asaas, PIX, assinatura e corte de acesso)
  - DERRUBADO como achado. O que o titulo e o impacto afirmam ("aceita token vazio dos dois lados", quem passa marca pedido como PAGO e reabre cancelado) nao se sustenta; o unico fato que sobrevive e uma assimetria cosmetica sem impacto medivel.

1) O vazio nao e alcancavel, e por mais motivos do que o 
- **Pedido de senha de conta da plataforma fica invisível para sempre e trava os próximos pedidos da mesma pessoa** (Banco e as 64 migracoes)
  - DERRUBADO. Os fatos de esquema que ele cita são verdadeiros (V50:20 `loja_id bigint` sem NOT NULL; índice só por `(loja_id, criado_em desc)`; repositório com 4 métodos e um único de listagem por `LojaId`; `PlataformaController:141` e `BootstrapAdmin.java:57` gravam conta de plataforma sem loja). O q
- **Integracao em ERRO ou desligada: o cancelamento feito no painel nao vai para o canal e ninguem avisa** (iFood, 99 e OpenDelivery)
  - DERRUBADO. O codigo e como o achado descreve, mas o defeito nao e defeito: e o comportamento documentado na MESMA frase do javadoc que o autor citou pela metade, e e o unico comportamento que funciona.

1) O autor leu meio comentario. Ele cita "linhas 287-291" e afirma que o javadoc "promete" que os
- **O webhook generico /webhooks/{canal} nao confere canal desligado nem loja suspensa -- a guarda posta em 27/10 so entrou no endpoint da 99** (iFood, 99 e OpenDelivery)
  - DERRUBADO como defeito na fatia "iFood, 99 e OpenDelivery" — o fato de codigo e verdadeiro, mas o caminho nao e alcancavel por ninguem alem do proprio gerente/admin da loja, e justamente nos casos de ACESSO que o achado alega (loja suspensa/arquivada/vencida) ele e inalcancavel por construcao.

O QU
- **O "Estoque minimo" do insumo e um campo que ninguem le: nada nunca compara o saldo com ele** (Estoque, insumo e ficha tecnica)
  - DERRUBADO: o campo E lido, em duas telas, e o autor nao achou porque grepou apenas os .html do frontend, onde nenhuma tela do BoraHapp tem logica. (1) bora-fase-2-frontend/assets/js/insumos.js:15-16 (carregado por insumos.html na ultima linha): `const baixo = i.estoqueMinimo != null && Number(i.esto
- **Criar insumo com estoque negativo passa calado -- e depois os botoes de ajuste recusam para sempre** (Estoque, insumo e ficha tecnica)
  - DERRUBADO. Os tres fatos de codigo do achado existem, mas as tres consequencias que o tornam defeito estao erradas. Sobra uma assimetria cosmetica de validacao, nao o defeito descrito.

O QUE CONFIRMEI LENDO (e que o achado acertou):
- InsumoService.java:68 `if (i.id == null) alvo.estoque = i.estoqu
- **Duvida: o custo do insumo aceita valor negativo pelo API, e o custo negativo abate o CMV do produto** (Estoque, insumo e ficha tecnica)
  - DERRUBADO — existe uma guarda a jusante que o autor nao viu, e a medicao que ele cita e de um comentario que descreve o codigo ANTIGO, nao o de hoje.

1) A GUARDA QUE FALTOU LER. PedidoService.custoDaFichaOuDoProduto (C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/
- **O deploy do painel confere num sentido so: ele nunca ve o que SOBRA no servidor, e diz 'ficou igual ao repositorio'** (Docker, Caddy, deploy, backup e vigia)
  - DERRUBADO — a mecânica descrita é real, mas a causa-raiz e o defeito alegados estão errados, e a correção implícita ("ver o que sobra / apagar o que não está na lista") derruba o site comercial do ar.

O que CONFIRMEI lendo C:/Users/user/OneDrive/Desktop/Bora/bora-landing/deploy/deploy-frontend.sh: 
- **Backup e ensaio de restauracao falham para um log que nada le; o vigia, que roda de 5 em 5 min, nunca olha nenhum dos dois** (Docker, Caddy, deploy, backup e vigia)
  - DERRUBADO por dois motivos independentes, os dois lidos no codigo.

1) GUARDA EM OUTRO ARQUIVO QUE O AUTOR NAO VIU — e ela e humana, nao um log.
C:/Users/user/OneDrive/Desktop/Bora/bora-landing/deploy/deploy-api.sh:24 tem `set -euo pipefail` e a linha 82 e o passo "7/9 BACKUP antes de trocar":
  `ss
- **Dump reprovado (.RUIM) com dado de cliente fica para sempre, fora do chmod 600 e fora da retencao de 14 dias** (Docker, Caddy, deploy, backup e vigia)
  - DERRUBADO no que o achado tem de titulo e de impacto: a ordem das linhas desmente a parte de permissao, e o "glob que nao casa" e exatamente o mecanismo do .RUIM, nao um descuido.

1) "fora do chmod 600" e "permanece com o dono/permissao com que nasceu dentro do container (root)" — FALSO, por ordem 
- **O dashboard gasta 6 idas ao banco a cada 8 segundos para devolver 6 números** (Consultas, N+1 e custo)
  - DERRUBADO no que o achado afirma como impacto — as 6 consultas existem, mas o número (105 consultas/min por loja) é inalcançável e uma das três telas citadas não chama o endpoint.

1) A terceira tela não existe. O achado diz "assets/js/caixa.js:46 (`Bora.resumo()`) com repetir de 15000". Li C:/Users
- **AuthController sem teste nenhum: login, troca de senha e troca de loja** (A qualidade dos proprios testes)
  - DERRUBADO no que o achado tem de load-bearing: ele mediu com `grep ... src/test/java` e perdeu as redes que existem fora dali. O fato cru ("nenhum .java de teste cita AuthController") eu confirmei — OcorsNaoFalhaAbertoTest.java:96 so cita a string "/auth/login" numa regra de CORS e FreioDeTentativas
- **A lista de rotas que dispensam token nao esta travada por teste** (A qualidade dos proprios testes)
  - DERRUBADO pela lente "o caminho é alcançável de verdade?" — existe uma segunda guarda que o autor não viu, e ela vale para TODA a superfície autenticada de hoje.

O QUE CONFIRMEI A FAVOR DO AUTOR (não disputo):
- C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/
- **O teste do limite exato de liberacao de acesso so prova que nao estourou, nao que liberou** (A qualidade dos proprios testes)
  - DERRUBADO. Li `AssinaturaService.liberarAcesso` (C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/service/AssinaturaService.java:969-1009), o `prazoDeAcesso` (linhas 1023-1029) e a classe de teste inteira. Tres motivos, todos medidos no codigo:

1) A mutacao que
- **DUVIDA: 29 dos 30 testes do backend que leem fonte de producao como texto nao tiram comentario antes de procurar** (A qualidade dos proprios testes)
  - DERRUBADO. O numero do titulo nao reproduz, e o instrumento que o produziu nao conseguia ver a protecao que procurava.

1) A medicao citada esta errada no proprio comando do autor. `grep -rn "semComentarios" src/test/java` em HEAD devolve DOIS arquivos, nao um: alem de C:/Users/user/OneDrive/Desktop
- **O sistema não sabe quanto a loja paga por entrega: o acerto manda pagar a taxa do cliente, que é R$ 0,00 fora da loja 1** (O processo de negocio ponta a ponta)
  - DERRUBADO. Os dois fatos de código estão certos, mas a premissa que carrega toda a gravidade — "fora da loja 1 o acerto diz R$ 0,00 para qualquer número de entregas" — é dedução, e o código a contradiz.

1) `pedido.taxa_entrega` NÃO depende da tabela de bairro. São três fontes, e a tabela de bairro 
- **Um job abre 15% de desconto sozinho, em qualquer loja, sem avisar e sem jeito de desligar — e trava a promoção do lojista por 3 horas** (O processo de negocio ponta a ponta)
  - DERRUBADO. O mecanismo existe, mas as três afirmações que sustentam o título são falsas — e duas delas o autor só poderia ter escrito por não ter aberto a tela de Promoções.

1) "O lojista não é avisado em nenhum lugar — o único registro é um log.warn no servidor" — FALSO.
C:/Users/user/OneDrive/Des
- **O acerto fecha sem nunca perguntar do dinheiro que o motoboy recebeu — e depois de fechado esse valor não volta a aparecer** (O processo de negocio ponta a ponta)
  - DERRUBADO. Li o codigo inteiro e a mecanica que o autor descreve existe, mas as tres afirmacoes que dao peso ao achado nao sobrevivem a leitura — e o que resta e pedido de campo novo, nao defeito.

1) O "recibo" que ele descreve NAO EXISTE. A impressao e de PREVIA, nao de acerto: `imprimir()` em bor

---

## O que cada agente conferiu e esta CORRETO

### A landing e a pagina de vendas

Varri as 5 páginas da landing (index, funcionalidades, precos, sobre, contato), o assets/site.css, as 3 imagens, e ainda termos.html/privacidade.html porque a landing linka para eles. Conferi os 32 links únicos no ar com curl (todos 200), comparei o sha256 dos 11 arquivos locais com o que o servidor serve (todos iguais — a virada roxa está publicada) e cruzei preço, limites, taxa e cada promessa de recurso com o código do backend. A fatia está em bom estado: nenhum link quebrado, nenhum preço divergente e nenhuma promessa de recurso que o sistema não entregue. Os 6 achados são de marca, de SEO e de navegação no celular — nenhum mexe em dinheiro, pedido ou acesso.

LINKS (tudo 200, nada quebrado): extraí os 32 hrefs únicos das 5 páginas e bati um por um no ar com curl — /, /funcionalidades.html, /precos.html, /sobre.html, /contato.html, /login.html, /cadastro.html, /termos.html, /privacidade.html, /assets/site.css, os 3 arquivos de imagem e os 12 links wa.me. As 3 âncoras internas existem de verdade no destino (#economia em index.html:192, #construindo em funcionalidades.html, #faq em precos.html). O /login.html e o /cadastro.html vêm do repositório do painel (bora-fase-2-frontend) e estão no ar — os dois repositórios publicam na mesma pasta, e dessa vez a landing venceu a disputa do index.html (a raiz devolve 30402 bytes, byte a byte igual ao index.html da landing).

PUBLICAÇÃO: comparei o sha256 dos 11 arquivos da landing com o que o servidor devolve — index, precos, funcionalidades, sobre, contato, termos, privacidade, site.css, logo-bora.svg, icone-bora.svg e og-borahapp.png: TODOS iguais. Não há deploy parcial aqui. Os 9 arquivos .bak que estão no disco (index.html.bak3-20261002 etc.) dão 404 no ar — não foram publicados, então ninguém baixa a página de vendas antiga pela URL. O /landing.html antigo é um redirect correto para / com noindex.

PREÇO x SISTEMA: a landing diz R$ 199/mês por loja em 14 lugares. O backend cobra exatamente isso — Plano.java:9 `UNICO(15, 0, 199.00)`. "Pedidos ilimitados" confere (maxPedidosMes=0 e PlanoService.checarLimitePedidosMes sai sem aplicar limite). "Até 15 usuários por loja" confere (maxUsuarios=15, cobrado em PlanoService.checarLimiteUsuarios). Não existe nenhum R$ 149, R$ 299 nem oferta de fundador sobrando em lugar nenhum das páginas.

TAXA: "sem taxa por pedido e sem comissão" e "o dinheiro não passa pela nossa conta". O split do PIX existe no código (PixService.java:178-186), mas só entra no corpo da cobrança quando `taxa.signum() > 0`; o padrão é 0 (application.yml:93, `${ASAAS_TAXA_PERCENTUAL:0}`). Com 0, nenhum campo "split" vai para o Asaas e a frase é verdadeira. NÃO consegui ler a variável de ambiente de produção (precisaria de chamada autenticada no /admin-bora) — fica medido só o padrão do código.

TESTE GRÁTIS E GARANTIA: "7 dias grátis antes da primeira cobrança" confere — SignupController.java:163 grava `acessoAte = now().plusDays(7)` e AssinaturaService.java:153 põe o 1º vencimento em +7 dias, uma vez só por loja. Termos (termos.html:35-39) batem com a landing em preço, 15 usuários, teste de 7 dias e garantia de 7 dias; o item 3.1 dos Termos aponta de volta para o site.

PROMESSAS DE RECURSO (achei o código de cada uma): cardápio por foto pela IA (IaService.importarCardapio + POST /api/ia/importar-cardapio chamado em produtos.js:453) — está "no ar" como a página diz; comanda automática a cada pedido novo (botão 🖨️ Auto, documentado em ajuda.html:15); promoção relâmpago aberta sozinha na queda de vendas (SaudeVendasScheduler a cada 30 min chamando PromocaoService.abrirAutomatica, com guarda de 1 por dia); relatórios em planilha pelo painel (CSV em relatorios.js); balancete da rede (RedeService/RedeController); acerto do motoboy travado depois de pago (AcertoEntregadorService); conta de recebimento aberta por dentro do sistema (AsaasSubcontaService.ativar + enviarDocumento); PWA com o nome da loja (PublicController:149 /public/loja/{id}/manifest, ligado em cardapio.html:19). A trilha honesta de funcionalidades.html#construindo (iFood "funciona, ligando as primeiras lojas", 99Food "conectado, esperando o primeiro pedido", robô WhatsApp "em construção") está coerente com o que o resto da documentação do projeto registra.

CALCULADORA (index.html:421-436): refiz a conta. comissão/ano = pedidos × ticket × taxa × 12 → 1.000 × 40 × 25% × 12 = R$ 120.000, que é o que a tela mostra; economia = 120.000 − (199 × 12) = R$ 117.612, idem. A matemática está certa e os dois textos de ressalva ("Valores ilustrativos", "Você não precisa abandonar o aplicativo hoje") estão presentes.

SEO/META: as 5 páginas têm title único e descritivo, meta description, canonical correto, og:type/url/site_name/title/description/image e theme-color #9333EA. A og:image é 1200x630 (1,905:1 — a proporção certa para WhatsApp e Facebook). Um h1 por página. lang="pt-BR" e charset em todas. aria-current="page" marcando a página atual no menu. As peças animadas do hero estão com aria-hidden="true" e têm versão parada para prefers-reduced-motion.

DADOS DA EMPRESA: CNPJ 68.761.778/0001-57, razão social, cidade, telefone (15) 99860-2332 e horário "seg a sáb, 9h às 22h" estão idênticos nas 5 páginas, no rodapé, nos Termos e no número dos 12 links wa.me (5515998602332).

### Usabilidade e fluxo

Li de ponta a ponta os fluxos de entrar (login.html, cadastro.html, api.js), cadastrar produto (produtos.html, produtos.js, renomear-categoria.js), receber pedido (novo-pedido, pedidos.js, kds.js, entregas.js, pdv.js), fechar caixa (caixa.html/js) e o cliente (cardapio.html/js ate acompanhar.html), mais app.js e styles.css. A fatia esta madura: os defeitos de 26/10 (faixa de sem conexao que era engolida, cupom editado depois de aplicado, saida da tela do PIX, impressao em lote na virada do dia) estao todos fechados e eu confirmei no codigo. Sobraram 6 achados, nenhum de dinheiro errado: o maior e que o pedido de RETIRADA ficou pela metade no quadro de Pedidos enquanto a KDS ja foi corrigida, e as duas telas se contradizem. NAO li por inteiro: configuracoes.html (72 KB), rede.html, integracoes.js, relatorios.js, crm.js, estoque/insumos/contagem e acerto-entregadores -- ficaram fora porque nao estao nos fluxos que a fatia nomeia.

LOGIN/ENTRAR: login.html tem "Trocar minha senha" com senha atual obrigatoria, validacao de 8 caracteres e mensagem traduzida; o "Esqueci" nao vaza se o e-mail existe (resposta unica) e oferece o WhatsApp do suporte; se a troca de senha falhar no meio, a sessao aberta e derrubada (login.html:131-133). api.js:33-34 nao desloga em 401 de /auth/login nem de /auth/trocar-senha -- a mensagem de senha errada chega na tela. CADASTRO: cadastro.html exige o aceite dos termos (checkbox required) e manda o aceite para o servidor guardar; entra direto apos criar. SEM CONEXAO: medi os 7 pollers -- caixa.js:98, entregas.js:120, canais.js:69, entregadores.js:73-77, kds.js:115 e pedidos.js:256 relancam o erro (o defeito de 26/10 esta fechado) e dashboard.js:227-233 trata com faixa propria de id diferente, sem apagar a dos outros. Todas chamam a primeira carga com .catch(Bora._conexao). FECHAR CAIXA: caixa.js:53-54 usa boraEhVenda/boraEsperandoPix do app.js (regra unica, nao copiada) e mostra separado o PIX que ainda nao entrou, em vez de somar; agrupa por forma normalizada; impressao avisa quando o pop-up e bloqueado (caixa.js:28). NOVO PEDIDO: retirada esconde taxa e endereco e manda tipoEntrega RETIRADA (novo-pedido.js:359-361); o canal nasce num optgroup "Pedido que a loja atendeu" em vez de cair no iFood; botao Salvar desabilita contra duplo clique; quem monta o produto e vai direto no Salvar nao leva mensagem generica; bairro digitado na hora ja define a taxa. PDV: tipoEntrega RETIRADA, cliente e cashback zerados depois de cada venda, botao Finalizar reabilita certo pelo renderCart:100. QUADRO DE PEDIDOS: o motivo de cancelamento avisa em letras maiusculas que o texto vai AO CLIENTE; excluir pedido confirma dizendo que estoque e cashback voltam e que nao da para desfazer; cancelados tem aba propria; "Dia fechado" substitui o "Atualizado hh:mm" quando nao e hoje. EXCLUSOES: todas as 9 acoes destrutivas que achei tem confirm (ajustes, insumos, entregadores, cupons, clientes, usuarios, produtos, pedidos, integracoes) -- clientes.js:100-109 e cupons.js:21 sao exemplares, dizem o que se perde. CARDAPIO DO CLIENTE: loja fechada avisa e desliga o botao antes de o cliente montar o pedido; esgotado fica visivel e nao clicavel, e o "repetir pedido" tambem barra; o cupom enviado e o APLICADO, nao o texto do campo; cupom e cashback respeitam o teto de total-0,01 igual ao servidor; a tela do PIX tem saida e o aviso de "fechar nao cancela, expira em 30 min" e verdade (CobradorDePixService.java:53, 30 min configurado); a tela de sucesso tem "Voltar ao cardapio"; o link de acompanhar leva a assinatura do pedido. ACOMPANHAR: veste a cor e o nome da LOJA, nao do Bora; falha de rede nao encerra o acompanhamento; link incompleto diz o que fazer. ESTADOS VAZIOS: conferi 20 e quase todos dizem o proximo passo ("Nenhuma taxa. Adicione os bairros que voce atende", "Nenhum insumo. Cadastre os ingredientes", "Nenhum horario cadastrado -- a loja fica sempre fechada no cardapio"). MENU: BORA_NAV esconde por papel o que a API ja recusa, entao o operador nao ve Usuarios/Planos/Relatorios. TERMOS: e faixa, nao portao -- nao trava a tela.

### Telas renderizadas, contraste e celular

Abri as 36 telas .html do painel no navegador de verdade (painel-local.py na porta 8099, sessao simulada no localStorage), medi contraste do texto JA RENDERIZADO em cada uma, varri estouro de largura em 375px e 360px, e li as 349 linhas do assets/css/styles.css. O estado geral e bom: a troca para o roxo #9333EA esta correta e nenhuma tela rola de lado no celular. Sobraram 8 coisas, quase todas de contraste herdado do cinza antigo (nao da cor nova), e uma de botao desabilitado que nao parece desabilitado.

COR NOVA (#9333EA) - CONFERIDA E CORRETA. Nao existe UM hex da escala violeta antiga (#8b5cf6, #7c3aed, #6d28d9, #5b21b6, #4c1d95, #a78bfa, #c4b5fd, #ddd6fe, #ede9fe, #f5f3ff) em nenhum .html, .css ou .js do frontend - grep em todo o bora-fase-2-frontend voltou vazio. So sobraram 3 usos em rgba() (ver achados). O login renderiza --primary = #9333ea e o botao Entrar sai rgb(147,51,234) com texto branco: 5,38:1, passa folgado.

CONTRASTE DA PALETA ROXA NOVA - TODO APROVADO. Calculei a razao WCAG de cada par roxo que existe no CSS: branco sobre #9333ea = 5,38; #9333ea sobre #fff = 5,38; #9333ea sobre #faf5ff (.pay-btn.sel, .ico.ticket, .topitem .rk) = 5,02; #581c87 sobre #faf5ff (.oficial-box.passo) = 10,14; link #7e22ce sobre #faf5ff = 6,51; badge .b-pronto #6b21a8 sobre #f3e8ff = 7,39. Nenhum roxo novo reprova.

CELULAR - APROVADO EM 375px E EM 360px. Varri as 36 telas em 375px: scrollWidth = 375 em todas, zero elemento com borda direita passando da viewport (so a guia-zira, ver achados). Depois repeti em 360px nas 6 telas mais pesadas (Configuracoes, Novo Pedido, Rede, PDV, Relatorios, Cardapio) FORCANDO overflow-x:visible no html e no body, para o `overflow-x:hidden` do bloco de 560px nao esconder nada de mim: scrollWidth continuou 360 em todas. O trabalho de 23/10 (o bloco @media 560px com o seletor [style*="grid-template-columns"]) esta de pe e funcionando.

TELAS SEM NENHUM DEFEITO MEDIDO: clientes.html, usuarios.html, planos.html, ajustes.html, respostas-whatsapp.html, cardapio-qr.html, integracoes.html, rede.html, cardapio-folha.html, ROTEIRO-DE-TESTE.html.

ALARME FALSO QUE EU DERRUBEI ANTES DE REPORTAR: na tela de Relatorios o KPI de margem aparece como "R$ 0,00 · undefined%" e o de faturamento como "!". Fui atras: assets/js/relatorios.js:133 so imprime a porcentagem quando `Number(rel.faturamento)` e verdadeiro, e o backend em RelatorioService.java:167 ja trata faturamento zero (`fat.signum() == 0 ? BigDecimal.ZERO`) e devolve margemPct na linha 192. O `undefined%` vem do painel-local nao mandar o campo, nao do codigo de producao. NAO e defeito.

SESSAO E ACESSO: login.html e cadastro.html so dao para medir com o boraToken apagado - com token eles redirecionam para o dashboard, que e o comportamento certo. Medi as duas com a sessao limpa e depois restaurei.

O QUE EU NAO FIZ: nao executei os 325 itens do roteiro-de-teste passo a passo (minha fatia foi definida como tela/contraste/celular, nao o fluxo funcional); nao testei larguras entre 561px e 900px (tablet); e nao conferi o cardapio-folha impresso em papel, so na tela.

### O codigo das telas

Varri os 46 arquivos de C:/Users/user/OneDrive/Desktop/Bora/bora-fase-2-frontend/assets/js procurando erro de API engolido, PUT que apaga campo no servidor, estado que nao limpa entre duas operacoes e funcao que nao existiria num api.js velho. A fatia esta madura: dos quatro padroes, o de "funcao inexistente" nao aparece em nenhum lugar e o de "PUT apaga cadastro" esta fechado em todas as telas que ja o tiveram. Sobraram 6 achados, 2 de gravidade media (um de preco na tela diferente do cobrado no cardapio publico, um de data em UTC na tela de Desempenho) e 4 baixos. Li integralmente api.js, app.js, cores.js, whitelabel.js, produtos.js, pedidos.js, novo-pedido.js, pdv.js, cardapio.js (caminho de carrinho/cupom/cashback/checkout), estoque.js, contagem.js, insumos.js, clientes.js, configuracoes.js, ajustes.js, caixa.js, canais.js, dashboard.js, entregas.js, entregadores.js, kds.js, crm.js, promocoes.js, cupons.js, planos.js, desempenho.js, limpeza.js, balancete.js, relatorios.js, ordem-categorias.js, renomear-categoria.js, complementos-gestao.js, credenciais-plataforma.js, importar-fichas.js, importar-insumos.js, recebimento.js, onboarding.js, rede-analise.js, agente-rede.js, usuarios.js. Fiquei SEM LER por completo: qr.js, cardapio-qr.js, cardapio-impresso.js e respostas-whatsapp.js (conferi por grep que nenhum deles faz escrita na API -- nenhum `method:` de POST/PUT/PATCH/DELETE -- e por isso nao mexem em dinheiro, pedido nem acesso), os trechos de integracoes.js e cardapio.js fora dos caminhos de salvar/checkout, e mock-data.js (467 bytes, nao referenciado por nenhum HTML).

1) FUNCAO QUE PODE NAO EXISTIR NUM api.js EM CACHE: nao ha nenhuma. Extrai todas as 71 chamadas `Bora.*` dos 46 .js e dos 35 .html e cruzei com o que api.js define -- todas existem. O mesmo para os globais de app.js e cores.js (boraCanal, boraSla, boraFormaPagamento, boraEhVenda, boraEsperandoPix, boraBeep, boraToast, boraPrintComanda, BoraCores.*, __compCorpo/__compProblema/__compAviso/__compQtd): todos tem definicao. E, mais importante, o medo do `?v=` desatualizado NAO se aplica: `curl -sI https://borahapp.com.br/assets/js/api.js` devolve `Cache-Control: no-cache` com ETag, e o Content-Length 16485 bate byte a byte com o api.js local -- o navegador revalida sempre. Existem 20 arquivos com `?v=` mais velho que a ultima alteracao (app.js em ?v=20261024 mudou em 29/10, produtos.js, integracoes.js, caixa.js, canais.js e outros), e isso e inofensivo pelo mesmo motivo. Nao reportei nada disso.

2) PUT QUE APAGA CADASTRO NO SERVIDOR: fechado onde doia. produtos.js:66-78 so manda `estoque` na CRIACAO e manda `codigoExterno` sempre (de proposito, para dar como apagar); salvarEstoqueSeMudou (produtos.js:52-56) so chama o endpoint de estoque quando o numero mudou. renomear-categoria.js:74-85 e produtos.js:261-271 (corpoDeEdicao do importador) devolvem `custo` e `estoqueMinimo` crus e deixam `estoque` e `imagemUrl` FORA -- confirmei no backend por que isso importa: ProdutoService.atualizar:73-83 grava custo e estoqueMinimo sem condicao e, como ProdutoResumo.de:42 agora devolve imagemUrl como URL (`/public/loja/X/produto/Y/imagem`) e nao a foto, devolver esse campo trocaria a foto por um link para si mesma. estoque.js e contagem.js:38 usam so o endpoint /estoque. clientes.js:117-123 manda 5 campos e ClienteService.atualizar:64-76 nao toca em cashback, totalGasto, qtdPedidos, canalExterno nem idExterno. configuracoes.js:36-49 e coberto por ConfiguracaoLojaService.atualizar:46-78, que ignora null campo a campo. credenciais-plataforma.js:146-147 e integracoes.js:479-480 so mandam o segredo quando preenchido. Conferi tambem o `custo` nao-sumir: ProdutoService.listar:44 tira o custo de quem nao pode ver numero de dono, e o conjunto de papeis de `podeVerNumeroDeDono` (AuthContext:81-83) e exatamente o mesmo que `atualizar` exige -- ou seja, nao existe papel que ve o produto sem custo E consegue salvar, que seria o caminho para zerar o CMV de toda a loja.

3) ERRO DE API ENGOLIDO NAS TELAS QUE RECARREGAM SOZINHAS: as 4 telas que o comentario de api.js:215-230 denunciava em 26/10 estao corrigidas de verdade, nao so no comentario. caixa.js:97 (`throw e`), canais.js:67, entregas.js:120 e entregadores.js:74 relancam, e as quatro tem a primeira carga com `.catch(e => Bora._conexao(false, e))` (caixa.js:108, canais.js:83, entregas.js:129) ou com aviso local (entregadores.js:78). kds.js:115 e pedidos.js:256 tambem relancam; pedidos.js:324-329 devolve a promessa ao `repetir` (sem o `return` o repetir nunca veria a falha). dashboard.js:232 e a unica que engole de proposito, e esta CERTO: ela tem faixa propria com id `semConexao` (dashboard.js:83), diferente do `boraSemConexao` que o `_conexao(true)` remove, entao uma nao apaga a outra -- e ela avisa ja na primeira falha, nao na segunda.

4) ESTADO ENTRE DUAS OPERACOES: pdv.js:218-222 zera cliente e o visto do cashback DEPOIS de gravar; produtos.js:80 e insumos.js:32 zeram `fotoAtual`/`estoqueNaTela` no reset e no `__edit`; pedidos.js:84-92 troca o conjunto `conhecidos` quando o dia muda (era isso que fazia o quadro inteiro apitar e imprimir na virada); produtos.js:361 e importar-insumos.js:146 reinterpretam SEMPRE o texto da caixa antes de aplicar (era o bug da lista A/lista B); cardapio.js:666-678 desfaz o cupom quando o campo e mexido; importar-fichas.js:155 recalcula no clique; renomear-categoria.js:153-158 exige que o 2o clique seja a mesma renomeacao; ordem-categorias.js:130 avisa ao sair com ordem nao salva; acerto-entregadores.js:104 guarda o nome antes do fecharModal zerar `selecionado`.

5) DATAS: pedidos.js:33 (`hojeISO`), canais.js:55-56, entregadores.js:52 e rede-analise.js:7 corrigem o fuso com `getTimezoneOffset()` ou com getters locais, e pedidos.js:288 ancora a navegacao de dia em `T12:00:00` para a virada nao comer um dia. So desempenho.js ficou fora (achado 2).

6) OUTROS: as 3 telas de dinheiro (caixa.js:53, dashboard.js:21, canais.js:20) usam o MESMO `boraEhVenda` de app.js:93 -- a copia divergente nao voltou. promocoes.js:10 escapa a apostrofe (o XSS do onclick) e onboarding.js:100 injeta so literais do servidor (OnboardingService:70-76), nao texto da loja. O menu de app.js:126-170 bate com o `requirePapel` do backend. ajustes.js:10 (`seguro`) poe alerta em toda acao da tela. limpeza.js tem as 3 travas e esconde a secao em 403. entregas.js:19-34 pergunta antes de despachar o bairro e lista o que NAO saiu.

### Controllers e contratos da API

Li os 37 controllers e os 17 DTOs inteiros (nada ficou sem ler), cruzei os 131 endpoints com as telas do painel e com o SecurityConfig, e conferi a trava de papel de cada um no controller e no servico. A fatia esta solida: 4 achados, nenhum de gravidade alta, e nenhum que esteja tirando dinheiro ou pedido da loja hoje.

COBERTURA: li os 37 arquivos de C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java/src/main/java/br/com/bora/controller e os 17 de dto. Nada ficou sem ler. Arvore de trabalho do backend limpa (git status --porcelain bora-fase-3-backend-java sem saida), entao as linhas que cito sao as que estao no ar; https://borahapp.com.br/actuator/health/viva devolveu 200.

TRAVA DE PAPEL - 131 endpoints mapeados, cada um conferido. Esta certo:
- Os 25 endpoints de /admin-bora tem ctx.requireAdminBora() (ou requirePapel("ADMINISTRADOR_BORA") no faturamento, que da no mesmo porque requirePapel libera o admin da plataforma). Os dois que nao tem no controller (seguranca/cifragem e dados-de-teste) tem no servico: CifragemEmRepousoService e LimpezaDeTestesService, 2 requireAdminBora cada. Contei 25 chamadas no controller para 25 endpoints.
- A trava mora no servico na maioria dos casos, e eu fui ler o servico em cada um: OperacaoService (7 guardas para as 7 escritas), InsumoService (6), UsuarioService (6), IntegracaoService (6 para 6 endpoints), AsaasSubcontaService (5 para os 5 de /api/recebimento), ProdutoService (4 escritas + podeVerNumeroDeDono na leitura), RedeService (5), EntregadorService (3), AcertoEntregadorService (3 para os 3 de dinheiro de motoboy), RelatorioService, DesempenhoService, AnaliseRedeService, AssinaturaService, ConfiguracaoLojaService, CategoriaOrdemService, ClienteService.
- O GET /api/ia/rede/sinais parecia estar sem trava (o irmao dossie e o irmao analisar tem), mas NAO esta: a primeira linha de AgenteRedeService.sinais chama dossie(), e e dossie que faz o requirePapel na linha 101. Alarme falso meu, derrubado lendo o codigo.
- As aberturas de proposito estao justificadas e corretas: o GET de /api/categorias (a Frente de Caixa do balconista precisa da ordem das secoes e o retorno nao tem numero de dono), o GET de /api/clientes e o POST (o balconista precisa cadastrar cliente para vender; o DELETE exige gerente), o GET de complementos.

MULTI-TENANT - nao achei um caminho de vazamento entre lojas:
- Todo write pega a loja do token (ctx.lojaId()) e ignora qualquer lojaId do corpo. Conferi um por um em OperacaoService (salvarTaxa/salvarForma/salvarMotivo/salvarHorarios: alvo.lojaId = loja, e o findByIdAndLojaId na edicao), ProdutoService.criar (p.lojaId = ctx.lojaId(); p.id = null), EntregadorService, ClienteService, CupomController, ComplementoController, ConfiguracaoLojaService.
- O unico endpoint que aceita lojaId do cliente e GET /api/relatorios?lojaId=. Conferi: RelatorioService.lojaDoRelatorio (linhas 46-53) exige vinculo do usuario com aquela loja (existsByUsuarioIdAndLojaId) e devolve 403 sem ele. Correto.
- POST /auth/trocar-loja idem: RedeService.trocarLoja exige vinculo e recusa loja bloqueada pela plataforma antes de emitir token novo.

MASS-ASSIGNMENT (corpo que grava campo que nao devia) - conferi todos os endpoints que recebem entidade crua no @RequestBody e nenhum grava o que nao devia:
- ClienteService.criar monta Cliente NOVO e copia campo por campo; cashback, totalGasto, qtdPedidos, canalExterno e idExterno ficam fora do alcance de quem chama. ProdutoService.atualizar copia campo por campo e NAO deixa o estoque entrar (quem mexe e PUT /{id}/estoque). EntregadorService.atualizar idem. ConfiguracaoLojaService.atualizar copia campo por campo, valida aliquota 0-100, custo fixo nao negativo e cashback 0-50%, e aplica o white-label so conforme o plano.
- Segredo nao sai no JSON: Loja.asaasApiKey (linha 76) e Loja.asaasWebhookToken (linha 95) tem @JsonIgnore, e GET /admin-bora/lojas devolve a entidade Loja crua.
- Custo nao sai para quem nao pode ver: ProdutoService.listar linha 44 faz podeVerNumeroDeDono() e aplica ProdutoResumo.semCusto(). PedidoItemView nao leva custoUnitario. ProdutoResumo tambem nao leva a foto em base64.

ENDPOINT SEM TELA - cruzei os 131 endpoints com os .html e .js de bora-fase-2-frontend. Todo /api/* e todo /admin-bora/* tem tela (inclusive os que eu suspeitei: ia/rede/sinais, rede/lojas-da-empresa, usuarios/pedidos-de-senha, clientes/links-repetir, recebimento/webhook, admin-bora/empresas/{id}/arquivar em configuracoes.html:975, admin-bora/marketplace/pedido-bruto em assets/js/api.js). O unico sem tela e GET /api/health, e o proprio ROTEIRO-DE-TESTE (item 30.8) ja documenta que ele devolve 401 de proposito e que apontar monitoramento para ele e o erro - nao e achado.

ENDPOINT PUBLICO (/public/**, sem login) - li os 10 endpoints inteiros:
- POST /public/loja/{id}/pedido: o dinheiro e recalculado no servidor (cupom resolvido de novo, teto de nao zerar o pedido, cashback debitado na hora e creditado so quando o PIX entra), o estoque e baixado pelo banco e nao por conferencia antes, o freio por origem conta antes de qualquer efeito, e o Asaas fica fora da transacao de proposito (sem @Transactional no metodo).
- GET .../pedido/{id}/status e .../repetir exigem assinatura HMAC e devolvem o MESMO 404 de pedido inexistente quando o token nao bate, entao nao servem de oraculo. GET .../cashback exige telefone E nome. GET .../cupom tem freio.
- POST /public/pix-webhook/{lojaId} e POST /webhooks/{canal} autenticam por token da loja; o /webhooks compara em tempo constante. O ?token= na URL do /webhooks NAO vaza no log: o Caddyfile (bora-landing/deploy/Caddyfile, linhas 9-17) apaga t, token, hub.verify_token, telefone e nome da query antes de escrever.
- OpenDelivery confere X-App-Signature e so depois pergunta se a loja pode operar; WhatsApp confere HMAC da Meta e usa comparacao em tempo constante; AsaasWebhook recusa com 503 quando o token nem esta configurado (a porta nao abre sozinha num deploy sem a variavel).

STATUS HTTP - GET /api/assinatura devolve 204 quando a loja nunca assinou (e nao 200 com corpo vazio); AuthContext.lojaId devolve 409 com instrucao quando a sessao e da plataforma e nao tem loja; login com senha errada e login com e-mail inexistente devolvem a mesma coisa; /auth/pedido-de-senha responde sempre igual. Tudo correto.

### Os servicos que mexem em dinheiro

Li de ponta a ponta os sete pontos de dinheiro da fatia (PedidoService 1015 linhas, RelatorioService, DesempenhoService, DescontoService, FidelidadeService, EstornoDaVendaService e o balancete, que vive em RedeService.balancete + PedidoRepository.balancetePorLoja, nao existe BalanceteService), mais as pontas que eles tocam: ClienteRepository (o SQL que mexe no saldo), PedidoRepository (somaReceita/contaPedidosValidos), PublicController (checkout e webhook do PIX), CobradorDePixService, Cupom/Pedido/Loja e as telas relatorios.js e desempenho.js. Nao alterei nada e nao toquei em producao. A fatia esta em bom estado: nenhuma divisao sem RoundingMode, nenhum double carregando dinheiro de pedido, e os defeitos de arredondamento/contagem fechados em 26-28/10 continuam fechados. Achei 1 defeito de conta de lucro, 1 defeito que tira cashback do cliente num caminho especifico, e 4 itens menores/duvidas.

ARREDONDAMENTO E TIPO: rodei `grep -rn "\.divide("` em todo br/com/bora e NAO existe uma unica divisao sem RoundingMode (todas HALF_UP, escala 2 para dinheiro, 1 para percentual, 4 nos rateios intermediarios). Nenhum `double`/`float` carrega dinheiro de pedido: os unicos doubles sao Plano.precoMensal (constante 199.00), o payload do AsaasClient (converte de BigDecimal na borda) e indices estatisticos do MotorDeSinais/VendasSaudeService, que nao sao dinheiro. cliente.cashback e NOT NULL DEFAULT 0 (V8), cupom.valor e NOT NULL (V23) — conferi porque `registrarVenda` (ClienteRepository.java:64) faz `c.cashback - :usado + :credito` sem coalesce e `Cupom.desconto` multiplica `valor` sem checar nulo; com as colunas NOT NULL nenhum dos dois pode virar NULL/NPE.

SOMA QUE FECHA COM O CABECALHO: RelatorioService monta `porDia` com uma barra para CADA dia da janela e devolve `porDiaSoma` para a tela conferir (linhas 123-133, 206) — a soma das barras e igual ao faturamento por construcao. `cancelados` conta so status CANCELADO e `aguardandoPagamento` virou numero proprio (linhas 93-99): o PIX nao pago nao aparece mais como venda perdida. A janela e de dias inteiros no fuso America/Sao_Paulo nos tres servicos (RelatorioService:72-74, DesempenhoService:65-68, RedeService.balancete:118-124). O balancete da rede numa consulta (PedidoRepository:297-309) usa, linha por linha, a MESMA regra de somaReceita e contaPedidosValidos — comparei os tres JPQL.

CMV/MARGEM: custo nulo entra como zero mas e CONTADO (`itensSemCusto`, RelatorioService:148-158) e a tela avisa que a margem real e menor (relatorios.js:139-147). `custoDaFichaOuDoProduto` (PedidoService:1005-1009) distingue ficha com custo 0,00 de ficha sem custo, e `somarCustoDoAdicional` preserva o nulo. A margem do relatorio e rotulada "Margem (apos CMV)" na tela (relatorios.html:16) e o faturamento diz embaixo quanto dele e taxa do marketplace — a taxa de entrega dentro da margem e, portanto, declarada, nao escondida. No Desempenho a taxa de entrega entra como custo e o rotulo do cartao lista as seis parcelas (desempenho.js:35); conferi que custoTotal = soma das parcelas e lucro = faturamento - custoTotal.

CASHBACK CREDITADO DUAS VEZES: nao encontrei. Os quatro creditadores sao mutuamente exclusivos e guardados — checkout sem PIX credita na hora (PublicController:679), com PIX so debita o resgate (:681), o webhook credita uma vez sob `primeiraConfirmacao = p.pagoEm == null` (:863, :913-921) e o CobradorDePixService pula quem ja tem `pagoEm` (:129). Todo movimento de saldo e UMA instrucao no banco, condicional na descida (`debitarSeTiver`, `registrarVenda ... where coalesce(cashback,0) >= :usado`) e com `greatest(0, ...)` na subida — clique duplo no "confirmar" nao duplica nem deixa saldo negativo. O estorno passa por um ponto unico (EstornoDaVendaService) nos quatro caminhos de cancelamento, e `excluir` nao estorna de novo pedido ja CANCELADO (PedidoService:895-897).

RESGATE E DESCONTO: `resgatePossivel` nunca zera o pedido (sobra R$ 0,01) e o cupom/promocao incide so sobre os itens, antes da taxa de entrega (PublicController:609-650); promocao tem janela em horas, teto de usos e incremento condicional no banco (DescontoService:271-305). O desconto e sempre recalculado no servidor.

PEDIDO E ESTOQUE: o total do pedido e calculado no servidor a partir do cadastro (PedidoService:222-233); `avancarSeAindaEsta` impede dois avancos simultaneos; `exigirQueAvance` impede recuo; cancelar devolve estoque/insumo/adicional com as guardas de estagio e o `rebaixarDeNovo` espelha exatamente essas guardas (EstornoDaVendaService:257-287). Tenant: todos os sete servicos filtram por lojaId do token, e `lojaDoRelatorio` (RelatorioService:46-53) exige vinculo antes de mostrar outra loja da rede.

TAMBEM OLHEI E NAO CONSIDEREI DEFEITO: o rateio de custo fixo/mensalidade usa 30 dias como mes (DesempenhoService:45, 180-183), entao em mes de 31 dias cobra 103% do mensal — e aproximacao consciente e documentada; e o faturamento por produto usa o subtotal bruto do item enquanto o cabecalho usa o valorTotal liquido de cupom/cashback, o que e coerente com o rotulo da coluna.

### Seguranca e isolamento entre lojas

Varri a fatia inteira de segurança e isolamento (security/, os 4 webhooks e os 29 repositórios) e NÃO achei nenhuma brecha de isolamento entre lojas. O ponto número um está limpo e medido: os dois únicos UPDATE sem lojaId que existem no projeto (PedidoRepository.amarrarAoAcerto e PromocaoRepository.somarUmUso) recebem ids que já vieram de consulta filtrada por lojaId, e rastreei os dois até o chamador; os 23 findById/deleteById de controller e service, os 6 DELETE por rota e os 6 endpoints que recebem a entidade inteira no corpo todos passam por findByIdAndLojaId ou sobrescrevem lojaId com ctx.lojaId(). Os 4 webhooks falham FECHADOS (o do Asaas devolve 503 sem a variável, o da 99 e o do WhatsApp exigem HMAC, o de marketplace exige token por loja+canal, e Segredos.iguais recusa nulo contra nulo). O papel vem do banco e não do token, nenhum log imprime valor de segredo, e os tokens de webhook são UUID v4. Trago 2 achados pequenos, nenhum de dinheiro, pedido ou acesso: um `equals` que sobrou num ramo de comparação de token do webhook PIX da subconta (o ramo irmão, na linha de baixo, já usa tempo constante) e uma dúvida sobre o split das origens de CORS sem trim — essa segunda fecha demais, não abre. FICOU SEM LER: MarketplacePoller/IfoodClient de ponta a ponta, o pacote de jobs agendados, os testes e o frontend. Não escrevi nada no banco, não fiz deploy e não chamei iFood nem 99.

ISOLAMENTO MULTI-LOJA (o ponto número um) — conferi e está correto:

1) Os 29 repositórios, método por método. Rodei um laço listando toda declaração de método de cada arquivo de `repository/` e filtrando as que NÃO citam lojaId. Sobraram só 14 linhas, e cada uma eu li e rastreei até o chamador:
- `PedidoRepository.java:176-177` `amarrarAoAcerto(acertoId, ids)` — UPDATE sem lojaId. O único chamador é `AcertoEntregadorService.java:149`, e os `ids` vêm de `entregasParaAcerto(lojaId, ...)` (`PedidoRepository.java:155-165`), que filtra `p.lojaId = :lojaId`. Escopado na origem.
- `PromocaoRepository.java:28-32` `somarUmUso(id)` — UPDATE sem lojaId. Chamador único `DescontoService.java:107`, e o `promocaoId` sai de `findByLojaIdAndCodigoIgnoreCase(lojaId, cod)` (`DescontoService.java:66`). Escopado.
- As outras (findByEmail, findByCnpj, findByAsaasPaymentId, findByAsaasSubscriptionId, findFirstByCanalAndMerchantId, findByUsuarioId*, findByAtivoTrue, findByCanal, ultimoPedidoPorLoja, ativosPorLoja) são chaves globais por natureza (e-mail, CNPJ, id do Asaas, id do marketplace) ou consultas de job/plataforma.
- Os dois UPDATE restantes do PedidoRepository têm lojaId no WHERE: `desamarrarCliente` (linha 328-330) e `avancarSeAindaEsta` (linha 446-448).

2) Todo `findById`/`deleteById`/`existsById` de `controller/` e `service/` (grep completo, 23 ocorrências). Nenhuma leitura de recurso de loja sem conferência:
- `UsuarioService.buscar` (linha 136-143) confere `ctx.lojaId().equals(u.getLojaId())` antes de trocar senha, papel ou ativo.
- `PublicController.java:525-527` filtra `lojaId.equals(x.lojaId)` no produto do checkout.
- `ComplementoController.java:129` filtra `lojaId.equals(p.lojaId)`.
- `FiscalController.java:44` usa `findByIdAndLojaId`.
- `configs.findById(...)` são chaves de configuração da plataforma (`fiscal.habilitado`, credenciais de marketplace), não dados de loja.

3) Os DELETE/UPDATE por id vindos de rota. Li os seis: `OperacaoService.excluirTaxa/excluirForma/excluirMotivo` (linhas 48-50, 74-76, 139-141), `EntregadorService.excluir` (53) + `buscar` (56-58), `CupomController.excluir` (62-67), `ClienteService.excluir` (109-117), `ProdutoService.excluir` (199-215), `InsumoService.excluir` (93-128). Todos passam por `findByIdAndLojaId(id, ctx.lojaId())` antes de apagar.

4) Mass assignment de lojaId. Os endpoints que recebem a entidade inteira no corpo (`@RequestBody TaxaEntrega/FormaPagamento/MotivoCancelamento/Insumo/Produto/Cliente`) todos sobrescrevem `lojaId = ctx.lojaId()` antes de salvar: OperacaoService linhas 44, 70, 97, 136; InsumoService 63 e 164; ProdutoService 58; ClienteService 52. `ClienteService.criar` monta um Cliente NOVO campo por campo, então `cashback`/`totalGasto`/`qtdPedidos` não entram pelo corpo; `ProdutoService.atualizar` deixa `estoque` de fora de propósito (linhas 73-81).

5) Rede multi-loja (onde o isolamento poderia furar de verdade). `RedeService.trocarLoja` (89-92) exige `vinculos.existsByUsuarioIdAndLojaId`; `vincular` (243+) exige `empresas.mesmaEmpresa`; `EmpresaService.mesmaEmpresa` (80-86) devolve false quando qualquer empresaId é nulo — falha fechado. `RelatorioService.lojaDoRelatorio` (45-53), `DesempenhoService.lojasDoUsuario` (99-111) e `AgenteRedeService.minhasLojas` (112-135) só caem no `lojas.findAll()` quando `ctx.isAdminBora()`; fora disso montam a lista pelos vínculos.

6) Consultas nativas / EntityManager, que escapam da disciplina de nome do Spring Data. Só existem duas: `ClienteRepository.java:115` (tem `and loja_id = :lojaId`) e `CifragemEmRepousoService.java:119 e 144`, onde tabela e coluna vêm de uma lista fixa `ALVOS` no código (linhas 59-65), não do request — sem injeção.

WEBHOOK QUE FALHA ABERTO — conferi e está correto:
- Asaas (`AsaasWebhookController.java:47-62`): sem `ASAAS_WEBHOOK_TOKEN` configurado devolve 503 e loga erro; token errado devolve 401. Falha fechado.
- Open Delivery / 99 (`OpenDeliveryWebhookController.java:62-105` + `OpenDeliveryClient.java:592-610`): exige HMAC-SHA256 do corpo; assinatura/corpo/segredo nulos ou vazios devolvem false; compara com `MessageDigest.isEqual`; depois confere `ativo` e `regra.podeOperar(loja)`.
- WhatsApp (`WhatsAppController.java:47-66 e 145-150`): sem App Secret o robô fica calado (`return false`), e ainda amarra o evento à loja pelo `phone_number_id` (linhas 89-108).
- Marketplace genérico (`WebhookController.java:33-45` + `IntegracaoService.java:260-265`): token por loja+canal comparado com `Segredos.iguais`.
- `security/Segredos.java:42-46`: nulo nunca é igual a nada, nem a outro nulo — é o que impede integração sem segredo aceitar chamada sem segredo.

PAPEL LIDO DO BANCO, NÃO DO TOKEN — conferi e está correto: `JwtAuthFilter.java:66-67` lê `usuario.getPapel()` do registro do banco e descarta a claim `papel` do token; sem papel, `ativo = false`. Suspensão da plataforma (linhas 86-88) e vínculo com loja da rede (92-97) também são reconsultados a cada request.

TOKEN PREVISÍVEL — conferi e está correto: os tokens de webhook saem de `UUID.randomUUID()` (IntegracaoService.java:241, PixService.java:68, AsaasSubcontaService.java:255) — UUID v4, com SecureRandom. A assinatura do link público de pedido (`RepetirPedidoService.java:103-122`) é HMAC-SHA256 de `lojaId:pedidoId` com chave derivada do segredo do servidor, 96 bits, comparada em tempo constante, e avisa no log se o segredo ainda é o padrão do repositório.

SEGREDO EM LOG — conferi e está correto: `grep -rniE "log\\.(info|warn|error|debug)\\(.*(token|secret|senha|segredo|chave|password|apikey|authorization)"` devolveu 16 linhas e todas falam da AUSÊNCIA ou do estado da credencial, nunca do valor. `WhatsAppController.java:149` deixa explícito que o corpo não é logado por causa do telefone do cliente (LGPD); `AsaasWebhookController.java:112-115` loga só as CHAVES do payload, não o payload.

AUTORIZAÇÃO POR PAPEL — conferi e está correto: as 24 rotas de `/admin-bora/**` chamam `ctx.requireAdminBora()` ou `requirePapel("ADMINISTRADOR_BORA")`; as duas que não chamam no controller (`/seguranca/cifragem` GET e POST, PlataformaController.java:960 e 972) têm a trava no serviço (`CifragemEmRepousoService.java:77 e 103`), e o mesmo vale para a limpeza de dados de teste (`LimpezaDeTestesService.java:93 e 125`). `/admin-bora/**` não está na lista `permitAll` do `SecurityConfig.java:203-207`, então também exige token. `AsaasSubcontaService` (conta bancária do lojista) exige `ADMINISTRADOR_LOJA` nos cinco métodos (98, 113, 180, 315, 345). `UsuarioService.parsePapel` (125-136) recusa atribuir `ADMINISTRADOR_BORA` pela loja, e `impedirAlvoProprio` impede o admin se rebaixar/desativar sozinho. `IntegracaoService.listar` exige GERENTE+ porque a resposta carrega o token do webhook em claro (linha 147, com o motivo escrito).

OUTROS QUE PASSARAM: CORS não falha aberto (`WebConfig.java:41-48`, padrão é localhost e grita no log); `SecurityConfig` é deny-by-default (`anyRequest().authenticated()`); login tem freio por e-mail+origem (`AuthController.java:48-58`) e o "esqueci a senha" responde sempre igual (109-120); `trocar-senha` exige a senha atual; cadastro público (`SignupController.java:53-170`) não deixa entrar na empresa de outro cliente só digitando o CNPJ dele (guardas nas linhas 93, 143-148 e 151-157); `/public/loja/{id}/pedido/{id}/status` e `/repetir` exigem a assinatura `t` e devolvem o mesmo 404 para token errado e pedido inexistente.

O QUE FICOU SEM LER (para o dono saber): não li `MarketplacePoller`/`IfoodClient` de ponta a ponta (só o `assinaturaValida` e os `findById(i.id)`); não li o pacote `job/`/agendados além do que apareceu nos greps; não li os 1238 testes nem rodei suíte; não li o frontend; e não fiz nenhuma chamada autenticada ao iFood ou à 99, como manda a regra 3. Não escrevi nada no banco e não toquei em produção.

### Asaas, PIX, assinatura e corte de acesso

Li a fatia inteira de cobrança do backend — AsaasWebhookController, AssinaturaService (1123 linhas), AsaasClient, CobradorDePixService, PixService, RegraDeAcesso, BloqueioPorAssinaturaFilter, o webhook PIX do pedido em PublicController e os endpoints de cobrança de PlataformaController — e achei 4 coisas, 1 grave.

O achado que mexe em dinheiro: PAGAMENTO_MANUAL virou um passe permanente. Quem paga UMA vez fora do Asaas fica com acesso_ate NULL e acesso_motivo PAGAMENTO_MANUAL, e os três caminhos que poderiam voltar a pôr data (atraso, cancelamento da assinatura, estorno) saem antes de gravar. Isso vale HOJE, com o corte desligado, porque o ativarLoja(false) do SUBSCRIPTION_DELETED — a única porta de corte que está valendo — também é bloqueado pelo mesmo motivo.

Os outros três: podeOperar não olha loja.ativo, então assinatura cancelada no Asaas fecha o cardápio e deixa a loja online no iFood/99; um PAYMENT_CONFIRMED apaga o motivo LIBERACAO e faz a guarda da v139/26-10 perder a loja de vista no atraso seguinte; e no webhook PIX o ramo da subconta ficou sem a comparação em tempo constante que o ramo legado recebeu (baixa, com dúvida declarada).

NÃO achei pagamento contado duas vezes nem webhook que falha aberto — os dois webhooks do Asaas recusam sem token, e as quatro rotas de duplicidade que testei estão travadas. Detalhei em oQueConferiEEstaBom.

O QUE FICOU SEM LER, para você não achar que está coberto: (a) AsaasSubcontaService só das linhas 180 a 300 — as 180 primeiras, que criam a subconta e mandam os dados de KYC, não li; (b) nenhum teste do projeto foi lido nem rodado, então não medi se os testes que existem realmente provam o que o nome deles diz; (c) a fatia de frontend (telas de Planos e de Faturamento) não foi aberta; (d) não confirmei nenhum valor de variável de ambiente em produção (ASAAS_TAXA_PERCENTUAL, ASAAS_PLATFORM_WALLET_ID, BORA_COBRANCA_CORTE_POR_ASSINATURA) — não há arquivo de env no repositório e eu não toquei no servidor, então não sei se o split de 2% está de fato ligado; (e) não li o robô de WhatsApp para ver se ele também cria pedido sem passar por podeOperar, que é o vizinho natural do achado 2.

CONFERI E ESTÁ CORRETO:

1. AsaasWebhookController (194 linhas, inteiro). Falha FECHADO sem token (503 + log, :202-208) e 401 com token errado (:209-211). O id de assinatura é lido na raiz E dentro de `payment` (:248-255), e evento SUBSCRIPTION_* sem id fica no log de auditoria (:261-264). somaDosEstornos (:283-295) só soma devolução com status DONE e devolve null fora do formato. dia() usa America/Sao_Paulo (:332-342) — o fuso bate com o da guarda pagamentosDaLojaNoDia (AssinaturaService:601-605), então o par "webhook + registro manual no mesmo dia" é detectado.

2. Pagamento contado duas vezes — NÃO achei. Testei os quatro caminhos: (a) PAYMENT_CONFIRMED e PAYMENT_RECEIVED chegam para a mesma cobrança, mas registrarPagamento:639 descarta id repetido; (b) o registro manual com baixa feita grava com o id da própria cobrança do Asaas (:574-576), então o PAYMENT_RECEIVED que a baixa dispara não duplica; (c) dois registros manuais no mesmo dia e mesmo valor são recusados com 409 até o dono confirmar (:543-552), e com confirmação ganham chave própria numerada (chaveManualLivre:619-635, sem o retorno antecipado que o comentário descreve); (d) estorno parcial soma em estornado_valor (:881-884) e vira integral quando alcança o cheio (:886-892).

3. Faturamento do mês (PlataformaController:988-1065): bordas do mês e YearMonth.now() no fuso de Brasília (:1004-1012); estorno integral sai do total e vai para totalEstornado (:1032-1033); parcial desconta só o que voltou, via valorQueFicou() (:1030-1037). A base da nota fiscal está consistente com o que o webhook grava.

4. Os 8 eventos de devolução do Asaas (AssinaturaService:711-720) e a resposta diferente de cada um (:757-812): IN_PROGRESS e REFUND_DENIED não mexem em nada; CHARGEBACK_DISPUTE não reinicia carência; AWAITING_CHARGEBACK_REVERSAL devolve acesso e faturamento (:768-777). Confere com o que o javadoc promete.

5. Carência do PAYMENT_OVERDUE (:403-427): a guarda é o status de ANTES do aviso (`st != INADIMPLENTE`, :419), então reenvio do Asaas e fatura do mês seguinte não ganham 10 dias novos. Loja nova com os 7 dias de cortesia gravados entra na carência (era o item 3.5).

6. assinar() (:107-188): ATIVA/PENDENTE devolve a que existe sem tocar no Asaas; INADIMPLENTE com assinatura VIVA é recusado com 409 e o link da fatura; INDISPONIVEL recusa com 503 em vez de decidir no escuro; cria ANTES de cancelar; a cortesia de 7 dias só vale na primeira vez (:146-153, com fuso). O "teste grátis infinito" está fechado.

7. AsaasClient (249 linhas, inteiro). estadoDaAssinatura devolve três estados e NUNCA confunde erro de rede com "não existe" (:157-174) — é o que sustenta as decisões de assinar(). faturaAbertaDaAssinatura devolve null na dúvida, e só alimenta tela (:192-217).

8. CobradorDePixService (218 linhas, inteiro). Pergunta ao Asaas quais foram pagos ANTES de cancelar (:88-95), fora da transação; pedido que já saiu da espera não é cancelado, só recebe aviso na observação, e aguardandoPagamento fica de pé para a venda não entrar no caixa (:187-200); cancelado devolve estoque e cashback por uma transação explícita (:46, :213).

9. Webhook PIX do pedido (PublicController:819-930): reabre pedido cancelado quando o PIX cai depois (:869-901), rebaixa estoque uma vez só (:905-912) e reconsome o cashback em vez de dar cashback novo (:913-922); pagamento sem pedido correspondente fica no log de auditoria (:856-860). Pagamento contado duas vezes aqui está travado por `primeiraConfirmacao` (:863).

10. BloqueioPorAssinaturaFilter (73 linhas): registrado DEPOIS do JwtAuthFilter (SecurityConfig:42), não bloqueia ADMINISTRADOR_BORA, deixa /api/assinatura, /api/plano, /api/termos e /auth/ abertos para quem precisa pagar, e responde 402 — não há beco sem saída.

11. Split do PIX (PixService:171-186): só entra quando o recebimento é pela subconta do lojista, com wallet da plataforma configurada e taxa > 0; loja fundadora com splitPercentual 0 fica isenta sem gambiarra. dueDate no fuso de Brasília (:175).

12. Subconta/KYC (AsaasSubcontaService:180-298): PIX só é oferecido com asaasStatus ATIVO (PublicController:977-980); webhookOk não confia na coluna, pergunta ao Asaas (:206-220, :289-293); webhooks antigos são apagados antes de criar o novo (:230-247) e o token só é gravado depois do POST dar certo (:269-271).

13. liberarAcesso (:969-1009): motivo obrigatório, data obrigatória e no futuro, teto de 180 dias, auditoria com quem liberou — e não lança receita nenhuma. cancelarPorAdministracao (:1098-1122) não fica refém do gateway. Os dois endpoints exigem ADMINISTRADOR_BORA (PlataformaController:311, :327): o lojista não consegue se dar acesso.

### Banco e as 64 migracoes

Varri as 64 migrações (listagem completa + grep estrutural em todas: VARCHAR, NUMERIC/float, REFERENCES, UNIQUE, CREATE INDEX) e li por inteiro as 25 que tocam dinheiro, pedido e acesso, cruzando cada uma com as entidades, repositórios e serviços que as usam. Não escrevi nada, não rodei nada contra a produção e não consertei nada.

4 achados: duas constraints UNIQUE que faltam em caminho de dinheiro (taxa_entrega por bairro, e cliente por telefone / por id do marketplace — esta última é o defeito que a própria V43 descreve e não fechou no banco), uma coluna nullable que esconde pedido de senha de conta de plataforma para sempre, e duas colunas de produto sem teto em lugar nenhum (gravidade baixa).

O que NÃO li e fica para outra rodada: li apenas por grep (não por inteiro) as migrações V3 (seed), V6, V8, V9, V10, V11, V14-V16, V18, V19, V21, V22, V23, V24, V26, V27, V30-V34, V36, V38, V40, V44-V48, V51, V52, V54, V56-V59, V61 e V63 — ou seja, confirmei nelas tipo, largura, FK, UNIQUE e índice, mas não a lógica dos UPDATE de backfill. Não cobri em profundidade: cobertura de índice dos relatórios e do CMV/estoque, cupom e promoção, o JSON de `pedido_item.complementos` (V46), estorno parcial (V57) e a trava de renovação de token (V59). Nada foi medido na base de produção: toda evidência é arquivo:linha ou saída de grep local, por causa da regra de não tocar em produção.

TIPO DE DINHEIRO — rodei `grep -n -i \"double precision|real\\b|float\"` nas 64 migrações: ZERO ocorrência em definição de coluna (os 8 hits são a palavra \"real\" dentro de comentário em português). Listei todas as colunas `numeric(...)`: tudo é numeric(12,2) para dinheiro, numeric(12,4) para custo de insumo, numeric(14,3)/(14,4) para estoque e quantidade, numeric(5,2) para percentual (split, cashback, alíquota, desconto). Nenhum dinheiro em ponto flutuante.

FK SEM ON DELETE — `grep -n \"REFERENCES\" *.sql | grep -v \"ON DELETE\"` devolve só 9 linhas (V17 usuario_loja x2, V19, V20 complemento_grupo x2 + complemento_item.loja_id, V23, V32 loja.empresa_id, V4 usuario.loja_id). Conferi cada uma contra os caminhos que de fato apagam: `ProdutoService.excluir` (linhas 199-215) já apaga complemento_item, complemento_grupo e produto_insumo na ordem certa antes do produto; `InsumoService.excluir` (93-129) recusa com 409 quando o insumo está em ficha técnica ou em adicional, e a FK `fk_comp_item_insumo` da V55 é a rede embaixo; exclusão de loja é lógica (`excluida_em`, V30), não DELETE; não existe DELETE de usuário em lugar nenhum (grep por `DeleteMapping` em UsuarioController e PlataformaController devolve só `/credenciais/{canal}`); `pedido.acerto_id` e `pedido.cliente_id` não têm FK, então a ordem do `LimpezaDeTestesService` (167-170, acertos antes de pedidos) não gera 500. Não achei FK que produza 500 hoje.

LARGURA DE COLUNA vs CIFRAGEM — os 7 campos com `@Convert(SegredoGuardado)` são integracao_canal.{client_secret, webhook_token, access_token, refresh_token}, loja.asaas_api_key e config_plataforma.valor. Todos têm o teto removido: V49 passou os 5 primeiros (mais code_verifier) para `text` e V63 passou `config_plataforma.valor`. Nenhuma coluna cifrada ficou com varchar estreito. `loja.asaas_webhook_token varchar(255)` não é cifrada (não tem @Convert) — não é risco.

LARGURA DAS COLUNAS QUE RECEBEM VALOR DE FORA — li `LarguraDeColuna.java` inteiro e conferi cada constante contra a largura real nas migrações: PEDIDO_ENDERECO 500 = V53:27, PEDIDO_ID_EXTERNO 160 = V53:28, PEDIDO_FORMA_PAGAMENTO 255 = V36:4, PEDIDO_TELEFONE 60 = V35:10, PEDIDO_CODIGO 40 = V2:1, CLIENTE_ENDERECO 500 = V37:5, CLIENTE_BAIRRO 100 / PEDIDO_BAIRRO 100 = V1:2 e V48:25, CLIENTE_NOME 160 e CLIENTE_TELEFONE 40 = V1:2, CLIENTE_ID_EXTERNO 160 = V35:5, PAGAMENTO_DESCRICAO 200 / NOTA_NUMERO 40 / NOTA_URL 300 = V41:15-17, INTEGRACAO_ULTIMO_ERRO 500 = V28:25. Todas batem. Conferi também que `pedido_item.descricao` virou TEXT na V37 e `pedido.observacao` já é text.

CHAVE DE IDEMPOTÊNCIA DE PAGAMENTO — `pagamento_assinatura.asaas_payment_id varchar(60) NOT NULL UNIQUE` (V41:12) e a chave manual gerada por `AssinaturaService.chaveManualLivre` tem o formato `manual:<loja>:<data>:<n>` (~26 caracteres), que cabe nos 60 e não colide com a chave do Asaas. `registrarPagamento` (639-648) checa `existsByAsaasPaymentId` antes de gravar. O reenvio de webhook do Asaas e dois pagamentos manuais no mesmo dia estão cobertos pelo banco.

ENUM vs LARGURA DE ACESSO — `loja.acesso_motivo varchar(30)` (V60:16) contra o `MotivoDoAcesso`: o maior valor é PAGAMENTO_MANUAL, 16 caracteres. Cabe com folga.

A ORDEM DAS CATEGORIAS (V64, a migração mais nova) — li V64 e `CategoriaOrdemService` inteiros. `categoria_ordem.nome varchar(80)` bate com `produto.categoria varchar(80)`; o serviço recusa com 400 acima de 80 (TAMANHO_MAXIMO_DO_NOME, linha 97-101); a UNIQUE `(loja_id, nome)` é case-sensitive e TODAS as comparações do lado Java também são (LinkedHashSet, chaves do Map de posições, `rotulo` só faz trim) — consistente; o `repo.flush()` entre o DELETE e os INSERT (linha 107) é necessário e está lá; `ix_categoria_ordem_loja_posicao (loja_id, posicao)` serve a leitura de toda abertura do cardápio.

UMA CONFIGURAÇÃO POR LOJA (V62) — a UNIQUE `uk_configuracao_loja_loja_id` está criada e o DROP do índice duplicado `idx_configuracao_loja` é legítimo (a constraint cria o próprio btree em (loja_id)). Conferi que `configuracao_loja.subdominio` não é usado como chave de busca em lugar nenhum (grep: só gravação em `ConfiguracaoLojaService:78`), então a falta de UNIQUE/índice nele não é defeito.

ÍNDICES DO CAMINHO QUENTE — `idx_pedido_loja(loja_id, criado_em desc)` (V15:5), `idx_pedido_loja_status(loja_id, status)` (V54:46), `idx_pedido_aguardando(loja_id, criado_em) WHERE aguardando_pagamento` (V39:24), `idx_cliente_loja_telefone(loja_id, telefone)` (V29:12) casando com `findFirstByLojaIdAndTelefone` sem função em volta da coluna, `idx_cliente_externo` (V35:6), `ix_assinatura_asaas_sub` (V14:13), `ix_pagamento_assinatura_loja_pago_em` (V56:41), `ix_comp_item_insumo(loja_id, insumo_id)` (V55:31) para a recusa do excluir insumo. Os filtros reais do painel, do cardápio e do cobrador têm índice. Não achei consulta quente de pedido/dinheiro sem índice.

MULTI-TENANT — toda tabela de dado de loja tem `loja_id NOT NULL`: cliente, produto, pedido, pedido_item, log_status, configuracao_loja (V1/V2/V7), taxa_entrega, forma_pagamento, horario_funcionamento, motivo_cancelamento (V12), insumo, produto_insumo (V13), assinatura (V14), complemento_grupo, complemento_item (V20), cupom (V23), acerto_entregador (V25), pagamento_assinatura (V41), categoria_ordem (V64). A única nullable que achei é `pedido_de_senha.loja_id`, e é o achado 3.

MIGRAÇÃO QUE TRAVA ESCRITA — as que mexem em tabela existente com DDL sensível declaram `set lock_timeout = '5s'` (V49:23, V53:25, V54, V56) e os `alter column ... type text` são mudança de catálogo, não reescrita. Não encontrei migração que trave escrita de forma que importe no volume de hoje, e por isso não reporto nada aqui.

### iFood, 99 e OpenDelivery

Cinco achados, todos medidos em arquivo:linha ou em saida de comando. O mais grave e um acidente de anotacao: no PedidoRepository o @Modifying que pertencia ao UPDATE marcarAceiteEnviado ficou colado no SELECT semAceiteConfirmado, inserido entre a anotacao e o metodo no commit de 27/10. Medi com javap nos jars do projeto (spring-data-jpa 3.3.1 e hibernate-core 6.5.2) que um @Query de update sem @Modifying cai em SingleEntityExecution -> Query.getSingleResult() -> doList() -> verifySelect(), que estoura. Consequencia: o aceite nunca fica marcado, o evento nunca e confirmado no canal, e o poller reenvia "confirmo" ao iFood/99 a cada 30 segundos -- o mesmo "confirm em dobro" que o codigo diz ter custado o primeiro pedido real, agora em laco. Nenhum teste cobre isso: os dois que citam o metodo usam mock. O segundo e o cancelamento que o cliente pede na 99: o acceptCancellation falha em silencio (o boolean do post e descartado) e o pedido e cancelado so aqui, com o evento confirmado -- cancelado no Bora, ativo na 99. Os outros tres: cancelamento do painel que nao sai quando a integracao esta em ERRO ou desligada, sem aviso nenhum; o "Confirmar" do painel que nao manda nada ao canal quando o aceite automatico esta ligado e tira o pedido da retentativa; e o webhook generico /webhooks/{canal} sem as guardas de canal desligado e loja suspensa que o endpoint da 99 ganhou em 27/10 (baixa, pode ser decisao). Nao toquei em producao, nao fiz nenhuma chamada autenticada e nao consertei nada. Ficou sem ler: o OAuth/renovacao de token dos dois clientes, o mapeamento de itens e precos do normalizador, validarCodigoDeEntrega/avisarQueFechou, a tela de Integracoes e os 20 testes de marketplace.

CONFERIDO E ESTA CORRETO (tudo por leitura de codigo e javap; nenhuma chamada autenticada ao iFood ou a 99, nenhuma escrita em banco, nenhum deploy):

1. PEDIDO QUE ENTRA DUAS VEZES -- esta protegido em tres camadas e nao achei furo. (a) MarketplacePoller.criarPedido:349-355 retorna cedo quando pedidos.buscarExterno acha o pedido, ANTES do contador (379-381) e do aceite (385-387); (b) PedidoService.criarExterno:326-330 refaz a checagem por in.externalId(); (c) o banco tem indice unico parcial uq_pedido_canal_externo em pedido(loja_id, canal_externo, id_externo) (V28__marketplace_oauth.sql:28-30), que torna o insert duplicado impossivel mesmo com o poller e o webhook rodando ao mesmo tempo. Conferi tambem que a chave usada na deduplicacao e a MESMA que e gravada: para o iFood o normalizador usa firstNonBlank(id, externalId) (MarketplaceNormalizer:124) e para a 99 usa str(r.get("id")) (:391), os dois casando com client.pedidoDoEvento(ev); o firstNonBlank(externalId, id) da linha 420 e so do canal generico (AiQFome/Goomer/testes).

2. PEDIDO QUE SE PERDE EM FALHA TRANSITORIA -- correto. processar:249-258 so poe o evento em paraConfirmar depois de tratarEvento devolver sem excecao, e criarPedido:359-361 TRANSFORMA detalhe vazio em excecao (`o detalhe do pedido X veio vazio`) em vez de sair calado. O acknowledge de cada cliente nao relanca (IfoodClient:510-513, OpenDeliveryClient:352-355), o que esta certo: ack perdido so faz o evento voltar.

3. INTEGRACAO DESLIGADA QUE AINDA RECEBE, pelo caminho oficial -- correto. MarketplacePoller.conectadas:112-141 parte de repo.findByAtivoTrue(), exige prontaParaSincronizar() ou mereceNovaTentativa(), e AINDA confere regra.podeOperar(loja) (133-137), que e o que protege loja suspensa/arquivada/vencida. O webhook /v1/newEvent da 99 confere as duas coisas (OpenDeliveryWebhookController:88-103). A decisao de o /v1/trackingEvent NAO conferir (linhas 163-165) esta documentada e me parece certa: ele so fecha pedido que ja entrou.

4. A INTEGRACAO QUE SE LEVANTA SOZINHA -- correto, e eu fui conferir porque o comentario podia estar mentindo. IfoodClient:479-486 e OpenDeliveryClient:272-276 mudam o status em memoria para CONECTADO e chamam marcarPollingOk; o UPDATE de marcarPollingOk (IntegracaoCanalRepository:47-50) realmente leva `i.status = case when i.status = 'ERRO' then 'CONECTADO' else i.status end`, entao a volta grava no banco e nao se perde (era o risco, ja que os repo.save(i) foram tirados no item 5.5).

5. ESCRITA QUE NAO ATROPELA O LOJISTA -- correto. Todos os pontos quentes usam UPDATE direcionado em vez de save da entidade: contarPedidoRecebido (:173-181), marcarAviso (:86-93), marcarImpedimento (:118-124), marcarPollingFalhou (:56-63). A separacao ultimo_erro (saude, apagada pelo polling bom) x ultimo_aviso (recado de pedido, so o lojista apaga pelo marcarAvisoComoLido) esta coerente nos dois lados.

6. ASSINATURA DO WEBHOOK DA 99 -- correta. OpenDeliveryClient.assinaturaValida:592-609 recusa assinatura ou corpo nulos, recusa segredo vazio, aceita hex e base64 (com e sem "sha256=") e compara com MessageDigest.isEqual, que e tempo constante. O /v1/trackingEvent tambem valida (controller:143-146).

7. ANOTAR O IMPEDIMENTO -- correto e, melhor, mais enxuto do que eu esperava. MarketplacePoller.anotarImpedimento:156-186 escreve so quando falta o merchantId e so quando o texto MUDA, o que evita uma escrita por integracao a cada 30 segundos.

8. MULTI-TENANT no meu escopo -- correto. Toda consulta do caminho do marketplace leva lojaId junto (buscarExterno, semAceiteConfirmado, marcarAceiteEnviado, os quatro UPDATEs do IntegracaoCanalRepository). IntegracaoService.salvar:218-222 impede duas lojas do Bora com o mesmo merchantId no mesmo canal, que e o que protege o findFirstByCanalAndMerchantId usado pelo webhook. MarketplaceDiagnosticoController exige requireAdminBora e loga quem consultou (:45-52).

O QUE FICOU SEM LER (para o dono saber o tamanho do buraco): o OAuth/renovacao de token dos dois clientes (IfoodClient:160-440 e OpenDeliveryClient:150-260, incluindo o arrendamento token_renovando_em), CredenciaisMarketplace e MarketplaceHttp, o mapeamento de itens/precos/pagamento do MarketplaceNormalizer (so olhei os campos de id), validarCodigoDeEntrega e avisarQueFechou da 99, a tela de Integracoes do frontend e os 20 testes de marketplace (abri so o AceiteQueFalhaNaoSePerdeTest, para ver que ele usa mock).

### Estoque, insumo e ficha tecnica

Fatia Estoque/insumo/ficha tecnica, lida em C:/Users/user/OneDrive/Desktop/Bora/bora-fase-3-backend-java. Li por inteiro InsumoService, InsumoRepository, ProdutoService, ProdutoRepository (trechos de estoque), EstornoDaVendaService, os dois caminhos de baixa do PedidoService (balcao e marketplace), o checkout do PublicController, o cancelamento do CobradorDePixService, o LimpezaDeTestesService e as migracoes V13/V45/V55. Achei 1 defeito grave de ponta a ponta (PIX que expira e e pago depois: o rebaixarDeNovo NUNCA baixa, e o cancelamento seguinte devolve estoque em dobro), 2 medios e 1 duvida de defesa. NAO reportei o que ja esta fechado (guarda de quantidade negativa na ficha, ficha fantasma, aviso de saldo negativo na venda, baixa atomica no banco, DEFINIR/AJUSTAR fora do cadastro): conferi e esta tudo de pe. FICOU SEM LER: RelatorioService (o CMV/margem que le o custo do insumo), AgenteRedeService, o ComplementoController (gravacao do insumo do adicional), o MarketplacePoller inteiro e o editor de ficha dentro de produtos.html (li so os atributos dos campos).

1) Baixa atomica: toda baixa e devolucao de insumo e de produto passa por UPDATE no banco com clausula, nunca por ler-subtrair-gravar (InsumoRepository.java:18-82, ProdutoRepository.java:40-90). consumirSeTiver com estoque NULL casa a linha e devolve 1, entao 0 quer dizer uma coisa so: controla e nao tem. Conferido linha por linha.
2) Simetria consumo/devolucao da ficha: consumirFicha (InsumoService.java:400-487) e devolverFicha (:562-577) usam a mesma ficha, a mesma conta e a mesma guarda de quantidade <= 0; devolverFicha usa mexerNoEstoque (nunca recusa) e nao somarAoEstoque (que recusaria) - esta certo, devolucao de cancelamento nao pode ser recusada.
3) Quantidade negativa na ficha: recusada na gravacao (quantidadeDaFicha, InsumoService.java:194-210) E pulada no consumo e na devolucao (:436 e :573). As duas pontas estao cobertas.
4) Ficha fantasma: o excluir recusa apagar insumo que esta em ficha ou em adicional, com a lista dos produtos (InsumoService.java:93-129); o consumo pula a linha fantasma, conta os fantasmas, loga, e se NENHUM insumo sobrou devolve null para o item se comportar como produto sem ficha (:451-485). A V55 ainda poe FK em complemento_item.insumo_id. ProdutoService.excluir apaga a ficha junto (ProdutoService.java:212), entao nao sobra linha orfa pelo lado do produto.
5) Saldo negativo na VENDA tem aviso nos tres caminhos, no mesmo logger AUDITORIA (produto, ficha e adicional: InsumoService.java:337 e :518, PedidoService.avisarSeVaiFicarNegativo).
6) Estoque fora do cadastro: nem ProdutoService.atualizar (:73-81) nem InsumoService.salvar (:68) gravam estoque na edicao; quem mexe e o endpoint proprio. O apagamento de consumo por formulario velho esta impossivel, nao so improvavel.
7) Baixa dupla nos caminhos que verifiquei: criarExterno e idempotente por idExterno (PedidoService.java:326-330); cancelarPorMarketplace recusa pedido ja CANCELADO/ENTREGUE (:514); alterarStatus toma o avanco com avancarSeAindaEsta no banco (:711); excluir pedido nao estorna de novo quando ja estava CANCELADO (:895); a limpeza de testes pula pedido CANCELADO (LimpezaDeTestesService.java:153-156). Nenhum destes baixa nem devolve duas vezes.
8) Transacao no checkout publico: o laco de itens que consome ficha e adicional com exigirEstoque=true roda dentro do tx.execute do Passo 1 (PublicController.java:384-409 e 519-608), entao a recusa no 3o item desfaz o consumo dos 2 primeiros. O @Transactional foi tirado do metodo de proposito e a transacao que importa continua existindo - conferi, nao e regressao.
9) Multi-tenant: todo acesso a insumo e a ficha usa findByIdAndLojaId / findByLojaIdAnd... com o lojaId do token; salvarFicha confere a posse do produto e ignora insumo de outra loja (InsumoService.java:157-162). Listar, ficha e salvar exigem GERENTE/ADMINISTRADOR_LOJA.
10) Quantidade zero na ficha continua valendo como rascunho e nao recusa mais venda (a guarda de :436 espelha o fichaDaParaFazer de :546) - conferi que as duas condicoes sao iguais.
11) Adicional com quantidade nula/zero/negativa nao consome nem entra no custo: consomeInsumo() exige signum() > 0 (ComplementoService.java:53). O que foi consumido vai gravado NO ITEM e a devolucao le dali, nao do cadastro de hoje (EstornoDaVendaService.java:162).

### Docker, Caddy, deploy, backup e vigia

Li o Caddyfile, deploy-api.sh, deploy-frontend.sh, backup-bora.sh, conferir-dump.sh, ensaio-de-restauracao.sh, vigia-bora.sh, servidor/crontab.txt, LEIAME.md e o Dockerfile do backend, e sondei o site publico com curl (so leitura: GET/HEAD anonimos, nenhuma chamada autenticada, nenhum ssh, nenhum deploy, nenhuma escrita). 6 achados medidos. O mais sujo: o Caddy esta servindo o diretorio .git do painel (/.git/config, /.git/index, /.git/logs/HEAD e objetos baixam com 200), e isso e sintoma de uma coisa maior -- o deploy-frontend.sh confere num sentido so e nunca ve o que SOBRA no servidor (/README.md e /.gitignore estao no ar hoje, e o proprio script os exclui de proposito da lista). O que mexe em dados: backup (4x/dia) e ensaio semanal escrevem "precisa de mao humana AGORA" num log que nada le -- o vigia, o unico que roda de 5 em 5 minutos, nunca abre esses logs nem olha a idade do dump mais novo. NAO LI (ficou de fora): ligar-cifragem.sh, copiar-backup-bora.ps1, LIGAR-BACKUP-S3.md, servidor/LEIAME.md, docker-compose.yml, a configuracao Java do actuator/Spring Security, e nao verifiquei nada por ssh no servidor (os containers de pe, o crontab real, as permissoes dos arquivos em /home/ubuntu/backups).

CADDY / SUPERFICIE PUBLICA (medido com curl em 29/10, https://borahapp.com.br):
- Actuator sensivel esta FECHADO: /actuator/env, /beans, /metrics, /loggers, /heapdump, /configprops, /threaddump, /mappings todos 401. /actuator (indice) 404. So /actuator/health e /actuator/health/viva abrem, e o corpo nao vaza nada: `{"status":"UP","groups":["viva"]}` -- sem o bloco `components`, entao nem o host do banco aparece.
- /v3/api-docs e /swagger-ui/index.html dao 404 publicamente, apesar de estarem no matcher @api do Caddyfile:25.
- Os 6 cabecalhos de seguranca do Caddyfile:43-49 CHEGAM, tanto no estatico quanto na API: Strict-Transport-Security max-age=31536000 includeSubDomains, X-Content-Type-Options nosniff, X-Frame-Options SAMEORIGIN, Referrer-Policy strict-origin-when-cross-origin e a CSP inteira. O `-Server` funciona: nao ha cabecalho Server em nenhuma das duas respostas. (O `header` esta fora dos blocos handle e, pela ordem de diretivas do Caddy, vale para o site todo -- confirmado na resposta de /actuator/health, que e proxy.)
- Os 3 .bak que existem na arvore do frontend (assets/js/cardapio.js.bak-20261001, planos.js.bak-20261002, usuarios.js.bak-20261002) NAO estao no ar: 404 nos tres. A exclusao `grep -vE '\.bak'` do deploy-frontend.sh:67 segura o que e novo.
- /testes/, /dev/, /docs/, /package.json, /backups/, /nginx.conf, /Caddyfile, /api.env, /bora/api.env, /.env: todos 404.
- ACESSO fechado: /admin-bora/lojas, /admin-bora/marketplace, /api/pedidos, /api/relatorios/vendas -> 401 sem token. /auth/login -> 405 em GET (so aceita POST).
- O matcher @api cobre TUDO: extrai os 34 caminhos de @RequestMapping do backend e todos caem em /api/*, /auth, /public/*, /admin-bora/* ou /webhooks. Nenhum endpoint escapa para o file_server e morre em 404 silencioso.

DOCKERFILE (bora-fase-3-backend-java/Dockerfile):
- Multi-stage com cache de dependencia (pom.xml antes do src), runtime em 21-jre, non-root de verdade (`USER 1001` depois do useradd).
- Os testes rodam DENTRO do build: `RUN mvn -q package` sem -DskipTests (linha 11). Imagem nao nasce com teste vermelho.
- JAVA_TOOL_OPTIONS com user.timezone=America/Sao_Paulo, MaxRAMPercentage=60 e ExitOnOutOfMemoryError (linha 30).
- O HEALTHCHECK da linha 34 esta correto e eu conferi a pegadinha: `curl -fs ... | grep -q UP` -- com `-f` um 503 nao devolve corpo, entao o grep NAO pode passar com o health DOWN. Mesma coisa no passo 9/9 do deploy-api.sh:152.

BACKUP / RESTAURACAO:
- conferir-dump.sh usa as duas conferencias certas: `pg_restore -f /dev/null` (le todos os blocos de dados, pega truncamento) mais contagem minima de entradas (pega dump vazio e bem formado). O que o comentario afirma sobre `--list` nao pegar corte bate com o que o codigo faz: o `--list` so e usado para CONTAR, nunca para validar integridade.
- backup-bora.sh nomeia o arquivo antes (linha 30) em vez de descobrir com `ls -t` depois, e so anuncia "backup ok" DEPOIS que o conferir-dump passa (linha 47-54). Dump reprovado vira .RUIM e o script sai 1.
- ensaio-de-restauracao.sh: `trap limpar EXIT` com `docker rm -f -v` (linha 34) -- mata o volume anonimo, que era o vazamento de 53 MB/semana. Senha local descartavel, nenhuma credencial de producao, porta 0 (nao disputa porta). Conta loja/usuario/produto/pedido e exige o historico do Flyway.
- O `max(version::int)` do ensaio (linha 101) funciona hoje: listei os arquivos de db/migration e as 64 versoes sao todas inteiras, nenhuma V64_1.

DEPLOY DA API (deploy-api.sh):
- Aborta com arvore suja (linha 37), testa a subida contra banco inexistente exigindo que a unica causa raiz seja Connection refused (linha 60-66), compara a ULTIMA camada local vs remota para provar que a imagem chegou igual (linha 76-78), faz backup antes de trocar (linha 82), guarda o container antigo com rename em vez de rm -f (linha 122), e o rollback e funcao unica usada nos dois pontos de falha e CONFIRMA a saude depois de rollbackar em vez de anunciar sucesso no escuro (linha 103-112). O diagnostico 9.7 (separar "codigo ruim" de "RDS fora") esta implementado de fato na linha 137-148.

PORTAO DOS TERMOS: conferi as tres pontas e hoje elas batem -- TermosService.java:52 `VERSAO_VIGENTE = "2026-10-04"`, bora-landing/termos.html "4 de outubro de 2026", e a pagina NO AR (curl https://borahapp.com.br/termos.html, 200) tambem "4 de outubro de 2026". Nao ha divergencia de aceite em producao agora.

VIGIA: as tres coisas que ele ganhou em 27/10 estao implementadas e nao sao so comentario -- batida em arquivo fora de /tmp com aviso de ausencia acima de 15 min (linha 83-91), disco com teto duplo 85%/5 GB e ruido limitado a cada 2 h (linha 94-118), certificado 1x/dia com limite de 20 dias (linha 120-134). E ele pergunta ao grupo `viva` antes de reiniciar, e NAO reinicia quando o processo esta vivo e o health cheio esta fora (linha 148-165) -- a correcao do 9.7 esta no codigo.

### Consultas, N+1 e custo

Varri a fatia "consultas, N+1 e custo" do backend Java. O projeto está bem defendido nesse eixo: as entidades não têm relação JPA nenhuma (zero @ManyToOne/@OneToMany em src/main/java/br/com/bora/entity), então N+1 por lazy loading não existe; o quadro de pedidos (PedidoService.board) resolve pedidos+clientes+itens em 4 consultas com comentário explícito contra N+1; a V56 é uma auditoria de índices feita medindo a produção; o checkout público e o cobrador de PIX já tiraram a chamada externa de dentro da transação. Achei 4 coisas, 2 delas na tela mais aberta que existe (o cardápio público): ela lê ~600 kB de base64 de foto do Postgres em cada abertura e joga fora, e faz 1 consulta por produto só para marcar "esgotado". As outras 2 são a chamada HTTP ao Asaas ainda dentro de @Transactional na assinatura, e as 6 contagens do dashboard a cada 8 s. NAO FICOU SEM LER, mas também não medi a fundo: RelatorioController/FiscalController (relatórios sob demanda), AgenteRedeService e AnaliseRedeService (telas de rede, consulta por loja em laço — bounded pelas 22 lojas, não medi o tempo), IntegracaoService, WhatsAppController, OpenDeliveryWebhookController, e as consultas @Query do PedidoRepository uma a uma (li os índices e os nomes dos métodos, não cada plano). Não rodei EXPLAIN: não toquei no banco, só no site público com curl.

1) N+1 por lazy loading NAO EXISTE: `grep -rn "@(ManyToOne|OneToMany|OneToOne|ManyToMany|ElementCollection)" src/main/java/br/com/bora/entity` devolve zero. As entidades são planas, com id solto.
2) O quadro de pedidos (PedidoService.java:127-190), que é o que 5 telas do painel recarregam sozinhas, está certo: 4 consultas fixas (pedidos do dia, abertos de outros dias, `clientes.findByLojaIdAndIdIn`, `itemRepo.findByLojaIdAndPedidoIdIn`), sem consulta dentro de laço. Todas as 4 casam com índice existente (idx_pedido_loja, idx_pedido_loja_status, idx_cliente_loja, idx_pedido_item_pedido).
3) ABERTOS é lista positiva de propósito (PedidoService.java:110) em vez de `status not in`, justamente para o índice servir. Confirmado no código, não só no comentário.
4) Payload do painel: `GET /api/produtos` devolve a projeção ProdutoResumo (ProdutoService.java:40-53 + ProdutoRepository.java:146-151), que nem toca na coluna da foto. Esse conserto está feito e funcionando.
5) Compressão na borda: pedi o cardápio da loja 18 com `curl --compressed` — volta `Content-Encoding: zstd`, 40.932 bytes crus viram 4.471 bytes no fio. O payload de 40 kB NAO é problema de rede. (Cheguei a suspeitar e medi antes de reportar.)
6) Cache das fotos de produto: `/public/loja/18/produto/60/imagem` responde `Cache-Control: public, max-age=600` + `Etag: "62da57e4"` + `X-Content-Type-Options: nosniff`. Está certo.
7) Chamada externa dentro de transação NO CHECKOUT: consertado de verdade. `PublicController.pedirOnline` (linha 384) não tem @Transactional no método; a transação é só o `tx.execute` do passo 1. Conferi no código, não no comentário.
8) Mesma coisa no cobrador de PIX (CobradorDePixService.java:73-115): o `pix.cobrancaFoiPaga` e o `pix.cancelarCobranca` rodam fora do `tx.execute`. Correto.
9) Mesma coisa no IaService: `recuperarClientes` (linha 99) e `importarCardapio` (linha 187) não são mais @Transactional, e o `importarCardapio` usa `TempoLimite.clienteDeIa()` (60 s) justamente por rodar fora de transação.
10) Pool do Hikari está dimensionado e escrito: application.yml:34 `maximum-pool-size: 20`, `connection-timeout: 10000`, `leak-detection-threshold: 20000`.
11) Timeout em TODO cliente HTTP: TempoLimite.java define connect 4 s / read 10 s (60 s só para IA) e o AsaasClient o usa no construtor (linha 25). Nenhum RestClient sem timeout.
12) Índices das consultas que me preocupavam, todas cobertas: `usuario.findByEmail` → V4 tem `email VARCHAR(180) NOT NULL UNIQUE` (o login não faz seq scan); `pagamento_assinatura.existsByAsaasPaymentId` (dedup do webhook de dinheiro) → V41 linha 12 `asaas_payment_id varchar(60) NOT NULL UNIQUE`; `findByAsaasSubscriptionId` → ix_assinatura_asaas_sub; `empresa.findByCnpj` → uq_empresa_cnpj; `usuario_loja.findByUsuarioId` → PRIMARY KEY (usuario_id, loja_id); `findByAguardandoPagamentoTrueAndCriadoEmBefore` → idx_pedido_aguardando, parcial em `where aguardando_pagamento = true`.
13) Rodei um detector de consulta-dentro-de-laço sobre os 188 arquivos .java (script próprio, em C:/Users/user/AppData/Local/Temp/claude/C--Users-user-OneDrive-Desktop-Bora/7baa071c-be99-425b-b6de-3dd423c94538/scratchpad/n2.py). Os laços que ele apontou em AcertoEntregadorService, AgenteRedeService, CategoriaOrdemService, RepetirPedidoService e IaService:112 são falso positivo: o `for (Object[] r : repo.consulta(...))` é UMA consulta agregada por laço, não uma por item. Conferi cada um.
14) `GET /public/loja/{id}/pedido/{id}/status`, que a tela do cliente pede a cada 5 s, faz 3 consultas por id e nada mais (PublicController.java:794-816).
15) VendasSaudeService.termometro (linha 43) faz 1 + SEMANAS_BASE consultas de soma, número fixo e pequeno. Não é N+1.
16) Subdomínio: `configuracao_loja.subdominio` não tem índice, e não precisa — nenhuma consulta filtra por ele (grep em todo src/main/java: só gravação, em ConfiguracaoLojaService.java:78).

### A qualidade dos proprios testes

Fatia: qualidade dos proprios testes (backend src/test e frontend testes/). Rodei a suite do frontend: 632 passam, 0 falham, 0 skipped, 0 todo (`node --test` em bora-fase-2-frontend/testes, 7,9s). Nao rodei a suite do backend nem IT nenhum (sem Postgres de teste e para nao estourar o tempo).

O que achei NAO foi "assert frouxo" espalhado — a qualidade do que existe e alta (ver oQueConferiEEstaBom). O buraco e de COBERTURA: cruzei os 188 arquivos de src/main com src/test por nome de classe e os 47 .js do painel com testes/, e os caminhos de ACESSO (criar usuario, trocar papel, redefinir senha, login) e um de DINHEIRO (percentual de cashback e aliquota) nao tem teste nenhum em nenhuma das duas camadas. Sao 5 achados medidos, mais 1 duvida.

O QUE FICOU SEM LER (nao presuma que esta bom): nao li os 59 arquivos .test.mjs um a um (li o harness inteiro e ~12 testes); nao li os 30 testes do backend que leem fonte de producao como texto um a um; nao li o pacote service/marketplace em profundidade; nao rodei `mvn test` nem nenhum IT; nao medi mutante nenhum (seria a prova forte de "mede alguma coisa", e nao deu tempo).

1. HARNESS DO FRONTEND (bora-fase-2-frontend/testes/harness.mjs, lido inteiro, 1-150): carrega o arquivo que vai para producao dentro de `vm.Context`, nao uma copia. Os dubles de DOM estao honestos: `__ouvintes`+`__disparar` deixam o teste disparar o `submit` de verdade em vez de chamar funcao interna; `comSeletores` existe porque sem querySelector real o teste parava ANTES de mexer na tela e lia o valor inicial do duble (teste verde medindo nada — ja aconteceu com entrega/retirada). Os helpers de dinheiro (`boraEhVenda`, `boraFormaPagamento`) vem do app.js de verdade, nao de stub.
2. RISCO QUE EU PROCUREI E NAO ACHEI: o `elemento()` do harness tem `classList.contains: () => false`, `getAttribute: () => null` e `hasAttribute: () => false` — qualquer assert sobre eles seria sempre-verdadeiro. Grep em *.test.mjs: ZERO testes usam classList.contains, getAttribute ou hasAttribute. Nenhum assert vacuo por esse caminho.
3. `semComentarios` (harness.mjs:112-150): existe porque em 2 dias tres testes acusaram o proprio comentario do autor; a versao atual nao acompanha estado de texto (a anterior era enganada por `/[&<>"]/g`) e o limite esta escrito. Ferramenta correta.
4. DUBLE DE SALDO (src/test/.../service/SaldoEmMemoria.java): conferi linha por linha contra as 4 @Query reais de ClienteRepository.java:62-116 (registrarVenda, debitarSeTiver, creditar, desfazerVenda). A aritmetica bate, inclusive a clausula `coalesce(cashback,0) >= :usado` que recusa gastar o que nao tem e o `greatest(0,...)` do desfazerVenda. A unica divergencia e o coalesce no lado do SET (o duble coalesce null->0, o SQL nao) e ela NAO pode acontecer: V8__crm_e_roteirizacao.sql:4 cria `cashback NUMERIC(12,2) NOT NULL DEFAULT 0`. Duble fiel.
5. CENARIO QUE NAO EXISTE EM PRODUCAO: procurei testes que poem cashback/totalGasto/qtdPedidos em null (seria cenario impossivel pelo NOT NULL da V8). ZERO ocorrencias em src/test e em src/main.
6. ASSERT FROUXO SOBRE DINHEIRO: procurei o padrao classico (`assertTrue(valor.signum() > 0)` / `compareTo(ZERO) > 0` como unico assert de valor). ZERO ocorrencias. Os testes de dinheiro que li (OpixABANDONADOnaoCOBRAcustoTest, OsplitDizAverdadeTest, EstornoCortaOAcessoTest, SaldoQueMudouRecusaOpedidoTest) comparam BigDecimal exato com `compareTo(...) == 0` e ainda fecham a conta (custoTotal = soma das partes).
7. TESTE SEM ASSERT NENHUM: varri os 165 arquivos de src/test contando assert/verify/fail por metodo @Test. ZERO metodos sem assert. Os 90 metodos cujo unico assert e assertNull/assertNotNull/assertDoesNotThrow eu revisei pela lista: em quase todos o valor esperado E null (ex.: `semCUSTOemLUGARnenhumFICAnulo_eNAOzero`, `enderecoVAZIOcontinuaVirandoNULO`), o que e assert legitimo. So um merece nota (achado 5).
8. FILTRO DE AUTENTICACAO: RebaixarTiraOPoderNaHoraTest cobre 13 cenarios do caminho de sessao contra banco (rebaixado, promovido, demitido, desativado, apagado, sem papel, loja suspensa, sem vinculo, token de outra chave, sem token) e RegraDeAcessoTest tranca as duas pontas do corte por assinatura, inclusive o interruptor desligado por padrao. Essa parte do acesso esta bem medida — o buraco e o AuthController e o UsuarioService (achados 1 e 2).
9. PedidoController.java:24-70 — eu ia reportar como "controller de pedido sem teste", mas li: e delegacao pura (toda linha e `return service.x(...)`), sem regra propria. Nao e defeito.
10. Suite do frontend executada de verdade: 632/632 passam, nada skipped e nada em todo — ninguem desligou teste para fechar a conta. estatico.test.mjs e js-compila.test.mjs enumeram a pasta com readdirSync, entao arquivo .js novo entra na checagem de compilacao e de requireAuth automaticamente (nao ha lista para esquecer de atualizar).

### O processo de negocio ponta a ponta

Varri o caminho do dinheiro do processo: pedido (cardápio/PDV/entregas) → status → acerto do motoboy → fechamento de caixa → relatório, mais o gatilho automático de promoção. 5 achados medidos, todos com arquivo:linha. Os dois mais graves estão na mesma tela (Acerto Motoboy): ela soma a venda de balcão inteira numa linha de "dinheiro fora da conta", e o sistema não tem em lugar nenhum quanto a loja paga por entrega — ele assume que é a taxa que o cliente pagou, que nas lojas sem taxa por bairro é zero. O terceiro é uma decisão que o sistema toma sozinho: um job de 30 min abre 15% de desconto em qualquer loja em queda, sem avisar, sem flag para desligar e sem guarda de margem. NÃO LI (fica para outra rodada): cupom/cashback/fidelidade ponta a ponta, poller do marketplace, cobrança Asaas/assinatura, nota fiscal, estoque e insumos, onboarding e WhatsApp. Não toquei em produção: nenhuma escrita, nenhuma chamada a iFood/99, nenhum deploy.

ACERTO DO MOTOBOY — conferido e certo: prévia e pagamento usam a MESMA chave normalizada `lower(trim(entregador))` (PedidoRepository.java:134-165), então a tela não mostra um valor e o sistema paga outro; `amarrarAoAcerto` é UPDATE condicional (`where acertoId is null`, PedidoRepository.java:176) e o serviço devolve 409 se amarrou menos linhas — não dá para pagar a mesma corrida duas vezes; valor pago negativo e desconto negativo são recusados (AcertoEntregadorService.java:111-117); período inválido recusado; PIX gerado e não pago fica FORA do acerto, igual ao faturamento (PedidoRepository.java:145,160).

TROCA DE MOTOBOY — certo: pedido já amarrado a acerto fechado não muda nunca (PedidoService.java:632-637); depois de ENTREGUE exige GERENTE; toda troca vai para o log de auditoria (PedidoService.java:644). O nome vem de `<select>` dos entregadores cadastrados (entregas.js:12-13), não é mais texto livre — conferi e o casamento de nome com o cadastro não quebra.

FLUXO DE STATUS — certo: ENTREGUE/CANCELADO são finais; `exigirQueAvance` barra voltar de etapa; o avanço é UPDATE condicional no banco (`avancarSeAindaEsta`), o que evita dois avisos de WhatsApp do mesmo passo; cancelamento exige motivo (RN05), cancela no marketplace ANTES e, se o marketplace recusar, não cancela aqui; gravação + devolução de estoque + log numa transação só; SAIU_PARA_ENTREGA é recusado para RETIRADA (PedidoService.java:661-669).

FECHAMENTO DE CAIXA (números do dia) — certo: a regra de "o que é venda" está num lugar só (`boraEhVenda`, app.js:93) e as três telas usam a mesma; PIX pendente sai do faturamento mas aparece explicitamente no subtítulo, não desaparece; agrupamento por forma de pagamento normalizado (`boraFormaPagamento`) sem perder centavos; erro de carga não deixa número velho na tela em silêncio e o pop-up bloqueado avisa em vez de não fazer nada.

RELATÓRIO — certo: janela de dias inteiros no fuso de São Paulo; soma das barras devolvida (`porDiaSoma`) e igual ao faturamento por construção; `cancelados` conta só CANCELADO (não conta mais PIX pendente); avisa `itensSemCusto`/`custosIncompletos` quando a margem sai maior que a real; taxa do marketplace mostrada AO LADO do faturamento, não dentro; exige ADMINISTRADOR_LOJA/GERENTE, e o menu (BORA_NAV) bate com o que a API recusa — conferi item por item de relatórios, desempenho, acerto e entregadores.

TERMÔMETRO — certo: a média divide pelas semanas que EXISTIRAM, não por 4 fixo (VendasSaudeService.java:54-82), e exige ~2 semanas de histórico antes de dar faixa.

PROMOÇÃO — certo: o código de promoção é validado contra injeção (regex `[A-Za-z0-9._-]{1,40}`); o teto de usos é incremento condicional no banco, então 20 é 20; a promoção realmente desconta no checkout público (DescontoService.resolver), cupom tem precedência sobre promoção.
