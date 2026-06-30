# Revisão de Negócio (ADM) + Termômetro de Vendas & Promoções Automáticas

## 1. Revisão crítica por fase — Falhas → Ajustes → Melhorias

**Produto/Operação**
- Falha: sem **alerta de atraso** (RN04) — pedido pode "morrer" no preparo. Ajuste: destacar pedidos parados acima do tempo limite (kanban). Melhoria: tempo-alvo por etapa configurável.
- Falha: cancelamento sem análise de causa. Ajuste: motivo já é obrigatório (RN05); Melhoria: relatório de motivos para reduzir recorrência.

**Vendas/Receita**
- Risco de vazamento: recurso dado além do plano. Ajuste: limites por plano já aplicados no backend (RN09). Melhoria: tela mostrando "X de Y pedidos do plano" com CTA de upgrade.
- Melhoria: ativação cobra muito pouco vs. valor entregue — manter implantação (R$99–599) como âncora.

**Retenção/Churn**
- Sinal antecedente de churn = **queda de vendas** + queda de uso. É aqui que entra o termômetro (abaixo).
- Melhoria: "pausar plano" em vez de cancelar; desconto de fidelidade.

**Custos** — todas as iniciativas abaixo são **SQL + job agendado = R$0 extra**, dentro do teto de R$ 800/mês (validado com finops).

## 2. Termômetro de Vendas (régua de saúde por loja)

**Métrica:** receita = soma de `valor_total` de pedidos **não cancelados**.

**Comparação:** receita da **janela atual** (dia corrente até agora) vs. **baseline** = média da receita nos **mesmos dias da semana das últimas 4 semanas**.

**Índice = atual / baseline.** Faixas:
| Faixa | Índice | Cor | Ação |
|------|--------|-----|------|
| SAUDÁVEL | ≥ 0,90 | verde | nenhuma |
| ATENÇÃO | 0,70–0,89 | amarelo | sugerir promoção (1 clique) |
| QUEDA | < 0,70 | vermelho | **abrir promoção rápida automática** |

**Guardas (anti-abuso / margem):**
- Não abre se já existe promoção ativa na loja.
- Máximo **1 promoção automática por dia** por loja.
- Desconto automático limitado (ex.: 15%) e validade curta (3h) com limite de usos.
- Baseline exige histórico mínimo (≥ 2 semanas) — sem isso, fica em "sem dados".

## 3. Promoções rápidas (marketing) ligadas ao gatilho
Tipos: **Cupom Relâmpago** (15%, 3h), **Combo do Dia**, **Frete Grátis por X horas**, **Última Hora**. Copy pronta em `marketing/ESTRATEGIA_PROMOCOES.md`. Comunicação: push no painel (grátis) e, no Premium, WhatsApp.

## 4. Implementação (backend)
- `Promocao` (entidade) + migration; `VendasSaudeService` (termômetro) e `PromocaoService` (abrir/listar).
- Endpoints: `GET /api/vendas/termometro`, `GET/POST /api/promocoes`.
- Job agendado a cada 30 min: para cada loja, se QUEDA + sem promo ativa + sob o limite diário → abre cupom relâmpago automático (origem AUTO) e registra.
