# O que falta — levantado em 24/10/2026

Tudo com **medido** foi lido hoje na produção (banco em modo somente-leitura, ou o arquivo no ar).
O resto veio da lista de 23/10 e está marcado como tal.

---

## 🔴 Vence em 2 dias

### 1. O acesso da Zirá vence em **26/10**
**Medido hoje:** `loja 18 · acesso_ate = 2026-10-26 00:58 UTC · acesso_motivo = PAGAMENTO_MANUAL`.

Ela **pagou R$ 398** e os dois pagamentos estão registrados. O que derrubou foi o cancelamento da
assinatura no Asaas. Se ninguém mexer, **no dia 26 o cardápio dela sai do ar** — e junto some todo
o trabalho de insumo e cardápio que está sendo feito agora.

**Só você pode:** liberar pelo painel (Plataforma → a loja → liberar acesso). É 1 minuto.
Detalhe em `O-QUE-FALTA-VOCE-FAZER.md`.

---

## 🟠 Zirá: o estoque ainda não funciona

A ordem importa. Fazer o passo 4 antes do 1 e 2 **apaga o cardápio inteiro** para o cliente.

| # | o que falta | medido hoje |
|---|---|---|
| 2 | **Lançar a contagem dos insumos** | 42 dos 43 estão em **estoque 0** |
| 3 | **Preencher o custo dos insumos** | 42 dos 43 estão em **R$ 0,00** |
| 4 | **Importar o cardápio** (`atualizacao-zira/cardapio-impresso-para-colar.txt`) | **13 a criar, 10 a atualizar** |
| 5 | **Montar as fichas técnicas** | **0 fichas** para 35 produtos |
| 6 | **Ligar os adicionais aos insumos** | **397 adicionais, 0 ligados** |

**Por que 3 e 6 importam tanto:** sem custo de insumo, **CMV e margem saem errados** — margem 100%,
CMV zero. E metade do valor de uma venda de açaí pode estar nos adicionais: sem a ligação, a
granola e o leite condensado somem da prateleira sem o sistema saber.

**Eu posso montar as fichas**, mas preciso das quantidades reais — quanto de polpa vai num copo de
300, 500, 770 e no pote. Isso só a Zirá sabe; eu não tenho como medir.

A regra inteira está em `COMO-FUNCIONA-ESTOQUE-E-FICHA.md`.

---

## 🟡 Zirá: coisas do cadastro que eu medi e não resolvi sozinho

| # | o que é | por que não fiz |
|---|---|---|
| 7 | **35 de 35 produtos sem custo cadastrado** | é dado de dono; inventar estragaria o CMV |
| 8 | **"Monte Seu Açaí" cobra R$ 100,00 num açaí de 300ml** — base R$ 90 + copo obrigatório | zerar a base é decisão sua; o import recusa preço 0 |
| 9 | Depois do import, **"Ziraçoca", "Ziraniho" e "Ziratella"** antigos viram repetidos | basta desmarcar "ativo" nos três |
| 10 | **Morango não está** nos adicionais do "Monte Seu Açaí", e o papel lista morango em FRUTAS | é cadastro dela |
| 11 | A categoria **`mantimento`** (leite condensado, paçoca) **aparece no cardápio do cliente** | parece insumo interno virado produto |
| 12 | O açaí de 5L está **cadastrado duas vezes** por R$ 65,00, em categorias diferentes | decidir qual fica |
| 13 | **Copo do Patrão**: cadastro diz 700ml, o papel diz 770 ML | nome aparece no pedido do cliente |

---

## 🔵 Segurança e infraestrutura — só você pode

| # | o que falta | medido hoje |
|---|---|---|
| 14 | **Credenciais de terceiros em texto puro no banco** | `BORA_SEGREDO_COLUNAS` **não está definido** no servidor. O painel e o script `ligar-cifragem.sh` já existem e estão na máquina. **Eu não crio nem digito segredo.** |
| 15 | **Backup não sai da instância** | o `aws` **não está instalado** e o bucket não existe. O papel IAM já devolve credencial temporária — **nenhuma chave precisa ser criada**. Passo a passo em `bora-landing/deploy/LIGAR-BACKUP-S3.md` |

✅ **O token do webhook do Asaas está definido** em produção — conferi hoje.

---

## ✅ Fechados em 24/10 (os "11 defeitos abertos")

Todos no ar e conferidos byte a byte contra o servidor.

