# Folha de bolso — liberar a plataforma na loja (21/10/2026)

Seis armadilhas que estão no seu caminho hoje. Nenhuma impede liberar; todas têm contorno manual.

> **O que é fato e o que é precaução:** as duas primeiras **eu medi hoje**, linha por linha. As
> outras quatro vêm da varredura, marcadas "LEITURA" — alguém leu o código e deduziu, e eu ainda não
> confirmei. Trate-as como precaução. No bloco 4, medir derrubou 2 de 5 achados.

---

## 1. Importar cardápio: use VÍRGULA, nunca ponto — **MEDIDO**

O import tira o ponto achando que é separador de milhar (`produtos.js:178`).

| Você cola | Entra como |
|---|---|
| `12,50` | **R$ 12,50** ✅ |
| `12.50` | **R$ 1.250,00** ❌ |
| `R$ 1.250,00` | R$ 1.250,00 ✅ |

**O que fazer:** se a planilha tiver ponto decimal, troca tudo por vírgula antes de colar. E depois de
importar, **confira dois ou três preços na tela** antes de abrir o cardápio.

---

## 2. Editar um produto RELIGA ele — **MEDIDO**

O salvar manda `ativo: true` fixo (`produtos.js:62`). Produto que você desativou volta a aparecer no
cardápio na primeira vez que alguém editar o preço. E **não existe botão de desativar no painel**.

**O que fazer:** produto que não deve vender, tire do cardápio excluindo — ou saiba que ele volta.

---

## 3. A cozinha não vê a observação do pedido — *precaução*

O "sem cebola" chega no navegador mas o cartão do KDS não desenha (`kds.js:16-30`).

**O que fazer:** quem anota o pedido avisa a cozinha por fora (voz, papel). Não confie no card.

---

## 4. Endereço do card e "é retirada" — *precaução*

Duas coisas juntas: o pedido de **balcão nasce como ENTREGA** (a tela não manda o tipo), e o card
mostra o endereço do **cadastro** do cliente, não o que foi informado no pedido. Em cliente
recorrente que se mudou, é o endereço antigo.

**O que fazer:** o motoboy **confirma o endereço com o cliente** antes de sair. E retirada no balcão
vai aparecer como entrega — combine isso com a equipe.

---

## 5. PIX do cardápio: pedido entregue pode virar CANCELADO — *precaução*

Se o PIX não for confirmado, o pedido é cancelado sozinho 30 minutos depois **mesmo já entregue**, e o
cliente recebe "pedido cancelado" depois de ter comido.

**O que fazer:** só despache pedido de PIX depois de ver o pagamento confirmado na tela.

---

## 6. Se a loja vai receber PIX: confirme a conta bancária no Asaas — *precaução*

A subconta pode aparecer como ATIVA com a **conta bancária ainda em análise**. Aí o cliente paga para
uma conta de onde a loja não consegue sacar. É o estado da loja 18 hoje.

**O que fazer:** antes de dizer que o PIX está no ar, confirme no Asaas que a conta bancária foi
**aprovada**, não só enviada. Faça um teste de R$ 1 e tente sacar.

---

## Três coisas que ficaram esperando você

1. **A Zirá perde o acesso em 26/10.** Refazer a assinatura é ação na conta financeira — é sua.
2. **A ficha fantasma da Sorveteria da Rosa**: o produto "Acai 500ml Atualizado" tem linha de ficha
   para um insumo apagado. O estoque está certo; o **custo** dele sai menor, em 26 vendas. Tire a
   linha da ficha no painel, ou ponha o insumo que faz as vezes dela.
3. **Estoque de adicional (v130, no ar)**: em Produtos → 🧩 Complementos, cada opção agora tem
   "baixa do estoque: [insumo] [qtd]". **Até você cadastrar, nada muda** — os 1202 adicionais que já
   existem estão sem insumo e seguem como antes.

---

## O que está fechado e você pode confiar

Dinheiro e estoque: **14 itens fechados** (cashback atômico, estoque que não vai a negativo pelo
cardápio, marketplace baixando estoque, excluir pedido devolvendo dinheiro, os dois canais com o
mesmo total na tela). Cobrança: 6. Banco de dados: 7.

**739 testes no backend, 122 contra Postgres de verdade, 129 no frontend.** O que subiu hoje (v129,
v130, v131) foi conferido dentro do jar que está rodando.

E uma coisa que eu procurei especificamente e **não existe**: vazamento de dado entre lojas. Os 29
repositórios e os 70 acessos por id foram conferidos um a um.
