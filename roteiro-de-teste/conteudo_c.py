# -*- coding: utf-8 -*-
"""Roteiro, parte C: os testes INTEGRADOS -- o que cruza funcionalidades."""

PARTE_C = [
{'n':'I-A','int':True,'t':'Balcão até o acerto do motoboy','tela':'PDV · KDS · Entregas · Acerto · Caixa · Relatórios','r':'O caminho mais comum da loja, do começo ao fim. Seis telas e quatro números que têm que fechar entre si. Faça os itens em ordem, sem pular.','testes':[
 {'id':'A.1','t':'Lançar o pedido que chegou por telefone','passos':[
   'Em <b>Ajustes Operação</b>, garanta um bairro com taxa cadastrada (anote o valor).',
   'Abra <b>Novo Pedido</b> — não o PDV: a Frente de Caixa é retirada por definição (item 5.6), '
   'e é o Novo Pedido que tem entrega, endereço e taxa.',
   'Escolha ou cadastre o cliente, informando esse bairro.',
   'Confira que o campo Taxa de entrega preencheu sozinho com o valor cadastrado.',
   'Ponha no carrinho produtos que somem R$ 50.',
   'Confira que o canal está num canal da própria loja (Telefone), e não num marketplace.',
   'Escolha pagamento em DINHEIRO e feche.'],
  'e':'O total é R$ 50 mais a taxa do bairro. Aparece em Pedidos e no KDS, com o canal e a taxa '
      'que você viu na tela.',
  'f':'Este item já mandou "abra o PDV e escolha ENTREGA" — impossível, e em contradição direta '
      'com o item 5.6, que é regressão e exige que todo pedido do PDV nasça RETIRADA. Como I-A é '
      'sequencial, o erro derrubava os dez itens do bloco.','eps':['POST /api/pedidos']},
 {'id':'A.2','t':'A cozinha recebe','passos':['Abra o <b>KDS</b>.','Ache o cartão desse pedido e leia o que tem nele.'],
  'e':'Itens, observação, endereço, e que é entrega.','eps':['GET /api/pedidos/board']},
 {'id':'A.3','t':'O estoque baixou','passos':[
   'Abra <b>Estoque</b> e veja os produtos que você vendeu.',
   'Abra <b>Insumos</b> e veja os insumos da ficha desses produtos.'],
  'e':'Baixaram na quantidade certa.','eps':['GET /api/produtos','GET /api/insumos']},
 {'id':'A.4','t':'Avançar até pronto','passos':[
   'No KDS, avance o pedido para EM PREPARO.','Avance para PRONTO.',
   'Confira o status em Pedidos.','Confira o que o cliente recebeu.'],
  'e':'O status acompanha em Pedidos e o cliente recebe os avisos.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'A.5','t':'Escolher o motoboy e despachar','passos':[
   'Abra <b>Entregas</b>.','Escolha o entregador nesse pedido.','Clique em despachar.'],
  'e':'Vai para SAIU_PARA_ENTREGA e o cliente é avisado.','eps':['PATCH /api/pedidos/{id}/entregador']},
 {'id':'A.6','t':'Marcar como entregue','passos':['Em Entregas, marque ENTREGUE.','Olhe a rota e o histórico.'],
  'e':'Sai da rota e entra no histórico.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'A.7','t':'O acerto bate','passos':[
   'Abra <b>Acerto</b>.','Escolha esse entregador.','Abra a prévia.'],
  'e':'A entrega aparece, com a MESMA taxa que você viu no item A.1 e o total do pedido em dinheiro recebido.','eps':['GET /api/acertos/previa']},
 {'id':'A.8','t':'O caixa bate','passos':['Abra <b>Fechar Caixa</b>.','Procure a linha da forma DINHEIRO e compare com o total do A.1.'],
  'e':'O total do pedido está lá, na forma DINHEIRO.','eps':['GET /api/pedidos/board']},
 {'id':'A.9','t':'O relatório concorda','passos':[
   'Abra <b>Relatórios</b> no período de hoje.',
   'Compare o faturamento com o do caixa e com o do Dashboard.','Olhe o CMV.'],
  'e':'O mesmo faturamento nas três telas. O CMV reflete o custo dos produtos vendidos.','eps':['GET /api/relatorios']},
 {'id':'A.10','t':'Cancelar desfaz tudo','passos':[
   'Repita os itens A.1 a A.3 com um pedido novo.','Cancele esse pedido.',
   'Confira estoque e insumos.','Confira o caixa e o Dashboard.'],
  'e':'Estoque e insumos voltam; sai do faturamento; entra em cancelados — e não aparece como PIX pendente.','eps':['PATCH /api/pedidos/{id}/status']},
]},

