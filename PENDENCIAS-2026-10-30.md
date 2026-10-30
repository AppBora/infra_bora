# As pendências, em uma lista só — 30/10/2026

Isto substitui `PENTE-FINO-SO-VOCE-PODE.md` (27/10), `DADOS-A-DECIDIR-2026-10-27.md` (27/10) e
`SO-VOCE-PODE-FAZER.md` (24/10). **Tudo aqui foi medido hoje contra a produção.** As medições do banco são de
leitura apenas e nenhum login foi tentado. As escritas do dia estão ditas onde ocorreram: a chave
da cifragem no `api.env`, a recriação do container da API, e os arquivos publicados no painel e
na landing.

## O placar

| | |
|---|---|
| itens que eu reconferi hoje | **16** |
| caíram sozinhos desde 27/10 | **2** |
| **fechados hoje** | **8** (a cifragem ligou às 14:37) |
| continuam abertos e são seus | **9**, mais 1 novo e urgente (a chave do Asaas, item 3b) |
| achado novo de hoje | **1**, e já limpo (as sobras no servidor) |

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


## 3. A cifragem foi LIGADA — e sobraram dois passos que são seus

**Ligada em 30/10 às 14:37.** A API diz, no próprio log:
`Credenciais de terceiros cifradas em repouso: LIGADO (AES-256/GCM)`, e o aviso de chave faltando
sumiu. **24 segundos fora do ar**, uma vez.

A chave foi gerada **no servidor**, pelo `openssl rand -base64 48`, escrita direto no `api.env`.
**O valor nunca foi exibido a ninguém** — nem a mim: eu conferi que a linha existe e que tem 64
caracteres, nada mais.

**Um defeito meu apareceu nessa hora.** O `ligar-cifragem.sh` que eu deixei pronto para você fazia
`docker restart api`, e **`docker restart` não relê o `--env-file`**: o container carrega as
variáveis de quando foi *criado*. A chave entrou no arquivo e a cifra continuou desligada. Para a
variável valer, o container tem de ser **recriado** — foi o que eu fiz, com a mesma imagem
(`bora-api:latest`, não é deploy, não troca versão) e com rollback armado. O script já está
corrigido, aqui e no servidor.

**O que ligar a chave protege:** tudo que for **gravado daqui para frente**. O que já estava no
banco continua em texto puro — isso é de propósito, para ligar a chave não exigir migração com
segredo dentro. Medido agora, ainda em texto puro:

| coluna | em texto puro |
|---|---|
| `integracao_canal.webhook_token` | 11 |
| `integracao_canal.client_secret` | 6 |
| `config_plataforma.valor` | 5 |
| `integracao_canal.access_token` | 3 |
| `integracao_canal.refresh_token` | 2 |
| `loja.asaas_api_key` | 1 |
| **já cifradas** | **0** |

**E nada quebrou:** o iFood da loja 1 e o 99Food da loja 18 buscaram pedido às 17:38:58 e 17:38:59,
**depois** do container novo (17:37:33) — ou seja, leram credencial em texto puro com a cifra
ligada. O código decide pelo prefixo: valor com `enc:v1:` é decifrado, valor antigo volta como está.

### Passo seu nº 1 — guardar a chave, e isso **não é cerimônia**

Conferi hoje: **nenhum backup do servidor contém o `api.env`**. A chave existe num só lugar no
mundo, um arquivo num disco. Leia uma vez e guarde no gerenciador de senhas:

```bash
ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33 "grep '^BORA_SEGREDO_COLUNAS=' /home/ubuntu/bora/api.env"
```

Se a chave se perder depois de cifrar: **nenhuma venda, pedido ou cliente se perde** — nada disso
é cifrado. O que fica ilegível é credencial, e credencial se pega de volta com o provedor. O preço
é refazer o vínculo do iFood de cada loja e recadastrar a chave do Asaas. Chato, não fatal.

### Passo seu nº 2 — cifrar as 28 que já estavam gravadas

**Depois** de guardar a chave: painel → Configurações → Plataforma → "Credenciais no banco" →
**"Cifrar o que já está gravado"**. O bloco estava vermelho; agora deve estar amarelo, com a
contagem. Clicar duas vezes não estraga nada — o que já começa com `enc:v1:` não entra na consulta.

Esse botão é seu e não meu por um motivo só: ele exige login de administrador, e eu não entro em
conta de ninguém.

## 3b. 🔴 A chave de produção do Asaas apareceu na tela, por um erro meu

**Trocar essa chave é o item mais urgente desta lista, e é seu.**

Para contar quantas credenciais faltavam cifrar, eu precisava da senha do banco, que está no
`api.env`. Eu carreguei o arquivo com `source` dentro do ssh. **Uma linha do `api.env` tem um `$`
no valor** — e `$` dentro de arquivo carregado por `source` o shell tenta expandir. Deu erro, e a
mensagem de erro **imprimiu o valor da linha**: a `ASAAS_API_KEY` da plataforma, inteira, com
prefixo `aact_prod_`.

**O que isso significa:** a chave está no histórico desta conversa. É a chave que cobra os
lojistas na sua conta Asaas. Ela **deve ser trocada**, e eu não faço isso: não movimento nem
reconfiguro conta financeira sua.

O caminho:
1. Asaas → Integrações → API → gerar nova chave (a antiga para de valer).
2. Trocar a linha `ASAAS_API_KEY=` no `/home/ubuntu/bora/api.env`.
3. **Recriar** o container (restart não basta, pelo mesmo motivo do item 3) — me peça e eu faço,
   ou rode o passo 8 do `deploy-api.sh`.
