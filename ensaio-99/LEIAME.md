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

## O que ficou em aberto

O ensaio termina com um aviso que **não reprova**, porque é decisão de negócio: no marketplace o
`valor_total` do pedido não inclui a taxa de entrega (fica só em `taxa_entrega`), enquanto no balcão e
no cardápio próprio o `valor_total` **inclui**. Como o faturamento soma só o `valor_total`, o mesmo
pedido de R$ 51 entra como 51 vindo do balcão e como 44 vindo da 99.

Qual é o certo depende de quem fica com a taxa: na entrega pela loja o dinheiro é dela; na entrega
pela 99, não.
