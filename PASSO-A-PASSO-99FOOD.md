# Ligar as 5 lojas da Zirá no 99Food — passo a passo

Escrito em **06/11/2026**. Cada afirmação aqui tem a fonte do lado: *(medido)* = eu li no banco, no código ou na tela; *(anotado)* = está registrado de uma leitura anterior e vamos reconferir na tela; *(da 99)* = foi a própria 99 que respondeu isso.

---

## ⛔ Parte 0 — tem uma coisa na frente de tudo: o servidor está fora do ar

Agora, 06/11, o servidor de produção **não responde** *(medido, por dois caminhos independentes)*:

| Prova | Resultado |
|---|---|
| `borahapp.com.br` e `api.borahapp.com.br` | sem resposta nas portas 22, 80 e 443 |
| Ping no IP `18.230.57.33` | 3 pacotes enviados, 0 recebidos |
| Teste de controle: Google | responde 200 |
| Teste de controle: outro endereço da AWS no Brasil | responde 307 |
| Pelo navegador, no mesmo endereço do site | esperou 6 segundos e desistiu |

Minha internet está boa e a rota até a AWS do Brasil está boa. **O servidor em si é que não atende.** Ele estava no ar hoje de manhã — você estava logado no painel e eu rodei scripts por lá.

Isso significa que **agora**: o cardápio das 5 lojas da Zirá está fora do ar para o cliente, o painel não abre, e eu não consigo ler nem escrever no banco.

**Não consigo checar a máquina para você:** as credenciais da AWS guardadas neste computador estão **inválidas** *(medido: `InvalidClientTokenId`)*. Esse passo é seu.

### 👉 O único passo agora

1. Abra **https://lightsail.aws.amazon.com**
2. Entre na conta da AWS
3. Na lista de instâncias, olhe a bolinha de estado da máquina do Bora

Me diga o que aparece — **"Running"**, **"Stopped"** ou outra coisa. Com isso eu sei se é reiniciar, se o IP mudou, ou se é cobrança. **Não clique em nada ainda**, só me diga o que leu.

> Enquanto o servidor estiver fora, nada das partes 1 e 2 abaixo pode ser feito.

---

## Parte 1 — o lado do Bora

### Já está pronto (medido no banco em 04/11 e 06/11)

As 5 unidades da Zirá existem no Bora e casam 1 a 1 com as 5 da 99 — **não falta loja nenhuma**:

| Loja no Bora | Nome | Como a 99 chama |
|---|---|---|
| 18 | Zirá - Montreal | Açaí Zirá - Montreal |
| 19 | Zirá - Zona Norte | Açaí Zirá - Zona Norte |
| 20 | Zirá - São Bento | Açaí Zirá - São Bento |
| 21 | Zirá - Vila Hortência | Açaí Zirá - Vila Hortência |
| 22 | Zirá - Jardim Nova Esperança | Açaí Zirá - Nova Esperança |

E nas 5, dentro do Bora *(medido)*:

- `ativo = true` — o canal está ligado
- `auto_aceitar = true` — o pedido é aceito sozinho, ninguém precisa clicar
- segredo de webhook gravado
- **o código real da 99 gravado** (é por ele que o pedido acha a loja)

**Como o pedido da 99 cai na loja certa** *(medido, lendo o código)*: a 99 chama `POST /public/opendelivery/v1/newEvent` com o cabeçalho `X-App-MerchantId`; o Bora procura esse código na tabela de integrações e acha a loja. Esse código é único em todo o sistema — não tem como um pedido cair na loja errada.

**A taxa de entrega do pedido da 99 vem da própria 99** *(medido: `PedidoService` linha 352 usa a taxa que chegou no pedido)*. Ou seja: a lista de bairros do Bora **não** atrapalha o pedido da 99.

### O que falta no Bora — 1 item, e é um colar só

**Colar o App Secret do aplicativo `BR_P_BoraHapp`.**

