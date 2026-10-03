# Levantamento de pendências do BoraHapp — 30/09/2026

Pergunta que originou este documento: **o que falta para o Bora rodar liso num cliente pagante?**
Resposta curta: **não falta só a integração com marketplace.** O sistema opera — pedido entra, cozinha
produz, entrega sai, PIX cai na conta do lojista. O que falta está espalhado entre segurança, cobrança,
e o que acontece quando algo dá errado e ninguém fica sabendo.

Doze agentes revisaram o sistema inteiro. Abaixo está a lista consolidada, sem repetição, ordenada por
**"o que impede vender amanhã"**. Cada item diz onde está o problema e o que fazer.

**Legenda de confiança:**
- ✅ **conferido por mim** — abri o código ou testei em produção, com o resultado na mão.
- 📋 **achado de agente** — vem com arquivo e linha, mas eu não reconferi um a um.

---

## 1. PARE TUDO — qualquer um pode entrar na loja de um cliente seu

✅ **Cadastro público com o CNPJ de outra loja dá acesso ao painel dela.**

O caminho, em quatro passos:
1. Qualquer pessoa cria uma loja em `borahapp.com.br/cadastro.html`. Testei em produção: o endereço
   está aberto, sem confirmação de e-mail e sem nenhuma barreira.
2. No cadastro tem um campo de CNPJ. Digitando o **CNPJ de um cliente seu**, o sistema coloca a loja nova
   **dentro da mesma empresa** do cliente — `EmpresaService.paraDocumento` reaproveita a empresa existente
   quando o CNPJ bate, **sem pedir prova nenhuma**.
3. Na mesma empresa, o recurso de rede multi-lojas deixa essa pessoa ligar o próprio usuário à loja da
   vítima. A única checagem em `RedeService.vincular` é "é da mesma empresa?" — e agora é.
4. Com o "trocar de loja", ela entra no painel da vítima **como administradora**: pedidos, clientes com
   telefone e endereço, usuários, integrações, faturamento.

CNPJ não é segredo: está na nota, na fachada e na página da loja no iFood.

**Risco hoje:** baixo — 5 lojas, todas suas ou da Zirá. **Risco com dez clientes:** vazamento de dados de
cliente, com LGPD junto.

**Conserto:** no cadastro público, nunca reaproveitar empresa existente — sempre criar uma nova. Agrupar
lojas sob a mesma empresa continua existindo, mas só pelo painel da plataforma (que já é o caminho certo).
Mais um teste automático que prove o buraco fechado.

---

## 2. PARE TUDO — link que rouba a senha do lojista

✅ **`borahapp.com.br/login.html?api=<site do golpista>`**

O painel aceita esse parâmetro e passa a mandar **todas** as chamadas para o endereço indicado, inclusive o
login. Quem abrir o link e digitar e-mail e senha manda os dois para o golpista — e o desvio **fica salvo no
navegador da vítima** para as próximas visitas. É um recurso de teste (`assets/js/api.js`, linha 3) que ficou
no código.

**Conserto:** apagar, ou aceitar só quando o endereço for `localhost`. Três linhas.

---

## 3. PARE TUDO — o mapa completo da API está aberto na internet

✅ Testei agora: `borahapp.com.br/swagger-ui/index.html` e `/v3/api-docs` respondem **200** para qualquer
pessoa. Isso entrega a lista das 138 rotas, incluindo as de administrador da plataforma — é o manual de
instruções para quem quiser procurar buraco.

**Conserto:** duas variáveis de ambiente desligando a documentação, aplicadas no próximo deploy.

---

## 4. PARE TUDO — robô do WhatsApp aceita ordem de qualquer um e guarda conversa de cliente no log

📋 `WhatsAppController.java:47-88` — o endereço que a Meta chama não confere assinatura nenhuma. Qualquer
pessoa manda um aviso falso ("mensagem de fulano") e **o robô responde para o número que o falsário
escolher, usando o número oficial da loja**. Isso é spam saindo da loja do seu cliente, com risco de a Meta
banir o número dele.

📋 `WhatsAppController.java:50` grava **o conteúdo inteiro de cada mensagem** no log — telefone e texto do
cliente final. O comentário no código diz "raio-X temporário". É dado pessoal guardado sem necessidade.

