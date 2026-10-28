# -*- coding: utf-8 -*-
"""Roteiro, parte B (segunda metade): equipe, integracoes, plataforma e publico. Secoes 23 a 32."""

PARTE_B2 = [
{'n':'23','t':'Usuários e equipe','tela':'usuarios.html','r':'Quem tem acesso, com qual papel, em qual loja.','testes':[
 {'id':'23.1','t':'Listar usuários','passos':['Abra <b>Usuários</b>.'],
  'e':'Nome, e-mail, papel e situação.','eps':['GET /api/usuarios']},
 {'id':'23.2','t':'Criar de cada papel','passos':[
   'Crie um OPERADOR, um GERENTE e um ADMINISTRADOR_LOJA.',
   'Entre com cada um deles.','Confira o menu de cada um.'],
  'e':'Todos entram e veem o menu do papel deles.','eps':['POST /api/usuarios']},
 {'id':'23.3','t':'Limite do plano','passos':[
   'Veja o limite de usuários do plano em Planos.','Crie usuários até passar desse número.'],
  'e':'Recusa dizendo o limite.','eps':['POST /api/usuarios']},
 {'id':'23.4','t':'Trocar papel vale na hora','passos':[
   'Entre com um GERENTE noutro navegador e deixe a tela aberta.',
   'No seu navegador, rebaixe esse usuário para OPERADOR.',
   'No navegador dele, SEM sair e entrar, abra Relatórios.'],
  'e':'Recusa imediatamente.',
  'f':'Quem foi rebaixado mantinha o poder até o token vencer, em 24h.','reg':True,'eps':['PUT /api/usuarios/{id}/papel']},
 {'id':'23.5','t':'Desativar usuário','passos':[
   'Com o usuário logado noutro navegador, desative ele.',
   'No navegador dele, clique em qualquer tela.'],
  'e':'Perde o acesso na requisição seguinte.','reg':True,'eps':['PUT /api/usuarios/{id}/ativo']},
 {'id':'23.6','t':'Trocar a senha de alguém','passos':[
   'Como administrador da loja, defina a senha de um usuário.',
   'Entre com ele usando a senha nova.'],
  'e':'Entra.','eps':['PUT /api/usuarios/{id}/senha']},
 {'id':'23.7','t':'Pedidos de senha','passos':[
   'Na tela de entrada, peça recuperação de senha com um usuário da loja.',
   'Abra Usuários e veja a lista de pedidos.'],
  'e':'Mostra quem pediu e quando.','eps':['GET /api/usuarios/pedidos-de-senha']},
 {'id':'23.8','t':'Equipe da rede','passos':['Numa rede, abra a aba de equipe.','Abra a lista de lojas da empresa.'],
  'e':'Mostra quem alcança cada loja.','eps':['GET /api/rede/equipe','GET /api/rede/lojas-da-empresa']},
 {'id':'23.9','t':'Vincular e desvincular loja','passos':[
   'Vincule um usuário a outra loja.','Entre com ele e troque de loja.',
   'Desvincule e tente trocar de novo.'],
  'e':'Passa a alcançar, e depois deixa de alcançar.','eps':['POST /api/rede/usuarios/{usuarioId}/lojas','DELETE /api/rede/usuarios/{usuarioId}/lojas/{lojaId}']},
 {'id':'23.10','t':'Usuário de rede aparece na loja','passos':[
   'Numa rede, troque para uma loja em que você entra por VÍNCULO (não é a sua loja de origem).',
   'Abra Usuários.'],
  'e':'Você aparece na lista.',
  'f':'A tela vinha vazia e parecia que ninguém conseguia entrar na loja — mandou a investigação para o lado errado por dias.','reg':True,'eps':['GET /api/usuarios']},
]},

{'n':'24','t':'Planos e assinatura','tela':'planos.html','r':'A cobrança da plataforma.','testes':[
 {'id':'24.1','t':'Ver o plano','passos':['Abra <b>Planos</b>.'],
  'e':'Plano atual, preço e o que inclui.','eps':['GET /api/plano']},
 {'id':'24.2','t':'Só existe um plano, e a tela não promete outro','passos':[
   'Abra <b>Planos</b> e conte quantos planos aparecem.',
   'Procure algum botão de trocar, assinar outro, ou comparar planos.',
   'Confira o limite de usuários em Usuários contra o que o card promete.'],
  'e':'Aparece UM plano (R$ 199/mês, até 15 usuários) e nenhum botão de troca — porque não há '
      'para onde trocar. O limite de Usuários bate com o card.',
  'f':'O endpoint PUT /api/plano existe para quando houver mais de um plano. Eu já cheguei a '
      'anotar "não dá para trocar de plano" como defeito que travava receita: era falso, o enum '
      'Plano tem só UNICO e as 5 lojas em produção estão nele. Quando nascer o segundo plano, '
      'este item volta a ser "troque e confira".','eps':['PUT /api/plano']},
 {'id':'24.3','t':'Status da assinatura','passos':['Veja o status na tela.','Compare com o painel do Asaas.'],
  'e':'Batem.','eps':['GET /api/assinatura']},
 {'id':'24.4','t':'Assinar','passos':['Clique em ativar a assinatura.','Siga o link de pagamento.'],
  'e':'Cria no Asaas e devolve o link.','eps':['POST /api/assinatura']},
 {'id':'24.5','t':'Reativar não apaga fatura','passos':[
   'Numa loja com assinatura cancelada, reative.','Veja o histórico de faturas.'],
  'e':'As faturas anteriores continuam lá.','reg':True,'eps':['POST /api/assinatura']},
]},

{'n':'25','t':'Integrações e recebimento','tela':'integracoes.html','r':'iFood, 99Food, PIX, WhatsApp e a subconta do lojista.','testes':[
 {'id':'25.1','t':'Ver as integrações','passos':['Abra <b>Integrações</b>.'],
  'e':'Estado de cada canal e o último erro, quando há.','eps':['GET /api/integracoes']},
 {'id':'25.2','t':'Salvar credencial de canal','passos':[
   'Num canal NÃO oficial, preencha os campos e salve. Recarregue.',
   'Agora repita num canal oficial (iFood ou 99Food): preencha, salve e recarregue.',
   'Olhe o status e o Merchant ID nos dois.'],
  'e':'Nos dois a credencial grava. No canal não oficial a tela mostra conectado. '
      'No oficial NÃO conecta só por salvar — conectar é pelo vínculo (item 25.3), e o Merchant ID '
      'só o suporte da plataforma muda.',
  'f':'Salvar não rebaixa quem já estava conectado. Este item já esteve escrito como se salvar '
      'conectasse, e nesses dois canais o lojista não conseguia cumpri-lo.','eps':['PUT /api/integracoes/{canal}']},
 {'id':'25.3','t':'Vincular o iFood','passos':[
   'No canal iFood, clique em vincular.','Copie o código que aparece.',
   'Digite o código no Portal do Parceiro do iFood.','Volte e clique em confirmar.',
   'Olhe o Merchant ID na tela.'],
  'e':'Conecta e descobre o Merchant ID sozinho — não fica em branco.',
  'f':'O vínculo terminava com o Merchant ID vazio e o card ficava verde sem receber pedido nenhum.','reg':True,'eps':['POST /api/integracoes/{canal}/vincular','POST /api/integracoes/{canal}/confirmar']},
 {'id':'25.4','t':'Diagnóstico do canal','passos':['Rode o diagnóstico do canal.'],
  'e':'Diz o que está faltando, em português.','eps':['GET /api/integracoes/{canal}/diagnostico']},
 {'id':'25.5','t':'Integração em erro volta sozinha','passos':[
   'Troque a credencial por uma errada e espere o status virar ERRO.',
   'Corrija a credencial.','Espere até 10 minutos sem mexer em mais nada.'],
  'e':'Volta sozinha para CONECTADO e passa a ser consultada a cada 30 segundos de novo.',
  'f':'Uma falha qualquer prendia a loja no ciclo de 10 minutos para sempre, e ela some do app do iFood.','reg':True,'eps':['GET /api/integracoes']},
 {'id':'25.6','t':'Status recusado aparece','passos':[
   'Faça o marketplace recusar um aviso de status (por exemplo, avançando fora de ordem).',
   'Abra Integrações.'],
  'e':'Mostra qual status, de qual pedido, e que lá dentro ele continua no anterior.','reg':True,'eps':['GET /api/integracoes']},
 {'id':'25.7','t':'O poller não desfaz o que você salva','passos':[
   'Com a integração ativa e recebendo, desligue ela na tela.',
   'Espere um minuto (dois ciclos) sem mexer.','Recarregue.'],
  'e':'Continua desligada.',
  'f':'O ciclo regravava a linha inteira com os valores de até 25 segundos antes, desfazendo o que o lojista salvou.','reg':True,'eps':['PUT /api/integracoes/{canal}']},
 {'id':'25.8','t':'Token não vaza para o operador','passos':[
   'Entre como OPERADOR.','Aperte F12 e vá na aba Rede.','Abra as telas que tocam integração.'],
  'e':'Nenhum token ou segredo aparece nas respostas.','reg':True,'eps':['GET /api/integracoes']},
 {'id':'25.9','t':'Estado do recebimento','passos':['Na aba de recebimento (PIX), veja o estado.'],
  'e':'Diz se a subconta existe e se está liberada.','eps':['GET /api/recebimento']},
 {'id':'25.10','t':'Ativar o recebimento','passos':[
   'Clique em ativar.','Informe o CPF/CNPJ e os dados pedidos.','Envie.'],
  'e':'Cria a subconta e devolve o link de KYC.','eps':['POST /api/recebimento/ativar']},
 {'id':'25.11','t':'Documentos do KYC','passos':[
   'Veja a lista de documentos pendentes.','Envie um documento.'],
  'e':'Lista o que falta, e o envio é aceito.','eps':['GET /api/recebimento/documentos','POST /api/recebimento/documentos/{documentoId}']},
 {'id':'25.12','t':'Reparar o webhook','passos':['Clique em reparar o webhook do recebimento.'],
  'e':'Reprovisiona e diz se deu certo.','eps':['POST /api/recebimento/webhook']},
 {'id':'25.13','t':'PIX só com KYC aprovado','passos':[
   'Com a subconta criada mas ainda EM ANÁLISE, abra o cardápio.','Vá até o pagamento.'],
  'e':'O PIX não é oferecido.',
  'f':'Ofereceria pagamento para uma conta que ainda não pode sacar.','reg':True,'eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'25.14','t':'Robô do WhatsApp responde','passos':[
   'Com o robô ligado, mande "oi" para o número da loja pelo WhatsApp.'],
  'e':'Responde com o menu e o link do cardápio.','eps':['POST /public/whatsapp-webhook/{lojaId}']},
 {'id':'25.15','t':'Verificação do webhook da Meta','passos':[
   'No painel da Meta, configure o webhook com o verify token certo.',
   'Repita com um token errado.'],
  'e':'Passa com o certo e falha com o errado.','eps':['GET /public/whatsapp-webhook/{lojaId}']},
 {'id':'25.16','t':'O robô só responde ao número da loja','passos':[
   'Capture um aviso legítimo da loja A, com assinatura válida da Meta.',
   'Reenvie esse MESMO corpo para o endereço da loja B.'],
  'e':'Ignora.',
  'f':'O robô responderia ao cliente da loja A com o nome e o cardápio da loja B, pelo número da B.','reg':True,'eps':['POST /public/whatsapp-webhook/{lojaId}']},
 {'id':'25.17','t':'O recado do marketplace espera você','passos':[
   'Abra <b>Integrações</b> numa loja que tenha recado do iFood ou da 99.',
   'Leia o recado e fique MAIS DE UM MINUTO na tela, sem clicar em nada.',
   'Clique em <b>Já vi, tirar da tela</b>.','Recarregue a página.'],
  'e':'O recado fica na tela até você marcar como lido. Depois de marcado, não volta.',
  'f':'Ele sumia sozinho em 30 segundos, porque dividia a coluna com a mensagem de erro — quem não estava olhando na hora nunca soube que a integração reclamou.','reg':True,
  'eps':['POST /api/integracoes/{canal}/aviso-lido','GET /api/integracoes']},
]},

