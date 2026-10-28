# -*- coding: utf-8 -*-
"""Roteiro, parte A: entrada, operacao do dia e dinheiro.
`passos` = o passo a passo de execucao. `e` = o que tem que acontecer. `eps` = endpoints exercitados."""

PARTE_A = [
{'n':'1','t':'Entrar, sair e trocar de loja','tela':'login.html · cadastro.html · index.html','r':'A porta de entrada. Testar com os quatro papéis.','testes':[
 {'id':'1.1','t':'Abrir a página inicial','passos':[
   'Abra o navegador numa aba anônima.',
   'Digite <code>borahapp.com.br</code> e aperte Enter.'],
  'e':'A página carrega e leva ao login ou ao cadastro, sem erro no console.','eps':['GET /']},
 {'id':'1.2','t':'Entrar com senha certa','passos':[
   'Em <code>/login.html</code>, digite o e-mail da conta de loja.',
   'Digite a senha.',
   'Clique em <b>Entrar</b>.'],
  'e':'Entra e cai no Dashboard, com o nome da loja no topo e o menu lateral do papel.','eps':['POST /auth/login']},
 {'id':'1.3','t':'Senha errada','passos':[
   'Na tela de login, digite um e-mail que existe.',
   'Digite uma senha qualquer, errada.',
   'Clique em <b>Entrar</b> e leia a mensagem.'],
  'e':'Mensagem clara de credencial inválida. Não diz se o e-mail existe ou não.',
  'f':'Resposta diferente para e-mail que existe entrega quais endereços são clientes.','eps':['POST /auth/login']},
 {'id':'1.4','t':'Freio de tentativas','passos':[
   'Com o mesmo e-mail, erre a senha seis vezes seguidas.',
   'Na sétima, digite a senha CERTA.'],
  'e':'Mesmo com a senha certa, recusa por alguns minutos. Depois do tempo, volta a aceitar.','reg':True,'eps':['POST /auth/login']},
 {'id':'1.5','t':'O freio não confia no cabeçalho do cliente','passos':[
   'Abra uma ferramenta de requisição (Postman ou curl).',
   'Mande <code>POST /auth/login</code> com senha errada seis vezes.',
   'Em cada tentativa, mande um <code>X-Forwarded-For</code> diferente (1.1.1.1, 2.2.2.2…).',
   'Na sétima, mande a senha certa.'],
  'e':'O freio continua valendo: a sétima também é recusada.',
  'f':'Se zerar, qualquer um desliga o freio só mudando um cabeçalho — e volta a testar senha em massa.','reg':True,'eps':['POST /auth/login']},
 {'id':'1.6','t':'Quem sou eu','passos':[
   'Depois de entrar, olhe o topo do painel.',
   'Abra o menu do usuário.'],
  'e':'Nome, papel e loja batem com a conta usada.','eps':['GET /auth/me']},
 {'id':'1.7','t':'Trocar a própria senha','passos':[
   'Na tela de login, clique em <b>Trocar minha senha</b>.',
   'Informe e-mail, senha atual e a nova senha.',
   'Confirme, saia e entre com a senha nova.'],
  'e':'Troca, e a senha nova funciona na entrada seguinte.','eps':['POST /auth/trocar-senha']},
 {'id':'1.8','t':'Esqueci minha senha','passos':[
   'Na tela de login, clique em <b>Esqueci minha senha</b>.',
   'Peça para um e-mail que EXISTE e anote a resposta.',
   'Peça para um e-mail que NÃO existe e compare.'],
  'e':'A mesma resposta nos dois casos. Quem existe recebe o pedido registrado.',
  'f':'Resposta diferente entrega quais e-mails são clientes.','eps':['POST /auth/pedido-de-senha']},
 {'id':'1.9','t':'Trocar de loja','passos':[
   'Entre com um usuário ligado a duas lojas.',
   'Clique no nome da loja no topo.',
   'Escolha a outra loja.',
   'Abra Pedidos e Produtos.'],
  'e':'Todas as telas passam a mostrar a loja escolhida.','eps':['POST /auth/trocar-loja']},
 {'id':'1.10','t':'Sair','passos':[
   'Clique em <b>Sair</b>.',
   'Aperte a seta de voltar do navegador.'],
  'e':'Volta ao login, e voltar no navegador não devolve o painel.','eps':['POST /auth/login']},
 {'id':'1.11','t':'Cadastro pelo site','passos':[
   'Abra <code>/cadastro.html</code>.',
   'Preencha empresa, CNPJ, nome da loja, seu nome, e-mail e senha.',
   'Envie.',
   'Depois de entrar, abra Planos.'],
  'e':'Cria, entra direto, e a loja nasce com os 7 dias de cortesia que o site anuncia.','reg':True,'eps':['POST /public/signup']},
 {'id':'1.12','t':'Cadastro com CNPJ repetido','passos':[
   'Repita o cadastro com o MESMO documento.'],
  'e':'Recusa com explicação, em vez de criar a segunda empresa.','eps':['POST /public/signup']},
 {'id':'1.13','t':'Sessão de outra loja','passos':[
   'Logado na loja A, abra um pedido e copie o número dele da URL.',
   'Saia e entre na loja B.',
   'Cole o endereço do pedido da loja A.'],
  'e':'Não encontra. Nenhum dado da loja A aparece.',
  'f':'Vazamento entre lojas é o pior defeito possível neste sistema.','eps':['GET /api/pedidos/{id}/itens']},
]},

{'n':'2','t':'Termos e primeiro acesso','tela':'(aparece sobre qualquer tela)','r':'O que acontece antes de o lojista poder usar.','testes':[
 {'id':'2.1','t':'Ver a versão dos termos','passos':[
   'Entre com uma conta que já aceitou.',
   'Abra <b>Ajuda</b> no menu e procure a versão dos termos.'],
  'e':'Não pede aceite nenhum, e a versão vigente aparece.','eps':['GET /api/termos']},
 {'id':'2.2','t':'Aceitar os termos','passos':[
   'Entre com uma conta que ainda não aceitou a versão atual.',
   'Leia a tela que aparece e clique em aceitar.',
   'Recarregue o painel.'],
  'e':'Pede o aceite antes de liberar, registra a versão, e não pede de novo.','eps':['POST /api/termos/aceitar']},
 {'id':'2.3','t':'Loja vencida ainda aceita','passos':[
   'Numa loja com acesso vencido, entre no painel.',
   'Aceite os termos na tela que aparecer.'],
  'e':'O aceite funciona mesmo com a loja bloqueada.',
  'f':'Se bloquear, o lojista não consegue regularizar nada — fica preso sem saída.','reg':True,'eps':['POST /api/termos/aceitar']},
 {'id':'2.4','t':'Passo a passo do começo','passos':[
   'Crie uma loja nova (ou use uma sem cadastros).',
   'Entre e abra o Dashboard.'],
  'e':'Mostra o que falta: cadastrar produto, horário, taxa e forma de pagamento.','eps':['GET /api/onboarding']},
 {'id':'2.5','t':'O passo a passo some quando termina','passos':[
   'Cumpra os passos listados.',
   'Volte ao Dashboard e recarregue.'],
  'e':'O bloco de primeiros passos desaparece.','eps':['GET /api/onboarding']},
]},

{'n':'3','t':'Dashboard','tela':'dashboard.html','r':'A primeira tela. Resumo do dia e termômetro.','testes':[
 {'id':'3.1','t':'Resumo do dia','passos':[
   'Faça duas ou três vendas.',
   'Abra <b>Dashboard</b>.'],
  'e':'Pedidos por status, faturamento do dia e a lista dos últimos pedidos.','eps':['GET /api/dashboard/resumo','GET /api/pedidos/board']},
 {'id':'3.2','t':'Faturamento bate com o Caixa','passos':[
   'Anote o faturamento do Dashboard.',
   'Abra <b>Fechar Caixa</b> e compare.'],
  'e':'O mesmo número nas duas telas.',
  'f':'As duas usavam regras diferentes: R$ 80 numa e R$ 30 na outra, no mesmo dia, para os mesmos pedidos.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'3.3','t':'Termômetro para quem pode','passos':[
   'Entre como GERENTE e abra o Dashboard.',
   'Repita como ADMINISTRADOR_LOJA.'],
  'e':'O painel "Termômetro de Vendas" aparece, com as últimas 24h e a média esperada.','eps':['GET /api/vendas/termometro']},
 {'id':'3.4','t':'Operador não vê o termômetro','passos':[
   'Entre como OPERADOR.',
   'Abra o Dashboard e role a tela.',
   'Aperte F12 e olhe a aba Console e a aba Rede.'],
  'e':'O painel do termômetro não aparece, nenhum erro no console, e nenhuma chamada a <code>/api/vendas/termometro</code>.',
  'f':'Mostrava o faturamento em reais das últimas 24h para quem atende o balcão.','reg':True,'eps':['GET /api/vendas/termometro']},
 {'id':'3.5','t':'Promoção relâmpago pelo Dashboard','passos':[
   'Com o termômetro em ATENÇÃO ou QUEDA, clique em <b>Abrir promoção relâmpago</b>.',
   'Confirme.',
   'Abra o cardápio público e teste o código.'],
  'e':'Cria a promoção e ela passa a valer no cardápio.','eps':['POST /api/promocoes']},
 {'id':'3.6','t':'Aviso de sem conexão','passos':[
   'Com o Dashboard aberto, aperte F12 → aba Rede → modo <b>Offline</b>.',
   'Espere a próxima atualização automática.'],
  'e':'Aparece a faixa de "sem conexão" com a hora. Os números não ficam congelados fingindo estar certos.','reg':True,'eps':['GET /api/dashboard/resumo']},
 {'id':'3.7','t':'Dia sem pedido','passos':[
   'Abra o Dashboard num dia sem nenhuma venda (ou numa loja nova).'],
  'e':'Diz "nenhum pedido ainda hoje" em vez de tabela vazia.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'3.8','t':'Repetir um pedido da lista','passos':[
   'Na lista de últimos pedidos, use o atalho de repetir.',
   'Siga o link.'],
  'e':'Abre o cardápio com o carrinho já montado.','eps':['GET /public/loja/{lojaId}/pedido/{pedidoId}/repetir']},
]},

