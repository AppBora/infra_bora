# Abrir uma unidade NOVA da Zirá — na 99Food e no Bora

Escrito em **13/11/2026**, para a unidade no endereço do dono. Cada afirmação tem a fonte do lado:
*(medido)* = eu li no banco, no código ou na tela; *(da 99)* = está escrito num guia oficial da 99,
com o link; *(não sei)* = está aqui justamente para você não contar com o que ninguém conferiu.

A decisão já tomada: **a unidade entra como a 6ª loja da Zirá, pelo CNPJ centralizador dela.**

> **A consequência, dita antes de começar:** a 99 só paga em conta bancária **do mesmo CNPJ** — não
> paga em conta de terceiro nem em CPF *(da 99,
> [guia do CNPJ e conta bancária](https://99app.com/99food/restaurantes/guias/como-vincular-seu-cnpj-e-conta-bancaria/))*.
> Então o repasse dos pedidos desta unidade **cai na conta da Zirá**, não na sua. Se a ideia é
> piloto e teste de ponta a ponta, tanto faz. Se a ideia é faturamento seu, o caminho é outro: CNPJ
> próprio, cadastro novo, conta nova — e aí a parte 1 vira um cadastro do zero.

---

## Parte 1 — o lado da 99 (é por aqui que você quer começar)

### Onde se cadastra

**Portal de Cadastro de Estabelecimentos Parceiros:** <https://merchant.99app.com/pt-BR/store>
*(da 99, [tipos de portal](https://99app.com/99food/restaurantes/guias/99food-store-quais-tipos-de-aplicativos-temos-qual-a-diferenca-entre-eles/))*

Dois avisos do próprio guia: o Portal do Estabelecimento Parceiro **não tem suporte para iOS nem
Mac**, e o portal no modo **Manager** (gerenciar várias lojas) **não recebe pedido e não abre nem
fecha loja** — quem opera é o app Android ou a versão Windows.

### O que ter na mão ANTES de abrir a tela

| Item | Observação |
|---|---|
| CNPJ da Zirá | o centralizador da rede *(da 99: "cada loja deve ter seu próprio CNPJ **ou estar ligada a um CNPJ centralizador de sua rede**")* |
| CPF e RG do responsável legal | pedido no cadastro |
| Endereço completo da unidade | o seu, com CEP |
| Telefone de contato | uso interno da 99; **não** é divulgado a cliente nem a entregador |
| **Foto da fachada** | **obrigatória** *(da 99)*. Só o entregador vê — serve para ele achar a porta |
| Foto de capa | **não pode repetir a de outra loja** — a própria 99 diz que repetir derruba a conversão. Sem perfil de rede social e sem publicidade pessoal, ou é recusada |
| Cardápio em **foto, PDF ou QR Code** | **envio obrigatório, e tem gente analisando** *(da 99)* |
| Dados bancários do CNPJ da Zirá | para o micro-depósito |

### Os 7 blocos que a 99 cobra para ativar a loja

Lido hoje no guia oficial *(da 99,
[como ativar sua loja](https://99app.com/99food/restaurantes/guias/como-ativar-sua-loja/))*:

1. **Informações do estabelecimento** — foto de capa, foto da fachada, telefone.
2. **Horário de funcionamento** — **a 99 aceita mais de um turno no mesmo dia** (almoço e jantar).
   ⚠️ **O Bora guarda um horário por dia** *(medido: uma linha por dia na tabela)*. É a mesma
   limitação que já apareceu na sexta-feira da Vila Hortência. Se esta unidade tiver turno partido,
   o Bora não representa — e isso é ajuste de código, não de cadastro.
3. **Configurações de operação** — no mínimo **1 categoria principal** e até 2 subcategorias, e o
   **tempo médio de preparo** (ele entra no prazo que o cliente lê; curto demais gera atraso, longo
   demais faz desistir).
4. **Entrega** — três modelos: **pela loja** (você cuida da logística e configura o raio),
   **pela 99Food** (entregador parceiro deles) ou **Flex** (os dois). Escolha sua.
5. **Formas de pagamento** — online pela plataforma, ou na entrega.
6. **Informações bancárias (CERC)** — CNPJ, conta do **mesmo titular**, e depois **confirmar o
   micro-depósito de centavos** no painel deles. **Pode levar até 2 dias úteis**, e é esse passo
   que libera o pagamento. Dado bancário errado é motivo de rejeição; e **um CNPJ não pode estar em
   duas contas ao mesmo tempo**.
7. **Cardápio** — vai para análise da equipe da 99. **O preço na 99 tem de ser o mesmo do balcão
   físico** — é esse o objetivo declarado da análise. Restaurante com balcão ou mesa manda foto ou
   PDF do menu físico; só dark kitchen pode mandar link de cardápio de outro aplicativo.

### O que pode travar, e já travou aqui

- **A lista de verificação de pré-lançamento.** Foi ela que **fechou à força a loja de teste do
  Bora** *(medido na tela em 06/11)*: "o estabelecimento foi forçado a se desconectar porque um ou
  mais itens da lista de verificação de pré-lançamento não foram concluídos". E **ninguém reabre
  sozinho** — depois de resolver, alguém tem de reabrir na mão.
- *(não sei)* **se a 99 deixa você mesmo criar a unidade nova dentro da conta da Zirá**, ou se isso
  passa pelo comercial deles. Não achei guia dizendo isso — nem que sim, nem que não. Quando você
  abrir o portal, eu leio a tela com você, como em 06/11.
- *(não sei)* **se a 99 vai pedir algum documento do endereço** (a unidade fica no seu endereço, e
  o CNPJ é o da Zirá). Vale ter em mãos o que comprove o uso do ponto, caso peçam.
- *(não sei)* **o prazo de aprovação.** Nenhum dos guias publica.

---

## Parte 2 — ligar essa unidade ao BoraHapp

Esta parte **já é caminho batido**: foi ela que destravou as 5 lojas da Zirá em 06/11 e 10/11.
O detalhe inteiro está em [PASSO-A-PASSO-99FOOD.md](PASSO-A-PASSO-99FOOD.md); aqui vai só o que
muda para uma loja nova.

1. **Portal do integrador:** <https://developer-food.99app.com> — login por telefone,
   aba "Entrar com código de verificação".
2. **Gerenciamento da loja → Vincular estabelecimento → "Autorização de solicitação do lote"** →
   gera um link de `merchant.99app.com`, que vale **7 dias**.
3. Abra esse link **logado na conta da Zirá** (você é Superadministrador dela) e autorize a unidade
   nova para o app **`BR_P_BoraHapp`** (App ID `5764607707103889279`).
   - **Etapa 1:** marque só "integração de pedidos / itens / lojas / entregas".
     **Deixe "integração financeira" DESMARCADA** — essa API não existe no Open Delivery, e marcar
     daria acesso a dado que o Bora não usa.
   - **Etapa 2:** marque o estabelecimento → Autorizar.
4. Volte ao portal do integrador: **país + aplicativo + ID do loja** → Pesquisar → **Vincular** →
   digite o **APPShopID**. A busca exige os **três** filtros; só com o ID do loja a tabela volta
   vazia.
   - **Padrão da casa:** `zira-<bairro>`, minúsculo, sem acento. Ex.: `zira-vila-mineirao`.
5. **Me traga dois números — e nenhum segredo:**
   - o **ID do loja** (o numérico, ex.: `5764615393256407102`)
   - o **APPShopID** que você digitou

> **Não precisa colar App Secret nenhum.** A credencial da plataforma está correta desde 10/11
> *(medido: as 5 lojas da Zirá autenticando e buscando pedido)*, e loja sem credencial própria
> **herda** a da plataforma: o `client_id` sai como `AppID_APPShopID` sozinho *(medido no
> `OpenDeliveryClient.clientIdDaLoja`)*.

E um aviso do documento oficial da 99 que vale guardar: **cada loja só pode estar vinculada a UM
app de produção**. A unidade nova nasce livre, então a Saipos — que está autorizada em 4 lojas da
Zirá desde junho/2026 *(medido na tela em 06/11)* — não atrapalha aqui.

---

## Parte 3 — o lado do Bora

### O que eu construí hoje (13/11), porque não existia

**Copiar o cardápio de outra unidade.** Antes, abrir a 6ª loja de um cliente era digitar tudo de
novo. O tamanho do "tudo", medido na loja 18 hoje:

| | loja 18 (Zirá Montreal) |
|---|---|
| produtos | **44** (42 ativos) em 13 categorias |
| grupos de complemento | **59** |
| itens de complemento | **639** |
| insumos | **43** |
| taxas de entrega | 6 |

639 itens à mão não é tarefa, é uma semana de erro de digitação — e a 99 **analisa o cardápio** e
exige o preço do balcão, então a unidade nova precisa sair **idêntica** à irmã, não parecida.

- **Onde fica:** painel da plataforma → Configurações → **➕ Nova loja (cliente)** → campo
  **"Copiar cardápio de outra unidade"**.
- **Vem:** produtos, ordem das categorias, grupos e itens de complemento, insumos, fichas técnicas,
  taxas de entrega, e a **marca** (logo, cores, cashback) — a unidade nova nasce com a cara da Zirá,
  não com o azul padrão do Bora.
- **Não vem:** **saldo de estoque** (nasce zerado; a decisão de controlar ou não é mantida),
  horários, formas de pagamento, cupons, e o **código do produto no iFood/99** — esse é por loja, e
  copiado faria o pedido do marketplace achar o produto da outra unidade.
- **Roda uma vez só**, em loja com cardápio vazio. Em cima de cardápio existente ela **recusa** e
  diz o que já está lá.
- **A trava que sustenta isso:** nenhum id da loja velha atravessa. Cada tabela é copiada por um
  mapa id-da-origem → id-do-destino. Sem isso, o adicional da loja nova apontaria para o **insumo
  da loja velha** e uma venda aqui baixaria o estoque de lá, calada — e **o banco não pegaria**: a
  chave estrangeira `fk_comp_item_insumo` (V55) fica satisfeita, porque aquele insumo existe, só é
  de outra loja. Provado por 9 testes contra Postgres de verdade, e eu conferi que eles **reprovam**
  quando o id vai cru.

**Campo para o "ID do loja" da 99.** A coluna existe desde a V67 e **nenhuma tela escrevia nela**
*(medido)* — toda unidade nova ficava pela metade esperando alguém abrir o banco. Agora está em
Integrações → cartão do 99Food. De quebra, a trava de unicidade passou a comparar os **dois**
identificadores entre si: o ID numérico de uma loja igual ao APPShopID de outra passava, e o pedido
real de uma cairia no painel da outra.

### O que falta, e é seu

1. **O nome da unidade** (ex.: "Zirá - Vila Mineirão") e o **endereço completo com CEP e bairro**.
2. **O e-mail do responsável.** Usando **o mesmo e-mail** da Zirá, a unidade entra no mesmo login e
   aparece no seletor de loja dela *(medido no código de criação)*.
3. **Duas decisões de dinheiro:**
   - **Esta 6ª unidade entra na cobrança?** Hoje a loja nova nasce com **7 dias de cortesia**; as 5
     irmãs vão até **24/01/2027**. Se for sua loja-piloto, eu alinho o prazo às irmãs e ela não
     entra na fatura; se for unidade de cliente, entra.
   - **A taxa de entrega dos bairros desta unidade.** Desde a v160, bairro fora da lista **recusa o
     pedido** em vez de cobrar R$ 0,00 calado — unidade sem bairro cadastrado não fecha pedido de
     entrega no cardápio próprio (no da 99 não atrapalha: lá a taxa vem da própria 99).

---

## Parte 4 — como vamos saber que funcionou

1. **O relógio da v161 começa sozinho.** Assim que a unidade autenticar e buscar pedido pela
   primeira vez, o cartão dela em Integrações passa a dizer **"🟡 Conectado há X, sem pedido
   ainda"**. Se passar de **48 horas** sem nenhum pedido, ele vira **🔴 "Ligada há X e nenhum pedido
   entrou — confira o vínculo desta loja no 99Food"**. É o aviso que faltou em setembro, quando esse
   mesmo silêncio custou dois meses.
2. **A prova final é um pedido de verdade**, feito no aplicativo da 99, caindo no painel da loja
   certa com o valor certo. **Nunca entrou um pedido do 99Food em nenhuma loja, desde sempre**
   *(medido no banco)* — essa unidade é a chance de fechar isso.
3. Se der 401 ou 403, o caminho não é adivinhar: **o log já imprime o `client_id` que SAIU na
   chamada**, e foi exatamente isso que resolveu em 10/11. Do lado deles, **Monitoramento de
   pedidos / Monitoramento da API**, no portal do integrador.