{'n':'26','t':'Fiscal (NFC-e)','tela':'pedidos.html','r':'Emissão fiscal. Hoje dorme até a plataforma ligar.','testes':[
 {'id':'26.1','t':'Com o módulo desligado','passos':['Num pedido, tente emitir a NFC-e.'],
  'e':'Responde 409 dizendo que o módulo não está ligado — sem erro feio na tela.','eps':['POST /api/fiscal/nfce/{pedidoId}']},
 {'id':'26.2','t':'Ligar na plataforma','passos':[
   'Entre como ADMINISTRADOR_BORA.','Abra a configuração da plataforma.',
   'Ligue a chave fiscal e salve.','Recarregue.'],
  'e':'A configuração grava e aparece ligada.','eps':['PUT /admin-bora/config/fiscal','GET /admin-bora/config']},
 {'id':'26.3','t':'Emitir com o módulo ligado','passos':['Volte à loja.','Emita a NFC-e de um pedido.'],
  'e':'Emite, ou diz exatamente o que falta no cadastro fiscal da loja.','eps':['POST /api/fiscal/nfce/{pedidoId}']},
 {'id':'26.4','t':'Papel para emitir','passos':['Entre como OPERADOR.','Tente emitir.'],
  'e':'Recusa.','eps':['POST /api/fiscal/nfce/{pedidoId}']},
]},

