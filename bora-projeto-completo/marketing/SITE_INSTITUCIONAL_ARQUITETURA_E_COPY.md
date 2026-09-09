# Site institucional BoraHapp (borahapp.com.br) — Arquitetura e Copy

> Base lida: `bora-landing/index.html` (landing atual, página única) e `bora-projeto-completo/docs/ESTUDO_MERCADO_2026.md` (guerra do delivery, jul/2026).
> Empresa: ADF Sistemas e Tecnologias LTDA, CNPJ 68.761.778/0001-57, Sorocaba/SP. WhatsApp (15) 99860-2332.
> Preço a comunicar: **R$ 199/mês por loja**, pedidos ilimitados, até 15 usuários, sem taxa por pedido, sem comissão.

## 0. Decisões

| Pergunta | Decisão |
|---|---|
| Quantas páginas | **5**: Home, Funcionalidades, Preços, Sobre, Contato |
| Tese central | Trocar "se gerencia sozinho" por **"no seu controle"** — mantém "sua marca/seu cliente/seu dinheiro" e "preço fixo" (validado pelo estudo de mercado), sem prometer autonomia que o produto ainda não entrega |
| iFood/99Food, robô de WhatsApp, PIX direto | **Não omitir, não vender como pronto.** Seção de roadmap explícita ("já funciona hoje" x "em construção") na página Funcionalidades, com frase-ponte na Home |
| Oferta "R$149 vitalício, restam 10 vagas" | **Tirar de vez.** Substituir pela garantia de 30 dias (já real) como gancho de segurança. Alternativas honestas descritas na seção 4, se quiserem manter um gancho comercial |

## 1. Arquitetura do site — justificativa

A landing atual converte bem quem já chega decidido (tráfego pago, link de WhatsApp, indicação): hero, recursos, comparativo, calculadora, preço e FAQ numa rolagem só. O site institucional também precisa servir quem está *pesquisando antes de decidir* — essas pessoas usam Google, comparam concorrentes (Anota AI, Saipos, Delivery Direto, OlaClick — ver estudo de mercado) e conferem o CNPJ da empresa antes de assinar. Uma página só não segura as duas jornadas sem virar uma rolagem cansativa.

Por isso, 5 páginas:

1. **Home** — porta de entrada para quem já ouviu falar do Bora. Vende a ideia em 90 segundos e direciona para Funcionalidades (dúvida técnica) ou Preços (já decidindo). Mantém o comparativo "mensalidade fixa x comissão" e a calculadora interativa — melhor gancho de atração hoje, conforme o próprio estudo de mercado recomenda como ação de custo zero.
2. **Funcionalidades** — profundidade para quem compara com concorrente antes de assinar. Carrega o roadmap honesto (o que já está no ar x o que está sendo construído) — não cabe na Home sem pesar a conversão de quem só quer decidir rápido.
3. **Preços** — página de maior intenção de compra; destino de tráfego pago comercial. Separar do resto evita que dúvidas sobre cancelamento/dinheiro pareçam "letra miúda" escondida — ficam visíveis, o que passa mais confiança.
4. **Sobre** — resolve "quem é essa empresa?". Dono de delivery de bairro é desconfiado de recorrência com CNPJ desconhecido; uma página de instituição (CNPJ, cidade, propósito) resolve isso.
5. **Contato** — curta e objetiva, útil para SEO de marca e para confirmar que existe atendimento humano.

**O que não foi criado agora, e por quê:**
- **Depoimentos/casos de sucesso** — ainda não há clientes suficientes para citar sem forçar. Fabricar prova social destrói a credibilidade que a página Sobre tenta construir. Criar quando houver 3–5 casos reais.
- **"Como funciona" separada** — o conteúdo já cabe na Home (3 passos) e na Funcionalidades (detalhe por área); página a mais seria redundante.
- **Blog/conteúdo** — estratégia de aquisição válida (a "Guerra do Delivery" é gancho forte), mas é frente contínua de marketing de conteúdo, não página estática do site v1.
- **Página própria da calculadora** — funciona melhor embutida na Home, com tráfego já existente, do que isolada.