| # | o que era | o que mudou |
|---|---|---|
| 16 | A escolha **entrega/retirada sumia** quando a loja não tinha bairro cadastrado, e o HTML já traz ENTREGA marcada: loja de balcão recebia **todo** pedido como entrega com frete zero | a escolha aparece sempre; o padrão continua ENTREGA |
| 17 | Borda "opcional" que não dava para desmarcar | **já estava corrigido** desde 23/10 — conferi em vez de mexer de novo |
| 19 | Migração por foto escondida em Configurações | é **add-on pago**: trazê-la daria o recurso de graça. Produtos ganhou o ponteiro |
| 20 | Produtos mandava `estoque` no corpo do PUT | só vai na criação, onde é a quantidade inicial |
| 21 | Ajuda sem termos; nenhuma tela dizia **com que conta** você está | links na Ajuda + nome e papel no menu |
| 22 | Cadastro não mencionava os 7 dias grátis | passa a mencionar, com o preço de depois junto |
| 23 | **"Sorveteria da Rosa"** (loja de verdade) como exemplo em 7 telas | exemplo neutro + whitelabel cai no nome da sessão |
| 24 | Loja 17 sem `merchant_id` | **não é defeito de código**: é campo de integração, o painel já tem. Falta o ID real do marketplace |
| 26 | O **QR vinha de um site de fora** (`api.qrserver.com`) | desenhado aqui dentro (`assets/js/qr.js`), provado com leitor de QR de verdade |

Seguem abertos destes: **#25** (3 endpoints sem tela), que é backend.

### ✅ Fechado na v145 (24/10, no ar — backend `9b2268d`, frontend `e70a2b0`)

Conferi no ar depois de subir: imagem do container idêntica à tag `v145`, saúde `UP`, cardápio
público em 200, `ASAAS_WEBHOOK_TOKEN` ainda definido, backup de 3,3 MB tirado antes da troca.

| o que estava errado | o que mudou |
|---|---|
| **Aviso do Asaas desligava loja que já tinha pago.** O `prazoSemEncurtar` protegia a *data* de acesso, mas `ativo` é **outra chave** e ninguém a olhava. Medido: loja liberada até dezembro ficava com a data intacta e **sumia do aplicativo do cliente** (cardápio público em 404), enquanto o painel continuava abrindo para o lojista. Nada explicava | a guarda vale **só** para quem pagou por fora (`PAGAMENTO_MANUAL`) ou foi liberado por você (`LIBERACAO`). Quem pagava pelo Asaas e cancelou **continua saindo do ar** quando a carência acaba — senão viraria uso grátis sem fim. A assinatura é marcada `CANCELADA` nos dois casos |
| **O iFood não dizia por que o pedido caiu.** O painel gravava "Cancelado pelo marketplace": qualquer motivo que o iFood mandasse era descartado *por construção*. No mesmo painel a 99Food explicava e o iFood não — e é esse texto que decide se você liga para alguém ou refaz a comida | lê o motivo do `metadata` e também da raiz do evento (integração antiga não manda o envelope). Código sozinho **não** vira texto para o lojista, e payload estranho não trava o cancelamento |
| **A tela de Acerto de Entregadores estava morta** — defeito meu, não chegou a produção. Um comentário de HTML com crases **dentro** de uma template literal fechou a template e o arquivo inteiro parou de compilar: botão Buscar sem reação, Imprimir sem reação, modal sem abrir. O QA pegou antes do deploy | consertado, e agora existe um teste que carrega os 45 arquivos de `assets/js` e exige que cada um compile. Era a classe de defeito que nenhum teste pegava: erro de sintaxe não falha nada, só apaga a tela em silêncio no navegador do lojista |
| **Os papéis no menu eram inventados** — eu escrevi `BALCONISTA` e `ENTREGADOR`, que não existem. O `OPERADOR`, que é o papel mais comum da loja, aparecia cru e em caixa alta. E o teste que eu tinha escrito passava porque media o *fallback*, não o mapa | mapa casado contra o enum, com teste que falha se divergir |

#18 (webhook do Asaas falhando aberto) já havia subido na v143.

---

## ⚪ A lista de 23/10, reconferida contra o código de hoje (24/10)

**Eu escrevi aqui que "nenhum destes mexe em dinheiro". Estava errado:** o #17 cobrava R$ 8,00 que o
cliente não pediu e o #16 fazia a loja entregar de graça. E, ao ir atacar, **6 dos 10 já estavam
consertados** — a lista estava velha, não o código. Fui item por item:

| # | o que era | estado medido |
|---|---|---|
| 16 | Sem bairro, somia a RETIRADA junto com a taxa | ✅ **fechado** — `cardapio.js:342`, "A ESCOLHA ENTRE ENTREGA E RETIRADA APARECE SEMPRE", conferido no ar |
| 17 | Borda "opcional" que não dava para desmarcar (+R$ 8,00) | ✅ **fechado** — grupo opcional usa `checkbox`, não `radio`; conferido no ar |
| 19 | Importação por foto escondida no cartão de IA | ⬜ **não achei a funcionalidade** no código, só no roteiro de teste. Precisa de um olhar seu: ela existe mesmo? |
| 20 | Produtos mandava `estoque` no PUT | ✅ **fechado** — o corpo de edição não leva mais estoque |
| 21 | Ajuda sem termos, sem menu de usuário | ✅ **fechado** — `ajuda.html` aponta para os termos, e o `quemSouEu` está no `app.js` |
| 22 | Cadastro não mencionava os 7 dias grátis | ✅ **fechado** — `cadastro.html:28` |
| 23 | Fallback "Sorveteria da Rosa" | ✅ **fechado** — o nome só existe num comentário explicando o conserto |
| 24 | Loja 17 sem `merchant_id` | ⬜ **é dado seu** — sem ele não dá para testar marketplace fora da loja 1 |
| 25 | 3 endpoints sem tela | ✅ **2 de 3** — `pedido-bruto` em `configuracoes.html:433`, `diagnostico` em `integracoes.js`. Falta `fiscal/nfce`, e isso é latente: sem o token da Focus a emissão não existe |
| 26 | QR dependia de serviço de fora | ✅ **fechado** — nenhuma chamada a `api.qrserver.com` sobrou, conferido nos 3 arquivos **baixados de produção** |

---

## ✅ Os 4 achados do QA de hoje, consertados (24/10)

| o que estava errado | o que mudou |
|---|---|
| **O recado do marketplace durava 30 segundos.** Quando o marketplace recusa um status que você avançou no painel, a explicação ia para `ultimo_erro` — e o polling, que roda a cada 30s, apagava. Você tinha meio minuto para ver, e só com a tela aberta na hora. E o estrago continua: na 99 a ordem dos status é obrigatória, então os status seguintes do mesmo pedido também são recusados. Você vê tudo verde e lá dentro o pedido ficou parado | coluna própria (**V61**: `ultimo_aviso` + a hora). O polling limpa só a saúde da integração. O único jeito de apagar o recado é você clicar em "Já vi", com linha de auditoria. O diagnóstico também parou de dizer "Nenhum erro registrado" com um pedido parado |
| **"Por forma de pagamento" estava fragmentado.** Medido na produção: `Pix` (12) e `PIX (pago)` (1) em duas linhas; `Dinheiro` (3) e `Dinheiro (atualizado)` (2) em outras duas; `CREDIT` (5) em inglês; e uma linha cujo rótulo é a frase *"Pago online: Crédito Visa R$ 17,00 + Pago online: Crédito Master R$ 10,00"*. Dez linhas na tela em que você confere o dinheiro do dia | agrupamento normalizado (`boraFormaPagamento`, no `app.js`). **O total não muda** — é a primeira coisa que o teste cobra. Forma desconhecida mantém o próprio nome, para não esconder uma forma nova de pagamento |
| **O cartão do KDS escondia o canal.** Com a forma de pagamento preenchida, a origem nunca aparecia: pedido do iFood pago em crédito dizia só "Crédito". E isso muda o que o operador faz — pedido de marketplace não se liga para o cliente, e o cancelamento é por lá | saem os dois, forma e canal. Com guarda, para um rótulo de pagamento não derrubar o quadro da cozinha |
| **O iPhone dava zoom no checkout do cliente.** O Safari amplia a página quando o campo tocado tem letra menor que 16px, e não volta. Os campos não declaravam tamanho e ficavam nos ~13px do padrão: o cliente tocava em "Seu nome" e o checkout ficava ampliado e cortado, no meio do pedido | 16px nos campos. **Não travei o zoom** com `maximum-scale` — isso tiraria a ampliação de quem precisa de letra maior, por um descuido nosso de 3px |

Testes: **1030 no backend** (incluindo 3 ITs novos contra Postgres de verdade) e **480 no frontend**,
0 falhas. 8 mutantes conferidos, todos pegos.

**Falta subir:** a API (com a migração V61) e 5 arquivos de frontend.

### ⬜ Ainda aberto deste lote

`FiscalService.java:80-84` devolve o erro da Focus sem tradução — 500 cru para o lojista. Latente:
sem o token da Focus configurado, a emissão não acontece. Vai no mesmo deploy quando você mandar.

---

## Nota fiscal

Latente, não quebrada: o token da Focus vive em `config_plataforma` (`fiscal.focus-token`) e
**não está configurado**. Enquanto não estiver, a emissão não existe — não é defeito, é
funcionalidade não ligada. Detalhe em `NOTA-FISCAL.md`.