{'n':'I-B','int':True,'t':'Cardápio com PIX, cashback e estoque','tela':'Cardápio · Caixa · Clientes · Acompanhar','r':'O cliente que pede sozinho e paga antes. Cruza pagamento, fidelidade e estoque. Use uma aba anônima para fazer o papel do cliente.','testes':[
 {'id':'B.1','t':'Cliente pede e gera PIX','passos':[
   'Numa aba anônima, abra o cardápio.','Monte um pedido de R$ 40.',
   'Informe nome e telefone.','Escolha PIX online.','Feche o pedido.'],
  'e':'Gera o código. O pedido nasce aguardando pagamento.','eps':['POST /public/loja/{lojaId}/pedido']},
 {'id':'B.2','t':'Antes de pagar não é faturamento','passos':[
   'SEM pagar, volte ao painel.','Abra Fechar Caixa.','Abra o Dashboard.'],
  'e':'Os R$ 40 NÃO entram, e aparecem como "esperando PIX" nas duas telas, com o mesmo número.','eps':['GET /api/pedidos/board']},
 {'id':'B.3','t':'O estoque já baixou','passos':['Abra Estoque.'],
  'e':'Baixou — a comida vai ser feita de qualquer jeito.','eps':['GET /api/produtos']},
 {'id':'B.4','t':'Pagar confirma','passos':[
   'Pague o PIX pelo banco (ou simule o webhook).','Volte ao painel e recarregue.','Abra o KDS.'],
  'e':'Deixa de esperar pagamento, entra no faturamento e aparece na cozinha.','eps':['POST /public/pix-webhook/{lojaId}']},
 {'id':'B.5','t':'O cashback entrou','passos':['Abra <b>Clientes</b>.','Ache o cliente e veja o saldo.'],
  'e':'Subiu pelo percentual configurado, sobre o valor certo.','eps':['GET /api/clientes']},
 {'id':'B.6','t':'Usar o cashback no pedido seguinte','passos':[
   'Faça outro pedido pelo cardápio com o mesmo telefone e nome.',
   'Marque para usar o saldo.','Olhe o total.','Veja o saldo em Clientes.'],
  'e':'O total desce e o saldo é debitado no mesmo valor.','eps':['GET /public/loja/{lojaId}/cashback']},
 {'id':'B.7','t':'Acompanhar','passos':[
   'Abra o link de acompanhamento.','Deixe aberto e avance o pedido no KDS.'],
  'e':'O status muda conforme a cozinha avança.','eps':['GET /public/loja/{lojaId}/pedido/{pedidoId}/status']},
 {'id':'B.8','t':'PIX abandonado some sozinho','passos':[
   'Gere um PIX e NÃO pague.','Espere passar o prazo de expiração.','Veja o pedido.',
   'Agora repita com outro pedido PIX, mas marque ENTREGUE antes do prazo.','Espere o prazo.'],
  'e':'O abandonado é encerrado e sai da conta do dia. O que foi ENTREGUE nunca é cancelado por isso.',
  'f':'Pedido PIX entregue virava CANCELADO sozinho 30 minutos depois, e o cliente recebia "pedido cancelado" depois de ter recebido a comida.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'B.9','t':'Pagar depois do cancelamento','passos':[
   'Deixe um PIX expirar e ser cancelado.','Só então confirme o pagamento.',
   'Veja o pedido, o estoque, o cashback e a observação.'],
  'e':'O pedido REABRE como RECEBIDO, o estoque baixa de novo, o cashback é reconsumido, e a observação explica.','reg':True,'eps':['POST /public/pix-webhook/{lojaId}']},
]},