**Conserto:** validar a assinatura da Meta e apagar essa linha de log.

---

## 5. PARE TUDO — login sem limite de tentativas

📋 `AuthController.java:36-56` — nada limita quantas senhas alguém tenta por minuto, e a senha mínima é de
6 caracteres. O cadastro público piora: com a senha certa ele cria loja, com a errada devolve "e-mail já
cadastrado" — ou seja, serve de adivinhador de senha, sem limite.

**Conserto:** limite por IP e por e-mail, senha mínima de 8.

---

## 6. DINHEIRO — o sistema não obriga ninguém a pagar

📋 Confirmado por dois agentes, em pontos diferentes do código:
- A loja **nasce ativa, sem assinatura**, tanto pelo painel quanto pelo cadastro público. São **4 lojas hoje
  usando de graça, sem data de fim combinada em lugar nenhum** — cerca de R$ 796/mês.
- Quem atrasa **não perde nada**: o aviso de fatura vencida só marca "inadimplente"
  (`AssinaturaService.java:92`). O painel continua aberto e o robô do marketplace continua puxando pedidos.
- Os seus próprios **Termos de Uso prometem** suspender em 10 dias e cancelar em 30. Nenhum código faz isso.
- O **Módulo IA de R$ 99 é um checkbox** que nunca entra na cobrança do Asaas.
- **Quem cancelou não consegue voltar**: a tela só mostra o botão de assinar para quem nunca teve
  assinatura. Se forçar, o sistema cria uma assinatura nova **sem cancelar a antiga** — cobrança dobrada.
- 📋 Um evento de "cobrança avulsa apagada" no Asaas (`PAYMENT_DELETED`) **cancela a assinatura inteira e
  derruba a loja**. Apagar uma fatura no painel do Asaas tira o cliente do ar.

**Conserto:** decidir a regra de carência, criar a rotina diária que a aplica, cobrar o Módulo IA junto,
arrumar o caminho de voltar a assinar e tratar `PAYMENT_DELETED` como aviso.

---

## 7. DINHEIRO — pedido do marketplace pode se perder sem ninguém ver

📋 O achado mais citado pelos agentes, em três frentes:

- **O "aceitar" pode falhar em silêncio.** Se a confirmação ao iFood/99 não completa (timeout, erro deles),
  o erro vira uma linha de log, o evento é dado como tratado e **nunca mais se tenta**. O pedido aparece
  bonito no seu painel e o iFood nunca soube que você aceitou — e cancela sozinho depois de alguns minutos.
  `IfoodClient.java:325`, `OpenDeliveryClient.java:446`, `MarketplacePoller.java:206`.
- **Um erro passageiro de token derruba o canal para sempre.** Se a renovação falha uma vez, a integração
  vira "ERRO" e **só o vínculo manual volta a ligar**. A loja some do aplicativo sem aviso.
  `IfoodClient.java:234`, `OpenDeliveryClient.java:218`.
- **Cancelamento recusado pelo marketplace só vira log.** O pedido fica cancelado no Bora e vivo no iFood.

**Conserto:** marcar o pedido como "não sincronizado" e tentar de novo, mostrar o erro no painel, e deixar
o atendente reenviar o aceite na mão.

---

## 8. DINHEIRO — PIX não pago vira venda, e cashback dá para fabricar

📋 **PIX:** o pedido nasce "PIX (aguardando)" e **entra na cozinha e no faturamento**. Nada o expira. Se
ninguém pagar, ele fica como venda para sempre. Se o cliente pagar depois de cancelado, o sistema marca
"pago" num pedido cancelado e ninguém é avisado.

📋 **Cashback:** é creditado **no ato do pedido, antes de pagar**. Dez pedidos falsos de R$ 50 viram R$ 25
de saldo real. Pior: no cardápio o cliente é identificado **só pelo telefone digitado** — dá para consultar
o saldo de qualquer número e **gastar o cashback de outra pessoa**.