Navegação (todas as páginas): **Home · Funcionalidades · Preços · Sobre · Contato**, com "Entrar" e "Falar no WhatsApp" fixos à direita.

## 2. Tese central

**Hoje:** "O delivery que se gerencia sozinho: sua marca, seu cliente, seu dinheiro — preço fixo que não cresce quando você cresce."

**Problema:** "se gerencia sozinho" sugere autopilotagem, no momento exato em que é preciso ser preciso sobre o que ainda depende do lojista fazer manualmente (não tem robô de WhatsApp, não tem PIX que concilia sozinho). Prometer autonomia na tese central e desmenti-la no roadmap é a contradição mais visível que o site poderia ter.

**Recomendação:** manter "sua marca / seu cliente / seu dinheiro" (bate direto na lacuna nº 1 do estudo de mercado: no canal próprio o dono é dono do dado do cliente) e trocar a abertura:

> **"Seu delivery, no seu controle: sua marca, seu cliente e seu dinheiro — por uma mensalidade fixa que não sobe quando você vende mais."**

"No seu controle" entrega a mesma emoção de autonomia sem prometer o que o produto não faz — organiza tudo em tempo real num painel que o dono enxerga, controle, não piloto automático. A segunda metade da frase (mensalidade fixa) não muda: é a lacuna nº 1 do mercado hoje (guerra de comissão iFood/Keeta/99Food).

**Tagline curta:** "Seu delivery. Sua marca. Preço que não sobe."

## 3. Tratamento dos 3 recursos ainda não prontos

Recursos: integração automática iFood/99Food, robô de atendimento no WhatsApp, PIX que cai direto e sozinho na conta do lojista.

A landing atual promete os três como prontos (hero, 3 cards, 3 itens do plano, 2 respostas de FAQ). Isso gera cancelamento por decepção no primeiro mês e é risco de propaganda enganosa (CDC) para uma cobrança recorrente.

**Recomendação:** nem vender como pronto, nem omitir — seção de roadmap explícita na página Funcionalidades, com frase-ponte na Home. Omitir faz o lojista descobrir sozinho depois de pagar (pior para confiança). "Em breve" genérico sem estado atual claro ainda cria expectativa de prazo que não existe. Contar o estado real é diferencial de marca frente à Geração 3 de concorrentes (Brendi, OlaClick) que vende promessa de IA por todo lado.

**Copy (página Funcionalidades, seção final):**

> **Sendo construído agora**
>
> **O que já está no ar — e o que vem a seguir**
>
> Preferimos contar exatamente o que funciona hoje a prometer o que ainda não existe.
>
> **Já funciona hoje:** pedidos em tempo real, tela de cozinha (KDS), organização de entregas por bairro, cardápio digital com QR Code (o cliente escolhe pagar por PIX, dinheiro ou cartão na entrega), sua marca em tudo, rede multi-lojas com balancete, CRM e cashback, estoque e CMV, relatórios em PDF/Excel.
>
> **No radar, em construção:**
> - **Integração automática com iFood e 99Food** — pedido do marketplace caindo direto no seu painel do BoraHapp, sem trocar de tela.
> - **Robô de atendimento no WhatsApp** — respostas automáticas de cardápio, horário de funcionamento e status do pedido.
> - **PIX automático no cardápio** — cliente paga, o sistema confirma sozinho e o dinheiro cai direto na sua conta, sem passo manual.
>
> Sem data fechada pra prometer — preferimos lançar redondo a lançar rápido e mal. Se algum desses recursos é decisivo pra você hoje, fala com a gente antes de assinar: somos diretos sobre o que já está pronto.

**Frase-ponte (Home, antes do CTA final):**
> "Também estamos construindo integração com iFood/99Food, robô de WhatsApp e PIX automático no cardápio. Veja o que já funciona e o que vem a seguir →"

