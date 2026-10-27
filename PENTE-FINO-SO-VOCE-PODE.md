# Pente fino 26/10 — o que só você pode fazer

Esta lista é a parte da varredura que **não depende de código**: é senha, credencial, chave ou decisão
sua. Está separada do resto de propósito, porque é a que pode ser feita hoje, sem deploy.

Cada item diz o que eu **medi** e o que eu **não consegui medir**. Nenhum segredo está impresso aqui.

---

## 1. 🔴 A sua landing page não está no ar

**Medido agora:**

```
curl https://borahapp.com.br/   →  48 bytes
<script>location.href="dashboard.html"</script>
```

A landing de verdade tem **30.371 bytes** e **não está publicada sob nome nenhum** (procurei por
`landing.html`, `home.html`, `site.html`, `inicio.html`). O `index.html` do painel sobrescreveu o da
landing — os dois são copiados para a mesma pasta no deploy.

**O que isso custa:** quem digita `borahapp.com.br`, quem clica no link do seu deck comercial, ou
quem aperta "Início" dentro de `/precos.html` **cai no painel do lojista**. A calculadora de comissão
e a oferta de 7 dias grátis estão inalcançáveis. O funil de venda não existe hoje.

**É conserto meu, não seu** — o deploy precisa deixar de sobrescrever. Está na minha lista. Está aqui
porque você precisa saber agora.

**Meu erro:** na minha própria medição de hoje eu vi `HTTP 200` na raiz e dei a landing por boa. Não
olhei o conteúdo.

---

## 2. 🔴 A taxa de 2% do PIX não cobra de ninguém

**Medido:** `ASAAS_TAXA_PERCENTUAL=0` no servidor.

Essa variável é o **padrão para toda loja que não tem percentual próprio**. Os fundadores deviam ser
a exceção isenta; hoje **todos** estão isentos. Receita de split zero em todo PIX online, em silêncio
— nada registra, nada alarma.

**A decisão é sua, e tem duas saídas que se excluem:**

- **Ligar os 2%** → e então a `precos.html` precisa mudar **antes**, porque ela diz hoje *"nunca uma
  porcentagem das suas vendas"* e *"o dinheiro não passa pela nossa conta em nenhum momento"*. Com o
  split ligado, a primeira frase fica falsa numa oferta comercial.
- **Não ligar** → a copy está correta, e aí o split é código que não se usa.

Hoje a copy é verdadeira **por acidente**: ela só não mente porque o percentual está em zero.

---

## 3. 🔴 A cifragem das credenciais nunca foi ligada

**Medido:** `BORA_SEGREDO_COLUNAS` **ausente** no servidor. A cifragem existe, tem tela, tem endpoint
e tem teste — **a chave nunca foi criada.**

Contagem medida no banco (só contagem, nenhum valor lido por mim):

| coluna | em texto puro |
|---|---|
| `integracao_canal.webhook_token` | 11 |
| `integracao_canal.client_secret` | 6 |
| `config_plataforma.valor` | 5 |
| `integracao_canal.access_token` | 3 |
| `integracao_canal.refresh_token` | 2 |
| `loja.asaas_api_key` | 1 |

**28 credenciais em texto puro** — e entre elas a chave Asaas que movimenta o dinheiro da Zirá, o
segredo do iFood da plataforma (que autoriza pedido em nome de **todas** as lojas) e o token do
WhatsApp. Tudo isso sai em claro em **qualquer** dump do banco, e há 67 dumps guardados.

**A ordem importa:** ligar `BORA_SEGREDO_COLUNAS` → reiniciar → só então rodar o botão
"Cifrar o que já está gravado" em Configurações. O endpoint **recusa** enquanto a chave estiver
desligada, de propósito.

### Correção de um alarme que eu te dei errado (27/10/2026)

Em 27/10 eu te disse que **não ligasse a cifragem** porque a coluna `config_plataforma.valor` era
`varchar(255)` e o valor cifrado não caberia. Fui medir, e o alarme era mais forte que o fato.

