# Guia — Cadastrar uma loja nova e deixá-la 100% operacional

> Levantado do código em produção em **28/08/2026**. Substitui o `LEVANTAMENTO_CADASTRO_LOJA_OPERAVEL.md`,
> que era o estudo prévio e hoje está desatualizado.

---

## Parte 0 — O que ter em mãos antes de começar

Peça isso ao lojista **antes** de sentar para configurar. Com esses itens, a loja fica operando em uma
sessão de ~30 minutos.

| Item | Para quê | Obrigatório? |
|---|---|---|
| Nome da loja | Nome no painel, no cardápio e no app instalável | Sim |
| E-mail e senha do dono | Login do administrador da loja | Sim |
| CPF/CNPJ do responsável | Ativar a assinatura no Asaas | Sim (na hora de cobrar) |
| Logo (PNG/JPG) e cor da marca | White-label | Sim (é passo obrigatório do onboarding) |
| Cardápio | Produtos e preços — **foto ou print do iFood serve**, o Módulo IA importa | Sim |
| Bairros atendidos + taxa + tempo | Taxa de entrega | Sim (ou marcar só retirada) |
| Horário real de funcionamento | Abrir/fechar o cardápio | Sim (vem preenchido, precisa conferir) |
| WhatsApp do dono | Gerente Virtual (só com Módulo IA) | Não |
| Credenciais de marketplace | iFood, 99Food, Rappi, Uber Eats, aiqfome, Goomer | Não |

---

## Parte 1 — Criar a loja

### Caminho A — O lojista se cadastra sozinho (padrão)
`https://borahapp.com.br/cadastro.html` → nome da loja, nome do dono, e-mail, senha (mín. 6).
Entra logado automaticamente.

> **Rede multi-loja:** se o dono usar **o mesmo e-mail e a mesma senha**, a segunda loja é **vinculada à
> conta existente** em vez de dar erro de e-mail duplicado. Um seletor de loja aparece no menu quando há 2+.

### Caminho B — Você cria pela plataforma (super-admin)
**Não existe tela.** Só via API, autenticado como `ADMINISTRADOR_BORA`:

```
POST /admin-bora/lojas
{ "nomeLoja": "...", "documento": "...", "plano": "UNICO",
  "adminNome": "...", "adminEmail": "...", "adminSenha": "..." }
```

Este caminho aceita `documento` (CNPJ) — o cadastro público **não pede CNPJ**; ele só é coletado depois,
na ativação da assinatura.

---

## Parte 2 — O que já nasce pronto (não cadastre à mão)

O `ProvisionamentoService` roda nos dois caminhos e semeia:

- **Configuração visual** — nome de exibição = nome da loja, cor primária `#7c3aed`
- **4 formas de pagamento** — Dinheiro (com troco), PIX (online), Cartão de crédito, Cartão de débito
- **5 motivos de cancelamento** — cliente desistiu, fora da área de entrega, produto em falta,
  endereço não encontrado, loja fechada
- **7 horários** — domingo a sábado, 18:00–23:00, todos abertos

É idempotente: rodar de novo não duplica nada.

**Continua vazio e precisa ser preenchido:** taxas de entrega, produtos, insumos, complementos,
entregadores, equipe, logo/banner, integrações, recebimento e assinatura.

---

## Parte 3 — Suas ações como administrador da plataforma

Faça **antes** de entregar o painel ao lojista. Ficam em **Configurações → card 🔧 Plataforma BoraHapp**
(o card só aparece para quem é `ADMINISTRADOR_BORA`).

| Ação | Onde | Como |
|---|---|---|
| **Preço negociado** (fundador R$ 149) | ❌ Sem tela | `PUT /admin-bora/lojas/{id}/preco` → `{"precoMensal": 149.00}` (`null` volta à tabela) |
| **Taxa de split do PIX** | ✅ Card Plataforma → campo "taxa PIX %" | Vazio = padrão da plataforma (2%) · `0` = isento (fundadores) |
| **Módulo IA** (add-on R$ 99) | ✅ Card Plataforma → checkbox por loja | Só se o cliente contratou |
| **Emissão de NFC-e** | ✅ Card Plataforma → toggle | Global, não por loja. Hoje **desligada** |

> ⚠️ **Ao fechar um fundador são dois ajustes:** preço R$ 149 **e** split 0. O preço tem que ser definido
> **antes** de o lojista clicar em "Ativar assinatura", senão ele assina pelo valor de tabela.

---

## Parte 4 — O checklist do lojista (card "Comece por aqui")

Aparece sozinho na **Dashboard** e calcula a % de prontidão. São 5 passos obrigatórios e 2 opcionais.
A loja é considerada **operável** quando os 5 obrigatórios estão verdes.

| # | Passo | Tela | Obrigatório | Fica verde quando |
|---|---|---|---|---|
| 1 | Personalize a marca | `configuracoes.html` | ✅ | Tem logo salvo |
| 2 | Monte o cardápio | `produtos.html` | ✅ | Tem ao menos 1 produto ativo |
| 3 | Defina a entrega | `ajustes.html` | ✅ | Tem ao menos 1 bairro com taxa |
| 4 | Confirme o horário | `ajustes.html` | ✅ | Tem horários cadastrados (já vem semeado) |
| 5 | Ative sua assinatura | `planos.html` | ✅ | Assinatura ATIVA no Asaas |
| 6 | Crie sua equipe | `usuarios.html` | ➖ | Existe mais de 1 usuário |
| 7 | Receba por PIX | `integracoes.html` | ➖ | Subconta Asaas ou chave PIX configurada |

---

## Parte 5 — Onde se cadastra cada coisa