**Textos da landing atual que precisam mudar na migração:**
- Hero: tirar "PIX online, robô de WhatsApp".
- Card "PIX na hora, direto pra você" → mover pro roadmap; reescrever card do cardápio como "cliente escolhe como pagar: PIX (chave), dinheiro ou cartão na entrega".
- Card "Robô de WhatsApp" → mover pro roadmap.
- Card "Marketplaces: Receba pedidos do iFood, Rappi..." → mover pro roadmap.
- Lista do plano: tirar "Pedido online com PIX" (reescrever), "Robô de WhatsApp (API oficial)", "Pedidos de marketplaces no painel".
- FAQ "Como recebo o dinheiro dos meus pedidos?" → reescrever (seção 6).
- FAQ "Preciso abandonar o iFood?" → reescrever (seção 6).
- Seção Economia, observação final ("os pedidos de lá também caem no painel do BoraHapp") → reescrever: "Você não precisa abandonar o marketplace hoje — pode continuar recebendo pedidos por lá enquanto constrói seu canal próprio com o BoraHapp. (A integração automática com iFood e 99Food está no nosso roadmap — veja em Funcionalidades.)"

## 4. Oferta de fundador "R$149 vitalício · restam 10 vagas"

**Recomendação: tirar de vez, sem substituir por outra contagem regressiva.**

- Preço "vitalício" trancado por cliente é dívida operacional permanente na cobrança.
- "Restam 10 vagas" estático (sem decrementar de verdade) é escassez falsa — a mesma tática fraca da Geração 3 de concorrentes (Brendi, preço variável disfarçado) apontada no estudo de mercado.
- A garantia de 30 dias já resolve a mesma ansiedade (risco da decisão) sem depender de contagem de vagas.

**Copy de substituição (padrão recomendado):**

> **Preço único, sem letra miúda**
> R$ 199 é o valor pra todo mundo — seja a sua primeira loja ou a quinta. Sem promoção que some amanhã, sem "oferta por tempo limitado" que nunca termina. E se em 30 dias o Bora não for pra você, devolvemos o que você pagou.

**Alternativas honestas, se quiserem manter um gancho comercial:**
- **Opção A — desconto no primeiro mês, com data real:** "Primeiro mês por R$ 99. A partir do segundo, R$ 199/mês, sem fidelidade. Oferta válida pra quem assinar até [data real]." — só publicar com data que pretendem realmente encerrar.
- **Opção B — indicação (ideia do estudo de mercado):** "Indicou, ganhou: cada lojista que você trouxer pro Bora dá 1 mês grátis pra você e 1 mês grátis pra ele." — custo pontual, não permanente.

Recomendação: Opção A como próximo movimento comercial, se quiserem algo mais agressivo. Mas o padrão de lançamento do site novo deve ser a versão sem gancho.

## 5. Copy completa por página

### PÁGINA 1 — HOME

**Título da aba (SEO):** BoraHapp — Sistema de delivery com a sua marca, sem taxa por pedido
**Meta description:** Organize pedidos, cozinha e entregas do seu delivery com o painel e o cardápio da sua marca. R$ 199/mês por loja, pedidos ilimitados, sem comissão.

**Navegação:** Home · Funcionalidades · Preços · Sobre · Contato | Entrar | Falar no WhatsApp

**Selo acima do título:** Sistema no ar em minutos · sem taxa por pedido

**H1:** Seu delivery, no seu controle.

**Subtítulo:** Sua marca, seu cliente e seu dinheiro — por uma mensalidade fixa que não sobe quando você vende mais.

**Parágrafo de apoio:** O BoraHapp organiza pedidos, cozinha e entregas em tempo real, com um cardápio digital e um painel que têm a cara da sua loja — não a nossa.

**CTA primário:** Criar minha loja
**CTA secundário:** Ver todos os recursos

---

**Seção — O problema que você já viveu**

Kicker: Se isso parece familiar...
H2: Pedido anotado no papel, print perdido no WhatsApp, motoboy sem saber pra onde ir.

