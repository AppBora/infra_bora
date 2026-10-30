# As pendências, em uma lista só — 30/10/2026

Isto substitui `PENTE-FINO-SO-VOCE-PODE.md` (27/10), `DADOS-A-DECIDIR-2026-10-27.md` (27/10) e
`SO-VOCE-PODE-FAZER.md` (24/10). **Tudo aqui foi medido hoje contra a produção**, com leitura apenas
— nenhuma escrita, nenhum login tentado.

## O placar

| | |
|---|---|
| itens que eu reconferi hoje | **16** |
| caíram sozinhos desde 27/10 | **2** |
| **fechei hoje** | **2** |
| continuam abertos e são seus | **12** |
| mais, do pente fino de ontem | **3** |

## O que está no ar neste momento

A API em produção é o commit **786c12d, de 28/10 às 11:57** — a v154. **Nada do dia 29 nem do dia 30
subiu.** O painel no ar tem o botão desabilitado (de 28/10) mas não tem o menu do celular nem os
contrastes; a landing no ar ainda é a laranja.

---

# 🔴 Primeiro, as três que eu faria hoje

## 1. O `.git` do painel continua aberto na internet

Medido agora: `/.git/config` → **200**. A regra do Caddy está escrita, validada e ensaiada. São três
comandos e eu rodo quando você mandar — estão em `PENTE-FINO-CONSERTADO-2026-10-29.md`.

## 2. A conta `admin@bora.app` provavelmente está com a senha que está publicada no código

Isto mudou de "não dá para saber" para "provavelmente sim", e foi medindo duas datas:

- a conta foi **criada em 01/07/2026**, está **ativa**, é **ADMINISTRADOR_LOJA da loja 1**;
- o arquivo de variáveis do servidor foi mexido pela última vez em **04/10/2026** — três meses depois.

O bootstrap **só cria**: ele nunca troca a senha de uma conta que já existe. Então definir a variável
depois não mudou nada, e o hash gravado continua sendo o de `bora123` — que está no
`BootstrapAdmin.java`, linha 34, em texto.

**Não tentei o login** (não é coisa que eu faça). Mas a partir da v155 o próprio sistema responde:
no start, ele compara o hash gravado com a senha do código e **grita no log de auditoria** se bater.
Também parei de deixar o super-admin da plataforma nascer com ela.

**O que fazer:** Usuários → redefinir a senha dessa conta. Um minuto. Ou desative, se ninguém usa.

## 3. 28 credenciais em texto puro no banco

Medido hoje, contagem por coluna (nenhum valor lido):

| coluna | em texto puro |
|---|---|
| `integracao_canal.webhook_token` | 11 |
| `integracao_canal.client_secret` | 6 |
| `config_plataforma.valor` | 5 |
| `integracao_canal.access_token` | 3 |
| `integracao_canal.refresh_token` | 2 |
| `loja.asaas_api_key` | 1 |

**Exatamente o mesmo número de 27/10.** `BORA_SEGREDO_COLUNAS` continua **ausente** no servidor. A
cifragem existe, tem tela, tem endpoint e tem teste — a chave nunca foi criada.

A ordem é: criar a chave → reiniciar → só então o botão "Cifrar o que já está gravado". O endpoint
recusa enquanto a chave estiver desligada, de propósito.

---

# ✅ As duas que caíram sozinhas

**A landing está no ar.** A raiz de `borahapp.com.br` serve a página de vendas. *(era o item 1)*

**"Monte Seu Açaí" não anuncia mais R$ 100,00.** Medido no cardápio público das três lojas da Zirá:
base **R$ 0,00** e recipiente mais barato **R$ 12,90**. O cartão agora diz "a partir de R$ 12,90".
*(era o item 11)*

# ✅ As duas que eu fechei hoje

**`taxa_entrega` e `cliente` ganharam os índices únicos que faltavam (V65).**

Eu tinha dito que esses dois precisavam de você porque exigiriam limpar dados antes. **Fui medir, e
não há o que limpar:** bairro repetido → 0 grupos; cliente com telefone repetido → 0; cliente com id
externo repetido → 0. Então a porta fecha antes de a primeira duplicata nascer.

A migração de cliente **não junta cliente duplicado**: se um dia encontrar, ela para com uma
mensagem dizendo o que fazer. Juntar dois clientes junta saldo de cashback, e isso não é decisão de
migração.

---

# 🟠 Operação — três integrações e um cadastro

## 4. O iFood da loja 17 nunca buscou um pedido

