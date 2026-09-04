# Plano de cadastro — Zirá Montreal (primeiro cliente)

> Levantado em 2026-09-01 do código em produção, do guia de cadastro e da especificação pública do
> Open Delivery. Tudo que o sistema exige está aqui, com a origem de cada informação.

## 1. O que já temos (veio do Jonas por WhatsApp)

| Campo | Valor | Onde entra |
|---|---|---|
| Nome da loja | Zirá Montreal | Formulário "Nova loja" |
| CNPJ | 53.953.786/0001-28 | Formulário "Nova loja" — **cria a Empresa** |
| Responsável | Maria Eduarda de Oliveira | Formulário "Nova loja" |
| E-mail (login e cobrança) | mariaeduardaoliveiramattos2005@gmail.com | Formulário "Nova loja" |
| WhatsApp | (15) 98103-4318 | Só é gravado se o Módulo IA estiver liberado |
| Preço | R$ 199 (tabela) | Deixar o campo vazio |

Decisões já tomadas: preço de tabela (não é fundador), Módulo IA liberado, cadastro feito pela
plataforma para gravar o CNPJ.

## 2. A pergunta do 99Food: dá para puxar por API?

**Resposta curta: hoje, não — e o motivo não é falta de implementação nossa.**

- O padrão Open Delivery tem, sim, um módulo **Merchant** que cobre "informações dos estabelecimentos
  e estrutura de cardápios", além de Pedidos e Logística.
- Só que no desenho do padrão quem **publica** o cardápio é o merchant (o PDV do restaurante) para o
  marketplace — o fluxo natural é do nosso lado para o 99, não o contrário. Ler o cardápio que já
  existe no 99 depende de o 99 expor essa leitura ao integrador, o que **a documentação pública não
  confirma**: o portal `developer-food.99app.com` exige login.
- Nossa integração (`OpenDeliveryClient`) implementa **só Pedidos**: vincular, polling, ack, detalhe e
  push de status. Não há importação de cadastro nem de cardápio.
- E nada disso roda sem `BORA_OPENDELIVERY_CLIENT_ID/SECRET`, que ainda não temos.

**Conclusão prática:** para este cadastro, os dados do 99 saem de lá por **cópia/print**, não por API.
Quando você estiver logado no portal do 99, vale conferir duas coisas de uma vez: se existe leitura de
merchant/cardápio disponível ao integrador, e as credenciais. Se existir, viramos isso em automação
depois — mas não é pré-requisito para a Zirá operar.

**Atalho que substitui a API:** com a `BORA_CLAUDE_API_KEY` no servidor e o Módulo IA liberado, o
**print do cardápio do 99 vira produto cadastrado** (`POST /api/ia/importar-cardapio`, Claude lê a
imagem). É o caminho mais rápido do cardápio dela para dentro do BoraHapp.

## 3. O que buscar no painel do 99 (você logado, uma visita só)

| Informação | Para que serve no BoraHapp | Tela de destino |
|---|---|---|
| **Print do cardápio inteiro** (categorias, nomes, descrições, preços) | Produtos | `produtos.html` (ou IA por foto) |
| **Endereço completo da loja** | Referência operacional e contato | — |
| **Bairros atendidos + taxa + tempo** | Taxa de entrega (passo obrigatório) | `ajustes.html` › Taxas |
| **Horário de funcionamento por dia** | Abrir/fechar o cardápio | `ajustes.html` › Horário |
| **Logo em boa resolução + cor da marca** | White-label (passo obrigatório) | `configuracoes.html` |
| **Merchant ID da loja no 99** | Vincular o canal quando houver credencial | `integracoes.html` |
| **Client ID / Client Secret** (se o portal deixar gerar) | Ligar a importação de pedidos do 99 | `api.env` (servidor) |

## 4. O que só a Maria Eduarda responde

Está tudo na ficha `FICHA_CADASTRO_LOJISTA.html` — dá para ela preencher no celular e devolver:
formas de pagamento aceitas, chave PIX / recebimento, equipe (quem opera, quem gerencia),
entregadores, complementos dos produtos e se quer cashback.

**Decisão que não pode passar batido:** toda loja nova nasce dando **5% de cashback** no cardápio.
Se ela não quiser, zerar em Configurações **antes** de publicar o link.

## 5. Sequência do cadastro

**Passo 0 — conferir se já existe.** No painel da plataforma, procurar o e-mail dela na lista de
clientes. O cadastro de 30/08 aparentemente falhou, mas se a conta existir, criar de novo dá
"E-mail já cadastrado".

**Passo 1 — criar a loja** (Configurações › Plataforma › ➕ Nova loja): nome, CNPJ, responsável,
e-mail, senha provisória, preço vazio. Sai o ID e o link do cardápio. A **Empresa é criada
automaticamente** a partir do CNPJ — se a Zirá abrir uma segunda unidade com o mesmo CNPJ, ela cai
na mesma empresa e o gerente pode atender as duas com um login só.

**Passo 2 — liberar o Módulo IA** na linha dela (checkbox), se for contratar o add-on.

**Passo 3 — ajustar o cashback** (0% ou o que ela quiser).

**Passo 4 — marca**: logo e cor.

**Passo 5 — cardápio**: print do 99 pela IA, ou à mão.

**Passo 6 — entrega e horário**: bairros com taxa e tempo, e o horário real (a loja nasce com
18h–23h todo dia, quase certamente errado).

**Passo 7 — equipe e entregadores**, se ela tiver.

**Passo 8 — assinatura**: ela mesma ativa em Planos, com o CNPJ. São 7 dias de cortesia antes da
primeira cobrança de R$ 199.

**Passo 9 — teste de aceitação** antes de entregar: pedido de ponta a ponta pelo celular, avançando
o status até ENTREGUE, conferindo o link público de acompanhamento e o pedido na Dashboard.

## 6. O que fica pendente sem bloquear

- **Pedidos do 99 dentro do BoraHapp** — depende das credenciais.
- **iFood** — depende da homologação (semanas).
- **Robô de WhatsApp** — depende da verificação na Meta.
- **Cardápio por foto** — depende da chave da Claude no servidor.

Nenhum impede a loja de vender pelo cardápio próprio, que é o produto que ela está contratando.