- Você recebe pedido pelo WhatsApp, pelo balcão e pelo aplicativo — e tudo vira uma bagunça de abas e memória.
- Quando o entregador pergunta "qual endereço mesmo?", o pedido já esfriou.
- No fim do mês, você não sabe direito quanto vendeu, quanto foi de comissão, nem quem comprou mais.

Linha de transição: O BoraHapp organiza tudo isso pra você, em tempo real, com a sua marca.

---

**Seção — Como funciona**

Kicker: Simples assim
H2: Do papel pro painel em 3 passos

1. **Cadastre sua loja** — Nome, logo e cores da sua marca. Em minutos, seu painel está pronto.
2. **Monte o cardápio** — Adicione produtos, preços e horários. Publique o cardápio digital com QR Code.
3. **Comece a vender** — Receba pedidos, organize a cozinha e as entregas, e acompanhe tudo pelos relatórios.

CTA: Quero começar agora

---

**Seção — Recursos em destaque**

Kicker: Tudo o que já funciona hoje
H2: Da cozinha à entrega, sem planilha
Apoio: Ferramentas simples de usar no balcão, na cozinha e no celular — sem curso, sem manual.

- **Pedidos em tempo real** — Painel da cozinha à entrega, com alerta de atraso e aviso de pedido novo.
- **Tela de cozinha (KDS)** — Fila por ordem de chegada, cronômetro e um toque pra avançar o status.
- **Entregas organizadas** — Agrupe por bairro, despache em lote e defina o entregador em segundos.
- **Cardápio digital com QR Code** — O cliente escaneia, monta o pedido sozinho e ele cai direto na cozinha.
- **Sua marca em tudo** — Logo, cores e nome da sua loja no painel, no cardápio e nos relatórios.
- **Relatórios que fazem sentido** — Faturamento, ticket médio e vendas por produto, exportado em PDF ou Excel.

CTA: Ver todos os recursos →

---

**Seção — Faça a conta** (manter comparativo e calculadora já existentes)

Kicker: Faça a conta
H2: Mensalidade fixa, não porcentagem
Apoio: Nos aplicativos de entrega, quanto mais você vende, mais você paga de comissão. No canal próprio com o BoraHapp, o custo é o mesmo vendendo 100 ou 10 mil pedidos.

(Manter o bloco comparativo "Só no marketplace" x "Canal próprio com o BoraHapp" e a calculadora interativa como estão. Ajustar só a observação final:)

Nova observação: Valores ilustrativos — comissões variam por contrato e categoria. Você não precisa abandonar o marketplace hoje: pode continuar recebendo pedidos por lá enquanto constrói seu canal próprio com o BoraHapp. (A integração automática com iFood e 99Food está no nosso roadmap — veja em Funcionalidades.)

---

**Seção — Por que confiar** (substitui depoimentos fabricados por marcadores de confiança reais)

Kicker: Quem está por trás
H2: Uma empresa de verdade, não um projeto de garagem

- CNPJ registrado: ADF Sistemas e Tecnologias LTDA — 68.761.778/0001-57
- Sede em Sorocaba/SP, atendimento em todo o Brasil
- Suporte por WhatsApp com gente de verdade, não robô

CTA: Conhecer a empresa →

---

**Seção — Preço resumido**

Kicker: Preço transparente
H2: Um plano só. R$ 199/mês por loja.

- Pedidos ilimitados
- Até 15 usuários por loja
- Sem taxa por pedido, sem comissão
- Sem fidelidade — cancele quando quiser
- Garantia de 30 dias

CTA primário: Ver o plano completo →
CTA secundário: Criar minha loja

---

**CTA final**

H2: Bora colocar seu delivery no controle?
Apoio: Fale com a gente e comece a organizar pedidos, cozinha e entrega ainda hoje — com a marca da sua loja.
CTA: Falar no WhatsApp agora

---

### PÁGINA 2 — FUNCIONALIDADES