| | |
|---|---|
| estado | `ativo`, conectado |
| token | **venceu em 07/10 — 23 dias** |
| merchant_id | **não tem** |
| último polling | **nunca** |

O erro gravado diz: *"Nenhum pedido do iFood vai entrar: falta o Merchant ID"*. **Caminho:**
Integrações → iFood → Conectar, e autorizar no portal.

## 5. O 99Food da plataforma continua recusado

Loja 1, canal NOVE_NOVE: **ativo**, sem `client_secret`, e o polling rodou **hoje** com
*"A 99Food recusou a credencial: confira o App Shop ID desta loja e o App Secret da plataforma"*.

Enquanto estiver assim, **nenhum pedido do 99Food entra na Sorveteria da Rosa**. Há tela:
Configurações → 🔑 Credencial do app BoraHapp nos marketplaces.

## 6. Quatro das cinco lojas entregam de graça

Medido hoje: **loja 1 tem 4 bairros; 17, 18, 19 e 20 têm zero.** Sem bairro cadastrado o frete sai
R$ 0,00 — inclusive nas três lojas pagantes da Zirá. É cadastro, não código.

## 7. Dois insumos estão à venda no cardápio da Zirá

Medido no cardápio público da loja 18, agora: categoria **"mantimento"**, com `leite condensado`
**R$ 3,00** e `pacoca` **R$ 2,50**, os dois ativos. O cliente final vê isso. As lojas 19 e 20 não
têm. É cadastro: desative os dois em Produtos.

## 8. Cinco contas de teste ativas, três delas GERENTE

| papel | ativas | de teste |
|---|---|---|
| ADMINISTRADOR_BORA | 2 | 0 |
| ADMINISTRADOR_LOJA | 3 | **1** |
| GERENTE | 5 | **3** |
| OPERADOR | 1 | **1** |

GERENTE vê faturamento, custo, margem e lucro, apaga cliente e apaga pedido. Revogar é imediato:
Configurações → Usuários → desativar.

---

# 🟡 Decisões, sem pressa

## 9. A taxa de 2% do PIX não cobra de ninguém

Medido: `ASAAS_TAXA_PERCENTUAL = 0`. Os fundadores deviam ser a exceção isenta; hoje **todos** são.

As duas saídas se excluem: **ligar os 2%** exige mudar a `precos.html` antes, porque ela diz hoje
*"nunca uma porcentagem das suas vendas"*; **não ligar** deixa a copy correta e o split vira código
que não se usa. Hoje a copy é verdadeira por acidente.

## 10. A loja de QA mora em produção

Loja 1 ("Sorveteria da Rosa", nome de sistema "BoraQATest"): **28 dos 36 pedidos do banco** e
**R$ 759,41 de R$ 1.091,91**. Qualquer número agregado da plataforma é, hoje, principalmente ela.

Melhorou um pouco desde 27/10 — não porque ela encolheu, mas porque entraram 3 pedidos reais
(loja 17 com 4, loja 18 com 3, loja 20 com 1). Limpar a movimentação dela, arquivá-la, ou aceitar e
lembrar disso ao ler relatório.

## 11. A empresa da Pizzaria está sem CNPJ

Empresa 2, CNPJ vazio. Não quebra nada hoje porque a emissão fiscal está desligada.

## 12. Os quatro itens de dados (iguais a 27/10)

| | medido hoje | mexe em dinheiro? |
|---|---|---|
| itens de pedido órfãos | **7** | não |
| pedidos apontando para cliente apagado | **5** | não dispara hoje |
| linha de ficha fantasma | **1** | **sim** — é a única |
| "Vale Refeicao" repetido na loja 1 | **1** | não, é um clique |

---

# E o que continua comigo

**O "Fechamento de Caixa" não guarda nada e não existe para ontem.** Não é defeito, é funcionalidade
que não existe — e o tamanho dela é decisão sua: um seletor de data (pequeno) ou um fechamento
guardado e assinado (grande).

**O deploy.** Está tudo commitado e testado — **1.335 testes de backend, 211 de integração contra um
Postgres de verdade, 660 do frontend, zero falhas.** Quando você mandar:

```bash
cd bora-landing/deploy && bash deploy-api.sh v155
```

```bash
cd bora-landing/deploy && bash deploy-frontend.sh --ensaio
```

A landing também mudou e é publicada à parte — ela ainda não tem script. Se quiser, eu estendo o
`deploy-frontend.sh` para cobrir os dois.
