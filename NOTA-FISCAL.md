# Nota fiscal da mensalidade do BoraHapp — 02/10/2026

Este documento fecha o item 6 das pendências ("não existe nada no projeto: nem documento, nem código,
nem definição de quem emite").

---

## 1. Não confunda com a outra nota

São duas coisas diferentes e só uma é nossa:

| | Quem emite | Para quem | Situação |
|---|---|---|---|
| **NFC-e do pedido** | a loja (Zirá, Bella Napoli…) | o cliente final dela | já existe código (`FiscalController`), **dormente** — só liga com a chave da plataforma |
| **NFS-e da mensalidade** | **nós** (ADF Sistemas) | o lojista | **é disto que este documento trata** |

---

## 2. Quem emite — fatos conferidos na Receita em 02/10/2026

| | |
|---|---|
| Razão social | **ADF SISTEMAS E TECNOLOGIAS LTDA** |
| CNPJ | 68.761.778/0001-57 (o mesmo que está no rodapé do site) |
| Situação | **ATIVA**, aberta em 12/08/2026 |
| Regime | **Simples Nacional** desde 24/08/2026 · Microempresa · não é MEI |
| Município | **Sorocaba/SP** (IBGE 3552205) |
| Sócio-administrador | Anderson Luiz Ferreira |
| CNAE principal | 6201-5/01 — desenvolvimento de programas **sob encomenda** |
| CNAEs secundários | 4651-6/01 · 4751-2/01 · **6202-3/00** (licenciamento customizável) · **6203-1/00** (não-customizável) |

**A empresa está certa para isto.** A mensalidade do BoraHapp é licenciamento de software, e os CNAEs
6202-3/00 e 6203-1/00 já estão lá. Não precisa abrir nem alterar nada na Receita.

---

## 3. Como a nota sai em Sorocaba

Sorocaba **manteve o emissor próprio** — não caiu no padrão nacional. O que isso significa na prática:

- o emissor oficial é o **Nota Fácil Sorocaba**, da prefeitura;
- o padrão técnico é **ABRASF 2.03**, com autenticação por **certificado digital A1**;
- para emitir é preciso **Inscrição Municipal regular** e **credenciamento na prefeitura**.

---

## 4. Os dois caminhos

### A) À mão, no Nota Fácil Sorocaba — **é o que eu faria agora**

Entra no emissor da prefeitura e emite a nota de cada mensalidade a partir da lista de faturamento que
acabei de colocar no painel. Depois cola o número da nota de volta na lista.

Por que este primeiro: hoje **ninguém paga de verdade** (ver item 6 abaixo), e quando os clientes
entrarem serão poucas notas por mês. Emitir 3 ou 5 notas à mão leva minutos e não depende de homologar
nada. E não dá para começar pelo caminho B sem antes ter Inscrição Municipal e certificado — que são
exatamente os mesmos pré-requisitos deste.

### B) Automático pelo Asaas

O Asaas emite NFS-e sozinho a cada mensalidade da assinatura. Exige:

- Inscrição Municipal regular;
- estar **homologado na prefeitura** para emitir por webservice;
- certificado digital / usuário e senha, conforme o que o município exige;
- **e Sorocaba precisa estar entre os municípios integrados do Asaas.**

⚠️ **Essa última parte eu não consegui confirmar.** A checagem exige a chave do Asaas, e fui barrado ao
ler o arquivo de ambiente do servidor. **Você confere em 1 minuto:** entre no painel do Asaas, menu
**Notas Fiscais** — ele diz se o seu município está disponível. Se estiver, o caminho B vira o destino
natural e eu ligo no código (a assinatura já é criada por nós; é configurar a emissão nela).

---

## 5. O que só você e o contador podem resolver

Leve estas perguntas — nenhuma delas eu posso responder por você, e todas mudam o que sai na nota:

1. **Código de serviço municipal** para licenciamento de software / SaaS em Sorocaba, e a **alíquota de
   ISS** correspondente.
2. Como marcar a nota por ser **optante do Simples** — o ISS vai no DAS, e a nota precisa sair de forma
   que ele não seja cobrado duas vezes.
3. **Anexo III ou Anexo V** (o tal fator R) e o que isso muda na carga — tem a ver com pró-labore/folha.
4. A nota sai **no recebimento** ou **na competência** do mês?
5. Quando o cliente for PJ, há **ISS retido na fonte**? Isso muda o valor líquido que entra.
6. **Inscrição Municipal**: já existe? Se não, é o primeiro passo — sem ela não há caminho A nem B.

---

## 6. O que eu descobri olhando o banco de produção hoje

**Hoje ninguém paga mensalidade pelo sistema.** Conferido em 02/10/2026:

- existe **uma única assinatura**, marcada ATIVA, de R$ 199,00, da loja **"Sorveteria da Rosa"** —
  cujo CNPJ cadastrado é `00000000000100`, ou seja, um número de teste. Ela aponta para uma assinatura
  real no Asaas (`sub_xnnjvxdaqpinyyo7`, criada em 01/07/2026). **Confirme se isso é cobrança sua de
  teste ou sobra de desenvolvimento** — se estiver cobrando de verdade, está cobrando de um CNPJ falso.
- as **3 lojas da Zirá** (CNPJ 53.953.786/0001-28) **não têm assinatura nenhuma** — nem registro, nem
  valor, nem cobrança.
- a Bella Napoli não tem nem CNPJ cadastrado.

Ou seja: **não há atraso de notas para regularizar.** É o melhor momento possível para acertar isso,
antes do primeiro cliente pagante.

---

## 7. O que eu já fiz no sistema

O buraco de verdade não era "falta emitir nota". Era mais embaixo: **quando um cliente pagava, o
sistema não guardava nada.** O aviso do Asaas chegava, o sistema trocava o status da assinatura para
ATIVA e jogava fora o identificador da cobrança, o valor e a data. Não existia como responder "quanto
entrou em outubro e de quem" sem entrar no painel do Asaas — e não havia onde pendurar o número da nota.

Agora:

- **cada mensalidade recebida vira uma linha** no banco, com loja, CNPJ, valor, data e o identificador
  da cobrança no Asaas;
- **o mesmo pagamento não conta duas vezes** — o Asaas reenvia o aviso enquanto não recebe resposta, e
  sem essa trava a mesma mensalidade entraria duas vezes no faturamento e geraria dois pedidos de nota;
- **tela nova no painel da plataforma** (Configurações → Plataforma BoraHapp): "Faturamento do mês",
  com o total recebido, **quanto ainda está sem nota**, e um campo para registrar o número da nota
  emitida;
- se o aviso vier sem valor, grava o valor da assinatura; se vier sem data, grava a hora da chegada —
  nunca uma mensalidade zerada ou solta fora do mês.

---

## 8. Fontes

- Dados cadastrais da empresa: [BrasilAPI / Receita Federal](https://brasilapi.com.br/api/cnpj/v1/68761778000157)
- [Como emitir NFS-e em Sorocaba — nfe.io](https://nfe.io/docs/prefeituras-integradas/sao-paulo-prefeituras-integradas/sorocaba-sp-3552205/)
- [NFS-e Nacional e Sorocaba — TOTVS](https://www.totvs.com/blog/fiscal-clientes/nfse-nacional-sorocaba-sp-padronizacao-em-2026/)
- [Emitindo notas fiscais de serviço — Asaas](https://docs.asaas.com/docs/emitindo-notas-fiscais-de-servico)
- [Emitir notas fiscais automaticamente para assinaturas — Asaas](https://docs.asaas.com/docs/emitir-notas-fiscais-automaticamente-para-assinaturas)
- [Listar configurações municipais — Asaas](https://docs.asaas.com/reference/listar-configuracoes-municipais)