O cifrado cresce por uma conta conhecida — `7 + ceil((L + 28) / 3) * 4` —, então em `varchar(255)` o
maior texto puro que ainda cabe tem **158 caracteres**. Os cinco valores dessa tabela na produção
têm **5, 13, 19, 36 e 99** caracteres; o maior, o `client-secret` do iFood, cifra para **179** e
cabe. **Ligar a cifragem hoje não falharia** — nem antes nem depois do conserto.

O fato que sobra: 99 de um teto de 158 é dois terços do caminho, e o próximo token de provedor
derruba. A migração **V63** tira o teto (passa para `text`, como as outras cinco colunas cifradas já
eram). Ela entra no próximo deploy; não é pré-requisito para você ligar a chave.

**Divulgação honesta:** um dos agentes, ao inventariar isso, **leu esses valores** no processo. Não
foram impressos para você nem para mim, mas passaram pelo contexto dele. Se você quiser rotacionar
por precaução, eu faria.

---

## 4. 🟠 Cinco contas de teste ativas em produção, três delas GERENTE

**Medido na tabela `usuario`** (não listo e-mail de pessoa real):

| papel | ativas | dessas, de teste/bootstrap |
|---|---|---|
| ADMINISTRADOR_BORA | 2 | 0 |
| ADMINISTRADOR_LOJA | 3 | **1** |
| GERENTE | 5 | **3** |
| OPERADOR | 1 | **1** |

**GERENTE vê faturamento, custo, margem e lucro, apaga cliente e apaga pedido.** Três contas com esse
papel são de QA, na loja 1. O padrão de conta de QA é senha fraca e reaproveitada — e isso eu **não
medi** (não tentei login).

**Revogar é imediato:** Configurações → Usuários → desativar. Vale no request seguinte, não precisa
esperar o token vencer.

---

## 5. 🟠 A conta de bootstrap `admin@bora.app` está ativa — e só você sabe a senha dela

**Medido:** ela existe, é `ADMINISTRADOR_LOJA` da loja 1, está `ativo = t`, e o hash é bcrypt normal.

**Medido também, e isto é a boa notícia:** `BORA_BOOTSTRAP_ADMIN_SENHA` (10 caracteres),
`BORA_BOOTSTRAP_SUPERADMIN_SENHA` (12) e `BORA_BOOTSTRAP_ADMIN_EMAIL` (14) **estão definidas** no
servidor. Então ela **não** nasceu com a senha padrão do código.

**O que eu NÃO consegui medir:** o bootstrap **só cria se não existir** — ele nunca atualiza a senha
de conta que já está lá. Se a conta foi criada **antes** de a variável ser definida, o hash ainda é o
da senha padrão, que está publicada no repositório (`BootstrapAdmin.java:34`). Saber qual dos dois
casos é o seu exige **tentar o login**, e isso eu não faço.

**Sua verificação de um minuto:** tente entrar com `admin@bora.app` e a senha padrão do código. Se
entrar, troque na hora. Se não entrar, está resolvido e eu tiro este item.

---

## 6. 🟠 A credencial do 99Food da plataforma está recusada

Já estava anotado, e a varredura confirmou com o log: **502 a cada 10 minutos**, com a mensagem
*"A 99Food recusou a credencial: confira o App Shop ID desta loja e o App Secret da plataforma"*.

O segredo salvo tem **13 caracteres**; o do único app de 99Food que funciona aqui (o próprio da Zirá)
tem **32**. Agora **existe tela** para corrigir: Configurações → 🔑 Credencial do app BoraHapp nos
marketplaces. Ela mostra o tamanho, justamente para você comparar com o portal.

**Enquanto estiver assim, nenhum pedido do 99Food entra na Sorveteria da Rosa.**

---

## 7. 🟠 Refazer o vínculo do iFood da loja 17