O que está gravado hoje é a credencial de **outro** aplicativo (o de teste, `5764607673624955027`, de 09/10) *(medido)*. É ela que a 99 recusa. As lojas 19 a 22 não têm credencial própria: herdam a da plataforma, que está errada.

- **Onde colar:** painel → **Configurações** → **🔑 Credencial do app BoraHapp nos marketplaces** → **99Food**
- **App ID:** `5764607707103889279`
- **App Secret:** você pega no portal da 99 (Parte 2, passo A)

**Eu não digito segredo** — nem senha, nem chave, nem token. Esse colar é seu; é linha que eu não cruzo. Um colar só resolve as quatro lojas, e conserta a loja 1 (Sorveteria da Rosa) de quebra.

> ⚠️ Aviso: depois desse colar a loja 1 passa a usar o aplicativo de produção em vez do de teste.

### O que já ajustei para o Bora ficar igual à 99 (06/11, ainda não commitado)

Você pediu "copia só os dias fechados" — foi o que fiz *(medido no banco)*:

- loja 21 (Vila Hortência): **quarta-feira fechada**
- loja 22 (Nova Esperança): **terça-feira fechada**
- loja 19: CEP `18075-700` preenchido

### Decisões que são suas (não são código, são preço/regra)

1. **A quarta da Vila Hortência e a terça da Nova Esperança são de verdade?** Copiei da 99. Se foi descuido da loja, me diga e eu reabro.
2. **Taxa de entrega do Jardim Montreal e do Jardim Hungarês.** Hoje um cliente que mora **na porta da loja 18** não fecha pedido no cardápio do Bora, porque o bairro não está na lista *(medido)*. Não afeta a 99 — afeta o cardápio próprio. Me diga a taxa de cada um e eu cadastro nas 5.
3. **A sexta-feira da Vila Hortência tem dois turnos na 99** (13:15–18:15 **e** 19:30–22:15). O Bora guarda **um** horário por dia *(medido: uma linha por dia na tabela)* — não dá para representar turno partido hoje. Ou escolho um turno, ou isso vira ajuste de código.
4. **"Observações do pedido" está DESLIGADO** na Montreal, na 99 *(medido na tela)*. O cliente não consegue pedir "sem granola". Se quiser ligar, é na 99.

---

## Parte 2 — o lado da 99

### O que a 99 já nos disse, e que explica tudo

Em **29/09** a 99 respondeu, por escrito: *"o vínculo de lojas reais só pode acontecer após a aprovação na homologação"* *(da 99)*.

É exatamente onde estamos. E agora está **provado**, não deduzido *(medido em 04/11)*: com o código **real** de cada loja, a 99 responde

> `403 — "User is forbidden to access this resource"`

Antes de 04/11 a loja 18 usava um apelido inventado (`zira-acaiteria`); a 99 devolvia **lista vazia, sem erro**, e o cartão ficava verde para sempre com 0 pedidos. **O teste de token não serve de prova** — a 99 devolve token até para um código que não existe. Quem separa é a consulta de pedidos, e ela diz 403.

**Nunca entrou um pedido do 99Food em nenhuma loja, desde sempre** *(medido no banco)*.

### Passo A — pegar o App Secret

No portal da 99, logado como **Superadministrador**:

**Gerenciamento de aplicativo** → **`BR_P_BoraHapp`** → **Ver detalhes** *(anotado — vamos confirmar na tela)*

Lá tem o **App Secret**. Esse valor vai no Bora, na tela da Parte 1. **Não me mande o valor** — cole direto no painel.

### Passo B — autorizar as 5 lojas para o nosso aplicativo

**Gerenciamento da loja** → **Vincular estabelecimento** → **"Autorização de solicitação de lote"** *(anotado)*

Isso **gera um link**. Abra o link **na mesma sessão** (mesmo navegador, já logado) e autorize as 5 unidades para o aplicativo `BR_P_BoraHapp` (App ID `5764607707103889279`).