{'n':'4','t':'Pedidos','tela':'pedidos.html','r':'A lista e o fluxo de status.','testes':[
 {'id':'4.1','t':'Lista e filtros','passos':[
   'Abra <b>Pedidos</b>.',
   'Filtre por status (ex.: Em preparo).',
   'Filtre por canal (ex.: iFood).'],
  'e':'Os filtros batem com o que a lista mostra.','eps':['GET /api/pedidos','GET /api/pedidos/board']},
 {'id':'4.2','t':'Ver os itens do pedido','passos':[
   'Clique num pedido da lista.'],
  'e':'Itens, quantidades, complementos e observação.','eps':['GET /api/pedidos/{id}/itens']},
 {'id':'4.3','t':'Aceitar e recusar','passos':[
   'Num pedido novo, clique em <b>Aceitar</b>.',
   'Noutro pedido novo, clique em <b>Recusar</b> e escolha o motivo.'],
  'e':'O aceite avança o status; a recusa cancela com o motivo escolhido.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'4.4','t':'O status só anda para frente','passos':[
   'Pegue um pedido em SAIU_PARA_ENTREGA.',
   'Tente mudar para EM_PREPARO.'],
  'e':'Recusa com explicação de que o pedido já passou dessa etapa.',
  'f':'Uma aba antiga re-clicando mandava "está sendo preparado" ao cliente depois do motoboy ter saído.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'4.5','t':'Pular etapa é permitido','passos':[
   'Num pedido RECEBIDO, vá direto para EM_PREPARO.'],
  'e':'Funciona — nem toda loja usa a etapa de confirmação.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'4.6','t':'Estado final é final','passos':[
   'Num pedido ENTREGUE, tente mudar o status.',
   'Repita num CANCELADO.'],
  'e':'Recusa nos dois.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'4.7','t':'Cancelar exige motivo','passos':[
   'Cancele um pedido deixando o motivo em branco.',
   'Cancele de novo escrevendo um motivo.'],
  'e':'Sem motivo recusa; com motivo cancela.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'4.8','t':'O motivo vai inteiro ao cliente','passos':[
   'Cancele um pedido feito por um cliente com WhatsApp.',
   'Escreva um motivo reconhecível.',
   'Veja a mensagem que chegou ao cliente e a tela de acompanhar.'],
  'e':'O texto que você digitou aparece para ele, e a tela avisa isso ANTES de confirmar.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'4.9','t':'Cancelar devolve estoque e cashback','passos':[
   'Anote o estoque de um produto e o saldo de um cliente.',
   'Faça um pedido para esse cliente usando o saldo.',
   'Cancele o pedido.',
   'Confira estoque e saldo de novo.'],
  'e':'Os dois voltam ao valor anterior.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'4.10','t':'Excluir é de gerente para cima','passos':[
   'Entre como OPERADOR.',
   'Tente excluir um pedido.'],
  'e':'Recusa.','eps':['DELETE /api/pedidos/{id}']},
 {'id':'4.11','t':'Excluir devolve o dinheiro uma vez só','passos':[
   'Como gerente, pegue um pedido pago que usou cashback.',
   'Cancele primeiro (o que já devolve).',
   'Agora exclua.',
   'Confira o saldo do cliente.'],
  'e':'Devolve o que precisa, e NÃO devolve duas vezes.','reg':True,'eps':['DELETE /api/pedidos/{id}']},
 {'id':'4.12','t':'Histórico do pedido','passos':[
   'Pegue um pedido que passou por vários status.',
   'Abra o histórico dele.'],
  'e':'Cada mudança com hora e autor (ou "marketplace" quando veio de fora).','eps':['GET /api/pedidos/{id}/historico']},
 {'id':'4.13','t':'Imprimir comanda','passos':[
   'Ligue o bloqueador de pop-up do navegador.',
   'Clique em imprimir a comanda de um pedido.'],
  'e':'Avisa que o pop-up foi bloqueado, em vez de não fazer nada.','reg':True,'eps':['GET /api/pedidos/{id}/itens']},
 {'id':'4.14','t':'Atualizar a lista','passos':[
   'Com Pedidos aberto, feche um pedido noutra aba.',
   'Clique em atualizar.'],
  'e':'O pedido novo aparece sem recarregar a página.','eps':['GET /api/pedidos/board']},
]},

