# Só você pode fazer — 24/10/2026

Tudo o que era meu foi feito. O que sobrou nesta lista depende de uma senha, de uma decisão sua,
ou de um dado que só a loja tem. **Nenhum item aqui eu consigo destravar sozinho.**

Cada número foi lido na produção hoje.

---

## 1. ✅ A Zirá NÃO sai mais do ar — resolvido em 24/10 às 16:08

Você clicou, e eu conferi no banco. **Medido depois:**

| chave | antes | agora |
|---|---|---|
| `acesso_ate` | `2026-10-26 00:58 UTC` (sáb 25/10, 21:58 BRT) | **`2027-01-24 02:59 UTC`** = **23/01/2027 às 23:59 BRT** |
| `acesso_motivo` | `PAGAMENTO_MANUAL` | **`LIBERACAO`** |
| `ativo` | `t` | `t` |

Cardápio público conferido no ar: `GET /public/loja/18/cardapio` → **HTTP 200**, 26.529 bytes,
nome "Zirá Açaíteria". O cliente final abre.

**Foram dois cliques.** O primeiro (16:06) pegou a data que a tela já vinha pré-preenchida —
`2026-11-23`, 30 dias — porque o campo vem pronto e é fácil aceitar como está. O segundo (16:08)
corrigiu para `2027-01-23`. Duas linhas no log de auditoria, as duas do `usuario 30`.

**O que o `LIBERACAO` te dá:** a guarda que subiu na v145 no mesmo dia impede que um aviso do Asaas
desligue loja com esse motivo. Antes dela, o Asaas podia tirar a loja do ar por trás com a data
intacta — foi o defeito que fechei hoje.

### Duas coisas que ficaram em aberto

- **O motivo gravado foi "Anderson".** O log diz `Motivo: Anderson`. O servidor aceita porque só
  exige texto não-vazio. Mas o log já identifica *quem* fez (`usuario 30`) — o campo é o *por quê*,
  e daqui a três meses "Anderson" não explica a decisão. Se quiser, clique de novo com um texto que
  se explique sozinho; a data não muda se você repetir `2027-01-23`.
- **Isso devolveu acesso e não religou cobrança.** A assinatura 4 segue `CANCELADA` (R$ 298/mês).
  Nada vai cobrar sozinho até 23/01/2027, e aí ela vence de novo.
- **R$ 398 não fecha com R$ 298/mês.** Ela pagou 2 × R$ 199 em 15/10 (sem estorno), um registro
  `manual:18:2026-10-15` ("PIX direto na conta") e um do Asaas (`pay_aj14zjq8wbcfqhfx`), **com o
  mesmo instante de pagamento**. Pode ser R$ 398 reais, ou o mesmo dinheiro contado duas vezes no
  faturamento. Só a sua conta no Asaas separa isso.

---

## 2. 🟠 A Zirá ainda não tem estoque funcionando

A ordem importa: **montar as fichas antes de lançar a contagem apaga o cardápio inteiro** para o
cliente (o sistema marca como esgotado o produto cuja ficha não dá para fazer).

| passo | o que é | estado medido |
|---|---|---|
| 1 | **Lançar a contagem dos insumos** (tela Estoque) | 42 dos 43 em **estoque 0** |
| 2 | **Preencher o custo de cada insumo** | 42 dos 43 em **R$ 0,00** |
| 3 | **Importar o cardápio** — cole `atualizacao-zira/cardapio-impresso-para-colar.txt` em Produtos → Importar | **13 a criar, 10 a atualizar** |
| 4 | **Montar as fichas técnicas** (Produtos → 🧪) | **0 fichas** para 35 produtos |
| 5 | **Ligar os adicionais aos insumos** | **397 adicionais, 0 ligados** |

**Por que o passo 2 não é detalhe:** sem custo de insumo, **CMV e margem saem errados** — margem
100%, CMV zero. E metade do valor de uma venda de açaí está nos adicionais: sem o passo 5, granola
e leite condensado somem da prateleira sem o sistema saber.

**Eu posso montar as fichas** (passo 4) se você me passar as quantidades reais — quanto de polpa
vai no copo de 300, 500, 770 e no pote. Isso só a Zirá sabe; eu não tenho como medir.

A regra inteira está em `COMO-FUNCIONA-ESTOQUE-E-FICHA.md`.

---

## 3. 🟡 Sete decisões sobre o cadastro da Zirá

Todas medidas hoje. São decisões de negócio, não de código.

| o que eu medi | a decisão |
|---|---|
| **35 de 35 produtos sem custo cadastrado** | é dado de dono; inventar estragaria o CMV |
| **"Monte Seu Açaí" cobra R$ 100,00 num açaí de 300ml** (base R$ 90 + copo obrigatório) | zerar a base? o importador recusa preço 0, então é na mão |
| Depois do import, **"Ziraçoca", "Ziraniho" e "Ziratella"** antigos viram repetidos | desmarcar "ativo" nos três |
| **Morango não está** nos adicionais do "Monte Seu Açaí", e o papel lista morango em FRUTAS | acrescentar? |
| A categoria **`mantimento`** (leite condensado, paçoca) **aparece para o cliente** | parece insumo virado produto |
| O açaí de **5L está cadastrado duas vezes** por R$ 65,00 | qual fica |
| **Copo do Patrão**: cadastro diz 700ml, o papel diz **770 ML** | o nome aparece no pedido do cliente |

---

## 4. 🔵 Duas de infraestrutura

| o que falta | medido hoje | por que não sou eu |
|---|---|---|
| **Credenciais de terceiros em texto puro no banco** | `BORA_SEGREDO_COLUNAS` **não está definido** no servidor | **eu não crio nem digito segredo** — essa linha eu não cruzo. O painel e o `ligar-cifragem.sh` já estão prontos na máquina |
| **Backup não sai da instância** | o `aws` **não está instalado** e o bucket não existe | é conta sua na AWS. **Nenhuma chave precisa ser criada** — o papel IAM já devolve credencial temporária. Passo a passo em `bora-landing/deploy/LIGAR-BACKUP-S3.md` |

✅ O token do webhook do Asaas **está** definido — conferi hoje.

---

## 5. ⚪ Duas decisões sem prazo

- **Nota fiscal (NFC-e):** o código está pronto e testado, mas o botão não existe de propósito —
  depende de você ligar o módulo e configurar a chave da Focus (`fiscal.focus-token`). Combinamos
  ligar só quando a plataforma passar de R$ 5 mil/mês livres. Detalhe em `NOTA-FISCAL.md`.
- **Loja 17 sem `merchant_id`:** o campo existe no painel (Integrações). Falta o ID real do
  marketplace — sem ele não dá para testar pedido de marketplace fora da loja 1.

---

## O que foi feito hoje, e não precisa de você

Os **11 defeitos abertos** da lista de 23/10: 9 corrigidos e no ar, 1 já estava corrigido, 1 não
era defeito de código. Mais o #25 (duas funções prontas que nenhuma tela alcançava) e o #18
(webhook do Asaas falhando aberto).

Detalhe de cada um em `PENDENCIAS-2026-10-24.md`.
