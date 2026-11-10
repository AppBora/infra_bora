# As pendências — a lista viva

**Este arquivo é o único que você precisa abrir.** O nome dele nunca muda de data, então o atalho
que você guardar hoje continua valendo no mês que vem. Aqui estão **só as ações**, em ordem, com
onde clicar. A prova de cada uma — o que foi medido, quando e onde — está em
[PENDENCIAS-2026-10-30.md](PENDENCIAS-2026-10-30.md).

Última conferência contra a produção: **10/11/2026** — e nesse dia rodou a **varredura dos 15 agentes na aplicação inteira** ([VARREDURA-2026-11-10.md](VARREDURA-2026-11-10.md)). Os itens de cadastro e operação seguem como foram medidos em **04/11**. Tudo marcado como pendente aqui foi medido, não deduzido.

---

## 🔴 Agora

## 🔴🔴 Varredura de 10/11 — os 2 que impedem liberação

Relatório inteiro, com os três níveis de confiança, em
[VARREDURA-2026-11-10.md](VARREDURA-2026-11-10.md). **15 agentes, aplicação inteira.** O QA de API
**não liberou**, e eu concordo. Os dois estão no ar na v153, no cardápio público, onde o cliente
final está.

- [ ] 🔴 **Pedido com código de promoção dá 500 DEPOIS de gravar o pedido, e o uso nunca é contado.**
      Medido pelo QA contra a API real: duas chamadas, dois pedidos gravados **com desconto**, e
      `promocao.usos` continuou **0**. O cliente vê erro e tenta de novo → **pedido duplicado**; e o
      limite de usos **nunca fecha** → desconto sem teto.
      **Mecanismo (um conserto quebrou outro):** `somarUmUso` é `@Modifying(flushAutomatically=true)`
      e o flush exige transação. O `POST /loja/{id}/pedido` perdeu o `@Transactional` de propósito
      (conserto de 26/10), e `DescontoService.contabilizarUso:107` roda no passo 2, fora do
      `tx.execute`. Estoura `TransactionRequiredException`.
      **Por que 1345 testes verdes não pegaram:** `DescontoNoCheckoutIT` é `@DataJpaTest` (roda
      DENTRO de uma transação) e o outro teste usa mock do repositório. É a lição de 09/10 de novo —
      os testes verificaram a lógica, não a premissa em volta.
      **Conserto é meu, pequeno:** `@Transactional` em `contabilizarUso`, ou somar o uso dentro do
      `tx.execute`. Precisa de deploy. **Me peça e eu subo.**

- [ ] 🔴 **Endereço com mais de 500 caracteres no cardápio público perde o pedido inteiro.**
      Medido pelo QA: 500 com `value too long for type character varying(500)`.
      `PublicController.java:576` grava `endereco.trim()` **sem** `LarguraDeColuna`; o caminho de
      marketplace (`PedidoService.java:418`) usa `encurtarAvisando`.
      **É regressão de defeito que este roteiro marca como resolvido:** o conserto da v126 cobriu o
      marketplace e deixou o cardápio — e o comentário do próprio código diz *"o Postgres recusava o
      INSERT e o PEDIDO INTEIRO se perdia, com o entregador a caminho"*. Mesmo estrago, no caminho
      onde o cliente de verdade digita.
      SUSPEITA não testada: `bairro_entrega` (varchar 100) tem o mesmo desenho na linha seguinte.
      **Conserto é meu, pequeno.** Precisa de deploy.

- [ ] 🔴 **A V68 transforma migração de dado em pré-condição de boot, e eu não posso editá-la.**
      Erro meu, de hoje. Três agentes confirmaram, dois por reprodução: com Postgres vazio a V68
      aborta e **todos os testes de integração falham** (o QA de API só conseguiu rodar os 211 ITs
      com `-Dspring.flyway.target=67`). Ambiente novo do zero também quebra.
      **A V69 já está corrigida** (commit `f8f82b9`), ensaiada em 3 cenários. A **V68 não pode ser
      editada**: está gravada como aplicada e o Flyway valida checksum — mudar o arquivo faz o
      próximo deploy falhar na validação. Consertar exige um **`flyway repair`** na produção.
      **Decisão sua.** Recuperação de desastre a partir do backup **não** está em risco: o dump
      contém o `flyway_schema_history`, então a V68 é pulada na restauração (medido).

- [ ] 🔴 **"Não consegui perguntar ao Asaas" é tratado como "o cliente não pagou", e o pedido pago é
      cancelado.** Confirmado por mim: `PixService.cobrancaFoiPaga` devolve `false` no
      `catch (Exception e)` — timeout, 429, 5xx e chave revogada dão o mesmo que "não pago". O
      `CobradorDePixService` segue para `cancelarVencidos`, que cancela, devolve estoque e cashback e
      avisa o cliente do cancelamento. Conserto: separar "o Asaas disse que não pagou" de "não
      consegui perguntar"; no segundo caso, pular a rodada.

- [ ] 🔴 **O caminho real do webhook do Asaas roda SEM transação.** Confirmado por mim: o
      `@Transactional` da linha 380 aplica-se à sobrecarga de 5 parâmetros, cujo próprio javadoc diz
      *"o webhook de verdade NÃO usa esta sobrecarga"*. A de 6 parâmetros, que
      `AsaasWebhookController:117` chama, não tem anotação. Pagamento registrado sem acesso
      estendido, ou o contrário.

