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

## Resumo em 1 linha

**O Bora está pronto, menos um colar de segredo. O que trava é a 99: a homologação não liberou o vínculo, e isso está provado pelo 403. E antes de qualquer coisa, o servidor precisa voltar.**
