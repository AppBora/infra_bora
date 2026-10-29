# O que eu consertei do pente fino — 29/10/2026

Dos **44 achados confirmados**, **39 estão consertados e commitados**. Os outros **5 precisam de
você** — estão no fim deste documento, com o porquê de cada um.

**Nada disso está no ar ainda.** Tudo está commitado nos três repositórios. O deploy é o seu
próximo passo, e eu paro aqui por regra sua.

| | brutos | confirmados | **consertados** | precisam de você |
|---|---|---|---|---|
| graves | 10 | **7** | **7** | 0 |
| médios | 38 | **23** | **19** | 4 |
| baixos | 30 | **14** | **14** | 0 |
| **total** | **78** | **44** | **39** | **5** |

## Como eu provei cada conserto

**1.327 testes de backend + 201 de integração contra um Postgres de verdade + 660 do frontend.
Zero falhas.**

E cada conserto importante passou por **mutação**: eu coloquei o defeito de volta e conferi que o
teste novo fica VERMELHO. Teste verde que não acende com o defeito presente não prova nada — e isso
já aconteceu neste projeto. Os números de cada mutação estão nas mensagens dos commits.

Testes onde não havia nenhum: **109 testes novos** em 12 arquivos.

---

## GRAVES — os 7, fechados

### 1. O `@Modifying` desgarrado (era meu, do commit 45e20d2 de 27/10)
Um método inserido ENTRE a anotação e o `UPDATE` fez a anotação colar no `SELECT` seguinte. Sem
ela, o Spring Data executa o update como consulta de uma linha e o Hibernate estoura em TODA
chamada — com o `confirm` já enviado ao canal. O evento nunca era confirmado e o aceite voltava a
cada 30 segundos, por 2 horas. É o risco de bloqueio de conta que o próprio código nomeia.

**Não chegou a disparar**: o último pedido de marketplace é de 30/09, anterior ao meu commit.

O conserto é uma linha. O que importa é o teste: `OmodifyingNaoDesgarraTest` confere os **53
`@Query`** do projeto, nos dois sentidos — escrita sem a anotação e leitura com ela sobrando.

### 2. O aceite de cancelamento da 99 era engolido
`responderPedidoDeCancelamento` era `void` e descartava o retorno. O pedido era cancelado aqui (com
estoque e cashback devolvidos) e seguia **ATIVO lá**, com o cliente esperando a comida e cobrado.
Sem aviso na tela e sem retentativa, porque o evento já tinha sido confirmado.

Agora a falha sobe: nada muda aqui e o evento não é confirmado, então o canal reenvia. É a mesma
política que o caminho irmão (cancelamento pedido pela LOJA) já usava.

### 3. PIX expirado não deixava rastro
O `CobradorDePixService` cancelava gravando o pedido direto, sem linha no `log_status`. E é dessa
linha que o `rebaixarDeNovo` depende quando o dinheiro cai depois — o único caso para o qual ele
foi escrito. O insumo devolvido nunca saía outra vez, com a comida saindo; e se o lojista seguisse a
instrução da própria observação do pedido e cancelasse de novo, o estoque voltava **em dobro**.

### 4. Venda de balcão entrava em "entregas sem motoboy escolhido"
A retirada também termina em ENTREGUE sem entregador, então casava com todos os filtros. Numa loja
com PDV, o faturamento do caixa inteiro aparecia como dinheiro de entrega sem responsável — e saía
no recibo impresso do acerto.

### 5. Botão desabilitado parecia habilitado *(já estava no ar desde ontem)*

### 6. O cardápio público lia ~601 kB de foto por abertura e jogava fora
É a tela mais aberta do sistema e a única sem cache. Agora o base64 não atravessa o cabo, o endereço
que o lojista COLOU continua funcionando, e o custo da loja não vai mais para a tela pública.

### 7. Criar usuário, trocar papel e redefinir senha: zero teste
**19 testes** onde não havia nenhum: a trava de escalada para ADMINISTRADOR_BORA, os cinco
`requirePapel`, o mínimo de 8 da senha, o "não se trancar fora" e o isolamento entre lojas.