{'n':'5','t':'Frente de Caixa (PDV)','tela':'pdv.html','r':'Venda no balcão. A tela que o operador usa o dia todo.','testes':[
 {'id':'5.1','t':'Vender no balcão','passos':[
   'Abra <b>Frente de Caixa</b>.',
   'Clique em dois produtos para somar ao carrinho.',
   'Escolha a forma de pagamento.',
   'Clique em <b>Fechar pedido</b>.',
   'Abra Pedidos e o KDS.'],
  'e':'O pedido aparece nas duas telas na hora.','eps':['POST /api/pedidos','GET /api/produtos']},
 {'id':'5.2','t':'Somar e tirar item','passos':[
   'Com itens no carrinho, use <b>+</b> e <b>−</b>.',
   'Remova um item.'],
  'e':'O total acompanha cada mudança.','eps':['GET /api/produtos']},
 {'id':'5.3','t':'Complementos no balcão','passos':[
   'Clique num produto que tenha grupo de complementos.',
   'Tente fechar sem escolher o mínimo.',
   'Escolha além do máximo.',
   'Escolha dentro da regra e some ao carrinho.'],
  'e':'Respeita mínimo e máximo, e o preço sobe conforme a escolha.','eps':['GET /api/produtos/{produtoId}/complementos']},
 {'id':'5.4','t':'Complemento que não carrega','passos':[
   'Aperte F12 → aba Rede → modo <b>Offline</b>.',
   'Clique num produto com complementos.',
   'Volte a rede e tente de novo.'],
  'e':'Avisa que não carregou. NÃO vende pelo preço base como se o produto não tivesse complemento.',
  'f':'O produto passava a vender mais barato até alguém recarregar a página.','reg':True,'eps':['GET /api/produtos/{produtoId}/complementos']},
 {'id':'5.5','t':'Operador não recebe custo','passos':[
   'Entre como OPERADOR.',
   'Abra Frente de Caixa.',
   'Aperte F12 → aba Rede.',
   'Recarregue e clique na chamada <code>/api/produtos</code>.',
   'Olhe a aba Resposta.'],
  'e':'O campo de custo vem vazio. Nome, preço e estoque vêm normais.',
  'f':'Com o custo de cada produto dá para calcular a margem da loja inteira.','reg':True,'eps':['GET /api/produtos']},
 {'id':'5.6','t':'Tipo de entrega no balcão','passos':[
   'Feche um pedido pelo PDV.',
   'Abra Entregas.'],
  'e':'O pedido nasce como retirada/balcão e NÃO aparece na rota de entrega.',
  'f':'Todo pedido de balcão virava entrega e entrava na rota do motoboy.','reg':True,'eps':['POST /api/pedidos']},
 {'id':'5.7','t':'Escolher forma de pagamento','passos':[
   'Feche um pedido em DINHEIRO.',
   'Outro em CARTÃO.',
   'Outro em PIX.',
   'Abra Fechar Caixa e veja a quebra por forma.'],
  'e':'Cada um grava a forma certa e aparece na quebra.','eps':['GET /api/formas-pagamento']},
 {'id':'5.8','t':'Identificar o cliente','passos':[
   'No PDV, busque um cliente pelo telefone.',
   'Feche o pedido no nome dele.',
   'Abra Clientes e veja o saldo.'],
  'e':'O pedido fica ligado ao cadastro e o cashback acumula.','eps':['GET /api/clientes']},
 {'id':'5.9','t':'Estoque baixa na venda','passos':[
   'Anote o estoque de um produto em Estoque.',
   'Venda 2 unidades dele no PDV.',
   'Volte a Estoque.'],
  'e':'Baixou exatamente 2.','eps':['POST /api/pedidos']},
 {'id':'5.10','t':'Venda sem estoque','passos':[
   'Zere o estoque de um produto.',
   'Venda ele pelo balcão.',
   'Confira o saldo e o log do servidor.'],
  'e':'A venda acontece (o produto está na mão do cliente), o estoque fica negativo e há aviso no log.','reg':True,'eps':['POST /api/pedidos']},
 {'id':'5.11','t':'Avançar o pedido pelo PDV','passos':[
   'Depois de fechar, use o atalho de mudar status no PDV.',
   'Confira em Pedidos e no KDS.'],
  'e':'Reflete nas três telas.','eps':['PATCH /api/pedidos/{id}/status']},
]},

