# Levantamento — Cadastro de Loja Totalmente Operável e Integrada

> Objetivo: definir **tudo** que é preciso para que uma loja recém-cadastrada nasça (ou fique rapidamente) **100% operacional** e integrada a todas as funcionalidades da plataforma BoraHapp. Este documento é o mapa: o que já existe, o que falta, o que deve ser semeado automaticamente e o que o lojista preenche por um assistente guiado.

---

## 1. O que significa "loja totalmente operável"

Uma loja está operável quando o dono consegue, sem tocar em SQL nem em suporte:

1. Entrar no painel com a marca dele (white-label).
2. Receber e faturar pedidos (balcão, WhatsApp, cardápio próprio e marketplaces).
3. Cobrar corretamente (formas de pagamento, taxa de entrega por bairro, PIX).
4. Preparar e entregar (KDS, quadro de status, entregadores, acerto).
5. Gerir (relatórios, rede, estoque/CMV, CRM, promoções).
6. Estar em dia com a plataforma (assinatura ativa no Asaas).

Cada um desses depende de dados por loja que hoje **não** são criados no cadastro.

---

## 2. Estado atual do cadastro (o gap)

Existem dois caminhos de criação de loja, e **ambos criam apenas o mínimo**:

| Caminho | Endpoint | O que cria hoje |
|---|---|---|
| Self-service | `POST /public/signup` | `loja` (plano ÚNICO) + `usuario` admin + vínculo `usuario_loja` |
| Plataforma (super-admin) | `POST /admin-bora/lojas` | idem, com plano/preço definíveis |
| 1º start | `BootstrapAdmin` | "Loja Demo" + admin, só se o banco estiver vazio |

Tudo o mais — configuração visual, formas de pagamento, taxas, horários, motivos, catálogo, complementos, entregadores, canais, assinatura — **começa vazio**. A loja "existe", mas não está pronta para operar. `ConfiguracaoLoja` é criada só na 1ª vez que alguém salva as configurações; `Assinatura` só quando o admin assina no Asaas.

**Conclusão:** falta uma camada de *provisionamento* (semear defaults) e uma de *onboarding* (assistente guiado) entre "loja criada" e "loja operando".

---

## 3. Modelo de dados por loja (tudo que é escopado por `loja_id`)

Toda entidade abaixo carrega `loja_id` e participa do isolamento multi-tenant (RN08). É o universo que um cadastro completo precisa popular:

`configuracao_loja`, `assinatura`, `usuario` / `usuario_loja`, `forma_pagamento`, `taxa_entrega`, `horario_funcionamento`, `motivo_cancelamento`, `produto`, `complemento_grupo` / `complemento_item`, `cupom`, `promocao`, `cliente`, `entregador`, `acerto_entregador`, `insumo` / `produto_insumo`, `integracao_canal`, `pedido` / `pedido_item` / `log_status`, `ia_recuperacao`.

---

## 4. Levantamento por módulo — o que cada funcionalidade exige

Legenda da coluna **Provisão**: 🌱 semear no cadastro · 🧭 wizard (lojista preenche) · 🔌 integração externa · ⚙️ opcional/avançado.

### 4.1 Identidade e acesso
| Item | Entidade / Endpoint | Obrigatório? | Provisão |
|---|---|---|---|
| Loja (nome, documento/CNPJ, plano) | `loja` / signup | Sim | 🌱 (já criado) |
| Admin da loja (ADMINISTRADOR_LOJA) | `usuario` + `usuario_loja` | Sim | 🌱 (já criado) |
| Equipe (operador, gerente) | `POST /api/usuarios` | Não (mas recomendado) | 🧭 |
| White-label (nome exibição, logo, cor primária) | `PUT /api/configuracao` | Sim p/ marca | 🌱 base + 🧭 refino |
| Cores secundárias, banner, subdomínio | idem (liberado por plano) | Não | 🧭 / ⚙️ |

### 4.2 Recebimento de pedidos
| Item | Entidade / Endpoint | Obrigatório? | Provisão |
|---|---|---|---|
| Formas de pagamento (Dinheiro, PIX, Cartão…) | `forma_pagamento` / `/api/formas-pagamento` | **Sim** | 🌱 defaults + 🧭 |
| Taxa de entrega por bairro (valor, tempo) | `taxa_entrega` / `/api/taxas` | Sim (se entrega) | 🧭 |
| Horário de funcionamento (7 dias, abre/fecha) | `horario_funcionamento` / `/api/horarios` | Sim | 🌱 padrão + 🧭 |
| Motivos de cancelamento (RN05) | `motivo_cancelamento` / `/api/motivos` | Sim | 🌱 defaults |
| Catálogo: produtos (nome, categoria, preço, imagem) | `produto` / `/api/produtos` | **Sim** | 🧭 |
| Complementos (grupos min/máx + itens) | `complemento_grupo/item` | Não | 🧭 / ⚙️ |