{'n':'27','t':'Plataforma: clientes e acesso','tela':'configuracoes.html (aba Plataforma)','r':'A tela que só você usa. Entre como ADMINISTRADOR_BORA.','testes':[
 {'id':'27.1','t':'Lista de clientes','passos':['Entre como ADMINISTRADOR_BORA.','Abra Configurações.','Vá na aba Plataforma.'],
  'e':'Todas as lojas com situação, plano, usuários e último pedido.','eps':['GET /admin-bora/clientes','GET /admin-bora/lojas']},
 {'id':'27.2','t':'Até quando o acesso vale','passos':[
   'Olhe a ficha de uma loja com prazo.','Procure uma com menos de 7 dias.'],
  'e':'Mostra a data e quantos dias faltam; em vermelho quando falta uma semana ou menos.','reg':True,'eps':['GET /admin-bora/clientes']},
 {'id':'27.3','t':'Criar loja','passos':[
   'Clique em criar loja.','Preencha empresa, nome, plano e o administrador.','Salve.',
   'Entre com o administrador criado.'],
  'e':'Nasce com 7 dias de cortesia e com um administrador que consegue entrar.','eps':['POST /admin-bora/lojas']},
 {'id':'27.4','t':'Renomear loja','passos':['Clique em <b>Renomear</b>.','Mude o nome.','Abra o cardápio público dela.'],
  'e':'Muda no painel e no cardápio.','eps':['PUT /admin-bora/lojas/{lojaId}/nome']},
 {'id':'27.5','t':'Liberar acesso','passos':[
   'Numa loja com prazo, clique em <b>🔓 Liberar acesso</b>.',
   'Deixe o motivo em branco e confirme.',
   'Repita informando data e motivo.',
   'Confira o prazo na ficha.','Confira a linha no log de auditoria.'],
  'e':'Sem motivo recusa. Com motivo libera, NÃO registra pagamento, e o status da assinatura não muda.','reg':True,'eps':['POST /admin-bora/lojas/{lojaId}/liberar-acesso']},
 {'id':'27.6','t':'Teto da liberação','passos':['Tente liberar por 200 dias.'],
  'e':'Recusa dizendo o máximo de 180.','reg':True,'eps':['POST /admin-bora/lojas/{lojaId}/liberar-acesso']},
 {'id':'27.7','t':'Registrar pagamento fora do Asaas','passos':[
   'Numa loja inadimplente, clique em <b>💰 Recebi o pagamento</b>.',
   'Informe valor, data e observação.','Leia o recado final.'],
  'e':'Registra, tenta dar baixa no Asaas e diz se a baixa saiu.','reg':True,'eps':['POST /admin-bora/lojas/{lojaId}/pagamento-recebido']},
 {'id':'27.8','t':'Dois pagamentos no mesmo dia','passos':[
   'Registre R$ 199 hoje.','Registre R$ 199 de novo, hoje.'],
  'e':'Pergunta se é um segundo pagamento de verdade, em vez de descartar o segundo em silêncio.','reg':True,'eps':['POST /admin-bora/lojas/{lojaId}/pagamento-recebido']},
 {'id':'27.9','t':'Entrar na loja como suporte','passos':[
   'Clique em <b>Entrar na loja</b>.','Opere alguma tela.',
   'Clique em sair da loja.','Veja o log de auditoria.'],
  'e':'Opera dentro dela e volta à plataforma. Fica registrado.','eps':['POST /admin-bora/lojas/{lojaId}/acessar','POST /admin-bora/sair-da-loja']},
 {'id':'27.10','t':'Suspender e reativar','passos':[
   'Suspenda uma loja com motivo.','Abra o cardápio dela.','Reative.','Veja o prazo.'],
  'e':'Suspensa: cardápio fora do ar. Reativada: volta com prazo de carência.','reg':True,'eps':['PUT /admin-bora/lojas/{lojaId}/ativo']},
 {'id':'27.11','t':'Pagamento não levanta suspensão','passos':[
   'Com a loja suspensa POR VOCÊ, simule o pagamento da assinatura.','Abra o cardápio.'],
  'e':'Continua suspensa. Só você reativa.','reg':True,'eps':['PUT /admin-bora/lojas/{lojaId}/ativo']},
 {'id':'27.12','t':'Arquivar e restaurar loja','passos':[
   'Arquive uma loja de teste.','Confirme que sumiu da lista.',
   'Marque "incluir arquivadas".','Restaure.'],
  'e':'Some e volta sem perder dados.','eps':['PUT /admin-bora/lojas/{lojaId}/arquivar','PUT /admin-bora/lojas/{lojaId}/restaurar']},
 {'id':'27.13','t':'Empresa inteira','passos':[
   'Numa empresa com duas lojas, use suspender tudo.','Confira as duas.',
   'Arquive tudo.','Restaure tudo.'],
  'e':'As duas lojas acompanham cada ação.','eps':['PUT /admin-bora/empresas/{empresaId}/ativo','PUT /admin-bora/empresas/{empresaId}/arquivar','PUT /admin-bora/empresas/{empresaId}/restaurar']},
 {'id':'27.14','t':'Preço negociado','passos':[
   'Defina um preço diferente do plano para uma loja.','Veja a ficha dela.'],
  'e':'Grava, aparece como "negociado", e a cobrança seguinte usa o valor novo.','reg':True,'eps':['PUT /admin-bora/lojas/{lojaId}/preco']},
 {'id':'27.15','t':'Split do PIX','passos':['Defina o percentual de split de uma loja.','Veja na tela da loja.'],
  'e':'Grava e aparece.','eps':['PUT /admin-bora/lojas/{lojaId}/split']},
 {'id':'27.16','t':'Ligar o módulo IA','passos':[
   'Ligue o módulo IA para uma loja.','Entre nela.','Abra um recurso de IA.'],
  'e':'Para de dar 403.','eps':['PUT /admin-bora/lojas/{lojaId}/modulo-ia']},
]},