{'n':'I-C','int':True,'t':'Marketplace até o caixa','tela':'Integrações · Pedidos · KDS · Estoque · Caixa','r':'Pedido que entra de fora. Cruza integração, estoque, status e faturamento. Precisa do Portal do Parceiro do iFood aberto.','testes':[
 {'id':'C.1','t':'O pedido entra sozinho','passos':[
   'No Portal do Parceiro, crie um pedido de teste.','Volte ao painel e espere até 30 segundos.'],
  'e':'Aparece no painel, com itens, endereço e pagamento.','eps':['GET /api/pedidos/board']},
 {'id':'C.2','t':'Entra marcado como teste','passos':['Abra o pedido e leia a observação.'],
  'e':'Começa com "PEDIDO DE TESTE DO IFOOD — NÃO PREPARE".','reg':True,'eps':['GET /api/pedidos/{id}/itens']},
 {'id':'C.3','t':'O aceite foi enviado','passos':['Volte ao Portal e veja a situação do pedido.'],
  'e':'Aceito, se o aceite automático estiver ligado.','eps':['GET /api/integracoes']},
 {'id':'C.4','t':'Aceite que falha é reenviado','passos':[
   'Faça o aceite falhar (por exemplo, com a credencial momentaneamente errada).',
   'Corrija e aguarde o próximo evento do mesmo pedido.','Veja o Portal.'],
  'e':'Tenta de novo. Pedido já aceito NÃO é confirmado duas vezes.','reg':True,'eps':['GET /api/integracoes']},
 {'id':'C.5','t':'O estoque baixou pelo produto certo','passos':[
   'Garanta que o produto tem o código externo do iFood preenchido.',
   'Abra Estoque e confira o saldo.'],
  'e':'Baixou. O casamento é pelo código externo, não pelo nome.',
  'f':'Pelo nome, 14 de 15 itens não casavam e o estoque não mexia.','reg':True,'eps':['GET /api/produtos']},
 {'id':'C.6','t':'O status vai para o marketplace','passos':[
   'Avance aqui para EM PREPARO.','Avance para PRONTO.','Confira cada etapa no Portal.'],
  'e':'O portal reflete cada etapa.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'C.7','t':'O que o canal anda chega aqui','passos':[
   'Num pedido entregue pelo PRÓPRIO marketplace, despache pelo lado do iFood.',
   'Conclua pelo lado do iFood.','Volte ao painel sem clicar em nada.'],
  'e':'O pedido anda aqui também, sem alguém clicar.',
  'f':'O pedido ficava congelado no painel para sempre, no status que a loja clicou por último.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'C.8','t':'Cancelamento dos dois lados','passos':[
   'Cancele o pedido pelo app do cliente.','Veja o pedido e o histórico dele aqui.','Confira o estoque.'],
  'e':'Cancela aqui com o motivo, e o estoque volta.','reg':True,'eps':['GET /api/pedidos/{id}/historico']},
 {'id':'C.9','t':'No caixa e no relatório','passos':[
   'Abra Fechar Caixa.','Abra Relatórios.','Olhe a linha do canal iFood e o que vem abaixo do faturamento.'],
  'e':'Aparece no canal iFood. A taxa de entrega do marketplace aparece embaixo do faturamento quando foi ele quem entregou.','eps':['GET /api/relatorios']},
 {'id':'C.10','t':'Cancele o pedido de teste','passos':['Cancele o pedido de teste no fim.','Confira faturamento e estoque.'],
  'e':'Sai do faturamento e do estoque.','eps':['PATCH /api/pedidos/{id}/status']},
]},

