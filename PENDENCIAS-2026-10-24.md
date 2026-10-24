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

## ⚪ Defeitos abertos que são meus (da lista de 23/10)

Nenhum destes mexe em dinheiro. Os quatro que mexiam já estão no ar.

| # | o que é |
|---|---|
| 16 | **Sem bairro cadastrado, some a RETIRADA junto com a taxa** — loja de balcão recebe tudo como entrega com frete zero |
| 17 | **Borda "opcional" que não dá para desmarcar**: depois do primeiro toque vira obrigatória e o cliente leva +R$ 8,00 que não pediu |
| 19 | Importação por foto **escondida** dentro do cartão de IA em Configurações |
| 20 | Produtos ainda manda `estoque` no corpo do PUT (inofensivo hoje porque o servidor ignora de propósito) |
| 21 | **Ajuda não menciona os termos**, e não existe menu de usuário mostrando com que conta você está |
| 22 | **Cadastro não menciona os 7 dias grátis** que a landing promete em 6 lugares |
| 23 | Fallback do nome da loja é **"Sorveteria da Rosa"** — risco, não defeito ativo (0 de 5 lojas com nome vazio) |
| 24 | A **loja 17 está sem `merchant_id`**, então não dá para testar marketplace fora da loja 1 |
| 25 | **3 endpoints que nenhuma tela chama**: `pedido-bruto`, `diagnostico`, `fiscal/nfce` |
| 26 | **O QR depende de um serviço de fora** (`api.qrserver.com`). Se ele cair, nenhuma loja imprime cardápio |

✅ **Corrigido e no ar (confirmei hoje):** a lista-branca do `GET /admin-bora/config` (commit
`94ec8fa`, 23/10 13:39; a API no ar é de 23/10 19:42, depois disso).

---

## Nota fiscal

Latente, não quebrada: o token da Focus vive em `config_plataforma` (`fiscal.focus-token`) e
**não está configurado**. Enquanto não estiver, a emissão não existe — não é defeito, é
funcionalidade não ligada. Detalhe em `NOTA-FISCAL.md`.