- [ ] 🔴 **O 401 no polling não invalida o token em cache, e a tela fica verde.** Confirmado por mim:
      o `catch` só grava hora e mensagem. Se o canal revogar o token antes do vencimento, o poller
      insiste com o token morto por até **1 h** na 99 e **6 h** no iFood. Ameaça direta ao 99Food das
      5 lojas da Zirá, que começou a funcionar hoje.
      **Armadilha de leitura:** `ultimo_polling_em` é gravado **também na falha** — "último polling
      21 s atrás" prova que *tentou*, não que *funcionou*.

- [x] ~~**O service worker derrubava as fontes do guia da Zirá.**~~ **CONSERTADO hoje** (`479f55f`).
      Medido pelo QA de tela em produção: `ERR_FAILED`, request de 0 byte, fontes vazias em
      `guia-zira.html` e `cardapio-folha.html`. O `sw.js` interceptava toda origem e a CSP
      `connect-src 'self'` bloqueava o fetch de dentro dele. **Eu reescrevi esse arquivo hoje e disse
      que o ERR_FAILED estava resolvido** — estava para mesma origem; para recurso de fora,
      continuava, e eu não conferi.

- [ ] 🟠 **O segredo do JWT falha ABERTO, com um valor publicado no repositório.** Confirmado por
      mim: sem `BORA_JWT_SECRET` a API sobe com `troque-este-segredo-...` e só emite um `log.warn`.
      Quem conhece o repositório forja token de qualquer usuário, inclusive do admin da plataforma. A
      variável existe em produção hoje (conferida pelo nome). **Neste projeto isso não é teórico:** já
      aconteceu a chave de cifragem parecer ausente porque `docker restart` não relê o `--env-file`.
      Conserto: recusar a subida se o segredo for o padrão. O CORS e o WhatsApp já falham fechados.

- [ ] 🟠 **O card verde que mente, agora medido na tela.** Com `ultimoErro="HTTP 403"` e última busca
      há 3 h, o chip fica **verde**, a caixa diz *"A busca está rodando e não dá erro"* e o
      "Último erro" fica **335 px abaixo da dobra**. Com `pedidosRecebidos > 0` o cabeçalho vira
      "🟢 Recebendo pedidos" — contador acumulado desde sempre, não sinal de agora.
      Dá para consertar só no front, sem esperar o backend: se há `ultimoErro`, ou se
      `ultimoPollingEm` tem mais de ~5 min, trocar chip, linha e caixa.

- [ ] **O freio de login pode ser contornado por cabeçalho.** O QA mediu local, sem o Caddy na
      frente: 6 erros com `X-Forwarded-For` diferentes e a 7ª com a senha certa **entrou**. O
      `FreioDeTentativas` lê o **último salto** por desenho, e o `Caddyfile` **não tem
      `trusted_proxies`**. O QA não reconferiu o comportamento real do Caddy — **vale medir**, porque
      é o freio que protege toda conta de lojista.

- [ ] **AWS Business Support+ custa R$ 162/mês** (43% da conta de R$ 373) e a própria API da AWS diz
      que o plano não dá acesso ao suporte. O custo total está **dentro do teto** de R$ 800, com
      folga de R$ 427. Decisão sua manter ou voltar ao Basic.

- [ ] **A apresentação comercial e a ficha de cadastro em PDF dizem que o iFood e o 99Food estão "em
      homologação"**, com "situação em 30 de setembro". O iFood recebe pedido real desde 19/09 e o
      99Food está em 5 lojas desde hoje. **A landing está certa** — o erro migrou para os dois
      documentos que vão direto ao cliente. É o mesmo erro de 09/10, em lugar novo.

---

## ✅ Fechado em 08 e 10/11 — o 99Food da Zirá está funcionando

**Medido em 10/11/2026 às 14:57 UTC, no banco de produção** (não na tela, que já mentiu antes):

| Loja | Status | Token da 99 até | Último polling |
|---|---|---|---|
| 18 Montreal | CONECTADO | 16:28 | 21 s atrás |
| 19 Zona Norte | **CONECTADO** | 18:25 | 21 s atrás |
| 20 São Bento | **CONECTADO** | 18:25 | 21 s atrás |
| 21 Vila Hortência | **CONECTADO** | 18:25 | 21 s atrás |
| 22 Nova Esperança | **CONECTADO** | 18:25 | 21 s atrás |

`ultimo_erro` limpo nas cinco. Zero recusa de credencial depois do conserto (a última foi
14:50:21 UTC, antes dele). As quatro buscam pedido a cada 30 segundos.

**A causa eram DOIS campos errados, não um.** A credencial da plataforma era inteira do aplicativo
de **teste**: o App ID `5764607673624955027` no `client-id`, e no campo do segredo o **nome** do app
de teste (`BR_T_BoraHapp`, 13 caracteres) em vez de um segredo. Os dois errados e coerentes entre
si — por isso nenhuma verificação de "existe credencial salva?" pegava.

Nada precisou ser digitado, e **ninguém precisou colar o App Secret**: o par certo estava guardado
na linha da loja 18, e as duas migrações o extraíram de lá.

