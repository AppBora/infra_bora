# Ensaio da homologação da 99Food

Roda o ciclo completo da 99 contra uma "99 de mentira", sem depender deles.

```bash
bash ensaio-homologacao-99.sh bora-api:v105
```

Sobe Postgres + a imagem do Bora + um servidor que fala Open Delivery, e confere o que a homologação
olha: o pedido chega sozinho pelo polling, os dados vêm certos, o recebimento é confirmado, e os dois
fluxos de status fecham do jeito que a 99 espera — inclusive a **retirada**, que termina em `pickedUp`
e nunca manda `dispatch`.

Não toca em produção: rede própria, containers próprios, tudo derrubado no fim.
`MANTER=1` deixa os containers de pé para investigar.

## Por que isto existe

A homologação da 99 pede para ver o fluxo funcionando. Até hoje nunca conseguimos gerar um pedido de
teste de verdade: a conta de teste não entra no aplicativo deles ("Formato de número de telefone
inválido"), chamado aberto em 29/09 e ainda sem resposta. Este ensaio é a prova enquanto isso não
destrava — e, quando destravar, continua servindo para não quebrar nada sem perceber.

## Dois tropeços que valem lembrar

1. **O Spring manda o acknowledgment em `chunked`, sem `Content-Length`.** A primeira versão da 99 de
   mentira lia só o `Content-Length`, via zero, e eu passei um tempo achando que o Bora não estava
   confirmando o recebimento. Estava. Quem não sabia ler era o teste.
2. **`MANTER=1` pulava também a limpeza do começo**, então a rodada reaproveitava os containers da
   anterior e media estado velho. A limpeza do início agora acontece sempre.

## Um erro meu que vale ficar registrado

A primeira versao deste ensaio inventou um campo `orderTotal` que **nao existe** no Open Delivery e
poe os itens secos em `orderAmount`. No schema oficial v1.7.1 e o contrario: `itemsPrice` sao os itens
e **`orderAmount` e o total do pedido** (itens + taxas - desconto). Com o payload errado, o ensaio
acusou uma diferenca de R$ 7 no faturamento e eu quase reportei isso como defeito do Bora.

O Bora sempre leu `orderAmount`, que e o certo. Quem estava errado era o teste. Se for inventar
payload, conferir contra `src/test/resources/opendelivery/*.json`, que foram montados a partir do
schema oficial.
