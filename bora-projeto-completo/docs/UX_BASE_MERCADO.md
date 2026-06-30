# Base de Design (pesquisa de mercado) — Bora

Referências do segmento: iFood (Gestor/Portal do Parceiro), Uber Eats Manager, Rappi Partners, Goomer, Anota AI, Saipos, Cardápio Web. Recomendações consolidadas, adaptadas à promessa do Bora: **simplicidade + tempo real + mobile-first**.

## Princípios adotados
- **Operação, não só visualização.** As telas mais usadas (pedidos, novo pedido) precisam ser ferramentas de ação.
- **Mobile-first de verdade.** O lojista opera no celular, no balcão. A navegação não pode comer 30–40% da tela.
- **White-label sem quebrar contraste.** A cor primária do lojista entra em destaques/botões, nunca em texto sobre fundo claro sem contraste mínimo.

## Recomendações por tela (prioritárias)
1. **Pedidos = quadro em tempo real (kanban).** Colunas por status (Recebido → Em preparo → Pronto → Saiu → Entregue), cartões arrastáveis/clicáveis, cor por status, **alerta de atraso** (RN04) destacando cartões parados acima do tempo limite. É o padrão do setor e o maior ganho de usabilidade. *(Hoje é tabela — reestruturar.)*
2. **Novo pedido com seleção de produtos.** Buscar produto, somar itens, calcular total automaticamente, escolher/criar cliente, forma de pagamento e origem. *(Hoje pede valor manual — vira "bloco de notas".)*
3. **Navegação mobile.** Trocar a sidebar fixa por barra inferior (bottom-nav) ou menu retrátil no mobile; alvos de toque ≥ 44px.
4. **Dashboard operacional.** KPIs que importam no delivery: pedidos hoje, em preparo, saiu, entregues/hora, ticket médio, atrasos. *(Já ligado à API.)*

## Componentes/base visual
- Cards com sombra suave, raio generoso; listas no mobile (tabela colapsa em cards).
- Badges de status com cor semântica (já existe no CSS: `.b-*`).
- Tipografia legível (16px base nos inputs — ajustado), hierarquia clara.
- Botão primário usa a cor da loja; garantir contraste AA.

## Próximos passos de implementação (frontend)
Reescrever `pedidos.html` como kanban em tempo real (polling), `novo-pedido.html` com seleção de produtos, e bottom-nav mobile. Conectar todas as telas à API no padrão já usado no dashboard.