> O link vale **7 dias**.
>
> Em 28/09 a aba "Vincular estabelecimento" veio com a **lista de aplicativos vazia**. Hoje, 06/11, o seletor de lojas também apareceu **"Sem dados"** — inclusive no perfil de Superadministrador *(medido)*. Se vier vazio de novo, é sinal de que a homologação ainda não liberou, e aí o caminho é o passo C.

### Passo C — a lista de verificação de pré-lançamento

Descoberta de hoje *(medido, lido na tela do aplicativo 99 Food do computador)*. Na loja de teste do Bora a 99 mostra:

> **Estabelecimento fechado**
> "O estabelecimento foi fechado pela plataforma e não poderá aceitar pedidos online até que seja reaberto. Para retomar as operações, reabra o estabelecimento manualmente."
> **Motivo:** "O estabelecimento foi forçado a se desconectar porque **um ou mais itens da lista de verificação de pré-lançamento não foram concluídos**."

Dois aprendizados:

1. A 99 **força o fechamento** quando falta item nessa lista.
2. Depois de resolver, **alguém reabre na mão** — não volta sozinho.

⚠️ Essa tela é da **Loja Teste BoraHapp**, não da Zirá. **Ainda não sabemos** se as 5 da Zirá estão na mesma situação. Vamos descobrir pelo **ⓘ** ao lado de "Loja fechada", na lista de lojas.

### Passo D — se travar, falar com a 99

Existe um contato (**Daniel, analista da 99Food**) e uma mensagem já redigida em `MENSAGEM-DANIEL-99.md`, de 05/10, pedindo justamente o caminho da homologação. **Não sei se foi enviada nem se teve resposta** — isso é você que sabe.

Tem também um chamado aberto no portal do desenvolvedor em **29/09**, status "Processando": a conta de teste não entra no aplicativo porque o telefone começa com `00` *(anotado)*.

---

## Parte 3 — como vamos saber que funcionou

A loja 18 (Montreal) ficou **ligada de propósito**: ela consulta a 99 a cada 30 segundos. É o nosso termômetro.

- **Hoje:** cada consulta volta `403`.
- **No instante em que a autorização existir:** o 403 vira 200 e o erro desaparece sozinho.

As lojas 19 a 22 ficaram em **ERRO** de propósito: nesse estado o Bora tenta de novo a cada 10 minutos, então elas **se acertam sozinhas** assim que o App Secret entrar. **Ninguém precisa clicar em nada depois.**

Prova final: um pedido de verdade feito no aplicativo da 99 caindo no painel da loja certa, com o valor certo.

---

## O que eu NÃO sei (para você não contar com o que não existe)

1. **Por que o servidor caiu.** Não consigo olhar a máquina — credencial da AWS inválida aqui.
2. **Se as telas dos passos A e B existem com esse nome hoje.** Os caminhos são de anotação de 04/11. Quando você abrir, eu leio a tela e corrijo.
3. **Se a homologação da 99 está aprovada, reprovada ou parada.** A 99 nunca nos disse.
4. **Quais itens faltam na lista de pré-lançamento.** Só vi que faltam, não vi quais.
5. **Se a mensagem ao Daniel foi enviada.**
6. **Os códigos da 99 das lojas 20, 21 e 22.** Estão gravados no banco (foram escritos em 04/11, 9 escritas e 0 falhas, conferidas na época), mas não os tenho aqui em texto e o banco está fora do ar. O da 18 é `5764615393256407102` e o da 19 é `5764608427259856166`.

---

## 📄 Adendo de 06/11 — a documentação oficial da 99 está aberta

O dono perguntou se havia algum repositório no GitHub com essa integração. Achei alguns, mas achei
coisa melhor: **o portal oficial da 99 abre sem login**.

**https://developer-food.99app.com/pt-BR/openapi**