{'n':'28','t':'Plataforma: administradores, credenciais e faturamento','tela':'configuracoes.html (aba Plataforma)','r':'O resto do que só o administrador da plataforma faz.','testes':[
 {'id':'28.1','t':'Listar administradores','passos':['Na aba Plataforma, abra a lista de administradores.'],
  'e':'Nome, e-mail e situação.','eps':['GET /admin-bora/admins']},
 {'id':'28.2','t':'Criar administrador','passos':['Crie um administrador novo.','Entre com ele.'],
  'e':'Entra e enxerga a aba Plataforma.','eps':['POST /admin-bora/admins']},
 {'id':'28.3','t':'Desativar administrador','passos':['Desative um administrador.','Tente entrar com ele.'],
  'e':'Perde o acesso.','eps':['PUT /admin-bora/admins/{id}/ativo']},
 {'id':'28.4','t':'Credenciais dos marketplaces','passos':[
   'Abra as credenciais da plataforma.','Salve o client id e o secret de um canal.',
   'Recarregue a tela e olhe o campo do secret.','Remova a credencial.'],
  'e':'Salva, e a tela NUNCA mostra o segredo de volta.','reg':True,'eps':['GET /admin-bora/credenciais','PUT /admin-bora/credenciais/{canal}','DELETE /admin-bora/credenciais/{canal}']},
 {'id':'28.5','t':'Configuração da plataforma','passos':['Abra a configuração geral.'],
  'e':'Mostra quais chaves estão ligadas, sem mostrar valor nenhum.','eps':['GET /admin-bora/config']},
 {'id':'28.6','t':'Estado da cifragem','passos':['Abra o estado da cifragem de credenciais.'],
  'e':'Diz quantas estão em texto puro e se a chave está ligada — sem mostrar nenhum valor.','reg':True,'eps':['GET /admin-bora/seguranca/cifragem']},
 {'id':'28.7','t':'Aplicar a cifragem','passos':[
   'Com <code>BORA_SEGREDO_COLUNAS</code> definida no servidor, rode a recifragem.',
   'Veja o número.','Rode DE NOVO.'],
  'e':'A primeira cifra o que estava em texto puro. A segunda não estraga nada e o relatório zera.','reg':True,'eps':['POST /admin-bora/seguranca/cifragem']},
 {'id':'28.8','t':'Faturamento da plataforma','passos':['Abra o faturamento.'],
  'e':'Os pagamentos das lojas, com valor e data.','eps':['GET /admin-bora/faturamento']},
 {'id':'28.9','t':'Nota fiscal do pagamento','passos':[
   'Num pagamento, lance o número e o link da nota.','Salve.','Recarregue.'],
  'e':'Grava e aparece na linha.','eps':['PUT /admin-bora/faturamento/{id}/nota']},
 {'id':'28.10','t':'Pedido bruto do marketplace','passos':[
   'Pegue o id externo de um pedido de marketplace.','Use o diagnóstico para ver o payload cru.'],
  'e':'Mostra o JSON como o canal mandou — é o que resolve dúvida de integração.','eps':['GET /admin-bora/marketplace/pedido-bruto']},
]},

