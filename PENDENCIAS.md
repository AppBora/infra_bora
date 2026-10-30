# As pendências — a lista viva

**Este arquivo é o único que você precisa abrir.** O nome dele nunca muda de data, então o atalho
que você guardar hoje continua valendo no mês que vem. Aqui estão **só as ações**, em ordem, com
onde clicar. A prova de cada uma — o que foi medido, quando e onde — está em
[PENDENCIAS-2026-10-30.md](PENDENCIAS-2026-10-30.md).

Última conferência contra a produção: **30/10/2026**. Tudo marcado como pendente aqui foi medido
nesse dia, não deduzido.

---

## 🔴 Agora

- [ ] **Trocar a chave de produção do Asaas.** Eu vazei a chave na sessão do dia 30/10, por um erro
      meu (carreguei o `api.env` com `source` e a mensagem de erro imprimiu a linha). Ela cobra os
      seus lojistas.
      **Caminho:** Asaas → Integrações → API → gerar nova chave → trocar a linha `ASAAS_API_KEY=`
      em `/home/ubuntu/bora/api.env` → **recriar** o container (restart não basta).
      **Me peça a recriação e eu faço.** As cobranças e assinaturas que já existem continuam
      valendo: a chave é acesso, não dona do dado.

---

## 🔑 Para terminar a cifragem (ela já está ligada desde 30/10, 14:37)

- [ ] **1º — guardar a chave `BORA_SEGREDO_COLUNAS` no seu gerenciador de senhas.**
      **Nenhum backup do servidor contém o `api.env`** (conferido em 30/10). A chave existe num só
      lugar no mundo. Leia uma vez:

      ```bash
      ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33 "grep '^BORA_SEGREDO_COLUNAS=' /home/ubuntu/bora/api.env"
      ```

- [ ] **2º — e só depois disso: cifrar as 28 credenciais que já estavam gravadas.**
      **Caminho:** painel → Configurações → Plataforma → "Credenciais no banco" →
      **"Cifrar o que já está gravado"**. Clicar duas vezes não estraga nada.
      Ligar a chave protege o que for gravado **daqui para frente**; essas 28 continuam em texto
      puro até esse clique, e saem em todo backup do banco.

O botão é seu, e não meu, por um motivo só: exige login de administrador, e eu não entro em conta
de ninguém.

---

## 🟠 Cadastro e operação — nada aqui é código

- [ ] **iFood da loja 17 nunca buscou um pedido.** Diz `conectado`, mas o token venceu em 07/10 e
      **não tem Merchant ID**. Nenhum pedido do iFood entra nessa loja.
      **Caminho:** Integrações → iFood → Conectar, e autorizar no portal.

- [ ] **99Food recusou a credencial da plataforma.** Loja 1: ativo, sem `client_secret`. O polling
      roda e volta recusado. Nenhum pedido do 99Food entra.
      **Caminho:** Configurações → 🔑 Credencial do app BoraHapp nos marketplaces.

- [ ] **Quatro lojas entregam de graça por falta de bairro.** Loja 1 tem 4 bairros; **17, 18, 19 e
      20 têm zero** — e sem bairro o frete sai R$ 0,00, inclusive nas três lojas pagantes da Zirá.
      **Caminho:** Configurações → Taxas de entrega, em cada loja.

- [ ] **Dois insumos estão à venda no cardápio público da Zirá** (loja 18, categoria "mantimento"):
      `leite condensado` R$ 3,00 e `pacoca` R$ 2,50, os dois ativos. O cliente final vê isso.
      **Caminho:** Produtos → desativar os dois.

- [ ] **Cinco contas de teste ativas, três delas GERENTE.** GERENTE vê faturamento, custo, margem e
      lucro, apaga cliente e apaga pedido.
      **Caminho:** Configurações → Usuários → desativar. Tem efeito imediato.

- [ ] **A empresa da Pizzaria está sem CNPJ** (empresa 2). Não quebra nada hoje porque a emissão
      fiscal está desligada — mas quebra no dia que ligar.

---

## 🟡 Decisões suas, sem pressa

- [ ] **A taxa de 2% do PIX não cobra de ninguém** (`ASAAS_TAXA_PERCENTUAL = 0`). Os fundadores
      deviam ser a exceção isenta; hoje todos são.
      As duas saídas se excluem: **ligar os 2%** exige mudar a `precos.html` primeiro, porque ela
      diz *"nunca uma porcentagem das suas vendas"*; **não ligar** deixa a copy correta e o split
      vira código que não se usa. Hoje a copy é verdadeira por acidente.

- [ ] **A loja de QA mora em produção.** A loja 1 ("Sorveteria da Rosa" / `BoraQATest`) tem **28 dos
      36 pedidos** e **R$ 759,41 de R$ 1.091,91**. Qualquer número agregado da plataforma é hoje,
      principalmente, ela. Limpar a movimentação, arquivar a loja, ou aceitar e lembrar disso ao
      ler relatório.

- [ ] **Decidir o caminho do modo offline** (internet da loja cai). O levantamento está pronto em
      [ESTUDO-OFFLINE-2026-10-30.md](ESTUDO-OFFLINE-2026-10-30.md): é viável, e o pedido de entrega
      **não para de entrar** quando a loja cai — ele fica na nuvem. O que para é o balcão e a
      visualização. Três caminhos; eu recomendo o A agora, depois a chave de idempotência, depois o
      B limitado ao PDV. **Antes de construir o B, me peça a medição de quantas vezes a internet
      caiu em cada loja** — é leitura de log e é ela que diz se vale.

- [ ] **Autorizar o conserto da venda duplicada** — isto é defeito de **hoje**, com a internet boa.
      O `POST /api/pedidos` não tem chave de idempotência: se a resposta se perde na volta e o
      balconista clica "Finalizar" de novo, a venda é gravada **duas vezes** (estoque baixado duas
      vezes, cashback acumulado duas vezes, faturamento inflado). O conserto é meu — código, uma
      migração e uma versão nova —, só preciso do seu "sobe". Detalhe no item 4 do estudo.

- [ ] **"Fechamento de Caixa" não guarda nada e não existe para ontem.** Não é defeito: é
      funcionalidade que não existe. O tamanho é decisão sua — um seletor de data (pequeno) ou um
      fechamento guardado e assinado (grande).

---

## ⚪ Um "sim" seu e eu faço — eu não escrevo em produção sem autorização

- [ ] **7 itens de pedido órfãos** — apontam para pedido que não existe mais. Não mexe em dinheiro.
- [ ] **5 pedidos apontando para cliente apagado** — não dispara erro hoje.
- [ ] **1 linha de ficha técnica fantasma** — **esta mexe em dinheiro**: entra no custo e, portanto,
      na margem que o lojista lê. É a única das quatro que mexe.
- [ ] **"Vale Refeicao" repetido na loja 1** — forma de pagamento duplicada. É um clique.

---

## Onde estão as outras listas

Estas ficaram como **registro**, não como pendência — todas têm um aviso no topo apontando para cá:
`PENTE-FINO-SO-VOCE-PODE.md` (27/10), `DADOS-A-DECIDIR-2026-10-27.md`, `PENDENCIAS-2026-10-24.md`,
`SO-VOCE-PODE-FAZER.md` (24/10), `O-QUE-FALTA-VOCE-FAZER.md` (23/10) e
`PENDENCIAS-30-09-2026.md`. Se um item delas não aparece nesta página, é porque já foi fechado — a
prova de cada fechamento está no relatório do dia.
