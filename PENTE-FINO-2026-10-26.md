# Pente fino da aplicação inteira — 26/10/2026

**13 agentes**, cobrindo 183 arquivos Java + 61 migrações, 36 telas + 46 JS, a landing, os scripts de
deploy e o banco de produção. Cada um com um pedaço fechado, sem sobra e sem buraco.

**Travas que todos tiveram:** sem deploy, sem escrita em produção, sem criar conta, sem digitar senha
ou segredo, banco somente-leitura (`default_transaction_read_only=on`), e **nenhuma chamada
autenticada ao iFood ou à 99** — o próprio código avisa que isso arrisca bloqueio da conta.

**Estado ao fim:** nenhum arquivo de produção alterado. Backend **1059 testes, 0 falhas**; frontend
**526, 0 falhas**. A v149 segue no ar, intacta. Os testes que os agentes escreveram como prova estão
guardados fora da build (eles falham de propósito e quebrariam o deploy).

**Como ler:** ✅ = eu medi com as minhas mãos. ⚠️ = o agente mediu e eu não reconferi. Onde foi
dedução e não medição, está escrito.

---

## 🔴 Está acontecendo agora, e custa venda

### 1. Três lojas recusam pedido 75% do dia ✅

`BORA_CARDAPIO_RESPEITAR_HORARIO=true` no servidor, e as lojas **17, 19 e 20** estão com
**18:00–23:00 nos 7 dias** — o padrão de fábrica que toda loja nova recebe, intocado. Só a 1 e a 18
foram revisadas.

Então de 00:00 às 18:00 o cliente dessas três lê **"A loja está fechada agora"** e vai embora.
Ninguém na loja é avisado. Medido: **16 dos 33 pedidos** da base entraram antes das 18:00, **4 deles
nessas lojas**.

O comentário no próprio código (`PublicController.java:383-386`) diz que a chave nasce **desligada**
e só deve ser ligada *"depois de confirmar o horário de cada loja"*. Foi ligada antes.

**Conserto é seu e é de minutos:** ou desligar a chave, ou corrigir o horário das três em
Ajustes → Operação.

### 2. A landing page não está no ar ✅

```
curl https://borahapp.com.br/   →  48 bytes
<script>location.href="dashboard.html"</script>
```

A landing tem **30.371 bytes** e não está publicada sob nome nenhum. O `index.html` do painel
sobrescreveu o dela — os dois vão para a mesma pasta no deploy. Quem digita o endereço, clica no link
do deck ou aperta "Início" em `/precos.html` **cai no painel do lojista**.

**É conserto meu.** E foi o agente que viu: na minha própria medição de hoje eu olhei `HTTP 200` e dei
por boa sem olhar o conteúdo.

### 3. A taxa de 2% do PIX não cobra de ninguém ✅

`ASAAS_TAXA_PERCENTUAL=0`. É o padrão para toda loja sem percentual próprio — os fundadores deviam
ser a exceção, hoje todos são. Receita de split zero em todo PIX online, em silêncio.

E a `precos.html` diz *"nunca uma porcentagem das suas vendas"*. Hoje é verdade **por acidente**. No
dia em que você ligar os 2%, a frase vira declaração falsa numa oferta comercial. **Uma das duas tem
de mudar de propósito.**

### 4. 28 credenciais em texto puro no banco e nos 67 backups ✅

`BORA_SEGREDO_COLUNAS` **ausente**. A cifragem existe, tem tela, tem endpoint, tem teste — a chave
nunca foi criada. Em texto puro: 11 `webhook_token`, 6 `client_secret`, 5 `config_plataforma.valor`,
3 `access_token`, 2 `refresh_token`, 1 `asaas_api_key`. Entre elas **a chave Asaas que movimenta o
dinheiro da Zirá** e o segredo do iFood que autoriza pedido em nome de todas as lojas.

**Ordem:** ligar a chave → reiniciar → só então o botão "Cifrar o que já está gravado". O endpoint
recusa antes disso, de propósito.

**Divulgação:** um agente leu esses valores ao inventariar. Não foram impressos, mas passaram pelo
contexto dele. Rotacionar por precaução é o que eu faria.

---

## 🟠 Dispara no primeiro caso real

### 5. O ramo `SUBSCRIPTION_DELETED` nunca executa ✅

O controller lê o id da assinatura **só de dentro de `payment`** (`AsaasWebhookController.java:71`) e
nada no código lê na raiz do payload. Evento de assinatura do Asaas não tem `payment`, então o id
chega nulo e o serviço sai na primeira linha (`AssinaturaService.java:388`). O webhook responde
**200 "received"**.

**Isso mata uma decisão sua que está pendente:** marcar os eventos `SUBSCRIPTION_*` no Asaas **não vai
funcionar**, e não vai dar erro.

### 6. Reativar uma loja encurta 89 dias para 10 e apaga o motivo ✅

