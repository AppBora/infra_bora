# Operar com a internet da loja caída — o que dá, o que não dá, e a que custo

Levantamento de **30/10/2026**. **Nada foi alterado** — é estudo. Tudo marcado como *medido* foi
lido no código ou no que está no ar hoje, com arquivo e linha.

---

## 1. O tamanho real do problema é menor do que parece

**Os pedidos não param de entrar quando a internet da loja cai.** O cardápio público, o link do
WhatsApp, o iFood e a 99Food falam com a API **na nuvem**, não com um servidor na loja. Se o link
da loja cai, o cliente continua pedindo e a nuvem continua recebendo e gravando. **Nada se perde.**

O que se perde é o que a loja **vê e faz**:

| | com a internet caída |
|---|---|
| pedido do cardápio / WhatsApp / iFood / 99 | **entra normal**, fica na nuvem |
| a loja ver esses pedidos | **não vê** |
| registrar venda de balcão (PDV) | **não registra** |
| mudar status, despachar, fechar | **não faz** |
| imprimir | **imprime** — é `window.print()` no navegador, não depende do servidor |

Medido: `caixa.js:41` e `app.js:259` montam uma janela no próprio navegador e chamam `print()`.

Quando o link volta, tudo que entrou aparece. Então a pergunta não é "como não perder pedido" — é
"como a loja continua **operando o balcão** e **vendo o dia** durante a queda".

---

## 2. O que existe hoje, medido

**Já há um service worker instalado em todas as lojas.** `https://borahapp.com.br/sw.js` responde
**200 com 1.205 bytes** (conferido hoje), e o `app.js:348` registra ele em toda tela. O
`manifest.webmanifest` também está no ar — o painel é instalável na tela inicial.

**Mas ele foi feito para cache de tela, não para operar offline.** O próprio arquivo diz: *"API:
sempre rede (dados ao vivo)"* — ele desvia `/api`, `/auth`, `/public` e `/admin-bora`. Para o resto
(HTML, CSS, JS) é rede primeiro e cache como reserva, então **as telas que o lojista já abriu
abrem offline** — e ficam vazias.

**Não há nenhuma gravação local.** Zero uso de IndexedDB em todo o frontend. O `localStorage` guarda
só o token, o usuário, a marca da loja e algumas preferências.

**Não há fila nem repetição.** O `Bora.api()` (`api.js:27`) é o caminho único de todas as telas: se
o `fetch` falha, ele estoura e a tela mostra o erro. Não tenta de novo, não guarda nada.

**Já há aviso de queda.** O `Bora.repetir` + `_conexao` (`api.js:195-230`) pinta uma faixa de "sem
conexão" nas 9 telas que recarregam sozinhas, **depois de duas falhas seguidas** — para um soluço de
rede não assustar ninguém no meio do movimento.

**A sessão expira em 24 h.** `bora.jwt.expiration-ms` = 86400000 (`JwtService.java:25`). Offline
ninguém consegue **entrar** (login é chamada ao servidor), e token com mais de 24 h para de valer.
Qualquer modo offline só serve para quem **já está logado**, e por uma janela limitada.

---

## 3. O que é genuinamente difícil: o servidor é a autoridade de dinheiro e de estoque

Isto não é detalhe de implementação — é o desenho, e está escrito no código:

- **O total é do servidor.** `PedidoService.criar`: *"o total é calculado no servidor
  (autoritativo)"*. Offline o preço teria de ser calculado no aparelho, por uma tabela em cache. Se
  o preço mudou no meio, **o cupom impresso e o pedido gravado divergem**.
- **O estoque baixa no banco, por diferença** (`produtos.baixarEstoque`), e o comentário diz por quê:
  ler-subtrair-gravar fazia duas vendas simultâneas lerem o mesmo saldo e uma baixa desaparecer.
  Diferença é segura na direção, **não na contagem**: mandar o mesmo pedido duas vezes baixa duas
  vezes.
- **O cashback é o pior.** `fidelidade.resgatePossivel` lê o saldo no servidor e
  `acumularFidelidade` acumula. Dois aparelhos offline — ou um aparelho offline e o cardápio online —
  **gastam o mesmo saldo duas vezes**. É exatamente a classe de defeito que já foi consertada uma vez
  (cashback atômico, v129).
- **A ficha técnica consome insumo** pelo mesmo caminho.

---

