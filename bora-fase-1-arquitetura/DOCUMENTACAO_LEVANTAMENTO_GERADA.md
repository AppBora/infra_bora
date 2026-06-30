# Documentação de Levantamento — Arquitetura, Custos e Modelo SaaS da Bora

## Visão geral
A Bora é uma solução de gestão operacional para negócios de delivery, inicialmente pensada para sorveterias, açaíterias, lanchonetes e pequenos estabelecimentos que recebem pedidos por WhatsApp, balcão, telefone ou plataformas externas.

## Objetivo
Criar uma arquitetura de baixo custo, rápida de implantar e escalável para SaaS.

## Arquitetura de menor custo adaptada para Java
- Front-end web responsivo.
- Back-end Java com Spring Boot.
- PostgreSQL como banco principal.
- Docker para deploy.
- n8n para automações futuras.
- WhatsApp API como recurso premium ou add-on.

## Custos operacionais estimados
| Cenário | Custo mensal estimado |
|---|---:|
| Uso interno em uma loja | R$ 3 a R$ 50 |
| MVP comercial estável | R$ 150 a R$ 350 |
| SaaS inicial com n8n | R$ 200 a R$ 500 |
| SaaS com WhatsApp oficial | R$ 350 a R$ 1.200+ |

## Planos sugeridos
| Plano | Valor | Público |
|---|---:|---|
| Bora Start | R$ 69/mês | Pequenos deliveries começando a organizar pedidos |
| Bora Pro | R$ 129/mês | Deliveries com necessidade de gestão e relatórios |
| Bora Premium | R$ 249/mês + consumo WhatsApp | Operações com automação, subdomínio e marca mais personalizada |

## Ponto de equilíbrio
Com custo fixo inicial aproximado de R$ 250/mês, a Bora paga sua infraestrutura com cerca de 3 clientes Pro ou 4 clientes Start.

## Posicionamento
Controlar pedidos, entregas e vendas de pequenos deliveries em tempo real.