`prazoAoReativar` (linha 926) usa `prazoDeAcesso(..., hoje+10, CORTESIA)` — que sobrescreve. A guarda
existe no mesmo arquivo (`prazoSemEncurtar`, linha 1030) e não é usada ali. Na Zirá, liberada até
23/01/2027 por `LIBERACAO`: um suspender + reativar e ela sai do ar em dez dias.

### 7. O faturamento pode contar R$ 199 duas vezes ✅

O webhook grava o dia do pagamento em **UTC** (`systemDefault()` no container) e a guarda contra
duplicidade procura o dia em **Brasília** — as três primeiras horas do dia em UTC ficam **fora da
janela**. Asaas confirma pelo webhook, você registra "recebi fora do Asaas" no mesmo dia, e a guarda
não acha o primeiro. Esse faturamento é a base da nota fiscal.

**Ainda não distorceu:** as duas linhas existentes foram escritas pelo caminho manual; o webhook
nunca gravou nenhuma. Dispara no primeiro pagamento real por webhook.

**É buraco no meu conserto de ontem.** Eu disse que o teste novo *"proíbe a classe toda"* de defeito
de fuso. Ele procura `LocalDate.now()` e `LocalDateTime.now()` — e **não** pega `ZoneId.systemDefault()`
nem `YearMonth.now()`, que são a mesma doença. Três instâncias, todas em caminho de dinheiro.

### 8. HTML cru na sua tela de clientes ✅

`configuracoes.html:606` e `:621` empurram `c.documento` e `c.motivo` **sem `esc()`** para dentro de
`innerHTML`. O `esc()` existe no mesmo arquivo e é usado no nome da loja. Quem controla aquele campo
roda script **na sessão do administrador da plataforma** — a conta que suspende, arquiva, entra em
qualquer loja e troca credencial. O agente não disparou o ataque; o que está medido é o campo saindo
sem escape.

Irmão disso ⚠️: o **código de promoção** é texto livre e cai dentro de uma string JS entre
apóstrofes, e o `esc` daquele arquivo **não escapa apóstrofe**. Um GERENTE consegue plantar script
para o ADMINISTRADOR_LOJA — ou para o suporte operando dentro da loja.

### 9. Eu deixei uma segunda porta aberta ontem ✅

`integracoes.js:106` troca a credencial da plataforma **sem perguntar nada**. É o mesmo `PUT` que a
tela que eu construí ontem protege com confirmação e com o aviso dos tokens esquecidos. Construí a
tela nova sem verificar se o controle já existia em outro lugar. Um clique no card do 99Food derruba
o recebimento de todas as lojas sem app próprio.

### 10. `null, 999` no endereço de entrega ✅

`firstNonBlank(a, "")` recebe `""`, que é blank, e devolve **null** — e `null + ", 999"` em Java
escreve o texto literal **`"null, 999"`**. Pedido de marketplace sem o nome da rua grava isso como
endereço, e é o que vai para a tela de Entregas e para a comanda, na mão de quem está na rua.

### 11. O pagamento manual vem com `199.00` preenchido ⚠️

Um Enter registra R$ 199 **independentemente do preço negociado do cliente** — e o servidor baixa a
cobrança no Asaas com o valor digitado e põe isso no faturamento. Mesma classe do campo
pré-preenchido que já te custou um clique errado na liberação da Zirá.

### 12. O cliente fica preso no checkout depois de confirmar ⚠️

O único botão que fecha o checkout mora **dentro** do bloco que é escondido ao confirmar. Na tela de
PIX, quem desiste só sai recarregando a página — e um `setInterval` de 5 s fica batendo no servidor
para sempre, no celular do cliente.

### 13. O cupom enviado é o texto do campo, não o cupom aplicado ⚠️

Se o cliente aplica o cupom e depois **apaga o campo** sem clicar em Aplicar de novo, a tela continua
prometendo o desconto e o servidor cobra o valor cheio. É preço na tela diferente do preço cobrado.

---

## 🟡 Risco, qualidade e operação

**Marketplaces** ⚠️ — cancelamento aceito aqui e não lá (o retorno da 99 é descartado); o reenvio do
aceite depende de um evento que nunca chega; o webhook da 99 ignora se a integração está desligada;
pedido que já existia conta de novo e recebe o aceite de novo.

**Estoque** ⚠️ — reabrir pedido pago depois de cancelado baixa insumo **duas vezes**; insumo vai a
negativo calado quando a venda é por ficha (medido em produção: Polpa de Açaí em **−11,5 kg**); ficha
com quantidade negativa faria cada venda **criar** insumo; limpar movimentação de teste não devolve
estoque; insumo sem custo grava CMV 0,00 e descarta o custo do produto.

**Painel de operação** ⚠️ — trocar o dia no quadro **reimprime as comandas**, inclusive as de ontem;
o quadro de ontem se disfarça de ao vivo; a comanda de papel **não diz que é retirada e imprime o
endereço de casa do cliente**; "Na cozinha" e "Saiu p/ entrega" do Dashboard contam desde a abertura
da loja; Entregas e Fechar Caixa **engolem a queda da API** e a faixa de "sem conexão" nunca acende.