📋 **Cardápio sem frete:** o pedido feito pelo cardápio público **não cobra taxa de entrega**, não baixa
estoque e **não respeita o horário de funcionamento** que o lojista configurou. A loja "fechada" recebe
pedido às 3 da manhã, e a entrega sai de graça. (Confirmar se "sem frete" foi decisão sua.)

📋 **Acerto do motoboy:** aceita valor negativo, não trava contra dois acertos ao mesmo tempo e trata
"João" e "joao" como entregadores diferentes.

---

## 9. PROMESSA — a marca do lojista não chega ao cliente final

✅ **Vi com meus olhos hoje.** Abri o cardápio da Pizzaria Bella Napoli e o topo mostra um **sorvete** e um
**roxo e verde fixos** — o ícone e as cores do Bora, não da pizzaria. A página em que o cliente acompanha o
pedido é roxa fixa e tem **"BoraHapp" no rodapé**.

📋 O servidor devolve só o id e o nome da loja no cardápio público; logo, cor e banner ficam no banco e
nunca saem de lá. O cardápio também não carrega o arquivo que aplica a marca — ele só vale no painel.

**Isso contradiz o site em dois lugares**, e é a promessa central do produto:
- "Logo, cores e nome da sua loja **no painel e no cardápio digital**"
- Na página de preços: "Meus clientes vão ver a marca do BoraHapp? **Não.**"

E contradiz a apresentação comercial que montei hoje, no slide "Sua marca em tudo".

**Conserto:** devolver logo, cor e banner no cardápio público e aplicar no cardápio e na tela de
acompanhamento. Enquanto isso não existir, a frase do site precisa mudar — hoje ela está errada.

---

## 10. QUEDA — ninguém é avisado, e o backup mora na mesma máquina

📋 **Sem alarme externo.** O vigia que criamos só age por dentro: se a máquina inteira cair, ele cai junto.
O log dele nem existe — nunca precisou agir. Não há UptimeRobot nem alarme da AWS.

📋 **Backup só dentro da instância.** Os 5 arquivos de backup (17 MB) estão no mesmo disco da máquina. Se a
instância se perder, o backup vai junto. O backup automático do banco da própria AWS **continua sem ser
confirmado no console** — depende de você entrar lá.

📋 **Todo deploy derruba o site por 20 a 30 segundos** (a API leva 19,8s para subir). Dá para resolver com
uma linha na configuração do Caddy, que segura a chamada até a API voltar.

📋 **A máquina nunca foi reiniciada** (91 dias) e tem atualização de segurança do sistema pendente. Também
nunca foi testado se tudo volta sozinho depois de um reboot.

📋 **Arquivos de senha legíveis por qualquer usuário da máquina** (permissão 664), e há 7 cópias antigas
espalhadas com chaves que podem ainda valer.

---

## 11. EMPRESA — não há contrato aceito, nem nota fiscal definida

📋 **Ninguém aceita os Termos.** A tela de cadastro não tem caixa de aceite nem link. Não existe prova de
que o lojista concordou com nada.

📋 **Os Termos contradizem o site em três pontos:**
- O site promete **garantia de 30 dias com devolução**; os Termos dizem **"não há reembolso"**.
- Os Termos dizem que dá para **cancelar pelo painel**; não existe esse botão.
- Os Termos citam uma **Central de Ajuda com SLA por plano**; não existe Central de Ajuda, o plano é único
  e a página de preços diz que não vendemos SLA.

📋 **Nota fiscal da mensalidade: não existe nada no projeto.** Nem documento, nem código, nem definição de
quem emite. Cliente com CNPJ vai pedir. Isso é conversa com o contador, não comigo.

📋 **Política de privacidade com defeito publicado:** os itens 1, 2 e 4 estão com a formatação quebrada e o
item 8 tem um rascunho visível ao público — o texto "[Descrever cookies de analytics, se houver.]" está no
ar. Além disso, a política não lista a Anthropic nem a Meta entre quem processa dados, e as duas processam.

📋 **O horário do suporte diz três coisas diferentes:** site e Termos dizem segunda a sábado, 9h às 22h; o
perfil do WhatsApp Business diz segunda a sexta, 9h às 18h; e o horário padrão das lojas é 18h às 23h,
todo dia. O suporte fecha antes da loja abrir o movimento, e no domingo não atende.