{'n':'6','t':'Novo pedido (balcão com entrega)','tela':'novo-pedido.html','r':'O pedido que o atendente digita por telefone.','testes':[
 {'id':'6.1','t':'Montar pedido com entrega','passos':[
   'Abra <b>Novo pedido</b>.',
   'Escolha o cliente.',
   'Preencha o endereço e escolha o bairro.',
   'Some dois produtos e feche.'],
  'e':'A taxa do bairro entra no total.','eps':['POST /api/pedidos','GET /api/taxas']},
 {'id':'6.2','t':'Cliente novo na hora','passos':[
   'Na busca de cliente, use a opção de cadastrar.',
   'Preencha nome e telefone.',
   'Continue o pedido com ele.'],
  'e':'Cria e já usa no pedido, sem sair da tela.','eps':['POST /api/clientes']},
 {'id':'6.3','t':'Complementos','passos':[
   'Adicione um produto com complementos.',
   'Escolha as opções.'],
  'e':'O preço do item acompanha.','eps':['GET /api/produtos/{produtoId}/complementos']},
 {'id':'6.4','t':'Remover item','passos':[
   'Remova um item do carrinho.'],
  'e':'O total acompanha.','eps':['GET /api/produtos']},
 {'id':'6.5','t':'O endereço fica no pedido','passos':[
   'Escolha um cliente com endereço cadastrado.',
   'Digite um endereço DIFERENTE neste pedido.',
   'Feche e abra o pedido em Entregas.'],
  'e':'Mostra o endereço informado agora, não o do cadastro.','reg':True,'eps':['POST /api/pedidos']},
]},