| O que | Tela | Caminho dentro da tela |
|---|---|---|
| Logo, cor, nome de exibição, banner | `configuracoes.html` | Card "Identidade da loja (white-label)" |
| **Taxa de entrega por bairro** | `ajustes.html` | Aba 🛵 Taxas → bairro / R$ / minutos → "+ Adicionar" |
| **Horário de funcionamento** | `ajustes.html` | Aba 🕒 Horário → grade por dia → "Salvar horários" |
| **Formas de pagamento** | `ajustes.html` | Aba 💳 Formas de pagamento |
| **Motivos de cancelamento** | `ajustes.html` | Aba 🚫 Motivos |
| **Produtos** (nome, categoria, preço, custo, estoque, foto) | `produtos.html` | Formulário do topo |
| **Complementos/adicionais** | `produtos.html` | Botão 🧩 na linha do produto |
| **Ficha técnica / CMV por insumo** | `produtos.html` | Botão 🧪 na linha do produto |
| **Insumos** (nome, unidade, custo, estoque) | `insumos.html` | Formulário da tela |
| **Entregadores** | `entregadores.html` | Nome, telefone, veículo |
| **Equipe** (operador/gerente/admin) | `usuarios.html` | Só o ADMINISTRADOR_LOJA consegue |
| **Cupons do cardápio** | `promocoes.html` | Seção 🎟️ (parte de baixo) |
| **Promoções** (relâmpago, combo, frete grátis) | `promocoes.html` | Card do topo |
| **QR do cardápio** | `cardapio-qr.html` | Gera o QR e o link |
| **Marketplaces** | `integracoes.html` | Card por canal |
| **Recebimento PIX próprio** | `integracoes.html` | Card "Recebimento por PIX" |
| **Assinatura** | `planos.html` | CPF/CNPJ + "Ativar assinatura" |
| **WhatsApp do dono** (Gerente Virtual) | `configuracoes.html` | Card 🧠 Módulo IA — **só aparece se o add-on estiver liberado** |

**Link público do cardápio:** `https://borahapp.com.br/cardapio.html?loja={ID_DA_LOJA}`

---

## Parte 6 — Assinatura (como a cobrança começa)

1. O lojista abre **Planos**, informa **CPF/CNPJ do responsável** e clica em "Ativar assinatura".
2. O sistema cria cliente + assinatura mensal no **Asaas**, com **7 dias de cortesia** antes da 1ª cobrança.
3. O e-mail de cobrança é o do usuário `ADMINISTRADOR_LOJA` da loja.
4. A cobrança (PIX/boleto/cartão) acontece **no Asaas**, fora do painel. O webhook atualiza o status
   para ATIVA / EM ATRASO / CANCELADA e liga/desliga a loja.

Só o `ADMINISTRADOR_LOJA` consegue assinar. **Defina o preço negociado antes desta etapa.**

---

## Parte 7 — Turbinar (opcional, depois do go-live)

- **Migração de cardápio por foto** (Módulo IA) — manda o print do iFood e a IA cadastra os produtos
- **Gerente Virtual** (Módulo IA) — resumo diário às 8h no WhatsApp do dono
- **Recuperador de clientes** (Módulo IA) — contata quem sumiu há 21+ dias
- **Marketplaces** — cada canal pede Merchant ID, Client ID e Client Secret; depois de salvar,
  a tela mostra a URL de webhook para colar no painel do parceiro. Há um botão **🧪 Simular pedido**
  para testar sem credenciais reais
- **Recebimento PIX próprio** — cria subconta Asaas (CPF/CNPJ, celular, CEP) e exige **KYC**
  (documentos + selfie) por link antes de ficar ATIVO
- **Rede & Análise** — faturamento consolidado, canais, mapa de calor por horário e tempos
  (admin e gerente)

---

## Parte 8 — Teste de aceitação antes de entregar

Faça um pedido de ponta a ponta, como se fosse o cliente final:

1. Abra `cardapio.html?loja={ID}` no celular
2. Monte um pedido com um produto que tenha complemento
3. Aplique um cupom, se houver
4. Feche o pedido (dinheiro ou PIX)
5. No painel, avance o status até **ENTREGUE**
6. Confira o link público de acompanhamento
7. Confira se o pedido apareceu na Dashboard e no Relatório

Se os 7 passos funcionarem, a loja está operacional.

---

## Parte 9 — Pegadinhas conhecidas

1. **⚠️ Permissões frouxas.** Ajustes, Produtos, Insumos, Entregadores, Integrações e Configurações
   **não checam papel no backend** — um `OPERADOR` consegue alterar taxa de entrega, preço e white-label
   pela API. Só têm proteção real: Usuários, Promoções/Cupons, Assinatura, Módulo IA e `/admin-bora/*`.
   **Corrigir antes de ter lojas com equipe grande.**
2. **O WhatsApp do `cardapio-qr.html` não é salvo no servidor** — fica só no `localStorage` do navegador
   e serve apenas para montar o link. Trocar de computador perde o valor.
3. **Sem Módulo IA não existe tela para gravar o WhatsApp do dono** no backend.
4. **Entregador não é login.** O cadastro em `entregadores.html` é operacional; para dar acesso ao
   painel é preciso criar um usuário em `usuarios.html`.
5. **O cadastro público não pede CNPJ** — o documento só entra na ativação da assinatura.
6. **Limite do plano ÚNICO: 15 usuários ativos.** O 16º retorna erro. Pedidos são ilimitados.
7. **NFC-e está desligada** globalmente e responde 409 até o `ADMINISTRADOR_BORA` ligar a chave.
8. **A loja precisa de assinatura ativa** para não ser suspensa pelo webhook de inadimplência.