{'n':'29','t':'Cardápio público','tela':'cardapio.html · acompanhar.html','r':'A única tela que quem compra vê. Testar em aba anônima.','testes':[
 {'id':'29.1','t':'Abrir o cardápio','passos':['Numa aba anônima, abra <code>/cardapio.html?loja=SEU_ID</code>.'],
  'e':'Carrega marca, categorias e produtos ativos, sem pedir login.','eps':['GET /public/loja/{lojaId}/cardapio','GET /public/loja/{lojaId}/marca']},
 {'id':'29.2','t':'Produto fora do cardápio','passos':['Desative um produto no painel.','Recarregue o cardápio.'],
  'e':'Some da lista pública.','eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'29.3','t':'Produto esgotado','passos':['Zere o estoque de um produto com controle de estoque.','Recarregue o cardápio.','Tente pôr no carrinho.'],
  'e':'Aparece esgotado e não entra no carrinho.','reg':True,'eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'29.4','t':'Complementos','passos':[
   'Escolha um produto com grupos.','Tente avançar sem o mínimo.','Tente passar do máximo.'],
  'e':'Mínimo e máximo respeitados, e o preço sobe conforme a escolha.','eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'29.5','t':'Taxa por bairro','passos':['Escolha entrega.','Troque o bairro.','Troque de novo.'],
  'e':'A taxa muda conforme o cadastro de cada bairro.','eps':['POST /public/loja/{lojaId}/pedido']},
 {'id':'29.6','t':'Retirada no balcão','passos':['Escolha RETIRADA.','Feche o pedido.','Veja no painel.'],
  'e':'Não pede endereço nem cobra taxa, e o pedido entra marcado como retirada.','reg':True,'eps':['POST /public/loja/{lojaId}/pedido']},
 {'id':'29.7','t':'Entrega exige endereço','passos':[
   'Escolha entrega.','Tente fechar com o endereço vazio.','Tente com "Rua" só.'],
  'e':'Recusa nos dois, com explicação.','reg':True,'eps':['POST /public/loja/{lojaId}/pedido']},
 {'id':'29.8','t':'Endereço muito longo','passos':[
   'Cole um endereço com mais de 500 caracteres.','Feche o pedido.',
   'Veja o pedido no painel.','Veja o log do servidor.'],
  'e':'O pedido ENTRA, o endereço é cortado, e o log avisa que foi cortado.',
  'f':'Antes o pedido inteiro se perdia por causa do tamanho da coluna.','reg':True,'eps':['POST /public/loja/{lojaId}/pedido']},
 {'id':'29.9','t':'Forma de pagamento na entrega','passos':[
   'Escolha "pagar na entrega".','Veja as opções oferecidas.','Escolha DINHEIRO e feche.',
   'Abra o pedido no painel.'],
  'e':'Pergunta dinheiro ou cartão, e grava qual foi.',
  'f':'Gravava só "Na entrega" e o acerto do motoboy nunca sabia o que era dinheiro vivo.','reg':True,'eps':['POST /public/loja/{lojaId}/pedido']},
 {'id':'29.10','t':'Cupom','passos':['Use um cupom válido.','Use um vencido.','Use um que não existe.'],
  'e':'O válido desconta; os outros recusam com o motivo certo.','eps':['GET /public/loja/{lojaId}/cupom/{codigo}']},
 {'id':'29.11','t':'Cashback no cardápio','passos':[
   'Com um cliente que tem saldo, informe o telefone dele e um nome ERRADO.',
   'Agora informe o telefone e o primeiro nome CERTO.'],
  'e':'Com o nome errado não libera. Com o certo mostra o saldo e deixa abater.',
  'f':'Telefone de cliente não é segredo — só com ele, qualquer um gastaria o cashback do vizinho.','reg':True,'eps':['GET /public/loja/{lojaId}/cashback']},
 {'id':'29.12','t':'Loja fechada','passos':['Marque hoje como fechado em Ajustes.','Abra o cardápio.'],
  'e':'Mostra fechada e não deixa pedir.','eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'29.13','t':'Loja suspensa some inteira','passos':[
   'Suspenda a loja pela Plataforma.','Abra o cardápio.',
   'Abra o endereço da logo.','Abra o endereço da foto de um produto.'],
  'e':'Os três respondem 404. Nada de meia página.','reg':True,'eps':['GET /public/loja/{lojaId}/{qual:logo|banner}','GET /public/loja/{lojaId}/produto/{produtoId}/imagem']},
 {'id':'29.14','t':'Acompanhar o pedido','passos':[
   'Depois de fechar, siga o link de acompanhamento.',
   'Na barra de endereço, troque o número do pedido por outro.'],
  'e':'Mostra o status do seu; o de outro não abre.',
  'f':'Sem assinatura no link, dava para varrer os pedidos da loja pelo id sequencial.','reg':True,'eps':['GET /public/loja/{lojaId}/pedido/{pedidoId}/status']},
 {'id':'29.15','t':'Repetir pedido','passos':[
   'Use o link de repetir de um pedido seu.','Troque o id da loja na URL e tente de novo.'],
  'e':'O seu monta o carrinho; o de outra loja não funciona.','eps':['GET /public/loja/{lojaId}/pedido/{pedidoId}/repetir']},
 {'id':'29.16','t':'Freio do cardápio','passos':['Feche muitos pedidos seguidos do mesmo navegador.'],
  'e':'Passa a recusar depois de alguns, com mensagem.','eps':['POST /public/loja/{lojaId}/pedido']},
]},