{'n':'7','t':'KDS da cozinha','tela':'kds.html','r':'A tela da parede. Quem monta o pedido lê daqui.','testes':[
 {'id':'7.1','t':'O pedido aparece sozinho','passos':[
   'Abra o <b>KDS</b> numa tela.',
   'Noutra aba, feche um pedido no PDV.',
   'Volte ao KDS SEM recarregar.'],
  'e':'O pedido aparece sozinho.','eps':['GET /api/pedidos/board']},
 {'id':'7.2','t':'A cozinha vê a observação','passos':[
   'Faça um pedido escrevendo "sem cebola" na observação.',
   'Veja o cartão dele no KDS.'],
  'e':'A observação aparece no cartão.',
  'f':'O dado chegava no navegador e o cartão não desenhava — "sem cebola" nunca chegava em quem monta.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'7.3','t':'Retirada não oferece despachar','passos':[
   'Faça um pedido de RETIRADA pelo cardápio.',
   'Veja o cartão no KDS e olhe os botões.'],
  'e':'Mostra que é retirada e NÃO oferece "Despachar".',
  'f':'O cliente está no balcão e recebia "saiu para entrega" no WhatsApp.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'7.4','t':'Avançar pelo KDS','passos':[
   'Clique no botão de avançar do cartão.',
   'Confira em Pedidos.',
   'Veja o WhatsApp do cliente.'],
  'e':'Muda nas duas telas e o cliente recebe o aviso da etapa.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'7.5','t':'O relógio do card','passos':[
   'Deixe um pedido parado mais tempo que o limite da etapa.',
   'Olhe o cartão.'],
  'e':'Destaca o atraso, para a cozinha ver de longe.','eps':['GET /api/pedidos/board']},
 {'id':'7.6','t':'Duas pessoas no mesmo pedido','passos':[
   'Abra o KDS em duas abas.',
   'Clique em avançar o MESMO pedido nas duas, quase ao mesmo tempo.'],
  'e':'A segunda recebe recusa clara, não um erro solto.','eps':['PATCH /api/pedidos/{id}/status']},
]},