- **V67** (08/11) — grava o APPShopID no `merchant_id` das 5 e guarda o ID numérico em
  `shop_id_canal`; o webhook casa pelos dois.
- **V68** (10/11) — o segredo. Copia o texto cifrado da loja 18, sem ninguém ver o valor em claro.
- **V69** (10/11) — o App ID. Extrai da própria loja 18, por subtração do `merchant_id`.
- **v153** no ar (commit `d87a98d`) — o `catch` do 401 passou a logar o que a 99 respondeu **e o
  `client_id` que saiu na chamada**.

**O que me custou dois meses, escrito aqui para não repetir:** eu conferi que o `client-id` da
plataforma tinha 19 caracteres e começava com `5764607`, e **declarei que era o App ID certo**. Os
dois App ID têm 19 dígitos e começam com `5764607`. Comparei um comprimento e chamei de identidade.
Pior: **o App ID errado já estava escrito nesta própria lista desde 06/11** — *"aponta para outro
aplicativo (`5764607673624955027`)"* —, e eu fui pela minha anotação em vez de medir. E nenhum log
mostrava o campo que saía na chamada, porque o `catch` descartava tudo.

A 99 responde **401 com corpo vazio**: logar só a resposta não resolveria nada. O que resolveu foi
logar o campo **enviado**.

---

## ✅ Fechado em 08/11 — o servidor voltou

- **IP estático definitivo: `56.126.177.18`** (o `18.230.57.33` e o `18.231.71.3` estão mortos).
  Site em 200, `/actuator/health` em `UP`, `api` e `caddy` de pé, 0 linha de `ERROR` no log.
- **Backup**: de 6 em 6 horas no servidor (verificado com `pg_restore`, não só `--list`), mais
  cópia diária para **`C:\bora-backups`** nesta máquina — 146 dumps aqui, o último de hoje 10:55.
  **Não vai para o OneDrive de propósito:** o dump tem telefone, endereço e CPF de todo cliente de
  toda loja.
- **Orçamento da AWS** ligado (US$ 45, avisos em 80% e 100%).
- Os scripts de deploy apontavam para o IP morto desde 06/11 — corrigidos em 10 arquivos.

---

## 🔴 Novos, medidos em 10/11

- [ ] 🔴 **Ligar MFA no usuário `adm` da AWS.** Ele tem `AdministratorAccess` **sem segundo fator**,
      numa conta que guarda telefone, endereço e CPF dos clientes de todas as lojas. (A chave que
      vazou em outubro, `AKIA5S2TU3Z5UVPCBVOV`, **já foi rotacionada** — conferido em 10/11: o `adm`
      tem só a `AKIA5S2TU3Z5ZBXWDVWM`, de 01/07.)

- [ ] **Quando o polling falha, o status NÃO é rebaixado — a loja fica verde.** Ainda aberto,
      reconferido no código em 10/11: `marcarPollingFalhou` grava só hora e mensagem, e
      `IntegracaoCanalRepository` não toca em `status`. O caminho inverso existe (sucesso promove
      `ERRO` → `CONECTADO`), mas a queda não rebaixa. Então uma loja CONECTADO que comece a levar
      403 na busca de pedido segue **verde**, com o motivo escondido num campo que ninguém lê.
      É o mesmo "morre em silêncio" que custou dois meses no 99Food, e agora que as 5 lojas da Zirá
      dependem desse canal, é a trava que eu ligaria primeiro. **O conserto é meu: código + deploy.
      Me peça e eu subo.**

- [ ] **O log conta cada 401 do 99Food duas vezes.** Efeito colateral da v153: a linha nova (com
      `client_id` e corpo) foi acrescentada **ao lado** da antiga, não em lugar dela. Para contar
      falhas use `grep -c "polling falhou para a loja"` (1 por evento) — e lembre que essa frase
      também cobre o 403 da loja 1, que não é recusa de credencial.

---


- [x] ~~**99Food da Zirá: o vínculo não existe.**~~ **FEITO em 06/11.** As **5 lojas estão vinculadas
      em ambiente de produção** ao `BR_P_BoraHapp`, com token emitido na hora. O caminho e as
      provas estão em [PASSO-A-PASSO-99FOOD.md](PASSO-A-PASSO-99FOOD.md).

- [x] ~~**Gravar o APPShopID no `merchant_id` das 5 lojas.**~~ **FEITO em 08/11 (V67).** E o
      `merchant_id` NAO era o campo principal: a loja 18 tem `client_id` proprio, que vai cru
      para a 99 sem passar pelo `merchant_id` -- a V67 reescreve os dois. O texto original:

- [x] **Quando o servidor voltar: gravar o APPShopID no `merchant_id` das 5 lojas.** A 99
      documenta que `ClientId = AppID_AppShopId`. Nós mandávamos o **ID do loja** — por isso o 403.
      Não era bloqueio da 99, era defeito nosso.

      | Loja | APPShopID a gravar |
      |---|---|
      | 18 Montreal | `zira-acaiteria` |
      | 19 Zona Norte | `zira-zona-norte` |
      | 20 São Bento | `zira-sao-bento` |
      | 21 Vila Hortência | `zira-vila-hortencia` |
      | 22 Nova Esperança | `zira-nova-esperanca` |

      **Cuidado:** esse campo também roteia o webhook (`X-App-MerchantId`), e a documentação **não
      diz** qual dos dois valores a 99 manda nesse cabeçalho. Vou **guardar os dois** e casar por
      qualquer um — adivinhar aqui derruba pedido de verdade.