{'n':'30','t':'Entradas automáticas (webhooks)','tela':'(sem tela)','r':'O que chega de fora sem ninguém clicar. Precisa de Postman ou curl.','testes':[
 {'id':'30.1','t':'Webhook do Asaas da plataforma','passos':[
   'Monte um corpo de evento <code>PAYMENT_RECEIVED</code> da assinatura.',
   'Mande <code>POST /public/asaas-webhook</code> com o token certo.',
   'Veja o status da assinatura e o acesso da loja.'],
  'e':'A assinatura muda de estado e o acesso acompanha.','eps':['POST /public/asaas-webhook']},
 {'id':'30.2','t':'Webhook do Asaas sem token','passos':['Mande o mesmo corpo sem token.','Mande com um token errado.'],
  'e':'Recusa nos dois.','reg':True,'eps':['POST /public/asaas-webhook']},
 {'id':'30.3','t':'PIX do lojista confirma o pedido','passos':[
   'Gere um PIX pelo cardápio e copie o id do pagamento.',
   'Mande <code>POST /public/pix-webhook/{lojaId}</code> com esse id.',
   'Veja o pedido no painel.'],
  'e':'Deixa de esperar pagamento e entra no faturamento.','eps':['POST /public/pix-webhook/{lojaId}']},
 {'id':'30.4','t':'PIX sem pedido deixa rastro','passos':[
   'Mande o mesmo webhook com um id de pagamento INVENTADO.',
   'Olhe o log de auditoria do servidor.'],
  'e':'Responde 200, e grava no log a loja, o id do pagamento e o valor.',
  'f':'Dinheiro entrava na conta do lojista e não havia rastro nenhum para conciliar depois.','reg':True,'eps':['POST /public/pix-webhook/{lojaId}']},
 {'id':'30.5','t':'Pedido novo da 99 (Open Delivery)','passos':[
   'Mande um evento <code>CREATED</code> em <code>/public/opendelivery/v1/newEvent</code>.','Abra o painel.'],
  'e':'O pedido entra no painel.','eps':['POST /public/opendelivery/v1/newEvent']},
 {'id':'30.6','t':'Rastreio da 99','passos':[
   'Mande <code>PICKED_UP</code> no trackingEvent.','Depois mande <code>DELIVERED</code>.',
   'Veja o pedido no painel.'],
  'e':'O pedido avança aqui sem ninguém clicar.','reg':True,'eps':['POST /public/opendelivery/v1/trackingEvent']},
 {'id':'30.7','t':'Webhook genérico de canal','passos':[
   'Mande <code>POST /webhooks/{canal}</code> com o token certo.','Repita sem token.'],
  'e':'Com token aceita; sem token recusa.','reg':True,'eps':['POST /webhooks/{canal}']},
 {'id':'30.8','t':'Saúde da API','passos':[
   'Sem estar logado, chame <code>GET /actuator/health</code>.',
   'Chame <code>GET /actuator/health/viva</code>.',
   'Agora chame <code>GET /api/health</code>, também sem login.'],
  'e':'Os dois do actuator respondem 200 (o <code>viva</code> olha só o processo). '
      'O <code>/api/health</code> responde <b>401</b>: ele não é público, e é isso mesmo.',
  'f':'Eu já apontei este item para /api/health como se fosse o endereço público. Não é — quem '
      'está no permitAll é o actuator. Monitoramento que apontar para /api/health vai ver 401 '
      'para sempre e achar que a API caiu.','reg':True,'eps':['GET /api/health']},
]},