{'n':'8','t':'Entregas','tela':'entregas.html','r':'A rota, o motoboy e o despacho.','testes':[
 {'id':'8.1','t':'Agrupar por bairro','passos':[
   'Faça pedidos de bairros diferentes pelo cardápio.',
   'Leve os três até PRONTO.',
   'Abra <b>Entregas</b>.'],
  'e':'Agrupa pelo bairro DO PEDIDO, e nenhum cai em "Sem bairro".',
  'f':'Usava o bairro do cadastro, e pedido do cardápio caía todo em "Sem bairro".','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'8.2','t':'O endereço é o do pedido','passos':[
   'Pegue um cliente que tenha endereço antigo no cadastro.',
   'Faça um pedido novo com endereço diferente.',
   'Veja os dois pedidos em Entregas.'],
  'e':'Cada um mostra o endereço daquele pedido.',
  'f':'Mostrava o do cadastro — entregar no lugar errado era questão de a pessoa ter se mudado.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'8.3','t':'Despachar um pedido','passos':[
   'Clique em <b>Despachar</b> num pedido.',
   'Veja o status e o WhatsApp do cliente.'],
  'e':'Vai para SAIU_PARA_ENTREGA e o cliente é avisado.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'8.4','t':'Despachar o bairro pergunta antes','passos':[
   'Num bairro com três pedidos prontos, clique em despachar o bairro.',
   'Leia a pergunta antes de confirmar.'],
  'e':'Pergunta dizendo quantos pedidos são e que cada um avisa o cliente no WhatsApp.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'8.5','t':'Falha no lote aparece','passos':[
   'Num bairro com três pedidos, marque um deles como ENTREGUE noutra aba.',
   'Despache o bairro.'],
  'e':'Diz quantos saíram e QUAIS não saíram.',
  'f':'Um catch vazio engolia a falha e o lojista achava que todos tinham saído.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'8.6','t':'Escolher o motoboy','passos':[
   'No seletor do pedido, escolha um entregador.',
   'Recarregue a tela.'],
  'e':'Grava e continua aparecendo.','eps':['PATCH /api/pedidos/{id}/entregador','GET /api/entregadores']},
 {'id':'8.7','t':'Trocar motoboy de pedido entregue','passos':[
   'Entre como OPERADOR.',
   'Num pedido já ENTREGUE, tente trocar o entregador.',
   'Repita como GERENTE e veja o log do servidor.'],
  'e':'Operador recusa; gerente consegue, e a troca fica no log de auditoria.',
  'f':'Qualquer um trocava, com texto livre, sem registro nenhum.','reg':True,'eps':['PATCH /api/pedidos/{id}/entregador']},
 {'id':'8.8','t':'Motoboy de pedido já acertado','passos':[
   'Feche um acerto que inclua um pedido.',
   'Tente trocar o entregador desse pedido.'],
  'e':'Recusa.',
  'f':'Mudaria quanto o motoboy tinha a receber depois de ele já ter recebido.','reg':True,'eps':['PATCH /api/pedidos/{id}/entregador']},
 {'id':'8.9','t':'Marcar como entregue','passos':[
   'Clique em <b>Entregue</b>.'],
  'e':'Sai da rota e entra no histórico.','eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'8.10','t':'Resumo da operação','passos':[
   'Olhe o resumo no topo de Entregas.'],
  'e':'Em preparo, saiu para entrega e entregues na última hora, coerentes com a lista.','eps':['GET /api/dashboard/resumo']},
 {'id':'8.11','t':'Tabela larga no celular','passos':[
   'Abra Entregas num celular de verdade.',
   'Role a tabela para o lado.',
   'Role a página para o lado.'],
  'e':'A tabela rola dentro do cartão; a PÁGINA não rola de lado.','reg':True,'eps':['GET /api/pedidos/board']},
]},