---

## MÉDIOS — 19 de 23

### Dinheiro
- **Um pagamento confirmado no Asaas APAGAVA a liberação.** Medido: a liberação da Zirá até 2027
  virava 08/11/2026. É o acidente de 15/10 por uma **terceira porta** — e a que mais engana, porque
  entra por um evento de SUCESSO. Liberação já vencida não segura o pagamento, senão a loja pagava e
  continuava bloqueada.
- **O Desempenho não cobrava o Módulo IA**: o lucro saía R$ 99/mês maior do que é.
- **O Desempenho cobrava cashback de 100% do faturamento.** Medido no teste: cobrava R$ 50 onde o
  sistema credita R$ 5. Os dois erravam para lados opostos, o que é pior — se escondiam um no outro.
- **Cancelar de novo o pedido reaberto pelo PIX** tirava do cliente um cashback que ele nunca
  ganhou. O saldo tirado vinha de outro pedido.
- **Um bairro, dois fretes.** O cadastro criava linha nova sempre, e a consulta que cobra era um
  `findFirst` sem ordem: o cliente escolhia um preço na tela e pagava outro. Agora o cadastro
  atualiza a linha que existe, e mostrar e cobrar usam a mesma ordem.

### Marketplace
- Com aceite automático ligado, o **"Confirmar" do painel** não manda nada ao canal mas MUDA o
  status — e isso tirava o pedido da fila de retentativa **para sempre**.

### Custo e infraestrutura
- **N+1 no cardápio público**: 45+ idas ao banco para desenhar a tela de 44 produtos. Agora são
  duas, e 11 testes comparam as duas regras produto por produto.
- **A assinatura falava com o Asaas segurando uma conexão do banco.** O pool é compartilhado: Asaas
  lento parava painel, KDS, cardápio e marketplaces.
- **O rollback do deploy devolvia DOIS deploys.** Com um `api-anterior` sobrando, o `rename` falhava,
  o script caía no rollback, e o rollback apagava o container BOM e subia o sobrado. Em silêncio.
- **O portão dos Termos media o arquivo do checkout**, não a página no ar. Agora confere as duas.
  Hoje as três batem: 2026-10-04.
- **O cadastro público de loja ganhou teto** (5 por hora por origem).

### Telas
- **Seis contrastes**, todos medidos, nenhum quebrando nada: o botão que fecha a venda no cardápio
  (1,98:1), os botões do quadro (2,15 a 3,96:1), o cinza #94a3b8 em 86 lugares (2,56:1), o rodapé da
  tela que o cliente mais olha (1,48:1), o aviso de estoque baixo (2,15:1) e a inicial do produto sem
  foto (1,42:1).
- **O Desempenho montava as datas em UTC**: das 21h à meia-noite o "Hoje" devolvia ZERO e o "Mês"
  perdia o dia 1.
- **No celular o menu eram 26 emoji sem nome.** Agora cada item leva um nome curto embaixo — barra de
  61px, medida no navegador em 375px.
- **Produtos mandava o lojista para Configurações** buscar uma função que está na própria tela.
- **O cardápio ficava com o cashback e o cupom do pedido anterior** quando o cliente pedia de novo.

---

## BAIXOS — os 14, fechados

Token do webhook PIX comparado em tempo constante também no caminho da subconta · o balconista
deixou de ler o faturamento recuperado pela IA · corpo mal formado no cardápio devolve 400 dizendo
qual campo, não 500 com rastro de pilha · nome e categoria de produto ganharam teto (as colunas têm
160 e 80) · "0 entregas" não aparece mais com dinheiro ao lado · a recarga do saldo no PDV deixou de
ser engolida · o Novo Pedido parou de perguntar ao layout · três respingos do roxo antigo · o
comentário da landing parou de dizer "laranja" · "Excluir produto?" agora diz o nome e o que vai
junto · a categoria ganhou a lista das que a loja já usa · e **a tela do cliente parou de prometer
motoboy para quem vai retirar**.

---

# O que precisa de você — 5 itens

## 1. O `.git` do painel está sendo servido pela internet AGORA