{'n':'31','t':'Ajuda, guia e respostas prontas','tela':'ajuda.html · guia-zira.html · respostas-whatsapp.html','r':'As telas de apoio. Ninguém testa, e são as que o lojista abre quando está perdido.','testes':[
 {'id':'31.1','t':'Ajuda abre e explica','passos':['Abra <b>Ajuda</b> no menu.'],
  'e':'Explica as telas, mostra a versão dos termos e o contato do suporte.','eps':['GET /api/termos']},
 {'id':'31.2','t':'Guia de operação','passos':['Abra <code>/guia-zira.html</code>.','Role até o fim.','Use a simulação.'],
  'e':'Carrega inteiro, com as telas desenhadas e o passo a passo funcionando.','eps':['GET /']},
 {'id':'31.3','t':'O guia não pede login','passos':['Abra o guia numa aba anônima.'],
  'e':'Abre — é feito para mandar para a equipe da loja.','eps':['GET /']},
 {'id':'31.4','t':'Respostas prontas','passos':['Abra <b>Respostas WhatsApp</b>.','Copie uma resposta.','Cole num bloco de notas.'],
  'e':'O texto traz o link do cardápio e o horário certos DESTA loja.','eps':['GET /api/horarios']},
 {'id':'31.5','t':'A resposta reflete a loja','passos':['Mude o horário em Ajustes.','Volte e copie de novo.'],
  'e':'O texto muda junto.','eps':['GET /public/loja/{lojaId}/cardapio']},
]},