- [ ] **Avisar a Zirá que a Vila Hortência está "Temporariamente fechado" na 99.** Lido na tela em
      06/11. Status posto por alguém da loja, não é defeito — mas enquanto estiver assim ela não
      recebe pedido da 99.


- [x] ~~**06/11: a conta da AWS foi encerrada e o servidor caiu.**~~ **RESOLVIDO.** Instancia e
      banco de volta, IP estatico `56.126.177.18`, DNS apontado, site em 200 e health `UP`
      (conferido 10/11). **Continua pendente so o e-mail de cobranca** (ver abaixo): o alarme
      de orcamento NAO pega falta de pagamento. O original:

- [x] **06/11: a conta da AWS foi encerrada por falta de pagamento e o servidor caiu.**
      **Medido:** portas 22, 80 e 443 de `18.230.57.33` mudas; ping sem resposta; a credencial da
      AWS guardada no PC devolvendo `InvalidClientTokenId`. O e-mail de
      `billing-subscriptions@aws.com` às **10:23** confirmou: *"your Amazon Web Services account
      has been closed"*. Conta **933793947259**.
      **O painel enganava:** `dashboard.html` abria do cache do navegador, com TODOS os números em
      traço e o Termômetro travado em "Carregando…". Casca sem dados é servidor morto.
      **Resolvido pela metade:** o dono pagou; a tela de Pagamentos mostra **saldo R$ 0,00 e
      nenhum pagamento devido**. A AWS disse que a liberação leva **até 24 h**.
      **Falta:** confirmar que a instância do Lightsail voltou e que o Bora subiu junto.

- [x] ~~**Avisar a Zirá que as 5 lojas estão fora do ar.**~~ **NAO SE APLICA MAIS:** o cardapio
      das 5 esta no ar desde 08/11. Ficaram fora de 06/11 ~10:23 a 08/11 -- se voce nunca
      avisou, vale um recado dizendo que voltou. O original:

- [x] **Avisar a Zirá que as 5 lojas estão fora do ar.** Desde as ~10:23 de 06/11 o cardápio
      público das 5 unidades não abre, e pode ficar assim até 07/11. **É recado seu, e é agora** —
      elas não têm como saber, e cliente que tenta pedir e não consegue não volta.

- [x] ~~**Backup fora da AWS.**~~ **FEITO em 08/11, na metade que importa:** dump de 6 em 6 h
      no servidor + copia diaria para **`C:\bora-backups`** nesta maquina (146 dumps, o ultimo
      hoje 10:55), verificada com `pg_restore`. **NAO vai para o OneDrive de proposito** -- o
      dump tem telefone, endereco e CPF de todo cliente. **Falta o bucket S3:** o
      `BORA_BACKUP_S3` segue indefinido e o script avisa em todo backup. O papel IAM da
      instancia ja existe; falta bucket + politica de escrita, e nenhuma chave nova. O original:

- [x] **Backup fora da AWS — esta semana quase custou tudo.** O `BORA_BACKUP_S3` nunca foi
      definido, e o S3 fica na **mesma conta** que foi encerrada. Se a AWS tivesse apagado os
      recursos, o banco das lojas ia junto e **não havia cópia em lugar nenhum**. O e-mail avisa:
      passados 90 dias a conta não pode mais ser reaberta e a AWS apaga o que sobrou.
      **Proposta:** dump do Postgres todo dia, guardado **fora da AWS**. Me autorize e eu monto.

- [x] ~~**Alarme de cobrança na AWS.**~~ **METADE FEITA em 08/11:** orcamento "BoraHapp - custo
      mensal" (US$ 45, avisos em 80% real e 100% previsto). **ELE NAO PEGA FALTA DE PAGAMENTO**
      -- so gasto em excesso. O que pegaria o caso de 06/11 e um contato de cobranca num e-mail
      que voce LEIA; hoje vai para `app-bora@hotmail.com`. **Me diga qual e-mail voce le de
      verdade e eu ponho.** O original:

- [x] **Alarme de cobrança na AWS.** A produção morreu por falta de pagamento **sem ninguém
      perceber** — descobrimos 4 h depois, e por acaso. Dá para ligar aviso de orçamento e alerta
      de fatura em aberto, para o aviso chegar antes do corte, não depois.


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
      ssh -i ~/.ssh/bora-lightsail.pem ubuntu@56.126.177.18 "grep '^BORA_SEGREDO_COLUNAS=' /home/ubuntu/bora/api.env"
      ```

- [ ] 🔴 **2º — e só depois disso: cifrar as credenciais que já estavam gravadas.**
      **Medido em 10/11: sao 20** (eram 28 em 30/10 -- 8 se cifraram sozinhas ao serem
      regravadas no uso normal). Por coluna: 9 `webhook_token`, 4 `client_secret`, 4 de
      `config_plataforma`, 1 `access_token`, 1 `refresh_token`. **Entre elas o
      `client-secret` do iFood da plataforma, 99 caracteres em texto puro** -- a credencial que
      autoriza pedido em nome de TODAS as lojas. Sai em todo `pg_dump`, inclusive nos 146 que
      estao nesta maquina. O texto original:
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

- [x] ~~**99Food da Zirá: o vínculo não existe.**~~ **SUPERADO.** O vinculo foi feito em
      06/11 (as 5 autorizadas e vinculadas ao `BR_P_BoraHapp`) e as 5 estao buscando pedido
      desde 10/11 -- ver o bloco no topo desta lista. O 403 de 04/11 descrito abaixo tinha
      DUAS causas nossas somadas, nao falta de vinculo: o `merchant_id` levava o ID numerico
      no lugar do APPShopID (V67) e a credencial da plataforma era do app de teste (V68+V69).
      O texto original, que valia com o que se sabia naquele dia:

- [x] **99Food da Zirá: o vínculo não existe, e agora está PROVADO.** Em 04/11 li a tela do
      portal da 99 (você logado como **Superadministrador**, José Camilo) e gravei no Bora o código
      real de cada uma das 5 unidades. A 99 passou a responder, a cada consulta:
      `403 "User is forbidden to access this resource"`.
      **Isso é a prova que faltava.** Até ontem o canal da loja 18 usava o apelido inventado
      `zira-acaiteria`, a 99 devolvia lista vazia e o cartão ficava verde para sempre. O teste de
      token **não serve de prova**: a 99 devolve token até para um código que não existe. Quem
      separa é a consulta de pedidos — e ela diz 403.
      **Caminho (é seu, e agora dá para fazer):** você já está logado com o perfil certo. 99Food →
      Gerenciamento da loja → Vincular estabelecimento → **"Autorização de solicitação de lote"**
      gera um link; abra-o nessa mesma sessão e autorize as 5 para o app `BR_P_BoraHapp`
      (App ID `5764607707103889279`). O link vale 7 dias.
      **A loja 18 ficou ligada de propósito**, consultando a 99 a cada 30 s. No instante em que a
      autorização existir, o 403 vira 200 e o erro some sozinho — ela é o nosso termômetro.
      Se preferir, eu pauso.

      **Estado do lado do Bora em 04/11, conferido no banco — não falta nada aqui:** as 5 lojas
      estão com `ativo = true`, `auto_aceitar = true`, segredo de webhook gravado e o código de
      roteamento da 99 único em todo o sistema. O pedido da 99 chega por **webhook**
      (`POST /public/opendelivery/v1/newEvent`) e o Bora acha a loja pelo cabeçalho
      `X-App-MerchantId` — que é exatamente esse código. Lojas 19-22 ficaram em **ERRO** de
      propósito: nesse estado o Bora tenta de novo a cada 10 min, então elas se acertam **sozinhas**
      assim que o App Secret entrar. Ninguém precisa clicar em nada depois.

- [x] ~~**Colar o App Secret do `BR_P_BoraHapp`.**~~ **FEITO em 10/11, e voce nao precisou
      colar nada** (V68 + V69). **Esta lista estava CERTA e eu nao li:** o App ID errado
      (`5764607673624955027`) ja estava escrito aqui desde 06/11. Eram DOIS campos errados,
      nao um. A loja 1 passou a usar o app de producao, como este item avisava. O original:

- [x] **Colar o App Secret do `BR_P_BoraHapp` — é o que trava as lojas 19 a 22.** A credencial
      da plataforma salva em 09/10 aponta para outro aplicativo (`5764607673624955027`) e tem 13
      caracteres; é ela que a 99 recusa na loja 1 todo dia. O par que funciona está guardado dentro
      da loja 18, no app de produção. As lojas 19-22 não têm credencial própria: herdam a da
      plataforma, que está errada.
      **Caminho:** painel → Configurações → 🔑 Credencial do app BoraHapp nos marketplaces →
      99Food → App ID `5764607707103889279` + o App Secret (portal da 99, Gerenciamento de
      aplicativo → `BR_P_BoraHapp` → Ver detalhes).
      **Eu não digito segredo — esse colar é seu.** Um colar só resolve as quatro, e conserta a
      loja 1 de quebra. Aviso: a loja 1 passa a usar o app de produção em vez do de teste.

- [x] ~~**Confirmar qual unidade é a "Zona Norte" da 99.**~~ **RESOLVIDO em 06/11.** Li o
      endereço na tela do portal da 99: *R. Firmino Mineli, 751 - Jardim Hungares, 18075-700*.
      Bate com a **loja 19**. O código `5764608427259856166` está na loja certa. As 5 unidades
      agora casam 1 a 1 **medidas**, nenhuma por eliminação.

- [ ] 🔴 **Jardim Montreal e Jardim Hungarês não estão na lista de bairros de entrega.** O
      checkout **recusa** bairro fora da lista. Hoje, um cliente que mora na porta da loja 18 não
      consegue fechar pedido no cardápio. Os Correios dizem que a Rua Antenor Maciel 393 fica no
      **Jardim Montreal** (por isso a loja 18 mudou de nome em 04/11) e que a Rua Firmino Minelli
      fica no **Jardim Hungarês**. "Jardim Tropical" existe em Sorocaba — só não é onde a loja está.
      **É decisão sua, porque é preço:** me diga a taxa de cada um e eu cadastro nas 5.

- [ ] **A tela diz CONECTADO com 403 em toda consulta.** Defeito do Bora, achado em 04/11: quando
      a consulta de pedidos falha, o Bora grava o erro mas **não rebaixa o status**. A loja 18 está
      agora com `status = CONECTADO` e `ultimo_erro = 403 ... forbidden`. É o mesmo padrão de
      "morre em silêncio" de sempre, numa variante nova.
      **Onde:** `OpenDeliveryClient.polling`, no `catch` — o `marcarPollingFalhou` grava hora e erro,
      e o status fica como estava. Precisa de deploy. **Me peça e eu subo.**

- [x] ✅ **PROVADO AO VIVO em 04/11, 13h08: a taxa de entrega entra no total do cardápio.** Até
      hoje isso só tinha sido **lido no código**. Pedido de teste real na loja 22
      (Zirá - Jardim Nova Esperança), que tinha **zero** pedidos:
      1 Água Mineral **R$ 3,50** + bairro Jardim Nova Esperança **R$ 7,00** = **R$ 10,50**.
      No banco: `taxa_entrega = 7.00`, `bairro_entrega = Jardim Nova Esperança`,
      `valor_total = 10.50`. Pedido 139, código CD-139.
      **E a recusa também foi provada:** com o bairro "Bairro Que Nao Existe" a resposta foi
      **400 — "Ainda nao entregamos nesse bairro"**, e a loja continuou com **1** pedido, não 2.
      Nada foi gravado.
      **Cancelado em seguida** (pedido 139, status CANCELADO): o cliente de teste voltou a
      `total_gasto = 0,00`, `qtd_pedidos = 0` e `cashback = 0,00`. A devolução funciona.

- [x] ✅ **Cashback DESLIGADO nas 5 lojas da Zirá — 04/11, por decisão do dono.** O teste tinha
      mostrado que os 3% saíam sobre **R$ 10,50**, o total **com** o frete (R$ 0,32 em vez dos
      R$ 0,11 que daria sobre o produto) — a loja devolvia dinheiro em cima do que pagou ao
      motoboy. Em vez de escolher a base de cálculo, o dono mandou desligar.
      **Feito:** `cashback_percentual` de **3% para 0%** nas lojas 18, 19, 20, 21 e 22. Zero é o
      próprio desligamento (não existe campo "ativo" separado). Cor, cor secundária, logo e nome
      ficaram intactos — o salvamento só grava o que vem preenchido.
      **Provado ao vivo**, não só no banco: pedido CD-140 na loja 22 voltou `cashbackNovo = 0.0`,
      e a taxa de entrega continuou entrando (R$ 10,50 com R$ 7,00 de frete). Cancelado em seguida.
      **Nenhum cliente perdeu saldo:** as 5 lojas tinham **zero** clientes com cashback acumulado.
      **Não toquei em cliente nenhum fora da Zirá:** Sorveteria da Rosa e Pizzaria Bella Napoli
      seguem com 5%.
      **O defeito do cálculo continua no código**, adormecido: se algum dia ligarem cashback em
      qualquer loja, ele volta a incidir sobre o frete. Para consertar de verdade precisa de deploy.

- [ ] **Nenhum dos 42 produtos das lojas novas controla estoque.** Tentei provar que o
      cancelamento devolve estoque e **não deu**: na loja 22, os 42 produtos estão com `estoque`
      vazio. Não é defeito do cancelamento — é que não há estoque para devolver. Veio assim da
      matriz (loja 18), junto com a falta de `custo` que já estava anotada.

- [x] ✅ **Rastro dos testes apagado da loja 22 — 04/11.** Os 2 pedidos de teste (CD-139 e CD-140,
      os dois já cancelados), seus 2 itens, as 2 linhas de histórico e o cliente
      "TESTE BORAHAPP - NAO ENTREGAR" saíram. **A loja 22 voltou a zero pedidos e zero clientes.**
      Usei o botão próprio da plataforma (limpeza de dados de teste), que apaga **só movimentação**
      e exige digitar o nome exato da loja. Conferido no banco depois: **42 produtos, 6 bairros,
      7 horários e a integração da 99 continuam no lugar**, com a cor e o cashback em 0%.
      Estoque: nada a devolver — os 2 pedidos já estavam cancelados (a própria limpeza os deixa de
      fora para não somar estoque que nunca saiu).
      **Nenhuma outra loja foi tocada:** as 7 vendas reais da loja 18 (até 01/11) e o pedido de
      07/09 da loja 20 continuam intactos.

- [ ] **99Food da loja 1 (Sorveteria da Rosa): agora e 403, nao mais 401.** **Medido em 10/11,
      depois da V68+V69:** ela **recebe token** da 99 -- prova de que a credencial esta certa --
      e leva `403 "User is forbidden to access this resource"` **com `request_id`** na busca de
      pedido. E a loja de teste do Bora, nao um estabelecimento vinculado ao app de producao:
      erro de autorizacao, nao de credencial. **Nao e defeito nosso.** Se um dia precisar falar
      com a 99 sobre ela, o `request_id` sai no log. O texto original: Ativo, sem
      `client_secret`, e o polling volta recusado a cada 10 min. É problema **diferente** do de
      cima, e na loja de QA.
      **Caminho:** Configurações → 🔑 Credencial do app BoraHapp nos marketplaces.

- [ ] **(opcional) Fazer o aviso de "sem pedido" contar o tempo.** O verde que mentia já foi
      consertado e publicado em 30/10 — a tela agora diz "Conectado, sem pedido ainda" em vez de
      prometer. O que ela **não** diz é há quanto tempo, porque isso **não existe no banco**: o
      `ultima_sync` só é gravado quando um pedido entra, e não há coluna de "conectado desde".
      Para o aviso virar "ativo há mais de 48 h sem pedido" falta uma coluna `conectado_em` —
      migração e **versão nova da API**. Só se você quiser; hoje a tela já não engana.

- [x] **Bairros e taxa de entrega das 5 lojas: FEITO em 04/11.** O dono passou a tabela e eu
      apliquei: **15 bairros gravados, 0 falhas** — Centro R$ 8,00, Vila Hortência R$ 6,00 e
      Jardim Tropical R$ 5,00, a mesma tabela nas cinco, sem tempo informado. Conferido pela API,
      direto no banco (0 duplicatas de bairro por loja) e no **cardápio público das cinco**, que
      já devolve os três bairros com os preços. A loja de outro cliente ficou intacta.

- [x] **O cardápio público cobra o frete de verdade — e os 6 bairros estão no ar (04/11).**
      Medido no commit que está rodando (`698e7f5`, `PublicController` 529-539): quando a loja tem
      bairro cadastrado e o pedido é entrega, o servidor **recusa** em vez de zerar — bairro em
      branco dá *"Escolha o bairro da entrega para calcularmos a taxa"* e bairro fora da lista dá
      *"Ainda não entregamos nesse bairro"*. Com bairro válido a taxa entra no total e é gravada.
      (Eu havia dito que saía R$ 0,00 em silêncio: isso é de **outro** caminho, o do balcão.)
      Como aquilo bloquearia quem mora nos bairros de três das próprias lojas, o dono completou a
      tabela no mesmo dia. **As 5 lojas agora têm os mesmos 6 bairros:** Jardim Tropical R$ 5,00 ·
      Vila Hortência R$ 6,00 · Vila Mineirão R$ 7,00 · Parque São Bento R$ 7,00 · Jardim Nova
      Esperança R$ 7,00 · Centro R$ 8,00. Conferido no banco: 6 por loja, todos ativos, **0
      duplicatas em todo o sistema**, e a loja de outro cliente intacta com os 4 dela.

- [ ] **Pedido de teste na loja 22, agendado para hoje 04/11 às 13:07.** É a única prova que falta
      do frete: tudo o que eu afirmei sobre a cobrança veio de LER o código que está rodando, não
      de ver o dinheiro na tela. A 22 foi escolhida porque nasceu hoje e tem **zero pedidos** —
      nada se confunde com venda real. O roteiro do agendamento: pedido de ENTREGA com bairro
      "Jardim Nova Esperança" (R$ 7,00), conferir se o total = produto + 7,00 na resposta E no
      banco; depois um segundo pedido com bairro inexistente, que deve levar 400 sem gravar nada;
      e por fim cancelar o pedido de teste e conferir o estorno de estoque.
      **Atenção:** o agendamento vive só nesta sessão do Claude. Se ela fechar antes das 13h, o
      pedido de teste não acontece e alguém precisa pedir de novo.

- [ ] **No balcão/painel, bairro fora da lista sai R$ 0,00 em silêncio.** `PedidoService.taxaPara`
      (linha 82): a taxa sai do bairro do **cadastro do cliente**, e sem correspondência devolve
      `BigDecimal.ZERO` — o pedido é aceito com frete zerado, sem aviso. Cliente sem bairro no
      cadastro também paga zero. Diferente do cardápio público, aqui não há bloqueio. É defeito
      ou é de propósito (o comentário do código diz que o balconista pode combinar frete fora da
      tabela)? Vale a decisão do dono antes de eu mexer.

- [x] **Horário das 5 lojas igualado em 04/11.** A 18 tinha 13:00→23:00 nos sete dias e as outras
      quatro tinham 18:00→23:00, o padrão genérico do `provisionamento.semear`. O dono autorizou
      copiar: **4 lojas gravadas**, ensaio antes mostrando o "hoje" e o "ficaria" de cada uma.
      Conferido no banco: as cinco com 7 dias, 13:00→23:00, todos abertos, **0 dias repetidos**,
      e as lojas de outros clientes intactas (loja 1 em 09:00→23:59, loja 17 em 18:00→23:00).


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

- [x] **As cinco unidades da Zirá: FEITAS em 04/11.** Executado por mim no painel, com o dono
      logado na janela do navegador. Ensaio antes, e releitura da produção depois:
      **10 operações, 0 falhas.** Estado conferido no ar:
      #18 Zirá - Jardim Tropical · Rua Antenor Maciel, 393 - Jardim Tropical · CEP 18053-458 · 44 produtos
      #19 Zirá - Vila Mineirão · Rua Firmino Mineli, 751 - Vila Mineirão · 42 produtos
      #20 Zirá - Parque São Bento · Rua Maria de Fátima Faria, 72 - Parque São Bento · 42 produtos
      #21 Zirá - Vila Hortência · Rua Dr. Pereira da Rocha, 94 - Vila Hortência · 0 produtos
      #22 Zirá - Jardim Nova Esperança · Rua Geraldo Aparecido Rodrigues, 401 - Jardim Nova Esperança · 0 produtos
      Todas em Sorocaba/SP. As duas novas foram vinculadas ao login da Maria Eduarda, como
      esperado. **Diferença de 1 dia a conferir:** a #18 vence 23/01/2027 23:59 e as duas novas
      vencem 24/01/2027 23:59 — eu pedi `ate=2027-01-24` e o servidor grava o fim daquele dia.
      Alinhar é uma chamada com `ate=2027-01-23`, se você quiser as cinco no mesmo minuto.


- [x] **Passo 2: o cardápio das duas lojas novas — FEITO em 04/11.** Aplicado por mim no painel,
      uma loja por vez, com ensaio antes. **70 passos em cada, 0 falhas.** Conferido duas vezes:
      pela API e, por fora dela, direto no banco em leitura.
      Cada uma das novas (#21 e #22) ficou com **42 produtos, 40 com foto, 59 grupos e 639 opções
      de adicional**, cor `#5B1A8B`, secundária `#FFD100`, cashback 3% e o logo — e **0 produto
      com preço diferente** da matriz. O cardápio público das duas responde 200 com as seções na
      mesma ordem da #18.
      Os dois "mantimento" (`leite condensado`, `pacoca`) **não vazaram**: seguem só na #18.
      Nenhuma opção de adicional das novas aponta para insumo de outra loja (medido: 0).
      **Diferença pequena que eu criei:** a #21 e a #22 ficaram com **13 seções fixadas** na
      `categoria_ordem`, contra 5 da matriz — o `GET /api/categorias` devolve todas as categorias
      em uso, e eu gravei todas. A ordem que o cliente vê é a mesma; sobrou uma linha órfã
      ("mantimento") apontando para categoria que não existe nessas lojas. Não atrapalha nada
      hoje. Limpar é um PUT com as 12 que existem, se você quiser.


