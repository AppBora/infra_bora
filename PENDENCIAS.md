# As pendências — a lista viva

**Este arquivo é o único que você precisa abrir.** O nome dele nunca muda de data, então o atalho
que você guardar hoje continua valendo no mês que vem. Aqui estão **só as ações**, em ordem, com
onde clicar. A prova de cada uma — o que foi medido, quando e onde — está em
[PENDENCIAS-2026-10-30.md](PENDENCIAS-2026-10-30.md).

Última conferência contra a produção: **04/11/2026** (o bloco do 99Food; o resto, **30/10/2026**). Tudo marcado como pendente aqui foi medido
nesse dia, não deduzido.

---

## 🔴 Agora

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
      ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33 "grep '^BORA_SEGREDO_COLUNAS=' /home/ubuntu/bora/api.env"
      ```

- [ ] **2º — e só depois disso: cifrar as 28 credenciais que já estavam gravadas.**
      **Caminho:** painel → Configurações → Plataforma → "Credenciais no banco" →
      **"Cifrar o que já está gravado"**. Clicar duas vezes não estraga nada.
      Ligar a chave protege o que for gravado **daqui para frente**; essas 28 continuam em texto
      puro até esse clique, e saem em todo backup do banco.

O botão é seu, e não meu, por um motivo só: exige login de administrador, e eu não entro em conta
de ninguém.

---

## 🟠 Cadastro e operação — nada aqui é código

- [ ] **iFood da loja 17 nunca buscou um pedido.** Diz `conectado`, mas o token venceu em 07/10 e
      **não tem Merchant ID**. Nenhum pedido do iFood entra nessa loja.
      **Caminho:** Integrações → iFood → Conectar, e autorizar no portal.

- [ ] 🔴 **99Food da Zirá: o vínculo não existe, e agora está PROVADO.** Em 04/11 li a tela do
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

- [ ] 🔴 **Colar o App Secret do `BR_P_BoraHapp` — é o que trava as lojas 19 a 22.** A credencial
      da plataforma salva em 09/10 aponta para outro aplicativo (`5764607673624955027`) e tem 13
      caracteres; é ela que a 99 recusa na loja 1 todo dia. O par que funciona está guardado dentro
      da loja 18, no app de produção. As lojas 19-22 não têm credencial própria: herdam a da
      plataforma, que está errada.
      **Caminho:** painel → Configurações → 🔑 Credencial do app BoraHapp nos marketplaces →
      99Food → App ID `5764607707103889279` + o App Secret (portal da 99, Gerenciamento de
      aplicativo → `BR_P_BoraHapp` → Ver detalhes).
      **Eu não digito segredo — esse colar é seu.** Um colar só resolve as quatro, e conserta a
      loja 1 de quebra. Aviso: a loja 1 passa a usar o app de produção em vez do de teste.

- [ ] **Confirmar qual unidade é a "Zona Norte" da 99.** Quatro das cinco casam por nome **e** por
      endereço oficial dos Correios. A quinta eu fechei **por eliminação**: sobrou a loja 19
      (Rua Firmino Mineli 751, que os Correios colocam no **Jardim Hungarês**) de um lado e a
      "Zona Norte" do outro. Gravei o código `5764608427259856166` nela, mas está **PRONTO, não
      conectado** — nenhum pedido corre risco até você confirmar.
      **Caminho:** 99Food → Lista de lojas → Zona Norte → Configurações → ver o endereço.

- [ ] 🔴 **Jardim Montreal e Jardim Hungarês não estão na lista de bairros de entrega.** O
      checkout **recusa** bairro fora da lista. Hoje, um cliente que mora na porta da loja 18 não
      consegue fechar pedido no cardápio. Os Correios dizem que a Rua Antenor Maciel 393 fica no
      **Jardim Montreal** (por isso a loja 18 mudou de nome em 04/11) e que a Rua Firmino Minelli
      fica no **Jardim Hungarês**. "Jardim Tropical" existe em Sorocaba — só não é onde a loja está.
      **É decisão sua, porque é preço:** me diga a taxa de cada um e eu cadastro nas 5.

- [ ] **A tela diz CONECTADO com 403 em toda consulta.** Defeito do Bora, achado em 04/11: quando
      a consulta de pedidos falha, o Bora grava o erro mas **não rebaixa o status**. A loja 18 está
      agora com `status = CONECTADO` e `ultimo_erro = 403 ... forbidden`. É o mesmo padrão de
      "morre em silêncio" de sempre, numa variante nova.
      **Onde:** `OpenDeliveryClient.polling`, no `catch` — o `marcarPollingFalhou` grava hora e erro,
      e o status fica como estava. Precisa de deploy. **Me peça e eu subo.**

- [ ] **99Food da loja 1 (Sorveteria da Rosa): credencial da plataforma recusada.** Ativo, sem
      `client_secret`, e o polling volta recusado a cada 10 min. É problema **diferente** do de
      cima, e na loja de QA.
      **Caminho:** Configurações → 🔑 Credencial do app BoraHapp nos marketplaces.

- [ ] **(opcional) Fazer o aviso de "sem pedido" contar o tempo.** O verde que mentia já foi
      consertado e publicado em 30/10 — a tela agora diz "Conectado, sem pedido ainda" em vez de
      prometer. O que ela **não** diz é há quanto tempo, porque isso **não existe no banco**: o
      `ultima_sync` só é gravado quando um pedido entra, e não há coluna de "conectado desde".
      Para o aviso virar "ativo há mais de 48 h sem pedido" falta uma coluna `conectado_em` —
      migração e **versão nova da API**. Só se você quiser; hoje a tela já não engana.

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

- [ ] **No balcão/painel, bairro fora da lista sai R$ 0,00 em silêncio.** `PedidoService.taxaPara`
      (linha 82): a taxa sai do bairro do **cadastro do cliente**, e sem correspondência devolve
      `BigDecimal.ZERO` — o pedido é aceito com frete zerado, sem aviso. Cliente sem bairro no
      cadastro também paga zero. Diferente do cardápio público, aqui não há bloqueio. É defeito
      ou é de propósito (o comentário do código diz que o balconista pode combinar frete fora da
      tabela)? Vale a decisão do dono antes de eu mexer.

- [x] **Horário das 5 lojas igualado em 04/11.** A 18 tinha 13:00→23:00 nos sete dias e as outras
      quatro tinham 18:00→23:00, o padrão genérico do `provisionamento.semear`. O dono autorizou
      copiar: **4 lojas gravadas**, ensaio antes mostrando o "hoje" e o "ficaria" de cada uma.
      Conferido no banco: as cinco com 7 dias, 13:00→23:00, todos abertos, **0 dias repetidos**,
      e as lojas de outros clientes intactas (loja 1 em 09:00→23:59, loja 17 em 18:00→23:00).


- [ ] **Dois insumos estão à venda no cardápio público da Zirá** (loja 18, categoria "mantimento"):
      `leite condensado` R$ 3,00 e `pacoca` R$ 2,50, os dois ativos. O cliente final vê isso.
      **Caminho:** Produtos → desativar os dois.

- [ ] **Cinco contas de teste ativas, três delas GERENTE.** GERENTE vê faturamento, custo, margem e
      lucro, apaga cliente e apaga pedido.
      **Caminho:** Configurações → Usuários → desativar. Tem efeito imediato.

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

- [ ] **Autorizar o conserto da venda duplicada** — isto é defeito de **hoje**, com a internet boa.
      O `POST /api/pedidos` não tem chave de idempotência: se a resposta se perde na volta e o
      balconista clica "Finalizar" de novo, a venda é gravada **duas vezes** (estoque baixado duas
      vezes, cashback acumulado duas vezes, faturamento inflado). O conserto é meu — código, uma
      migração e uma versão nova —, só preciso do seu "sobe". Detalhe no item 4 do estudo.

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

- [ ] **Duas das cinco lojas da Zirá nunca vencem.** A 19 e a 20 estão com `acessoAte = NULL`, que
      o código trata como "sem prazo, nunca vence" (`Loja.java:163`). O roteiro das unidades **não
      mexe** nisso — não é hora de tirar acesso de loja que já existe. Mas é o mesmo buraco do item
      do corte por falta de pagamento: loja sem prazo some da cobrança sem ninguém notar. E não há
      porta para o contrário: nada no backend põe `acessoAte` de volta em `null`, `POST
      /admin-bora/lojas` grava sempre +7 dias e `liberar-acesso` exige data futura com teto de 180.
      Se quiser alinhar as duas a 24/01/2027 como as outras, é um clique no painel por loja.

---

## ⚪ Um "sim" seu e eu faço — eu não escrevo em produção sem autorização

- [ ] **7 itens de pedido órfãos** — apontam para pedido que não existe mais. Não mexe em dinheiro.
- [ ] **5 pedidos apontando para cliente apagado** — não dispara erro hoje.
- [ ] **1 linha de ficha técnica fantasma** — **esta mexe em dinheiro**: entra no custo e, portanto,
      na margem que o lojista lê. É a única das quatro que mexe.
- [ ] **"Vale Refeicao" repetido na loja 1** — forma de pagamento duplicada. É um clique.
- [ ] **O nome da loja no painel tem uma rede de segurança que nunca pega** (`whitelabel.js:45`).
      Medido em 31/10. Quando o lojista **apaga** o campo "nome de exibição", o painel cai no texto
      neutro do HTML em vez do nome da loja. A rede está morta por três motivos somados:
      `window.Bora` é sempre `undefined` (o `const Bora` do api.js não cria propriedade em
      `window`); o `boraUser` da sessão guarda só `{nome, papel, lojaId}`, **sem `lojaNome`**; e
      `lojaNome` só vem de dois endpoints, nunca do login normal. **Não toca dinheiro nem papel
      impresso** — é o nome na tela do próprio lojista. O conserto é meu, é pequeno, e precisa de
      um "sim".

---

## Onde estão as outras listas

Estas ficaram como **registro**, não como pendência — todas têm um aviso no topo apontando para cá:
`PENTE-FINO-SO-VOCE-PODE.md` (27/10), `DADOS-A-DECIDIR-2026-10-27.md`, `PENDENCIAS-2026-10-24.md`,
`SO-VOCE-PODE-FAZER.md` (24/10), `O-QUE-FALTA-VOCE-FAZER.md` (23/10) e
`PENDENCIAS-30-09-2026.md`. Se um item delas não aparece nesta página, é porque já foi fechado — a
prova de cada fechamento está no relatório do dia.