É ele o "portal do integrador" que eu procurei de manhã sem achar. O menu de cima tem
**Gerenciamento de aplicativo** (onde fica o App Secret) e **Documentos do desenvolvedor**.

> A própria página diz que o conteúdo é confidencial, só para parceiro. Resumo aqui para uso
> interno; não republicar.

### O processo oficial tem 4 fases (lido na tela, 06/11)

| Fase | O que é | Onde estamos |
|---|---|---|
| 1 | Contato comercial → **NDA assinado** → criar conta → **auditoria de qualificação** | feito (temos conta e apps) |
| 2 | App de teste + loja de teste + desenvolvimento e QA | feito (loja `boraloja1` conectava) |
| 3 | **Criar o App de Produção** — só depois de cumprir o "Before Going Live" — e pôr 1 ou 2 lojas piloto | o app `BR_P_BoraHapp` existe |
| 4 | Expansão: adicionar as demais lojas | **travado aqui** |

### 🔴 O achado que mais pesa: Open Delivery **não** faz vínculo por endpoint

A 99 documenta **dois protocolos**, e publica uma tabela comparando (lida na tela, 06/11):

| Recurso | 99Food | Open Delivery |
|---|---|---|
| **Vínculo de loja por endpoint** | ✅ | **❌** |
| Endpoints de loja | ✅ | ❌ |
| API financeira | ✅ | ❌ |
| Atualizações frequentes | ✅ | ❌ |
| Adicionais de vários níveis | ✅ | ❌ |
| Atualizar um item só do cardápio | ✅ | ❌ |
| Polling | ❌ | ✅ |
| Arquitetura mais simples | ❌ | ✅ |
| API de logística / endpoint de cardápio | ✅ | ✅ |

**Nós falamos Open Delivery.** A 99 diz, com todas as letras, que o 99Food Protocol é o recomendado
e que o Open Delivery é uma "camada de compatibilidade" onde eles **de propósito** deixaram recursos
de fora. Isso explica o 403 de outra forma: **no nosso protocolo o vínculo não se faz por API** —
tem de vir do portal ou da própria 99.

> **Decisão que vai bater na sua mesa:** migrar para o 99Food Protocol. Não é urgente e não é hoje,
> mas é o caminho que a 99 está investindo. Hoje perdemos: API financeira, vínculo por endpoint,
> adicionais de vários níveis e atualização de item avulso do cardápio.

### 🟢 O caminho que eu não conhecia: a 99 vincula as lojas para nós, por e-mail

Está escrito na fase 4 do documento oficial — há **dois** modos:

1. **Autoatendimento** (o que vinhamos tentando): link de autorização loja a loja, ou o lote pelo
   **Tools Introduction > Store Management**.
2. **Modo assistido pela 99:** mandar e-mail ao Especialista de API dizendo que quer vincular,
   informando **país**, **app_id** e o **shop_id** de cada loja com o **app_shop_id** correspondente.
   O time de Integração faz e avisa quando terminar.

**Esse segundo caminho não depende de nenhuma tela funcionar.** Rascunho pronto em
`EMAIL-99-VINCULAR-LOJAS.md`.

### ⚠️ "Cada loja só pode estar vinculada a UM app de produção"

Está escrito no documento oficial. Se alguma unidade da Zirá já estiver vinculada ao app de outro
sistema de gestão, ela **não entra no nosso** enquanto não for desvinculada. Não sei se é o caso —
e isso pode ser exatamente o motivo do 403.

### A lista de pré-lançamento, item por item, contra o nosso código

Li a página "Before Going Live" e conferi cada item no nosso código *(medido com busca no código,
06/11)*:

| Item da 99 | Exigência | No Bora |
|---|---|---|
| Token: obter e **renovar sozinho** ao expirar | obrigatório | ⚠️ não achei tratamento de "token expirado" |
| Receber o webhook de pedido novo e responder | obrigatório | ✅ existe |
| Ler números grandes (64 bits) sem arredondar | obrigatório | ✅ Java trata (o alerta deles é para Node) |
| Mostrar **order_id e order_index** na tela e no cupom | obrigatório | ❌ `order_index` não existe no código |
| Tratar `shop_paid_money` se a loja aceita dinheiro | obrigatório | ❌ não existe no código |
| Tratar JSON diferente p/ entrega da 99 vs da loja | obrigatório | ⚠️ existe `entregaPeloCanal`, mas não conferi preço e endereço |
| Tratar as **promoções** que vêm no pedido | obrigatório | ❌ não existe no código |
| Ler a estrutura de preço inteira | obrigatório | ⚠️ não conferido |
| Confirmar pedido pela API | obrigatório | ✅ existe |
| Recusar/cancelar pela API | recomendado | ✅ existe |
| Responder a todos os webhooks | obrigatório | ✅ existe |
| Guardar o **request id** de cada chamada | recomendado | ✅ já gravamos no log |

**Ressalva honesta:** essa lista está na seção **Common** e usa nomes de campo do **99Food
Protocol** (`order_index`, `shop_paid_money`). **Não sei** se ela vale igual para quem integra por
Open Delivery. Não vou dizer que estamos reprovados em 3 itens obrigatórios sem confirmar isso —
é pergunta para a 99.

### Os repositórios que achei (e por que não resolvem)

| Repositório | O que tem | Serve? |
|---|---|---|
| `Kawa-Vinicius-Dev/pedeai` PR #13 | Open Delivery v1.7.1 para a 99: OAuth client credentials, polling de 30 s com acknowledgment, webhook assinado `X-App-Signature` | **Arquitetura idêntica à nossa** — mas o próprio PR diz que falta homologar "quando houver as credenciais". Parou no mesmo lugar. |
| `biielFranca/hamburgueria-dispatch` PR #5 | diz que a 99 passou a usar protocolo próprio | Nota de um dev, não oficial. A documentação oficial mostra que os **dois** existem. |
| `wesley956/PedeAqui` issue #934 | planejamento de 99Food como adaptador separado | só planejamento |
| `allanpinon/integracao-99-entrega` | API da **99 Entrega** (logística) | outro produto, não é pedido |

**Conclusão:** nenhum repositório público passou do ponto onde nós estamos. Todos param na
homologação/credencial. **O que destrava é a 99, não código de terceiro** — e nossa arquitetura
bate com a de quem seguiu a mesma especificação.

---

## ✅ 06/11, à tarde — O VÍNCULO FOI FEITO. E o 403 tinha outra causa.

Tudo abaixo foi **lido na tela** em 06/11, entre 15h e 16h.

### O portal do integrador existe, e você tem acesso

**https://developer-food.99app.com** — login por telefone (`15998602332`), aba **"Entrar com código de verificação"**. O menu da esquerda tem **Gerenciamento de aplicativo**, **Gerenciamento da loja**, Monitoramento de pedidos, Monitoramento da API, Ambiente sandbox, Gerenciamento de permissões.

### O caminho que funcionou (e por que a gente errava)

A aba **Gerenciamento da loja → Vincular estabelecimento** só lista estabelecimentos que **já autorizaram** o aplicativo. Enquanto ninguém autoriza, ela mostra `暂无数据` ("sem dados"). **Era esse o "Sem dados" que a gente leu como bloqueio da plataforma**, em 28/09 e de novo na manhã de 06/11. Não era bloqueio: era uma tabela vazia esperando a autorização.

A sequência certa:

1. **Autorização de solicitação do lote** → gera um link de `merchant.99app.com`
2. Abrir esse link **logado na conta do lojista** (você é Superadministrador da Zirá, então autorizou sozinho)
3. **Etapa 1:** conceder as permissões — marcada só "integração de pedidos/itens/lojas/entregas"; **"integração financeira" deixada DESMARCADA** de propósito, porque a API financeira não existe no Open Delivery e daria acesso a dados que o Bora não usa
4. **Etapa 2:** marcar os estabelecimentos → **Autorizar**
5. Voltar ao portal do integrador, buscar por país + aplicativo + ID do loja → **Vincular** → digitar o **APPShopID**

