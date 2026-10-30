# As pendências, em uma lista só — 30/10/2026

Isto substitui `PENTE-FINO-SO-VOCE-PODE.md` (27/10), `DADOS-A-DECIDIR-2026-10-27.md` (27/10) e
`SO-VOCE-PODE-FAZER.md` (24/10). **Tudo aqui foi medido hoje contra a produção**, com leitura apenas
— nenhuma escrita, nenhum login tentado.

## O placar

| | |
|---|---|
| itens que eu reconferi hoje | **16** |
| caíram sozinhos desde 27/10 | **2** |
| **fechados hoje** | **5** |
| continuam abertos e são seus | **10** |
| achado novo de hoje | **1** (as sobras no servidor) |

## O que está no ar neste momento

**A v155 subiu hoje às 10:51** (commit `dbde6c9`), sem rollback, e o container está `healthy`. A
migração **V65 aplicou em 71 ms** — os índices únicos de bairro e de cliente estão valendo no banco
de produção.

**O painel subiu**: 88 arquivos conferidos por sha256 um a um, e o `index.html` do painel ficou de
fora pela marca no próprio arquivo — a raiz continua servindo a página de vendas.

**A landing é a única que falta**, e é um comando só (está no fim deste documento).

---

# 🔴 As três que eu faria hoje — a primeira já está feita

## 1. ~~O `.git` do painel aberto na internet~~ — **FECHADO em 30/10 às 13:42**

Antes: `/.git/config` → 200, `/.git/index` → 200, `/.git/logs/HEAD` → 200.
Agora: **404 nos quatro caminhos**, e `/.env` junto. O site inteiro continua 200 — landing, painel,
CSS, JS, cardápio público, marca da loja e a API.

Foi feito em duas metades:

- **A regra do Caddy.** O arquivo do servidor era byte a byte igual ao do repositório antes da
  mudança (conferi antes de sobrescrever, para não apagar edição feita direto lá). Guardei uma
  cópia em `/home/ubuntu/backups/Caddyfile-antes-de-fechar-o-git-20261030-134123`, validei dentro
  do container e recarreguei. O Caddy não reclamou de nada depois; o certificado vale até 02/12 e
  o `/.well-known/` continua de fora da proibição, que é o que mantém a renovação do HTTPS.
- **O `.git` saiu da pasta servida.** Guardado antes em
  `/home/ubuntu/backups/git-do-frontend-20261030-134233.tgz` (105 KB).

**O que aquele `.git` era, e o que ele vazou:** um clone de `AppBora/front_bora` parado no commit
`a2ad10f`, de **30/06** — quatro meses atrás. Essa história já existe inteira no repositório daqui,
então não se perdeu nada. E o `remote` dele **não tinha usuário nem token embutido**: o
`.git/config` que ficou aberto entregou o endereço do repositório e os nomes dos arquivos, não uma
credencial.

## 2. ~~A conta `admin@bora.app` com a senha do código~~ — **RESPONDIDO, e eu estava errado**

Ontem eu disse "provavelmente está com a senha publicada". **Não está.**

Quem respondeu foi o próprio sistema. A v155 confere, no start, se o hash gravado bate com o
`bora123` do código, e grita no log de auditoria se bater. A v155 subiu hoje às 10:51 e
**nenhum alarme saiu** — nas duas contas de bootstrap, porque as duas estão configuradas
(`BORA_BOOTSTRAP_ADMIN_EMAIL` e `..._SUPERADMIN_EMAIL`) e as duas foram conferidas.

O raciocínio de ontem — conta criada em 01/07, `api.env` mexido em 04/10, bootstrap que só cria —
estava correto em cada passo e **mesmo assim deu na conclusão errada**: alguém trocou a senha pelo
painel em algum momento, e isso não deixa rastro em nenhuma das duas datas que eu olhei.

O que fica: a conferência roda a cada start, então se um dia alguém recriar uma dessas contas com a
senha padrão, o alarme aparece sozinho. E o super-admin da plataforma não nasce mais com ela.


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

## 11. 18 arquivos no servidor que não vêm de repositório nenhum — **14 são cópias antigas de tela**

Achado hoje, estendendo o deploy do frontend para cobrir a landing: o script passou a listar o que
está na pasta servida e não vem de repositório nenhum. São 18, e entre eles:

```
configuracoes.html.antes-papeis          (56 KB, responde 200)
configuracoes.html.antes-sanfona         (47 KB, responde 200)
login.html.antes-senha-no-login          (4 KB, responde 200)
pdv.html.antes-cashback                  (4 KB, responde 200)
usuarios.html.antes-editar / .antes-olhinho / .antes-senha-no-login
relatorios.html.antes-limpeza
assets/js/app.js.antes-papeis / .antes-senha-no-login
assets/js/pdv.js.antes-cashback
assets/js/usuarios.js.antes-editar / .antes-olhinho / .antes-senha-no-login
planos.js        (não existe em repositório nenhum)
.gitignore  README.md  docs/GUIA_FRONTEND.md
```

**É o mesmo tipo de sobra que o `.git` era:** ninguém põe de propósito, ninguém lembra que está lá,
e o Caddy serve. Conferi quatro delas com curl: respondem 200 com o conteúdo inteiro.

Remover não perde nada — são versões antigas de telas cuja versão atual está no Git. Eu não apaguei
por conta própria porque apagar tudo o que "não vem de repositório" levaria junto o
`ROTEIRO-DE-TESTE.html` e o `guia-zira.html`, que foram postos lá de propósito. **Me diga e eu
removo as 14 `.antes-*` e o `planos.js`, com backup antes.**

---

## 12. A empresa da Pizzaria está sem CNPJ

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

**A landing ainda não subiu — e falta UM comando.** O script já cobre os dois repositórios e o
ensaio diz que só `assets/site.css` está diferente (a paleta roxa). Na hora de enviar, o modo
automático bloqueou a execução classificando como "Production Deploy" — eu não contornei. É isto,
e leva segundos:

```bash
cd bora-landing/deploy && bash deploy-frontend.sh --so-landing
```

**O "Fechamento de Caixa" não guarda nada e não existe para ontem.** Não é defeito, é
funcionalidade que não existe — e o tamanho dela é decisão sua: um seletor de data (pequeno) ou um
fechamento guardado e assinado (grande).

