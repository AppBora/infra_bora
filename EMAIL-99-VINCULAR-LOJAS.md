# E-mail para a 99 — pedir o vínculo das 5 lojas da Zirá (modo assistido)

**Escrito em 06/11/2026. Não enviado — é você quem envia.**

## Por que este e-mail existe

A documentação oficial da 99 (lida em 06/11 em https://developer-food.99app.com/pt-BR/openapi, Integration Guide → Basic Process Overview, Fase 4) diz que existem **dois** modos de adicionar lojas a um aplicativo de produção:

1. **Autoatendimento** — link de autorização loja a loja, ou lote pela ferramenta do portal.
2. **Modo assistido pela 99** — *"send an e-mail to the API Specialist you are in contact with, telling that you want to bind (or unbind) a store, adding the country of your application, the app_id and the shop_id with the corresponding app_shop_id of each store. Our Integration Ops Team will integrate the store(s) and let you know when the task is done."*

**O modo 2 não depende de nenhuma tela funcionar.** E a tela do modo 1 veio vazia nas duas vezes que olhamos (28/09 e 06/11).

Some isso com outro fato da mesma documentação: **no protocolo Open Delivery — o que nós usamos — o vínculo de loja por endpoint não é suportado** (tabela comparativa, lida na mesma página). Ou seja: para nós, o modo assistido pode ser o caminho normal, não o plano B.

## Para quem mandar

Para o **Especialista de API / KAM** com quem você fala — o **Daniel** é o contato que está registrado aqui (veja `MENSAGEM-DANIEL-99.md`). **Eu não tenho o e-mail dele**; isso é com você.

## ✅ Pronto para enviar — os 5 códigos estão completos

Lidos um a um na tela do portal da 99 em **06/11/2026**, no campo **"ID da loja"** de cada
estabelecimento, e cada um conferido com lupa dígito por dígito:

| Loja no Bora | Nome na 99 | shop_id | Endereço que confirma |
|---|---|---|---|
| 18 | Açaí Zirá - Montreal | `5764615393256407102` | Rua Antenor Maciel, 393 |
| 19 | Açaí Zirá - Zona Norte | `5764608427259856166` | R. Firmino Mineli, 751 - Jardim Hungares |
| 20 | Açaí Zirá - São Bento | `5764614166724478604` | Rua Maria de Fátima Faria, 72 - Parque São Bento |
| 21 | Açaí Zirá - Vila Hortência | `5764608491428513041` | Vila Hortência, CEP 18020-000 |
| 22 | Açaí Zirá - Nova Esperança | `5764608368417965364` | Rua Geraldo Aparecido Rodrigues, 407 |

> **Por que isto está escrito aqui e não só no banco:** em 06/11 a conta da AWS foi encerrada por
> falta de pagamento e o servidor caiu. Esses códigos existiam **só** no banco de produção, e por
> algumas horas não havia como lê-los. Agora existem em arquivo, versionado no git.

---

## Rascunho do e-mail

**Assunto:** Solicitação de vínculo de 5 lojas ao app BR_P_BoraHapp (Open Delivery) — Açaí Zirá, Sorocaba/SP

> Olá,
>
> Aqui é o Anderson, da ADF Sistemas (BoraHapp). Estou usando o **modo assistido** descrito na documentação de vocês (Integration Guide → Basic Process Overview, Fase 4, "99Food's assisted mode") para pedir o vínculo de 5 lojas ao nosso aplicativo de produção.
>
> **País da aplicação:** Brasil
> **app_id:** `5764607707103889279` (`BR_P_BoraHapp`)
> **Protocolo:** Open Delivery
> **Cliente:** Açaí Zirá — 5 unidades, todas em Sorocaba/SP
>
> | # | Loja | shop_id | app_shop_id |
> |---|---|---|---|
> | 1 | Açaí Zirá - Montreal | `5764615393256407102` | (igual ao shop_id) |
> | 2 | Açaí Zirá - Zona Norte | `5764608427259856166` | (igual ao shop_id) |
> | 3 | Açaí Zirá - São Bento | `5764614166724478604` | (igual ao shop_id) |
> | 4 | Açaí Zirá - Vila Hortência | `5764608491428513041` | (igual ao shop_id) |
> | 5 | Açaí Zirá - Nova Esperança | `5764608368417965364` | (igual ao shop_id) |
>
> **Três perguntas objetivas, para não travar o trabalho de vocês:**
>
> **1) `app_shop_id`:** hoje nossa integração monta o `client_id` como `{app_id}_{shop_id}`, ou seja, usamos o próprio `shop_id` de vocês como `app_shop_id`. Está certo, ou vocês esperam um identificador nosso, interno? Se for o segundo, me digam o formato e eu ajusto antes do vínculo.
>
> **2) Vínculo anterior:** a documentação diz que *"each store can only be bound to one production app"*. Alguma dessas 5 unidades já está vinculada ao aplicativo de outro integrador? Se estiver, por favor nos avisem — e, se o lojista autorizar, peço o desvínculo para que possam entrar no nosso.
>
> **3) Lista de pré-lançamento:** nossa loja de teste foi **fechada pela plataforma** com a mensagem *"o estabelecimento foi forçado a se desconectar porque um ou mais itens da lista de verificação de pré-lançamento não foram concluídos"*. Quais itens estão pendentes do nosso lado? Vi a página "Before Going Live", mas ela usa campos do 99Food Protocol (`order_index`, `shop_paid_money`) — queria confirmar **o que exatamente é exigido de quem integra por Open Delivery**, já que a própria documentação de vocês diz que o Open Delivery é uma camada de compatibilidade com escopo reduzido.
>
> **Situação atual, medida do nosso lado:** com o `shop_id` real de cada loja, a consulta de pedidos responde `403 — "User is forbidden to access this resource"`. Com um identificador inexistente, respondia lista vazia sem erro. Entendemos isso como ausência de vínculo, não como defeito nosso — mas, se a leitura estiver errada, me corrijam.
>
> Fico à disposição e respondo no mesmo dia.
>
> Obrigado,
> Anderson — ADF Sistemas / BoraHapp

---

## Fatos usados neste e-mail e de onde vieram

| Afirmação | Fonte |
|---|---|
| Existe modo assistido por e-mail, com país + app_id + shop_id + app_shop_id | Portal da 99, Basic Process Overview, Fase 4 — lido em 06/11 |
| "Each store can only be bound to one production app" | Mesma página |
| Open Delivery não suporta vínculo de loja por endpoint | Portal da 99, Open Delivery Introduction, tabela comparativa — lido em 06/11 |
| Nosso `client_id` é `{app_id}_{shop_id}` | Nosso código, `OpenDeliveryClient.clientIdDaLoja` |
| 403 "User is forbidden to access this resource" | Medido em produção em 04/11 |
| Identificador inexistente devolvia lista vazia | Medido: o apelido `zira-acaiteria` respondia 200 com lista vazia |
| Mensagem de fechamento forçado | Lida na tela do app 99 Food em 06/11 (loja de teste do Bora) |
| App ID `5764607707103889279` = `BR_P_BoraHapp` | Registrado em `PENDENCIAS.md` |
| Os 5 `shop_id` | Lidos no campo "ID da loja" do portal da 99 em 06/11, um a um |

**Não afirmei** que cumprimos a lista de pré-lançamento — porque não sei se cumprimos, e perguntar é mais rápido do que adivinhar.
