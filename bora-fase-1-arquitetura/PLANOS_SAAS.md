# Planos SaaS do BoraHapp

> Atualizado em 28/08/2026. Os três planos escalonados (Start R$69 / Pro R$129 / Premium R$249)
> **não existem mais** — foram substituídos por um plano único em 2026-07-05. Este documento
> descreve o que está no código hoje (`entity/Plano.java`, `PlanoService`).

## Plano ÚNICO — R$ 199/mês por loja

Preço de lançamento, fixo. Sem taxa por pedido e sem comissão sobre as vendas.

| | |
|---|---|
| **Pedidos** | Ilimitados |
| **Usuários** | Até 15 ativos por loja |
| **White-label** | Completo — logo, cores, nome de exibição, banner |
| **Cobrança** | Mensal via Asaas, com 7 dias de cortesia antes da 1ª cobrança |
| **Fidelidade** | Nenhuma — cancela quando quiser |

Tudo incluso: pedidos, frente de caixa, fechamento de caixa, tela de cozinha, entregas e acerto
com entregadores, cardápio digital com QR, CRM com cashback, estoque e CMV por ficha técnica,
cupons e promoções, relatórios, e rede multi-loja com balancete consolidado.

**No código:** `Plano.UNICO(15, 0, 199.00)` — o segundo parâmetro `0` significa pedidos ilimitados;
`PlanoService` pula a checagem quando é ilimitado. Preço negociado por loja é possível via
`loja.preco_mensal` (`PUT /admin-bora/lojas/{id}/preco`), mas hoje **não está em uso**: a decisão
de 28/08/2026 é preço fixo para todos.

## Add-on: Módulo IA — +R$ 99/mês por loja

Liberado por loja **somente** pelo `ADMINISTRADOR_BORA` (`loja.modulo_ia`). Uma loja sem o add-on
recebe 403 nos endpoints `/api/ia/*`.

- **Migração de cardápio por foto** — o print do cardápio vira produtos cadastrados
- **Gerente Virtual** — resumo diário do movimento no WhatsApp do dono, às 8h
- **Recuperador de clientes** — contata quem sumiu há 21+ dias, com ROI medido em reais

**Proteção de custo:** o Recuperador tem teto de **200 disparos por loja/mês**
(`IaService.MAX_MSGS_MES`), com saldo exposto no retorno da API. Somado ao Gerente Virtual
(1 mensagem/dia), o pior caso é ~230 mensagens/loja/mês — o que mantém o add-on positivo mesmo
na faixa alta de tarifação de template do WhatsApp.

## Módulo Fiscal (NFC-e) — dormente

Existe no código atrás de uma chave global (`config_plataforma`, `fiscal.habilitado`), hoje
**desligada**. Combinado: ligar só quando o faturamento justificar o custo da API fiscal
(~R$109/mês + R$0,65/nota). Quando ligar, vira módulo repassado por loja emissora.

## O que NÃO é cobrado à parte

- Pedidos, usuários (até 15), lojas na mesma conta (cada loja tem sua própria mensalidade)
- Cardápio digital, QR code e o app instalável (PWA) da loja
- Suporte por WhatsApp, de segunda a sábado, das 9h às 22h