{'n':'9','t':'Entregadores','tela':'entregadores.html','r':'O cadastro de quem entrega.','testes':[
 {'id':'9.1','t':'Listar','passos':['Abra <b>Entregadores</b>.'],
  'e':'Lista com nome, telefone e situação.','eps':['GET /api/entregadores']},
 {'id':'9.2','t':'Criar','passos':[
   'Clique em novo entregador.',
   'Preencha nome e telefone e salve.',
   'Abra Entregas e olhe o seletor.'],
  'e':'Aparece na lista e na escolha do pedido.','eps':['POST /api/entregadores']},
 {'id':'9.3','t':'Editar','passos':[
   'Clique em editar um entregador.',
   'Mude o nome e o telefone e salve.'],
  'e':'Salva e a lista reflete.','eps':['PUT /api/entregadores/{id}']},
 {'id':'9.4','t':'Desativar não volta sozinho','passos':[
   'Desative um entregador.',
   'Clique em editar ele e mude só o telefone.',
   'Salve e recarregue.'],
  'e':'Continua desativado e some da escolha em Entregas.',
  'f':'A tela mandava "ativo: true" fixo e religava quem tinha sido desligado.','reg':True,'eps':['PUT /api/entregadores/{id}']},
 {'id':'9.5','t':'Excluir','passos':[
   'Exclua um entregador que nunca teve entrega.'],
  'e':'Sai da lista.','eps':['DELETE /api/entregadores/{id}']},
 {'id':'9.6','t':'Entregas do dia por entregador','passos':[
   'Atribua dois pedidos a um entregador.',
   'Veja a contagem dele na tela.'],
  'e':'Bate com os pedidos atribuídos.','eps':['GET /api/pedidos/board']},
]},

{'n':'10','t':'Acerto do motoboy','tela':'acerto-entregadores.html','r':'Quanto o entregador recebe e quanto de dinheiro traz de volta.','testes':[
 {'id':'10.1','t':'Prévia do acerto','passos':[
   'Com entregas concluídas no dia, abra <b>Acerto Motoboy</b>.',
   'Escolha o entregador.'],
  'e':'Lista as entregas, o valor das taxas e quanto ele recebeu em dinheiro.','eps':['GET /api/acertos/previa']},
 {'id':'10.2','t':'Dinheiro vivo bate','passos':[
   'Pelo cardápio, faça um pedido em DINHEIRO na entrega.',
   'Faça outro em CARTÃO na entrega.',
   'Marque os dois como entregues pelo mesmo motoboy.',
   'Abra a prévia.'],
  'e':'Só o de dinheiro entra em "recebeu dinheiro".',
  'f':'Era R$ 0,00 para todo pedido do cardápio, porque o texto gravado era sempre "Na entrega".','reg':True,'eps':['GET /api/acertos/previa']},
 {'id':'10.3','t':'Entrega sem motoboy escolhido','passos':[
   'Marque um pedido como ENTREGUE sem escolher entregador.',
   'Abra a prévia de qualquer entregador.'],
  'e':'Aparece uma linha avisando que há entregas sem motoboy, com o valor.',
  'f':'Essas entregas sumiam do acerto. Em produção eram 15 entregas e R$ 531,70 invisíveis.','reg':True,'eps':['GET /api/acertos/previa']},
 {'id':'10.4','t':'PIX não pago não entra','passos':[
   'Gere um pedido PIX e não pague.',
   'Marque como entregue.',
   'Abra a prévia.'],
  'e':'Não entra como dinheiro recebido.','reg':True,'eps':['GET /api/acertos/previa']},
 {'id':'10.5','t':'Fechar o acerto','passos':[
   'Confira o total da prévia.',
   'Clique em fechar o acerto.',
   'Abra um dos pedidos incluídos.'],
  'e':'O total bate com a prévia e os pedidos ficam marcados como acertados.','eps':['POST /api/acertos']},
 {'id':'10.6','t':'Histórico de acertos','passos':['Abra o histórico na mesma tela.'],
  'e':'Os acertos fechados, com data e valor.','eps':['GET /api/acertos/historico']},
 {'id':'10.7','t':'Imprimir o recibo','passos':[
   'Ligue o bloqueador de pop-up.',
   'Clique em imprimir o recibo.'],
  'e':'Avisa que foi bloqueado, em vez de não fazer nada.','reg':True,'eps':['GET /api/acertos/historico']},
]},