**Título da aba:** Funcionalidades do BoraHapp — pedidos, cozinha, entregas e mais
**Meta description:** Conheça tudo o que o BoraHapp já faz pelo seu delivery: pedidos em tempo real, KDS, entregas, cardápio digital, CRM, estoque e relatórios — com a marca da sua loja.

**Kicker:** Recursos
**H1:** Tudo o que o seu delivery precisa, num só painel.
**Subtítulo:** Simples de usar no balcão, na cozinha e no bolso — sem treinamento, sem manual de 40 páginas.

**Pedidos e cozinha**
- *Pedidos em tempo real* — Todo pedido novo aparece na hora, com aviso sonoro. Você acompanha o status de cada um até a entrega, sem precisar perguntar pra ninguém "cadê o pedido 42?".
- *Tela de cozinha (KDS)* — Fila organizada por ordem de chegada, cronômetro em cada pedido e um toque pra avançar o status. Feito pra ficar aberto numa TV ou tablet na cozinha.

**Entregas**
- *Entregas organizadas por bairro* — Agrupe pedidos da mesma região, despache em lote e atribua entregador em segundos. Sem anotar endereço em papel.

**Cardápio e vendas**
- *Cardápio digital com QR Code* — Seu cliente escaneia, monta o pedido sozinho e escolhe como pagar (PIX por chave, dinheiro ou cartão na entrega). O pedido cai direto na sua cozinha, sem digitação manual.

**Sua marca (white-label)**
- *Sua marca em tudo* — Logo, cores e nome da sua loja no painel, no cardápio digital e nos relatórios. Quem aparece pro seu cliente é você, não o BoraHapp.

**Rede de lojas**
- *Multi-lojas com balancete* — Tem mais de uma unidade? Troque de loja com um clique e acompanhe o faturamento consolidado da rede.

**Relacionamento com o cliente**
- *CRM e cashback* — Fidelize com cashback, reative clientes que sumiram e segmente sua base pra promoções direcionadas.

**Gestão**
- *Estoque e CMV* — Ficha técnica, baixa automática na venda, custo e margem por produto.
- *Relatórios gerenciais* — Faturamento, ticket médio, vendas por canal e por produto. Exporte em PDF ou Excel.

**Módulo IA** (add-on opcional, +R$ 99/mês)
Um gerente trabalhando por você por menos de R$ 3,30 por dia: resumo diário no seu WhatsApp, recuperação automática de clientes sumidos e cadastro de cardápio por foto. Detalhes e preço completo na página de Preços.

---

**Seção — Sendo construído agora** (copy da seção 3 acima)

---

CTA de fechamento da página: Quer ver isso rodando na sua loja? Falar no WhatsApp | Criar minha loja

---

### PÁGINA 3 — PREÇOS

**Título da aba:** Preços do BoraHapp — R$ 199/mês por loja, pedidos ilimitados
**Meta description:** Um plano só, com tudo incluso: R$ 199 por mês por loja, pedidos ilimitados, até 15 usuários, sem taxa por pedido. Sem fidelidade, garantia de 30 dias.

**Kicker:** Preço transparente
**H1:** Um plano. Tudo incluso. Sem pegadinha.
**Subtítulo:** R$ 199 por mês, por loja. Pedidos ilimitados. Sem taxa por pedido, sem comissão sobre suas vendas.

**Cartão do plano — BoraHapp — R$ 199/mês por loja**
- Pedidos ilimitados
- Até 15 usuários por loja
- Painel de pedidos em tempo real
- Tela de cozinha (KDS)
- Entregas organizadas por bairro
- Cardápio digital com QR Code
- Rede multi-lojas com balancete consolidado
- CRM, cashback e promoções
- Estoque, CMV e relatórios (PDF/Excel)
- White-label: sua marca em tudo
- Sem fidelidade — cancele quando quiser
- Garantia de 30 dias: não gostou, devolvemos

CTA: Criar minha loja

**Banner abaixo do plano** (substitui a oferta de fundador — seção 4):