{'n':'32','t':'Celular','tela':'todas','r':'A loja opera no celular. Testar em aparelho de verdade, não no emulador.','testes':[
 {'id':'32.1','t':'Nenhuma tela rola de lado','passos':[
   'No celular, abra uma a uma: Dashboard, Pedidos, PDV, KDS, Entregas, Entregadores, Acerto, Caixa, Produtos, Estoque, Insumos, Clientes, Promoções, Relatórios.',
   'Em cada uma, tente arrastar a PÁGINA para o lado.'],
  'e':'Nenhuma rola horizontalmente.',
  'f':'Em Relatórios, a página tinha 495px de largura dentro de uma tela de 375.','reg':True,'eps':['GET /api/relatorios']},
 {'id':'32.2','t':'Grade vira uma coluna','passos':['Abra Relatórios, Dashboard e Desempenho no celular.'],
  'e':'Os blocos ficam um embaixo do outro, nunca dois ao lado espremidos.','reg':True,'eps':['GET /api/desempenho']},
 {'id':'32.3','t':'Tabela rola dentro do cartão','passos':[
   'Abra Entregas e Relatórios no celular.','Arraste a TABELA para o lado.'],
  'e':'A tabela rola sozinha e a página fica parada.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'32.4','t':'Botão dá para acertar com o dedo','passos':['Use os botões do KDS e de Entregas só com o polegar.'],
  'e':'Acerta sem precisar ampliar a tela.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'32.5','t':'Menu inferior','passos':['Role uma tela longa até o fim.'],
  'e':'O menu fica acessível e não cobre conteúdo.','eps':['GET /api/pedidos/board']},
 {'id':'32.6','t':'Pedir pelo celular','passos':[
   'Como cliente, abra o cardápio no celular.','Monte o pedido.','Preencha o endereço.','Pague.'],
  'e':'Dá para fazer tudo sem ampliar nada e sem teclado cobrindo o campo.','eps':['POST /public/loja/{lojaId}/pedido']},
 {'id':'32.7','t':'Ajuda e guia no celular','passos':['Abra Ajuda no celular.','Abra o guia de operação no celular.'],
  'e':'Leem bem, sem rolagem lateral.','eps':['GET /api/termos']},
]},
]