{'n':'11','t':'Fechar caixa','tela':'caixa.html','r':'O fechamento do dia.','testes':[
 {'id':'11.1','t':'Faturamento do dia','passos':[
   'No fim de um dia com vendas, abra <b>Fechar Caixa</b>.',
   'Some os pedidos à mão e compare.'],
  'e':'O total bate com a soma dos pedidos válidos.','eps':['GET /api/pedidos/board']},
 {'id':'11.2','t':'PIX abandonado não é faturamento','passos':[
   'Gere um PIX de R$ 50 pelo cardápio e NÃO pague.',
   'Abra Fechar Caixa.'],
  'e':'Os R$ 50 não entram no faturamento, e aparecem como "esperando PIX" com o valor.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'11.3','t':'Cancelado não conta','passos':[
   'Cancele um pedido do dia.',
   'Abra Fechar Caixa.'],
  'e':'Sai do faturamento e aparece na contagem de cancelados — sem se confundir com PIX pendente.','reg':True,'eps':['GET /api/pedidos/board']},
 {'id':'11.4','t':'Quebra por forma de pagamento','passos':[
   'Veja a divisão por forma.',
   'Some as formas à mão.'],
  'e':'A soma bate com o total.','eps':['GET /api/pedidos/board']},
 {'id':'11.5','t':'Imprimir o fechamento','passos':[
   'Ligue o bloqueador de pop-up.',
   'Clique em imprimir o fechamento.'],
  'e':'Avisa, em vez de não fazer nada.','reg':True,'eps':['GET /api/pedidos/board']},
]},

{'n':'12','t':'Canais e cardápio QR','tela':'canais.html · cardapio-qr.html','r':'De onde vêm os pedidos, e o link para o cliente.','testes':[
 {'id':'12.1','t':'Resumo por canal','passos':[
   'Tenha pedidos de balcão, cardápio e marketplace no dia.',
   'Abra <b>Canais</b>.'],
  'e':'Cada canal com a contagem certa.','eps':['GET /api/pedidos/board']},
 {'id':'12.2','t':'QR do cardápio','passos':[
   'Abra <b>Cardápio QR</b>.',
   'Aponte a câmera do celular para o código.'],
  'e':'Abre o cardápio da loja certa.','eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'12.3','t':'Copiar o link','passos':[
   'Clique em copiar o link.',
   'Cole numa aba anônima.'],
  'e':'O link funciona e abre o cardápio.','eps':['GET /public/loja/{lojaId}/cardapio']},
 {'id':'12.4','t':'App instalável','passos':[
   'No celular, abra o cardápio da loja.',
   'Use o menu do navegador → "Adicionar à tela inicial".',
   'Abra pelo ícone criado.'],
  'e':'Instala com o nome e o ícone da loja, e abre sem a barra do navegador.','eps':['GET /public/loja/{lojaId}/manifest','GET /public/loja/{lojaId}/marca']},
 {'id':'12.5','t':'Folha do cardápio para imprimir','passos':[
   'Abra <code>cardapio-folha.html?loja=SEU_ID</code> (o mesmo caminho que o botão de imprimir usa).',
   'Espere as fotos carregarem.',
   'Mande imprimir (Ctrl+P) e olhe a PRÉ-VISUALIZAÇÃO, não só a tela.'],
  'e':'Sai uma folha com as seções na mesma ordem do cardápio do cliente, as fotos da loja, os preços e o QR. Nada cortado na margem.',
  'f':'Tela não mede papel: três defeitos desta folha só apareceram no PDF, nunca no navegador.','reg':True,
  'eps':['GET /public/loja/{lojaId}/cardapio','GET /public/loja/{lojaId}/produto/{produtoId}/imagem']},
 {'id':'12.6','t':'A folha diz o MESMO preço que o cliente paga','passos':[
   'Escolha um produto que tenha recipiente ou adicional obrigatório.',
   'Veja o preço dele na folha impressa.',
   'Abra o cardápio do cliente e monte esse mesmo produto até o carrinho.'],
  'e':'O número é o mesmo nos dois.',
  'f':'A folha anunciava o preço-base e o cliente só descobria o valor real no carrinho: num caso, R$ 90,00 virava R$ 100,00.','reg':True,
  'eps':['GET /public/loja/{lojaId}/cardapio']},
]},
]