{'n':'I-D','int':True,'t':'Assinatura, corte e acesso','tela':'Planos · Plataforma · Cardápio','r':'O que acontece quando o cliente deixa de pagar. Cruza Asaas, bloqueio e cardápio. Use uma loja de teste, nunca uma loja real.','testes':[
 {'id':'D.1','t':'Loja em dia opera normal','passos':[
   'Numa loja com assinatura ATIVA, use o painel.','Abra o cardápio.','Veja a tela de Planos.'],
  'e':'Tudo funciona, sem data de vencimento.','eps':['GET /api/assinatura']},
 {'id':'D.2','t':'Fatura vencida marca inadimplente','passos':[
   'Mande o aviso de atraso (<code>PAYMENT_OVERDUE</code>) para o webhook.',
   'Veja o status na Plataforma.','Use o painel da loja.'],
  'e':'Vira INADIMPLENTE e ganha a carência. O acesso continua até o prazo.','eps':['POST /public/asaas-webhook']},
 {'id':'D.3','t':'Carência não é encurtada','passos':[
   'Numa loja com prazo maior (cortesia ou liberação), anote a data.',
   'Mande o aviso de atraso e confira a data.',
   'Mande o aviso de cancelamento da assinatura e confira a data outra vez.'],
  'e':'O prazo maior é mantido nos dois casos.',
  'f':'O cancelamento sobrescrevia o prazo de quem já tinha pago — foi o que tirou a Zirá do ar.','reg':True,'eps':['POST /public/asaas-webhook']},
 {'id':'D.4','t':'Prazo vencido tira do ar','passos':[
   'Com o corte ligado, deixe o prazo vencer.','Tente usar o painel.',
   'Abra o cardápio.','Tente aceitar os termos.'],
  'e':'O painel bloqueia e o cardápio some. O aceite dos termos continua funcionando.','eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'D.5','t':'Pagar devolve o acesso','passos':[
   'Mande o aviso de pagamento recebido.','Use o painel.','Veja o prazo.'],
  'e':'Volta ATIVA e o acesso é liberado sem data.','eps':['POST /public/asaas-webhook']},
 {'id':'D.6','t':'Pagamento fora do Asaas','passos':[
   'Numa loja inadimplente, use <b>💰 Recebi o pagamento</b>.',
   'Leia o recado sobre a baixa.','Confira a cobrança no painel do Asaas.'],
  'e':'Libera o acesso e tenta dar baixa na cobrança aberta, para o Asaas não desfazer dias depois.','reg':True,'eps':['POST /admin-bora/lojas/{lojaId}/pagamento-recebido']},
 {'id':'D.7','t':'Liberar acesso sem pagamento','passos':[
   'Use <b>🔓 Liberar acesso</b> por 30 dias com motivo.',
   'Veja o status da assinatura.','Veja o faturamento da plataforma.','Veja o log de auditoria.'],
  'e':'Libera, o status da assinatura NÃO muda, nenhum pagamento é registrado, e o motivo fica no log.','reg':True,'eps':['POST /admin-bora/lojas/{lojaId}/liberar-acesso']},
 {'id':'D.8','t':'O corte está mesmo ligado','passos':[
   'No servidor, leia o log de subida da API.','Procure a linha do corte por falta de pagamento.'],
  'e':'Diz "Corte por falta de pagamento: LIGADO". Se disser DESLIGADO, nada acima vale em produção.',
  'f':'A variável tem COBRANCA no meio do nome; escrita errada, o corte nunca acontece.','reg':True,'eps':['GET /api/health']},
]},

{'n':'I-E','int':True,'t':'Duas pessoas ao mesmo tempo','tela':'todas','r':'O que quebra quando a loja tem movimento. Cada item precisa de duas abas (ou dois aparelhos) agindo quase junto.','testes':[
 {'id':'E.1','t':'Dois caixas, um produto','passos':[
   'Deixe um produto com estoque 1.','Abra o PDV em duas abas, com o mesmo produto no carrinho.',
   'Feche a venda nas duas quase ao mesmo tempo.','Confira o saldo e as duas vendas.'],
  'e':'O saldo final é coerente; nenhuma venda some.','reg':True,'eps':['POST /api/pedidos']},
 {'id':'E.2','t':'Dois pedidos no mesmo cashback','passos':[
   'Deixe um cliente com saldo de R$ 10.','Abra o cardápio em duas abas com esse cliente.',
   'Feche os dois pedidos usando o saldo, quase ao mesmo tempo.','Veja o saldo final.'],
  'e':'Só um abate, ou os dois recalculam. O saldo nunca fica negativo.','reg':True,'eps':['GET /public/loja/{lojaId}/cashback']},
 {'id':'E.3','t':'Dois avanços no mesmo pedido','passos':[
   'Abra o mesmo pedido em duas abas.','Avance o status nas duas quase ao mesmo tempo.',
   'Veja o que o cliente recebeu.'],
  'e':'A segunda recebe recusa clara. O cliente não recebe dois avisos conflitantes.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'E.4','t':'Salvar produto enquanto vende','passos':[
   'Abra a edição de um produto numa aba e não salve.','Venda esse produto na outra aba.',
   'Volte e salve o cadastro.','Confira o estoque.'],
  'e':'A venda não é apagada pelo salvamento.','reg':True,'eps':['PUT /api/produtos/{id}']},
 {'id':'E.5','t':'Painel e poller juntos','passos':[
   'Com o poller ativo, mude a integração na tela e salve.',
   'Espere um minuto sem mexer.','Recarregue.'],
  'e':'Sua mudança permanece.','reg':True,'eps':['PUT /api/integracoes/{canal}']},
 {'id':'E.6','t':'Dois registros de pagamento','passos':[
   'Abra a Plataforma em duas abas.','Registre o mesmo pagamento nas duas.'],
  'e':'Pergunta antes de gravar o segundo.','reg':True,'eps':['POST /admin-bora/lojas/{lojaId}/pagamento-recebido']},
]},