### As 5 lojas vinculadas, em ambiente de produção

| Loja Bora | ID do loja (99) | **APPShopID** | Token válido até |
|---|---|---|---|
| 18 Montreal | `5764615393256407102` | `zira-acaiteria` | 08/11/2026 |
| 19 Zona Norte | `5764608427259856166` | `zira-zona-norte` | 06/12/2026 |
| 20 São Bento | `5764614166724478604` | `zira-sao-bento` | 06/12/2026 |
| 21 Vila Hortência | `5764608491428513041` | `zira-vila-hortencia` | 06/12/2026 |
| 22 Nova Esperança | `5764608368417965364` | `zira-nova-esperanca` | 06/12/2026 |

A Montreal ficou fora do padrão de propósito: a linha de produção só oferece **"Desvincular"**, então renomeá-la exige desvincular e vincular de novo — e ela era o único termômetro vivo. **Decisão sua: mexer nela depois que as outras 4 estiverem provadas.**

### 🔴 A causa real do 403 — era defeito NOSSO, não bloqueio deles

Lido na documentação da 99, em **Open Delivery → Authorization API → Get Access Token**:

> **"ClientId = AppID_AppShopId.** You can see all these datas on Application Management."
> *"This token is unique for every shop not for application."*

O nosso código (`OpenDeliveryClient.clientIdDaLoja`) monta `{app_id}_{merchant_id}`, e o nosso `merchant_id` guarda o **ID do loja**. Então, para a Montreal, nós mandávamos `5764607707103889279_5764615393256407102` quando o certo era `5764607707103889279_zira-acaiteria`. **Daí o 403.**

**Correção de registro:** em 04/11 eu escrevi que `zira-acaiteria` era "apelido inventado". **Era o APPShopID de verdade**, cadastrado na 99 desde 09/10. O valor estava certo; o que estava errado era o aplicativo (o de teste, não o de produção) e, depois, a minha "correção", que trocou o APPShopID pelo ID do loja.

### O que isso exige do Bora (quando o servidor voltar)

1. `integracao_canal.merchant_id` das 5 lojas passa a guardar o **APPShopID**, não o ID do loja.
2. **Atenção:** esse mesmo campo é a chave de roteamento do webhook (`X-App-MerchantId`). A documentação descreve esse cabeçalho só como *"unique identifier for the merchant across different systems"* — **não diz se é o APPShopID ou o ID do loja**. Não vou adivinhar: a solução é **guardar os dois** e o webhook casar por qualquer um deles.
3. Colar o **App Secret** do `BR_P_BoraHapp` — continua sendo seu.

### 🔶 Descoberta de lado: a Saipos

Na lista de autorizados apareceram **9 registros**. Quatro são do **Sistema Saipos** (Saipos Serviços de Software Ltda), autorizados em **junho de 2026** nas mesmas 4 lojas. Não impediu o nosso vínculo — mas é informação comercial que você precisa ter.

### O que a tarde matou de dúvida

- As 4 lojas aparecem **Online / Aberto / "Durante o horário de funcionamento: Sim"**. O *"Loja fechada"* das 08h era **horário**, não bloqueio. A lista de pré-lançamento que fechou a loja de teste **não está travando a Zirá**.
- A pergunta nº 1 do e-mail (formato do `app_shop_id`) está respondida.
- O e-mail para a 99 **não é mais necessário para o vínculo**. Segue útil só para a pergunta da lista de pré-lançamento, se um dia ela nos atingir.

---

## Resumo em 1 linha

**O Bora está pronto, menos um colar de segredo. O que trava é a 99: a homologação não liberou o vínculo, e isso está provado pelo 403. E antes de qualquer coisa, o servidor precisa voltar.**