Preço único, sem letra miúda
R$ 199 é o valor pra todo mundo — seja sua primeira loja ou a quinta. Sem promoção que suma amanhã, sem "oferta por tempo limitado" que nunca termina. E se em 30 dias o Bora não for pra você, devolvemos o que pagou.

**Bloco Módulo IA** (manter como está na landing atual)

Kicker: add-on opcional
H3: Módulo IA — +R$ 99/mês por loja
Apoio: Um gerente trabalhando pra você por menos de R$ 3,30 por dia:
- Gerente Virtual — Resumo diário no seu WhatsApp: faturamento, comparativo e alertas, todo dia.
- Recuperador de clientes — Chama de volta quem sumiu há 21+ dias, sozinho, e mostra quantos reais recuperou.
- Migração por foto — Fotografe seu cardápio atual e a IA cadastra tudo em minutos.
CTA: Quero o Módulo IA

**Seção — Faça a conta**

Kicker: Comissão x mensalidade
H2: Comissão que cresce com você vs. mensalidade que não muda
(tabela estática com os mesmos números do comparativo da Home: 1.000 pedidos/mês × ticket R$ 40 = R$ 40.000; comissão média ~25% = R$ 10.000 no marketplace; R$ 199 fixo com o BoraHapp)
Link: Quer simular com os seus números? Use a calculadora na página inicial →

**Seção — Perguntas frequentes** (copy completa na seção 6, abaixo)

**CTA final:** Criar minha loja | Falar no WhatsApp

---

### PÁGINA 4 — SOBRE

**Título da aba:** Sobre o BoraHapp — sistema de delivery da ADF Sistemas e Tecnologias
**Meta description:** Conheça o BoraHapp: por que criamos um sistema de delivery com preço fixo e marca própria pro pequeno lojista brasileiro.

**H1:** Por que existe o BoraHapp

**Corpo:**
A gente viu o mesmo problema se repetir em sorveteria, açaiteria, lanchonete e pizzaria de bairro: o dono vende cada vez mais e sobra cada vez menos, porque a comissão do aplicativo cresce junto com as vendas. E quem fica com o cliente, com o contato, com o histórico de compra, é o aplicativo — não a loja.

O BoraHapp nasceu pra inverter isso: um sistema com a marca da sua loja, não a nossa, e uma mensalidade que não muda se você vender 100 ou 10 mil pedidos no mês. Você organiza pedido, cozinha e entrega em tempo real — e continua dono do seu cliente, do seu dado e do seu dinheiro.

**Seção — Como trabalhamos**

- **Preço fixo é compromisso, não promoção.** R$ 199 é o valor pra todo mundo, sempre.
- **Só prometemos o que já está no ar.** O que ainda estamos construindo, a gente conta — veja nosso roadmap na página de Funcionalidades.
- **Sua marca, não a nossa.** O BoraHapp fica nos bastidores; quem aparece pro seu cliente é você.

**Seção — Quem está por trás**

O BoraHapp é um produto da ADF Sistemas e Tecnologias LTDA, CNPJ 68.761.778/0001-57, com sede em Sorocaba/SP. Atendemos lojistas de delivery em todo o Brasil pelo WhatsApp (15) 99860-2332.

**CTA:** Quer conversar com a gente antes de assinar? Falar no WhatsApp

---

### PÁGINA 5 — CONTATO

**Título da aba:** Fale com o BoraHapp — WhatsApp, suporte e vendas
**Meta description:** Fale com o time do BoraHapp pelo WhatsApp (15) 99860-2332. Tire dúvidas, peça uma demonstração ou comece sua loja hoje.

**H1:** Bora conversar?
**Subtítulo:** Tira dúvida, pede uma demonstração ou já começa sua loja — tudo pelo WhatsApp, com gente de verdade do outro lado.

Três botões, cada um com WhatsApp pré-preenchido diferente:
- **Quero conhecer o BoraHapp** → "Quero conhecer o BoraHapp"
- **Já sou cliente, preciso de suporte** → "Sou cliente do BoraHapp e preciso de ajuda"
- **Quero criar minha loja agora** → "Quero criar minha loja no BoraHapp"