{'n':'I-F','int':True,'t':'Perda e recuperação','tela':'servidor','r':'O teste que ninguém faz até precisar. Tudo aqui é por SSH, e em ambiente de teste.','testes':[
 {'id':'F.1','t':'Backup roda e é conferido','passos':[
   'Entre no servidor por SSH.','Rode <code>backup-bora.sh</code> à mão.','Leia a saída.'],
  'e':'Diz "backup ok" com tamanho, entradas e que foi lido inteiro pelo pg_restore.','reg':True,'eps':['GET /api/health']},
 {'id':'F.2','t':'Dump cortado é reprovado','passos':[
   'Copie um dump bom.','Corte a cópia pela metade.','Rode <code>conferir-dump.sh</code> nela.'],
  'e':'Reprova. A assinatura PGDMP sobrevive a qualquer corte e não serve de conferência.','reg':True,'eps':['GET /api/health']},
 {'id':'F.3','t':'Ensaio de restauração','passos':['Rode <code>ensaio-de-restauracao.sh</code>.','Leia a contagem no fim.'],
  'e':'Restaura num banco descartável e conta as linhas de loja, usuário, produto e pedido, mais a versão do schema.','reg':True,'eps':['GET /api/health']},
 {'id':'F.4','t':'Subir a aplicação no banco restaurado','passos':[
   'Aponte a API de teste para o banco restaurado.','Suba.','Entre no painel e abra Pedidos.'],
  'e':'Sobe, o Flyway não reclama, e dá para entrar e ver os pedidos.','eps':['GET /api/health']},
 {'id':'F.5','t':'Quanto se perderia','passos':['Liste a pasta de backups.','Veja o horário do dump mais novo.'],
  'e':'No máximo 6 horas — o backup roda de 6 em 6 horas.','eps':['GET /api/health']},
 {'id':'F.6','t':'Os backups estão em dois lugares','passos':[
   'Confira a pasta de backups no servidor.','Confira a pasta de backups no seu computador.',
   'Leia o log do backup.'],
  'e':'Estão nos dois. Sem cópia em S3, o log do backup avisa isso em voz alta.','reg':True,'eps':['GET /api/health']},
 {'id':'F.7','t':'Saúde separa processo de banco','passos':[
   'Chame <code>/actuator/health</code>.','Chame <code>/actuator/health/viva</code>.'],
  'e':'Os dois UP. O <code>viva</code> olha só o processo.','reg':True,'eps':['GET /api/health']},
 {'id':'F.8','t':'O vigia não reinicia por causa do banco','passos':[
   'Derrube só o banco, deixando a API de pé.','Espere o vigia rodar.','Leia o <code>vigia.log</code>.'],
  'e':'Com o processo vivo e o sistema não, ele escreve que o problema é depois da API — e não reinicia.','reg':True,'eps':['GET /api/health']},
 {'id':'F.9','t':'Deploy com rollback','passos':[
   'Em ambiente de teste, suba uma versão que não fica sadia.','Leia a saída do deploy.'],
  'e':'Faz rollback e diz se o processo subiu, para não acusar código bom quando o problema é o banco.','reg':True,'eps':['GET /api/health']},
 {'id':'F.10','t':'Deploy não derruba o site','passos':[
   'Abra o cardápio e deixe recarregando.','Faça um deploy.','Olhe se alguma recarga falhou.'],
  'e':'Nenhum 502 na cara do cliente.','reg':True,'eps':['GET /public/loja/{lojaId}/cardapio']},
]},
]
