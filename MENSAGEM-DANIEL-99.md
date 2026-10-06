# Mensagem para o Daniel (analista da 99Food) — 05/10/2026

Copiar e colar no WhatsApp. Em três partes, para não virar um bloco gigante.

---

## Parte 1 — abertura e o que já está pronto

> Oi Daniel, tudo bem? Aqui é o Anderson, da ADF Sistemas (BoraHapp).
>
> Obrigado por se colocar à disposição — tenho três assuntos objetivos, e o primeiro é só uma boa notícia.
>
> Recebemos ontem o comunicado do time de engenharia sobre o Pedido para Retirada, com prazo de implementação até 12/10. **Do nosso lado já está pronto e no ar desde 22/09.** Conferimos item por item contra o comunicado: o pedido com `type = TAKEOUT`, a ausência do objeto `delivery`, a leitura do objeto `takeout` e o fechamento pelo endpoint `/v4/opendelivery/v1/orders/{orderId}/pickedUp`. Falamos Open Delivery, então o trecho do protocolo próprio (`fulfillment_mode`, `takeaway_code`) não se aplica a nós.

---

## Parte 2 — o que de fato está travando (o pedido principal)

> O que trava a gente não é a retirada: é a **homologação**.
>
> No dia 29/09 vocês nos informaram que *"o vínculo de lojas reais só pode acontecer após a aprovação na homologação"*. Faz sentido, e é exatamente onde estamos parados: nosso aplicativo de teste (App ID **5764607673624955027**) conecta normalmente a loja de teste `boraloja1` — status conectado, polling a cada 30s, zero falhas — mas na aba **Vincular estabelecimento** a lista de aplicativos vem vazia, então não conseguimos ligar nenhuma loja real.
>
> **O que eu preciso de você:** qual é o caminho da homologação, o que vocês exigem de nós para abrir esse processo, e qual é o prazo típico. Se houver checklist ou formulário, me manda que eu respondo no mesmo dia.
>
> Contexto para você dimensionar: somos uma integradora pequena, 4 lojas na fila, Open Delivery com polling. A primeira loja real é a **Açaí Zirá – Montreal**, que já é loja 99Food ativa.

---

## Parte 3 — o chamado parado e uma dúvida

> Duas coisas menores, mas que me prendem:
>
> **1) Chamado aberto em 29/09 (status "Processando"):** a conta de teste não entra no aplicativo — o telefone começa com `00` e o app recusa com "Formato de número de telefone inválido". Por causa disso **nunca conseguimos gerar um pedido de teste de verdade**, o que imagino que seja justamente o que a homologação vai pedir. Serve qualquer uma das três saídas: uma conta de teste com celular válido, a orientação de qual aplicativo aceita esse login, ou vocês mesmos dispararem um pedido de teste para a loja `boraloja1`.
>
> **2) Uma dúvida honesta sobre o comunicado:** em 29/09 vocês nos responderam que *"quanto aos pedidos de retirada, nenhuma liberação extra é necessária"*. O comunicado de ontem diz que as integradoras que quiserem usar ou testar a retirada **devem entrar em contato para liberação da aplicação parceira**. São informações diferentes — qual das duas vale para a gente? Se precisar da liberação, considere este contato como o pedido formal.
>
> Fico à disposição e respondo rápido. Obrigado!

---

## Fatos usados nesta mensagem (todos conferidos)

| Afirmação | De onde veio |
|---|---|
| Retirada implementada desde 22/09 (v73) | Código: `MarketplaceNormalizer` linha 250 e `OpenDeliveryClient` linha 332 |
| A URL `pickedUp` bate com a do comunicado | `baseUrl` + `/v1/orders/{id}/pickedUp`, conferido no código |
| Falamos Open Delivery, não o protocolo próprio | Só existe `OpenDeliveryClient`; o protocolo 99 proprietário não é lido |
| App ID 5764607673624955027, loja `boraloja1` conectada | Log do servidor em 27/09, status CONECTADO |
| "Vincular estabelecimento" vem vazia | Visto na tela do portal em 28/09 |
| "Vínculo de loja real só após homologação" | Resposta da 99 em 29/09 |
| "Nenhuma liberação extra é necessária" para retirada | Resposta da 99 em 29/09 |
| Chamado do login de teste aberto em 29/09 17:38 | Portal do desenvolvedor, status "Processando" |
| 4 lojas na fila, Open Delivery, polling | Formulário de onboarding técnico da própria 99 |

**Não afirmei** que já rodamos um pedido de retirada de ponta a ponta — porque não rodamos: o pedido de
teste nunca saiu. O que está provado é que o código trata o formato e chama o endereço certo.