### 4.3 Preparo, entrega e acerto
| Item | Entidade / Endpoint | Obrigatório? | Provisão |
|---|---|---|---|
| Quadro de status / KDS | usa `pedido` + `log_status` | Sim | já funciona |
| SLA de preparo (alerta de atraso RN04) | hoje fixo por canal no front (`BORA_SLA`) | Não | ⚙️ (config por loja é melhoria) |
| Entregadores (nome, telefone, veículo) | `entregador` / `/api/entregadores` | Sim (se entrega) | 🧭 |
| Acerto de motoboy | `acerto_entregador` / `/api/acertos` | Não | ⚙️ (opera sob demanda) |

### 4.4 Canais e integrações
| Item | Entidade / Endpoint | Obrigatório? | Provisão |
|---|---|---|---|
| Cardápio digital público (QR / link) | `/public/loja/{id}/cardapio` | Sim | 🌱 (nasce do catálogo) |
| Canal próprio WhatsApp (número do dono) | `integracao_canal` / config IA | Recomendado | 🧭 |
| iFood / 99Food / Rappi (merchantId, tokens) | `integracao_canal` / `/api/integracoes/{canal}` | Não | 🔌 |
| Módulo IA (Gerente Virtual, recuperação) | `loja.moduloIa` (add-on) | Não | ⚙️ liberado pelo ADMINISTRADOR_BORA |

### 4.5 Gestão e monetização
| Item | Entidade / Endpoint | Obrigatório? | Provisão |
|---|---|---|---|
| Assinatura recorrente (Asaas) | `assinatura` / `/api/assinatura` | **Sim** p/ cobrança | 🔌 🧭 |
| Preço negociado (fundador R$149 etc.) | `loja.precoMensal` | Não | ⚙️ (ADMINISTRADOR_BORA) |
| Estoque / CMV (insumos + ficha técnica) | `insumo`, `produto_insumo` | Não | 🧭 / ⚙️ |
| Cupons e promoções | `cupom`, `promocao` | Não | ⚙️ |
| CRM / clientes / cashback | `cliente` | Não (cresce sozinho) | — |
| Relatórios, Rede & Análise, termômetro | agregam dados existentes | Sim | já funciona |
| Fiscal (NFC-e) | toggle global `fiscal.habilitado` | Não | 🔌 ⚙️ (plataforma) |

---

## 5. Estratégia de provisionamento recomendada (defaults + wizard)

A loja deve nascer **quase pronta** por defaults semeados e ser finalizada por um **assistente guiado** com barra de progresso. Três camadas:

### Camada 1 — Semear automaticamente no cadastro (🌱, transacional no signup)
Ao criar a loja (em `SignupController`/`PlataformaController`), popular de uma vez:

- **`configuracao_loja`** — registro criado já com `nomeExibicao` = nome da loja, `corPrimaria` padrão (#7c3aed) e `mostrarMarcaBora` conforme plano.
- **`forma_pagamento`** — Dinheiro (com troco), PIX (online), Cartão de crédito, Cartão de débito — todas ativas.
- **`motivo_cancelamento`** — "Cliente desistiu", "Fora da área de entrega", "Produto em falta", "Endereço não encontrado", "Loja fechada".
- **`horario_funcionamento`** — 7 linhas (dom–sáb) com um horário padrão (ex.: 18:00–23:00) marcado para o lojista revisar.
- (Opcional) **produtos de exemplo** desativados, como modelo — ou nenhum, para não sujar o catálogo.

> Efeito: recém-criada, a loja já aceita pedido no balcão com pagamento e já tem cardápio válido assim que o 1º produto entrar.

### Camada 2 — Assistente de onboarding no painel (🧭, guiado com progresso)
Um checklist de ativação na home (estilo "Comece por aqui"), calculando **% de prontidão** e destravando o "publicar cardápio":

1. **Marca** — logo + cor (Configurações).
2. **Cardápio** — cadastrar ao menos 1 categoria e 1 produto com preço.
3. **Entrega** — taxa de pelo menos 1 bairro (ou marcar "só retirada").
4. **Horário** — confirmar os horários semeados.
5. **Equipe** — (opcional) criar operador/gerente.
6. **Pagamento da plataforma** — assinar no Asaas (CPF/CNPJ).
7. **Canais** — (opcional) conectar WhatsApp / marketplaces.

Cada passo lê o dado real via API e marca ✓ quando preenchido. A loja é considerada "operável" ao concluir os passos 1–4 e 6.

### Camada 3 — Avançado/opcional (⚙️ / 🔌, sob demanda)
Complementos, insumos/CMV, cupons/promoções, integrações de marketplace, módulo IA, fiscal — apresentados como "turbine sua loja", sem bloquear o go-live.

---

## 6. Sequência técnica do provisionamento (o que o endpoint deve fazer)

Num único método `@Transactional` de criação de loja:

1. Validar entrada (nome, documento, e-mail, senha ≥ 6) — já existe.
2. Criar `loja` (plano ÚNICO, ativo) — já existe.
3. Criar `usuario` admin (BCrypt) + `usuario_loja` — já existe.
4. **[novo] Semear Camada 1**: `configuracao_loja`, `forma_pagamento` (4), `motivo_cancelamento` (5), `horario_funcionamento` (7). Idealmente via um `ProvisionamentoService.semear(lojaId, nomeLoja, plano)` chamado tanto pelo signup self-service quanto pelo `/admin-bora/lojas`.
5. **[novo] Estado de onboarding**: registrar quais passos faltam (pode ser derivado on-the-fly da presença dos dados, sem tabela nova — mais simples e sem migration).
6. Retornar `{ lojaId, adminEmail, prontidao: % }`.
7. Assinatura no Asaas segue como passo do wizard (envolve CPF/CNPJ e cliente externo), não no signup.

**Cuidados de isolamento (RN08):** todo dado semeado usa o `loja_id` recém-criado; nenhuma query de leitura pode cruzar lojas. O `ProvisionamentoService` deve receber o `lojaId` explicitamente (não do token), pois no self-service ainda não há sessão.

---

## 7. Checklist de go-live (ordenado, por loja)

- [ ] Loja criada com nome e documento corretos, plano certo.
- [ ] Admin da loja com senha forte (troca no 1º acesso).
- [ ] White-label: logo + cor + nome de exibição.
- [ ] Formas de pagamento revisadas (semeadas por padrão).
- [ ] Horário de funcionamento confirmado (semeado por padrão).
- [ ] Motivos de cancelamento revisados (semeados por padrão).
- [ ] Catálogo: categorias + produtos com preço (e imagem quando possível).
- [ ] Taxa de entrega por bairro **ou** marcar "somente retirada".
- [ ] Entregadores cadastrados (se há entrega própria).
- [ ] Cardápio público testado (`/public/loja/{id}/cardapio`, QR).
- [ ] Assinatura ativa no Asaas (CPF/CNPJ do lojista).
- [ ] (Opcional) Canais conectados: WhatsApp, iFood/99Food.
- [ ] (Opcional) Módulo IA liberado (add-on) pelo ADMINISTRADOR_BORA.
- [ ] Equipe criada com papéis corretos (respeita limite do plano).
- [ ] Teste ponta a ponta: novo pedido → status → entrega → relatório.

---

## 8. Integrações externas e credenciais necessárias

| Integração | Para quê | Credenciais / dados | Onde |
|---|---|---|---|
| **Asaas** | Cobrança recorrente da mensalidade | `ASAAS_API_KEY`, `ASAAS_WEBHOOK_TOKEN` (plataforma) + CPF/CNPJ do lojista | env + `/api/assinatura` |
| **WhatsApp** | Robô / avisos ao cliente e resumo do dono | número do dono; provedor de envio | `integracao_canal` / módulo IA |
| **iFood / 99Food / Rappi** | Importar pedidos do marketplace | `merchantId`, `clientId`, `clientSecret`, `webhookToken` | `/api/integracoes/{canal}` |
| **Fiscal (NFC-e)** | Emissão fiscal | toggle global + credencial fiscal | `/admin-bora/config/fiscal` |

Sem Asaas configurado na plataforma, a loja opera, mas não há cobrança automática — decisão de negócio para o piloto.

---

## 9. Lacunas e decisões pendentes (identificadas no código)

1. **Não existe entidade `Categoria`** — `produto.categoria` é texto livre. Para um cardápio organizado, decidir entre (a) manter texto livre com autocomplete, ou (b) criar entidade `categoria` (nova migration). Recomendo (a) no curto prazo.
2. **"Tipo de venda" (entrega/retirada/salão/ficha)** não é gravado no pedido — o Saipos segmenta por isso. Se quiser paridade, exige campo novo em `pedido` + migration (já discutido).
3. **SLA de preparo** é fixo por canal no front (`BORA_SLA`); tornar configurável por loja é melhoria.
4. **Estado de onboarding** — preferir derivar a prontidão on-the-fly (presença dos dados) a criar tabela nova, para não adicionar migration.
5. **Semeadura idempotente** — o `ProvisionamentoService` deve checar existência antes de inserir, para poder rodar em lojas antigas sem duplicar.
6. **Plano ÚNICO** hoje libera quase tudo; se surgirem tiers, os defaults semeados e o wizard devem respeitar o que o plano permite (RN10 já cobre white-label).

---

## 10. Roadmap de implementação sugerido (quando for codar)

1. **`ProvisionamentoService.semear(lojaId, nome, plano)`** — Camada 1 (defaults idempotentes). Ligar no `SignupController` e `PlataformaController`. Sem migration.
2. **Endpoint de prontidão** — `GET /api/onboarding` retornando os passos e o `% concluído`, derivado dos dados reais.
3. **Wizard no painel** — card "Comece por aqui" na `dashboard.html`, consumindo `/api/onboarding`, com deep-links para cada tela.
4. **Retrofit** — rodar a semeadura nas lojas já existentes (endpoint admin ou no start).
5. **Extras** — categoria estruturada, tipo de venda, SLA por loja (cada um com sua migration), conforme prioridade comercial.

---

*Base: análise do código em `bora-fase-3-backend-java` (entidades, controllers de signup/plataforma/operação, `BootstrapAdmin`, `ConfiguracaoLojaService`, `AssinaturaService`) e do front `bora-fase-2-frontend` (ajustes, configurações, api.js). Nenhuma alteração de código foi feita — este é o levantamento prévio.*