Medido com `curl` no site no ar, hoje:

```
/.git/config      200  (300 bytes, com o endereço do remote)
/.git/index       200  (5.307 bytes, lista todo caminho versionado)
/.git/logs/HEAD   200  (572 bytes, com nome e e-mail de quem commitou)
```

A partir de `/.git/refs/heads/main` dá para baixar os objetos um a um e reconstruir a árvore.

**A regra já está escrita e ensaiada**, num Caddy local com a mesma imagem do servidor: `.git` dá
404, `/.well-known/` continua 200 (sem isso a renovação do HTTPS quebraria), o resto 200. Falta
aplicar no servidor — e isso é escrita em produção, que eu não faço sem a sua palavra.

São três comandos, nesta ordem:

```bash
scp -i ~/.ssh/bora-lightsail.pem bora-landing/deploy/Caddyfile ubuntu@18.230.57.33:/home/ubuntu/bora/Caddyfile
```

```bash
ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33 'docker exec caddy caddy validate --config /etc/caddy/Caddyfile && docker exec caddy caddy reload --config /etc/caddy/Caddyfile'
```

```bash
ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33 'tar czf /home/ubuntu/backups/git-do-frontend-$(date +%Y%m%d).tgz -C /home/ubuntu/bora/frontend .git && rm -rf /home/ubuntu/bora/frontend/.git && ls -lh /home/ubuntu/backups/git-do-frontend-*.tgz'
```

O terceiro guarda o `.git` num backup antes de apagar. Me diga e eu rodo.

## 2. `cliente` não tem UNIQUE: a deduplicação é read-then-insert em Java

`pedido` ganhou índice único na V28 exatamente para o evento repetido não virar segunda linha.
`cliente` ficou só com índices NÃO únicos. Dois pedidos do mesmo telefone ao mesmo tempo criam dois
clientes.

**Por que eu não fiz:** criar o UNIQUE exige limpar as duplicatas que já existem, e limpar cliente
duplicado significa **juntar saldo de cashback** de duas linhas. Isso é dinheiro de cliente e é
decisão sua, não minha. Se você quiser, eu levanto quantas duplicatas existem hoje (leitura, sem
escrever nada) e te mostro antes de qualquer coisa.

## 3. O UNIQUE de `taxa_entrega` (a outra metade do item 3)

A parte de código está feita: o cadastro não cria mais a segunda linha, e mostrar e cobrar escolhem
a mesma. **As linhas duplicadas que já existem continuam lá** — só deixaram de ser sorteadas. A
migração com UNIQUE precisa de uma limpeza antes, e vale a mesma pergunta: qual linha fica.

## 4. O "Fechamento de Caixa" não guarda nada e não existe para ontem

A tela é uma vista viva: pede o dia corrente e filtra pelo relógio do navegador. Não há seletor de
data, não existe tabela de fechamento em migração nenhuma, e nada é gravado ao imprimir.

**Isso não é defeito, é funcionalidade que não existe.** Guardar o fechamento muda o que o sistema
promete ao lojista, e o tamanho disso é seu: pode ser só um seletor de data (pequeno) ou um
fechamento assinado e guardado (grande). Me diga qual e eu faço.

## 5. O deploy

Está tudo commitado e nada no ar. Quando você mandar:

```bash
cd bora-landing/deploy && bash deploy-api.sh v155
```

```bash
cd bora-landing/deploy && bash deploy-frontend.sh --ensaio
```

O `--ensaio` mostra o que mudaria sem enviar nada. Depois, o mesmo comando sem o `--ensaio`.

**A landing também mudou** (a paleta) e ela é publicada à parte — ela não tem script ainda. Se você
quiser, eu estendo o `deploy-frontend.sh` para cobrir os dois repositórios.

---

## Uma coisa que entrou sem eu querer

O commit da landing levou junto o `ROTEIRO-DE-TESTE.pdf`, que estava solto na pasta e ainda não
tinha sido commitado. Não faz mal nenhum — é o PDF que você pediu para imprimir, e agora está
versionado. Se preferir fora, eu tiro.