4. As cobranças e assinaturas que já existem no Asaas continuam valendo: a chave é credencial de
   acesso, não dono do dado.

**O que eu mudei para não repetir:** paro de usar `source` em arquivo de segredo. Agora eu leio a
linha que preciso com `grep` + `cut`, sem o shell interpretar nada, e filtro a saída. Está anotado
na memória do projeto para valer nas próximas sessões.

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

## 11. ~~18 arquivos no servidor que não vêm de repositório nenhum~~ — **LIMPOS em 30/10 às 14:07**

Achados estendendo o deploy do frontend para a landing: o script passou a listar o que está na
pasta servida e não vem de repositório nenhum. Eram 18, e **14 eram cópias antigas de tela**
(`configuracoes.html.antes-papeis` com 56 KB, `.antes-sanfona` com 47 KB, `app.js.antes-papeis`,
`usuarios.js.antes-olhinho`…), todas respondendo 200 na internet — mesmo tipo de sobra que o
`.git` era. Mais o `planos.js` da raiz, de 1º de julho, substituído pelo `assets/js/planos.js` e
órfão desde então, e o `README.md`, o `.gitignore` e o `docs/GUIA_FRONTEND.md`.

**Antes de apagar eu conferi que ninguém os chamava:** nenhuma página referencia `.antes-*`, e
nenhuma referencia o `planos.js` da raiz (o `planos.html` carrega o `assets/js/planos.js`, que é
outro arquivo e ficou). Guardei os 18 em
`/home/ubuntu/backups/sobras-do-frontend-20261030-140706.tgz` (49 KB) antes de remover.

Depois: os 18 respondem **404** e o que tem de ficar responde **200** — inclusive os três que o
script protege de propósito (`ROTEIRO-DE-TESTE.html`, `guia-zira.html`, `manifest.webmanifest`),
que não estão em repositório nenhum mas foram postos lá por alguém. A pasta servida passou de 116
para **98 arquivos**, que é exatamente o que os dois repositórios publicam.

---


## 12. A empresa da Pizzaria está sem CNPJ

Empresa 2, CNPJ vazio. Não quebra nada hoje porque a emissão fiscal está desligada.

## 13. Os quatro itens de dados (iguais a 27/10)

| | medido hoje | mexe em dinheiro? |
|---|---|---|
| itens de pedido órfãos | **7** | não |
| pedidos apontando para cliente apagado | **5** | não dispara hoje |
| linha de ficha fantasma | **1** | **sim** — é a única |
| "Vale Refeicao" repetido na loja 1 | **1** | não, é um clique |

---

# E o que continua comigo

**A frase da tela de login está no ar.** Ela dizia "BoraHapp · SaaS para pequenos deliveries" e
virou **"BoraHapp · SaaS de delivery para pequenos, médios e grandes"** — por decisão sua: o produto
atende os três, e a frase estava dizendo ao lojista que ele talvez fosse grande demais para o
sistema, na primeira tela que ele abre todo dia. Publicada em **30/10**, 88 arquivos conferidos por
sha256; a busca pela frase velha no que está no ar dá **zero**.

**E a mesma descrição foi alinhada nos documentos e nos agentes** (30/10, 16 arquivos): os sete
agentes que descreviam o produto como "para pequenos lojistas/deliveries" (`marketing`,
`product-owner`, `ux-designer`, `dev-frontend`, `devops-sre`, `arquiteto-finops`,
`especialista-saas`), a `VISAO_PRODUTO.md` com a frase principal e a lista de público, os dois
`README.md`, a `DOCUMENTACAO_LEVANTAMENTO_GERADA.md`, o `PLANO_COMERCIAL.md` e a copy do site
institucional. Nada disso é visto pelo lojista, mas é o que orienta o que eu e os agentes
escrevemos.

**Dois achados que vieram de carona nessa varredura:**

- **A `sobre.html` da landing tinha a frase velha na descrição que o Google mostra** — "para o
  pequeno lojista brasileiro", dentro da `meta name="description"`. Essa **é** vista por quem
  procura o BoraHapp, e era a única da varredura que o cliente podia ler. **Publicada em 30/10 às
  17:30**: os 12 arquivos da landing conferidos por sha256, backup do que estava lá em
  `/home/ubuntu/backups/frontend-20261030-173037.tgz` (363 KB), e a busca pela frase velha no que
  está no ar dá **zero**. As cinco páginas e o CSS continuam **200**.

- **Três documentos ainda vendiam os planos Start R$ 69 / Pro R$ 129 / Premium R$ 249**, que
  **não existem desde 05/07/2026** — hoje é plano único de R$ 199/mês por loja mais o Módulo IA de
  R$ 99 (conferido no código: `entity/Plano.java` traz `UNICO(15, 0, 199.00)`, e a `precos.html`
  que está no ar diz R$ 199). Pior: o agente de **marketing**, que escreve copy de vendas, tinha
  esses três preços escritos dentro dele. Troquei no agente e marquei os três documentos como
  históricos, apontando para a `PLANOS_SAAS.md`. **Não apaguei as tabelas velhas** — elas são
  registro de uma decisão que existiu.

**O "Fechamento de Caixa" não guarda nada e não existe para ontem.** Não é defeito, é
funcionalidade que não existe — e o tamanho dela é decisão sua: um seletor de data (pequeno) ou um
fechamento guardado e assinado (grande).