Também já anotado, confirmado de novo: `CONECTADO`, `ativo`, **token vencido em 07/10** (19 dias),
**sem `merchant_id`**, `ultimo_polling_em` **nulo** — nunca buscou um pedido desde que nasceu. E não
há `client_secret` próprio para renovar.

**Caminho:** Integrações → iFood → Conectar, e autorizar no portal. O `merchant_id` o sistema
descobre sozinho depois, se o token enxergar **uma** loja.

---

## 8. 🟡 Quatro das cinco lojas entregam de graça

**Medido:** só a loja 1 tem bairros cadastrados (4). Lojas **17, 18, 19 e 20 têm zero** linhas de
taxa de entrega — e sem bairro cadastrado o frete sai **R$ 0,00**, incluindo na loja pagante.

É cadastro, não código.

---

## 9. 🟡 A loja de QA mora em produção e distorce todo relatório

**Medido:** a loja 1 ("Sorveteria da Rosa" / nome de sistema "BoraQATest", documento placeholder) tem
**6 de 6 produtos com nome de teste**, insumos de QA, bairro de QA, promoções de QA, e **28 dos 33
pedidos do banco** — R$ 759,41 de R$ 997,31. É também a **única assinatura ATIVA**.

Qualquer número agregado da plataforma é, hoje, principalmente essa loja. **Decisão sua:** limpar a
movimentação dela (há botão para isso), arquivá-la, ou aceitar e lembrar disso ao ler relatório.

---

## 10. 🟡 Dois insumos cadastrados como produto vendável no cardápio da Zirá

**Medido:** loja 18, produtos ativos `pacoca` (R$ 2,50) e `leite condensado` (R$ 3,00), categoria
"mantimento". São os únicos 2 dos 35 produtos dela com estoque preenchido — cara de insumo digitado
na tela errada.

**O cliente final vê uma categoria "mantimento" no cardápio da açaiteria** e pode comprar um leite
condensado por R$ 3,00. É cadastro: desative os dois em Produtos.

---

## 11. 🟡 "Monte Seu Açaí" anuncia R$ 100,00 no cardápio que está no ar

**Medido no cardápio público da loja 18:** o cartão escreve *"a partir de R$ 100,00"*, porque o
produto tem preço base R$ 90 e o recipiente obrigatório mais barato custa R$ 10. Duas linhas abaixo,
"Copo de Açaí 300ml" custa R$ 17,90.

A tela está certa (ela soma o obrigatório, como deve). **O R$ 90,00 de base é que não deveria estar
lá** — é cadastro.

---

## 12. 🟡 A empresa da Pizzaria está sem CNPJ

**Medido:** empresa 2 ("Pizzaria Bella Napoli", loja 17) com CNPJ vazio. Não quebra nada hoje porque
a emissão fiscal está desligada; quebra no dia em que ligar.

---

## O que a varredura disse de BOM, e é o mais importante

**Não há vazamento entre lojas.** Um agente conferiu os **29 repositórios** um por um: todas as
consultas e **todos** os UPDATE/DELETE levam `lojaId` na cláusula. Os dois únicos sem ele recebem ids
que vêm de consultas já escopadas. O papel vem do banco a cada request, não do token. Rebaixar ou
desvincular um usuário vale no request seguinte.

Em SaaS multi-loja, isso é o defeito que acaba com a empresa. Não está lá.

Também medido e correto: nenhum endpoint responde sem token (testados 15 em produção); os webhooks
exigem token em tempo constante e **falham fechado**; as chaves da loja têm `@JsonIgnore` e não saem
na resposta; nenhum log imprime segredo; o cardápio público não devolve custo nem estoque; o link de
acompanhar pedido exige assinatura e devolve 404 igual para token errado e pedido inexistente; o
upload tem lista branca de tipo, sem SVG; e não há SQL concatenado com entrada de usuário em lugar
nenhum.