📋 **Não existe e-mail.** O domínio não tem registro de e-mail configurado, então `adm@borahapp.com.br`
nunca recebeu nada — e esse endereço está cadastrado no Asaas ligado à subconta da Zirá.

📋 **Não existe "esqueci a senha"** em nenhuma tela. Domingo à noite, com a loja cheia, isso vira chamado
urgente para o seu celular.

---

## 12. CRESCIMENTO — o que quebra quando forem 20 ou 50 lojas

📋 **Uma instância só.** O robô que mantém a loja online no iFood roda dentro do mesmo processo do site. Todo
deploy tira **todas** as lojas do ar no iFood por meio minuto. E não dá nem para subir uma segunda máquina:
o controle de renovação de token está na memória do processo, então duas máquinas brigariam entre si.

📋 **O robô do marketplace aguenta 8 lojas por vez.** Com o iFood respondendo normal, dá conta de centenas.
Com o iFood lento, atende cerca de **16 lojas por ciclo** — e sempre as mesmas ficam de fora, porque a lista
não é embaralhada.

📋 **O quadro de pedidos lê a lista inteira de clientes da loja a cada 6 segundos.** Hoje não pesa. Com uma
loja de 3.000 clientes e a tela aberta o dia todo, é cerca de 100 MB por hora, por tela, à toa.

📋 **Robô do WhatsApp: um número por loja.** Como está, cada loja precisa de um aplicativo próprio na Meta,
criado à mão. Para vender o Módulo IA para dezenas de lojas, o desenho precisa mudar: um aplicativo só do
BoraHapp, descobrindo a loja pelo identificador do número que a Meta manda no aviso. Estimativa do agente:
3 a 4 dias para a primeira etapa.

📋 **Chamada a serviço de fora dentro do clique do lojista**, boa parte **sem tempo limite**. Se o Asaas ou o
iFood travar, poucos clientes simultâneos esgotam as 10 conexões do banco e **o painel inteiro congela**.

---

## 13. DEPOIS — dívida que vai cobrar juros

📋 Banco sem chave estrangeira nas tabelas do dia a dia; telefone gravado em dois formatos, o que duplica
cliente e divide o cashback; faltam índices que só doem com histórico grande; segredos de pagamento
guardados em texto puro no banco; nenhuma validação de entrada, então erro de digitação vira erro 500 com
mensagem interna vazando; o build **não roda os testes** (`-DskipTests`), então nada impede subir código
quebrado; e o relatório de lucro mostra margem inflada no marketplace, porque o pedido vindo do iFood entra
sem custo e sem desconto da comissão.

📋 **"Fechar o mês" não existe de verdade.** Os relatórios são janela móvel de 7, 30 ou 90 dias — não dá
para escolher "setembro". O faturamento soma tudo que não foi cancelado, inclusive pedido ainda em preparo
e PIX nunca pago, e não desconta a comissão do marketplace. O fechamento de caixa é feito no navegador,
só do dia, e agrupa por texto livre, então aparecem baldes como "PIX (aguardando)".

📋 **Não existe "esqueci minha senha"** em tela nenhuma, e o sistema não manda e-mail. A tela de Ajuda manda
o lojista pedir a redefinição ao administrador em Usuários, mas esse botão não existe lá. A rota já existe
no servidor — falta a tela.

---

## O que eu faria, nesta ordem

| Quando | O quê | Por quê |
|---|---|---|
| **Hoje** | Itens 1, 2 e 3 | São poucas linhas e fecham porta aberta |
| **Esta semana** | Item 4, item 9 (alarme + backup fora da máquina), trocar as chaves expostas | Barato, e evita o pior |
| **Antes de cobrar** | Item 6 (cobrança), item 10 (contrato e nota) | Sem isso não dá para cobrar direito |
| **Antes de 10 lojas** | Itens 7 e 8 | É onde se perde pedido e dinheiro |
| **Antes de 20 lojas** | Item 11 | É onde o desenho atual para de servir |

**Nada disso foi corrigido ainda.** O que foi feito hoje: o site institucional foi corrigido (a conta de
recebimento aparecia como "em construção" e já estava pronta) e está no ar.