- [ ] **Nenhum dos 44 produtos da loja 18 tem custo gravado** (medido 04/11: `custo IS NOT NULL` = 0).
      Sem custo não há margem real, e é por isso que o número que o lojista lê sai do jeito que sai.
      Não é conserto de código: é cadastro que alguém precisa preencher.

- [ ] **Duas das cinco lojas da Zirá nunca vencem.** A 19 e a 20 estão com `acessoAte = NULL`, que
      o código trata como "sem prazo, nunca vence" (`Loja.java:163`). O roteiro das unidades **não
      mexe** nisso — não é hora de tirar acesso de loja que já existe. Mas é o mesmo buraco do item
      do corte por falta de pagamento: loja sem prazo some da cobrança sem ninguém notar. E não há
      porta para o contrário: nada no backend põe `acessoAte` de volta em `null`, `POST
      /admin-bora/lojas` grava sempre +7 dias e `liberar-acesso` exige data futura com teto de 180.
      Se quiser alinhar as duas a 24/01/2027 como as outras, é um clique no painel por loja.

---

## ⚪ Um "sim" seu e eu faço — eu não escrevo em produção sem autorização

- [ ] **7 itens de pedido órfãos** — apontam para pedido que não existe mais. Não mexe em dinheiro.
- [ ] **5 pedidos apontando para cliente apagado** — não dispara erro hoje.
- [ ] **1 linha de ficha técnica fantasma** — **esta mexe em dinheiro**: entra no custo e, portanto,
      na margem que o lojista lê. É a única das quatro que mexe.