## 4. O bloqueio que apareceria primeiro — e que é um defeito de HOJE

**Não existe chave de idempotência para o pedido do painel.**

Medido: a única deduplicação que existe é a do marketplace — índice único
`uq_pedido_canal_externo` em `(canal_externo, id_externo)` (V28), usado pelo
`findFirstByLojaIdAndCanalExternoAndIdExterno`, com o comentário *"idempotência webhook"*.

Para o `POST /api/pedidos` **não há nada**:

- o código que o painel manda é `'#' + Date.now().toString().slice(-6)` (`novo-pedido.js:355`) — os
  6 últimos dígitos do relógio, que **se repetem a cada 16 min 40 s**;
- o **PDV não manda código nenhum** (`pdv.js:200-211`), o pedido nasce sem;
- **não há índice único** em `pedido(loja_id, codigo)`.

Qualquer fila de "guarda e manda de novo" criaria **pedido duplicado** numa conexão instável: baixa
de estoque dobrada, cashback acumulado duas vezes, faturamento inflado.

**E isto já morde hoje, com a internet funcionando.** O PDV faz duas chamadas em sequência
(`criarPedido`, depois `mudarStatus(ENTREGUE)`). Se a resposta da primeira se perde no caminho de
volta, o balconista não sabe se a venda entrou — clica de novo, e **a venda é gravada duas vezes**.
Uma chave de idempotência (uuid gerado no aparelho) mais um índice único resolve isso **agora**, sem
nenhum modo offline.

---

## 5. Os três caminhos, com custo honesto

### A. Não guardar nada, mas dizer a verdade na tela — **viável, barato, hoje**

A faixa de "sem conexão" já existe. O que falta é a instrução operacional: *"você está sem internet.
As vendas de balcão vão para o papel. Os pedidos de entrega estão guardados na nuvem e aparecem aqui
quando voltar."* Mais travar o botão de finalizar enquanto está offline, em vez de deixar o
balconista clicar e levar erro.

**Custo:** horas. **O que resolve:** a dúvida "a venda entrou ou não?", que é justamente o que faz a
mesma venda ser lançada duas vezes.

### B. PWA com fila de gravação — **viável, e é a resposta de verdade**

A base está pronta: service worker já instalado, **um caminho único** no `Bora.api()`, código do
pedido já gerado no cliente, sinal de conexão já existente.

Precisa de: catálogo em IndexedDB, venda de balcão gravada local e enfileirada, reenvio ao voltar —
e, **obrigatoriamente antes**, a chave de idempotência do item 4.

**Limites que eu não esconderia do lojista:**
- preço, estoque e cashback calculados offline são **aposta**, reconciliada quando sobe;
- **cashback bloqueado offline.** É o único que gasta dinheiro duas vezes e não tem como conferir
  saldo sem servidor;
- **estoque vai a negativo**, e isso já é aceito no balcão hoje, com aviso;
- escopo realista: **o PDV e as telas de leitura do dia**, não o painel inteiro.

### C. Um servidor dentro da loja — **tecnicamente possível, desproporcional**

A pilha são dois containers (`docker-compose.yml`: postgres 16 + api) e roda num mini PC. Mas aí
passam a existir **duas autoridades para a mesma loja**, e juntar dois Postgres em que os dois
receberam pedido, mexeram em estoque e acumularam cashback não é funcionalidade: é problema de
sistema distribuído. Mais hardware, atualização, backup e suporte por loja.

Para 5 lojas num plano de R$ 199/mês, e com teto de R$ 800/mês de infra para a plataforma
**inteira**, isso não fecha. Só se um cliente específico tiver internet cronicamente ruim e pagar
por isso.

---

## 6. O que eu recomendo

1. **A** agora (horas).
2. **A chave de idempotência** — pequena, e conserta um defeito que existe hoje com a internet boa.
3. **B limitado ao PDV e à leitura do dia.**
4. **C: não**, por ora.

## 7. O que eu NÃO sei, e é o que deveria decidir o tamanho

**Com que frequência isso acontece, e por quanto tempo.** Não tenho nenhuma medição de queda de
internet nas lojas. Dá para medir: o log de acesso do painel mostra, por loja, os buracos em que
nenhum aparelho daquela loja falou com a API durante o horário de funcionamento.

Construir B antes de ter esse número é chutar o tamanho. **Peça a medição e eu faço** — é leitura de
log, não mexe em nada.