**Relatórios** ⚠️ — a soma do gráfico "por dia" não fecha com o faturamento do cabeçalho, na mesma
tela; o Desempenho conta o custo do PIX abandonado e não a receita dele; o termômetro de vendas
divide por 4 semanas mesmo quando só 2 existem, e diz "saudável" para loja que vendeu metade.

**Cadastro** ⚠️ — o importador aplica o texto **anterior** e diz que deu certo; linha repetida cria
produto duplicado; `Bebidas ; ; 8,00` cria um produto chamado "Bebidas".

**Banco** ⚠️ — `configuracao_loja` sem UNIQUE em `loja_id` (duas linhas e o **cardápio público sai do
ar**); `config_plataforma.valor` em `varchar(255)` quando o valor cifrado precisa de mais, então
cifrar pode falhar inteiro; nota fiscal gravada sem corte em colunas de 40 e 300; N+1 no Módulo IA
(medido: 2.232 ms contra 240 ms com `group by`).

**Infra** ⚠️ — cada ensaio de restauração deixa uma cópia inteira do banco num volume órfão (**53 MB
por semana, sem teto**, 259 MB já acumulados); o log do Caddy está com **314 MB** num arquivo só, sem
rotação; o vigia não mede disco, nem certificado, nem a própria morte.

**Dados** ⚠️ — 7 itens de pedido órfãos, 5 pedidos apontando para cliente apagado, 1 ficha fantasma,
"Vale Refeicao" duplicado na loja 1 ✅, dois insumos cadastrados como produto vendável na Zirá, e a
loja de QA em produção dominando todo relatório agregado (28 dos 33 pedidos).

---

## O que está BOM, e é o mais importante

**Não há vazamento entre lojas.** Um agente conferiu os **29 repositórios** um por um: todas as
consultas e todos os UPDATE/DELETE levam `lojaId`. Os dois únicos sem ele recebem ids de consultas já
escopadas. O papel vem do banco a cada request, não do token. Rebaixar ou desvincular vale no request
seguinte. Em SaaS multi-loja, esse é o defeito que acaba com a empresa — ele não está lá.

Também medido e correto: nenhum dos 15 endpoints testados responde sem token; webhooks exigem token
em tempo constante e **falham fechado**; as chaves da loja têm `@JsonIgnore`; nenhum log imprime
segredo; o cardápio público não devolve custo nem estoque; o link de acompanhar exige assinatura e
devolve 404 igual para token errado e pedido inexistente; upload com lista branca sem SVG; **zero SQL
concatenado** com entrada de usuário; **nenhum `.divide(` sem `RoundingMode`** e **nenhum `double`
carregando dinheiro** em todo o projeto; cashback e estoque atômicos no banco; não dá para pagar a
mesma corrida duas vezes; o reenvio do webhook de PIX não credita cashback de novo; backup roda 4×
por dia, é lido de volta pelo `pg_restore`, e a restauração é ensaiada toda semana — com log.

E o cardápio público pesa **26,5 KB em 40 ms** hoje. Os 510 KB de base64 que estavam na memória do
projeto não existem mais.

---

## Três coisas que eu de-escalei em vez de repassar

**As lojas "fechadas" do cardápio** foram reportadas como catástrofe geral. Fui medir: a Zirá é
13:00–23:00 e era 07:51 de uma segunda — para ela está **correto**. O defeito real é nas outras três,
e é o item 1.

**A conta `admin@bora.app`** com a senha `bora123` do código: as três variáveis de bootstrap **estão
definidas** no servidor, então ela não nasceu com aquela senha. O que eu não consigo medir é se foi
criada *antes* de a variável existir — o bootstrap só cria, nunca atualiza senha. **Teste de login
seu, de um minuto.**

**"O cliente vê a forma de pagamento duplicada"**: a duplicata existe no banco ✅, mas o cardápio
público **não devolve** a lista de formas. Então "o cliente vê" é dedução, não medição.

---

## Os meus erros, nomeados

1. **Olhei `HTTP 200` na landing e dei por boa.** Não olhei o conteúdo. O funil de vendas está morto
   desde 24/10 e eu passei por cima dele hoje.
2. **Disse que o teste de fuso "proíbe a classe toda".** Proíbe um padrão. Três instâncias passam, e
   uma delas anula uma guarda de dinheiro que eu mesmo construí.
3. **Construí a tela da credencial sem procurar se o controle já existia.** Existia, em Integrações,
   sem confirmação. Criei a segunda porta em vez de fechar a primeira.
4. **Consertei o cartão do KDS e não a comanda de papel** — estando as duas no mesmo arquivo, 160
   linhas de distância. Mesma coisa com a retirada: tela e KDS consertados, papel fora.
5. **Dei por certo que o dano do v147 "se curava sozinho"** sem medir. Não se curava.