- [ ] **"Vale Refeicao" repetido na loja 1** — forma de pagamento duplicada. É um clique.
- [ ] **O nome da loja no painel tem uma rede de segurança que nunca pega** (`whitelabel.js:45`).
      Medido em 31/10. Quando o lojista **apaga** o campo "nome de exibição", o painel cai no texto
      neutro do HTML em vez do nome da loja. A rede está morta por três motivos somados:
      `window.Bora` é sempre `undefined` (o `const Bora` do api.js não cria propriedade em
      `window`); o `boraUser` da sessão guarda só `{nome, papel, lojaId}`, **sem `lojaNome`**; e
      `lojaNome` só vem de dois endpoints, nunca do login normal. **Não toca dinheiro nem papel
      impresso** — é o nome na tela do próprio lojista. O conserto é meu, é pequeno, e precisa de
      um "sim".

---

## Onde estão as outras listas

Estas ficaram como **registro**, não como pendência — todas têm um aviso no topo apontando para cá:
`PENTE-FINO-SO-VOCE-PODE.md` (27/10), `DADOS-A-DECIDIR-2026-10-27.md`, `PENDENCIAS-2026-10-24.md`,
`SO-VOCE-PODE-FAZER.md` (24/10), `O-QUE-FALTA-VOCE-FAZER.md` (23/10) e
`PENDENCIAS-30-09-2026.md`. Se um item delas não aparece nesta página, é porque já foi fechado — a
prova de cada fechamento está no relatório do dia.