**Dados da empresa:**
ADF Sistemas e Tecnologias LTDA
CNPJ 68.761.778/0001-57
Sorocaba/SP
WhatsApp: (15) 99860-2332

**Linha final:** Antes de falar com a gente, dá uma olhada nas perguntas mais frequentes → (link pra Preços#faq)

## 6. FAQ completa (objeções reais de quem paga mensalidade de software)

**E se eu quiser sair?**
Não tem fidelidade nem multa de cancelamento. A assinatura é mensal: você cancela quando quiser e o acesso continua até o fim do período já pago. No primeiro mês, vale a garantia de 30 dias — se não for pra você, devolvemos o valor.

**Meus dados são meus?**
Sim. Os pedidos, o cadastro de clientes e o histórico de vendas são da sua loja, não nossos. Se um dia você sair, pode pedir a exportação dos seus dados. Não vendemos nem compartilhamos informação de cliente com terceiros.

**Funciona no celular? Preciso de computador?**
Funciona no navegador do celular, tablet ou computador — não precisa instalar nada. A tela de cozinha (KDS) foi pensada pra ficar aberta numa TV ou tablet na cozinha, mas dá pra rodar a loja inteira só com o celular.

**Tem taxa por pedido ou porcentagem sobre as vendas?**
Não. R$ 199/mês por loja, com pedidos ilimitados. Vendendo mais, você paga o mesmo — nunca uma porcentagem das suas vendas.

**Como recebo o dinheiro dos meus pedidos?**
Hoje, o cliente escolhe no cardápio como quer pagar: PIX (chave), dinheiro ou cartão na entrega/balcão — igual você já faz. O pagamento não passa pela nossa conta em nenhum momento: é sempre direto entre você e o seu cliente. Confirmação automática de PIX no próprio cardápio está no nosso roadmap.

**Preciso abandonar o iFood ou outros aplicativos?**
Não. O BoraHapp cuida do seu canal próprio (WhatsApp, cardápio com QR Code, pedido direto). Você pode continuar recebendo pedidos pelos aplicativos normalmente enquanto cresce seu canal próprio, que é o que não paga comissão. Estamos construindo a integração automática pra trazer os pedidos do iFood e do 99Food pro mesmo painel; ainda não está no ar.

**Tenho mais de uma loja. Como funciona?**
Cada loja tem seu próprio painel, cardápio e assinatura de R$ 199/mês. Você troca de loja com um clique e acompanha o balancete consolidado da rede.

**Preciso saber de tecnologia pra usar?**
Não. Se você sabe usar WhatsApp, sabe usar o BoraHapp. Não tem curso nem manual obrigatório — o cadastro da loja e do cardápio leva minutos.

**Quanto tempo leva pra colocar minha loja no ar?**
Em geral, minutos: você cadastra nome, logo e cores, monta o cardápio e já pode publicar o QR Code. Se quiser ajuda, a gente acompanha o processo pelo WhatsApp.

**A empresa é confiável? Quem está por trás do BoraHapp?**
O BoraHapp é operado pela ADF Sistemas e Tecnologias LTDA, CNPJ 68.761.778/0001-57, sediada em Sorocaba/SP. Você pode conferir nosso CNPJ, falar com a gente pelo WhatsApp (15) 99860-2332 antes de assinar, e ver os Termos de Uso e a Política de Privacidade no rodapé do site.

**Meus clientes vão ver a marca do BoraHapp?**
Não. O painel, o cardápio digital e os relatórios rodam com a sua marca — seu logo, suas cores e o nome da sua loja. O BoraHapp fica nos bastidores.

**Pendências a confirmar antes de publicar (não inventar número/promessa):**
- "E se o sistema cair, eu perco pedido?" — precisa de SLA real ou rotina de backup confirmada antes de escrever a resposta.
- "Como é cobrada a assinatura?" (cartão, boleto, PIX recorrente) — depende de como o checkout de cobrança está implementado hoje.
