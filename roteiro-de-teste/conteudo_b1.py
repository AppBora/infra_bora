# -*- coding: utf-8 -*-
"""Roteiro, parte B (primeira metade): cadastros e numeros. Secoes 13 a 22."""

PARTE_B1 = [
{'n':'13','t':'Produtos e complementos','tela':'produtos.html','r':'O catálogo e os adicionais.','testes':[
 {'id':'13.1','t':'Listar produtos','passos':['Abra <b>Produtos</b> no menu.'],
  'e':'Lista com nome, categoria, preço, custo e estoque.','eps':['GET /api/produtos']},
 {'id':'13.2','t':'Criar produto','passos':[
   'Clique em novo produto.','Preencha nome, categoria, preço, custo e foto.','Salve.',
   'Abra o cardápio público numa outra aba.'],
  'e':'Aparece na lista e no cardápio.','eps':['POST /api/produtos']},
 {'id':'13.3','t':'Editar','passos':[
   'Clique em editar um produto.','Mude preço e categoria.','Salve.','Recarregue o cardápio.'],
  'e':'Reflete no cardápio.','eps':['PUT /api/produtos/{id}']},
 {'id':'13.4','t':'Desativado não volta sozinho','passos':[
   'Desmarque "ativo" num produto e salve.','Confira que sumiu do cardápio.',
   'Edite de novo esse produto, mude só o preço e salve.','Recarregue a lista.'],
  'e':'Continua desativado, com o selo "fora do cardápio".',
  'f':'A tela mandava "ativo: true" fixo e religava o que tinha sido desligado.','reg':True,'eps':['PUT /api/produtos/{id}']},
 {'id':'13.5','t':'Excluir produto','passos':[
   'Escolha um produto que tenha complemento e ficha técnica.','Exclua.',
   'Abra um pedido ANTIGO que tinha esse produto.'],
  'e':'Leva junto o que é dele, sem deixar lixo e sem quebrar o pedido antigo.','reg':True,'eps':['DELETE /api/produtos/{id}']},
 {'id':'13.6','t':'Estoque pelo cadastro','passos':[
   'Em Produtos, defina o estoque de um item.','Salve.','Confira na tela de Estoque.'],
  'e':'Salva, e não apaga consumo feito em paralelo.','reg':True,'eps':['PUT /api/produtos/{id}/estoque']},
 {'id':'13.7','t':'Grupos de complemento','passos':[
   'Num produto, abra a gestão de complementos.',
   'Crie um grupo com mínimo 1 e máximo 2.','Cadastre três opções.','Salve.',
   'Abra esse produto no cardápio público.'],
  'e':'O cardápio respeita o mínimo e o máximo.','eps':['PUT /api/produtos/{produtoId}/complementos','GET /api/produtos/{produtoId}/complementos']},
 {'id':'13.8','t':'Adicional com preço','passos':[
   'Ponha R$ 3,00 num adicional.','Venda o produto com esse adicional.',
   'Veja o total do pedido.','Depois veja o CMV em Relatórios.'],
  'e':'O preço do item sobe R$ 3,00 e o custo do pedido reflete o adicional.','reg':True,'eps':['PUT /api/produtos/{produtoId}/complementos']},
 {'id':'13.9','t':'Papel para mexer em complemento','passos':[
   'Entre como OPERADOR.','Tente abrir e salvar complementos de um produto.'],
  'e':'Recusa.','reg':True,'eps':['PUT /api/produtos/{produtoId}/complementos']},
 {'id':'13.10','t':'Importar cardápio por foto','passos':[
   'Tire uma foto de um cardápio que tenha um preço escrito "12.50".',
   'Em Produtos, use a importação por imagem.','Envie e aguarde.','Abra o produto criado.'],
  'e':'Entra como R$ 12,50.',
  'f':'Virava R$ 1.250,00 quando o preço vinha com ponto em vez de vírgula.','reg':True,'eps':['POST /api/ia/importar-cardapio']},
 {'id':'13.11','t':'A importação não trava o sistema','passos':[
   'Comece uma importação por imagem.',
   'SEM esperar terminar, abra Pedidos, Estoque e Relatórios noutra aba.'],
  'e':'O painel continua respondendo normalmente.',
  'f':'Segurava uma conexão do banco (de 20) por até 64 segundos a cada importação.','reg':True,'eps':['POST /api/ia/importar-cardapio']},
 {'id':'13.12','t':'Lista não carrega foto','passos':[
   'Aperte F12, vá na aba Rede e marque "Desabilitar cache".','Abra Produtos.',
   'Olhe o tamanho total transferido no pé da aba Rede.'],
  'e':'Carrega leve; as fotos vêm por endereço separado, só as que aparecem na tela.','reg':True,'eps':['GET /api/produtos']},
 {'id':'13.13','t':'Foto não vira página','passos':[
   'Tente salvar como foto de produto um arquivo que não é imagem (HTML ou SVG).',
   'Se deixar salvar, abra o endereço da imagem direto no navegador.'],
  'e':'Recusa. O endereço da imagem nunca serve HTML nem SVG.',
  'f':'Era caminho para roubar o token de quem abrisse o link.','reg':True,'eps':['GET /public/loja/{lojaId}/produto/{produtoId}/imagem']},
 {'id':'13.14','t':'Código do marketplace','passos':[
   'Edite um produto e preencha o código dele no iFood.','Salve e recarregue.'],
  'e':'Salva — é por ele que o pedido de fora casa com o produto.','eps':['PUT /api/produtos/{id}']},
 {'id':'13.15','t':'Ordem das seções: a lista abre como o cliente vê','passos':[
   'Abra <b>Produtos</b> e role até <b>Ordem das seções do cardápio</b>.'],
  'e':'Lista as seções da loja, numeradas, com quantos produtos cada uma tem. Se a loja nunca escolheu uma ordem, a tela diz que hoje elas saem em ordem alfabética.',
  'eps':['GET /api/categorias']},
 {'id':'13.16','t':'Mudar a ordem e salvar','passos':[
   'Use ↑/↓ para pôr uma seção em primeiro lugar.',
   'ANTES de salvar, leia o aviso embaixo e recarregue a página sem salvar.',
   'Mude de novo e clique em <b>Salvar a ordem</b>.','Recarregue.'],
  'e':'Mexer na tela não grava nada: ao recarregar sem salvar, volta como estava. Depois de salvar, a ordem continua ao recarregar.',
  'eps':['PUT /api/categorias/ordem','GET /api/categorias']},
 {'id':'13.17','t':'A ordem vale nas duas pontas','passos':[
   'Com a ordem salva, abra a <b>Frente de Caixa</b> e olhe a fila de categorias.',
   'Abra o cardápio do cliente dessa loja.'],
  'e':'As duas listam na ordem que você escolheu. Seção que você não ordenou fica no fim, em ordem alfabética — e nenhuma seção aparece partida em dois pedaços.',
  'eps':['GET /api/categorias','GET /api/produtos','GET /public/loja/{lojaId}/cardapio']},
 {'id':'13.18','t':'A seta que não tem para onde ir','passos':[
   'Olhe a seta ↑ da PRIMEIRA seção e a ↓ da ÚLTIMA.','Tente clicar nas duas.'],
  'e':'As duas saem apagadas, com cursor de bloqueado, e o balão explica ("Já é a primeira").',
  'f':'Saíam com a mesma cor e o mesmo cursor das que funcionam: o lojista clicava, nada acontecia, e aprendia que a tela estava quebrada.','reg':True,
  'eps':['GET /api/categorias']},
 {'id':'13.19','t':'Sair sem salvar a ordem','passos':[
   'Mude a ordem com ↑/↓ e, SEM salvar, tente fechar a aba.',
   'Depois recarregue, não mexa em nada, e tente fechar de novo.'],
  'e':'Na primeira vez o navegador pergunta se você quer mesmo sair. Na segunda, não pergunta.',
  'f':'Avisar sem motivo ensina o lojista a ignorar o aviso.','reg':True,
  'eps':['GET /api/categorias']},
]},

{'n':'14','t':'Estoque e contagem','tela':'estoque.html · contagem.html','r':'O saldo e o acerto do saldo.','testes':[
 {'id':'14.1','t':'Ver o estoque','passos':['Abra <b>Estoque</b> no menu.'],
  'e':'Saldo e mínimo por produto, com destaque para quem está abaixo do mínimo.','eps':['GET /api/produtos']},
 {'id':'14.2','t':'Ajustar (entrada e saída)','passos':[
   'Num produto com saldo 10, lance uma ENTRADA de 5.','Confira: deve virar 15.',
   'Lance uma SAÍDA de 3.','Confira: deve virar 12.'],
  'e':'O saldo muda pelo valor lançado, e não por sobrescrita.','reg':True,'eps':['PUT /api/produtos/{id}/estoque']},
 {'id':'14.3','t':'Definir saldo exato','passos':[
   'Use a opção de definir saldo e informe 40.','Confira a lista.'],
  'e':'Fica exatamente 40.','eps':['PUT /api/produtos/{id}/estoque']},
 {'id':'14.4','t':'Salvar cadastro não apaga estoque','passos':[
   'Abra a tela de edição de um produto e NÃO salve ainda.',
   'Noutra aba, venda 3 unidades dele.',
   'Volte à primeira aba e salve o cadastro (mude só o preço).',
   'Confira o estoque.'],
  'e':'O estoque continua com a baixa das 3 unidades.',
  'f':'Corrigir o preço às 21h apagava o consumo da noite inteira.','reg':True,'eps':['PUT /api/produtos/{id}']},
 {'id':'14.5','t':'Contagem de estoque','passos':[
   'Abra <b>Contagem</b>.','Digite a contagem física de alguns produtos.',
   'Olhe a diferença que a tela calcula.','Aplique.'],
  'e':'Ajusta o saldo e mostra a diferença que foi aplicada.','eps':['PUT /api/produtos/{id}/estoque']},
 {'id':'14.6','t':'Duas vendas ao mesmo tempo','passos':[
   'Deixe um produto com estoque 1.','Abra o PDV em duas abas.',
   'Feche a venda desse produto nas duas quase ao mesmo tempo.','Confira o saldo.'],
  'e':'O saldo final é coerente e nenhuma venda some.','reg':True,'eps':['POST /api/pedidos']},
]},

{'n':'15','t':'Insumos e ficha técnica','tela':'insumos.html','r':'O que o produto consome. É onde mora o custo.','testes':[
 {'id':'15.1','t':'Listar insumos','passos':['Abra <b>Insumos</b> no menu.'],
  'e':'Nome, unidade, custo e saldo.','eps':['GET /api/insumos']},
 {'id':'15.2','t':'Criar e editar','passos':[
   'Cadastre um insumo com unidade e custo.',
   'Depois de algum consumo do dia, edite só o custo e salve.','Confira o saldo.'],
  'e':'Salva, e corrigir o custo NÃO zera o consumo do dia.','reg':True,'eps':['POST /api/insumos','PUT /api/insumos/{id}']},
 {'id':'15.3','t':'Mexer no estoque do insumo','passos':[
   'Lance uma entrada de insumo.','Lance uma saída.','Confira o saldo.'],
  'e':'O saldo acompanha.','eps':['PUT /api/insumos/{id}/estoque']},
 {'id':'15.4','t':'Excluir insumo em uso','passos':[
   'Ponha um insumo numa ficha técnica.','Tente excluir esse insumo.'],
  'e':'Recusa explicando onde ele está sendo usado.','reg':True,'eps':['DELETE /api/insumos/{id}']},
 {'id':'15.5','t':'Montar a ficha técnica','passos':[
   'Em Produtos, abra a ficha de um produto.','Acrescente dois insumos com quantidades.',
   'Salve.','Olhe o custo calculado.'],
  'e':'Salva, e o custo aparece somando os insumos.','eps':['PUT /api/produtos/{id}/ficha','GET /api/produtos/{id}/ficha']},
 {'id':'15.6','t':'Ficha baixa insumo na venda','passos':[
   'Anote o saldo dos dois insumos.','Venda 2 unidades do produto.','Volte a Insumos.'],
  'e':'Baixaram na proporção da ficha vezes 2.','eps':['POST /api/pedidos']},
 {'id':'15.7','t':'Adicional baixa insumo','passos':[
   'Na gestão de complementos, ligue um insumo a um adicional.',
   'Venda o produto COM esse adicional.','Confira o saldo do insumo.'],
  'e':'O insumo do adicional baixa também.','reg':True,'eps':['PUT /api/produtos/{produtoId}/complementos']},
 {'id':'15.8','t':'Cancelar devolve os dois','passos':[
   'Cancele o pedido do teste anterior.','Confira os dois insumos.'],
  'e':'Devolve o insumo da ficha e o do adicional.','reg':True,'eps':['PATCH /api/pedidos/{id}/status']},
 {'id':'15.9','t':'Insumo é de gerente para cima','passos':[
   'Entre como OPERADOR.','Tente abrir Insumos.','Tente abrir a ficha de um produto.'],
  'e':'Recusa nos dois.',
  'f':'Insumo é onde o custo da loja mora de verdade.','reg':True,'eps':['GET /api/insumos','GET /api/produtos/{id}/ficha']},
 {'id':'15.10','t':'Ficha fantasma','passos':[
   'Use uma ficha antiga em que um dos insumos já foi excluído do cadastro.',
   'Abra a ficha desse produto.'],
  'e':'Avisa que falta insumo, em vez de calcular o custo a menos, calado.','reg':True,'eps':['GET /api/produtos/{id}/ficha']},
]},

{'n':'16','t':'Clientes e CRM','tela':'clientes.html · crm.html','r':'Quem compra, o saldo e o histórico.','testes':[
 {'id':'16.1','t':'Listar e buscar','passos':['Abra <b>Clientes</b>.','Busque por nome.','Busque por telefone.'],
  'e':'Acha nos dois.','eps':['GET /api/clientes']},
 {'id':'16.2','t':'Cadastrar','passos':['Clique em novo cliente.','Preencha nome, telefone e endereço.','Salve.','Procure ele no PDV.'],
  'e':'Aparece na lista e já serve no PDV.','eps':['POST /api/clientes']},
 {'id':'16.3','t':'Editar em vez de excluir','passos':[
   'Num cliente existente, clique em <b>Editar</b>.','Corrija o nome e o endereço.','Salve.',
   'Confira que o saldo de cashback e o histórico continuam lá.'],
  'e':'Dá para corrigir sem precisar excluir.',
  'f':'Antes só existia excluir — e excluir levava cashback e histórico junto.','reg':True,'eps':['PUT /api/clientes/{id}']},
 {'id':'16.4','t':'Excluir avisa do cashback','passos':[
   'Escolha um cliente COM saldo.','Clique em excluir e leia o aviso.'],
  'e':'Avisa que o saldo será perdido antes de confirmar.','reg':True,'eps':['DELETE /api/clientes/{id}']},
 {'id':'16.5','t':'Telefone duplicado','passos':[
   'Cadastre um cliente com um telefone que já existe.'],
  'e':'Avisa que já existe, em vez de criar o segundo cadastro e rachar o cashback.','eps':['POST /api/clientes']},
 {'id':'16.6','t':'CRM: quem sumiu','passos':['Abra <b>CRM</b>.','Olhe a lista por recência e por valor.'],
  'e':'Mostra quem está sumido e quanto cada um já gastou.','eps':['GET /api/clientes']},
 {'id':'16.7','t':'Links de repetir','passos':[
   'No CRM, copie o link de repetir de um cliente.','Abra o link numa aba anônima.'],
  'e':'Abre o cardápio com o último pedido dele montado.','eps':['GET /api/clientes/links-repetir']},
]},

{'n':'17','t':'Promoções e cupons','tela':'promocoes.html','r':'Desconto por tempo e por código.','testes':[
 {'id':'17.1','t':'Listar promoções','passos':['Abra <b>Promoções</b>.'],
  'e':'Código, tipo, desconto, validade, usos, origem e situação.','eps':['GET /api/promocoes']},
 {'id':'17.2','t':'Limite escolhido','passos':[
   'Clique em nova promoção.','No campo <b>Limite de usos</b>, digite 200.','Salve.','Veja a lista.'],
  'e':'Grava 200 — o campo existe e é respeitado.',
  'f':'Era 20 fixo no código, sem campo e sem aviso: a loja via a promoção morrer no meio da noite.','reg':True,'eps':['POST /api/promocoes']},
 {'id':'17.3','t':'Limite em branco = sem limite','passos':[
   'Crie uma promoção deixando o limite VAZIO.','Veja a lista.'],
  'e':'Mostra "sem limite", e ela não morre por uso.','reg':True,'eps':['POST /api/promocoes']},
 {'id':'17.4','t':'Quantos faltam','passos':[
   'Crie uma promoção com limite 5.','Use o código 3 vezes no cardápio.','Volte à lista.'],
  'e':'Mostra 3/5 e "faltam 2", em vermelho porque restam 3 ou menos.','reg':True,'eps':['GET /api/promocoes']},
 {'id':'17.5','t':'Encerrar','passos':[
   'Numa promoção ativa, clique em <b>Encerrar</b>.','Leia a pergunta e confirme.',
   'Tente usar o código no cardápio.'],
  'e':'Pergunta antes, encerra, e o código para de valer.',
  'f':'O endpoint existia no servidor desde o início e nenhuma tela chamava.','reg':True,'eps':['PATCH /api/promocoes/{id}/encerrar']},
 {'id':'17.6','t':'Promoção desconta de verdade','passos':[
   'No cardápio, monte um carrinho.','Digite o código da promoção.','Olhe o total.'],
  'e':'O desconto aparece no total.','reg':True,'eps':['GET /public/loja/{lojaId}/cupom/{codigo}']},
 {'id':'17.7','t':'Criar cupom','passos':[
   'Na aba de cupons, crie um com código, validade e limite.','Salve.'],
  'e':'Aparece na lista.','eps':['POST /api/cupons','GET /api/cupons']},
 {'id':'17.8','t':'Cupom vencido e esgotado','passos':[
   'Crie um cupom com validade de ontem e tente usar no cardápio.',
   'Crie outro com limite 1, use uma vez e tente de novo.'],
  'e':'Os dois recusam, cada um com o motivo certo.','eps':['GET /public/loja/{lojaId}/cupom/{codigo}']},
 {'id':'17.9','t':'Excluir cupom','passos':['Exclua um cupom.','Tente usar o código no cardápio.'],
  'e':'Para de valer.','eps':['DELETE /api/cupons/{id}']},
]},

{'n':'18','t':'Relatórios e desempenho','tela':'relatorios.html · desempenho.html','r':'Os números de dono.','testes':[
 {'id':'18.1','t':'Relatório fecha a conta','passos':[
   'Abra <b>Relatórios</b>.','Troque entre 7, 30 e 90 dias.',
   'Some o faturamento por canal à mão e compare com o total.'],
  'e':'Faturamento, pedidos, ticket, CMV e margem. A soma por canal bate com o total.','eps':['GET /api/relatorios']},
 {'id':'18.2','t':'Taxa do marketplace aparece','passos':[
   'Garanta um pedido entregue PELO marketplace no período.','Abra Relatórios.',
   'Olhe logo abaixo do faturamento.'],
  'e':'Aparece quanto desse faturamento é taxa de entrega do marketplace.',
  'f':'Essa taxa é do marketplace e somia dentro do seu faturamento sem aviso nenhum.','reg':True,'eps':['GET /api/relatorios']},
 {'id':'18.3','t':'Por produto e por entregador','passos':[
   'Veja a quebra por produto.','Veja a quebra por entregador.','Some cada uma e compare com o total.'],
  'e':'As somas batem.','eps':['GET /api/relatorios']},
 {'id':'18.4','t':'Exportar CSV','passos':['Clique em exportar.','Abra o arquivo numa planilha.'],
  'e':'Abre e os números batem com a tela.','eps':['GET /api/relatorios']},
 {'id':'18.5','t':'Relatório é de dono','passos':[
   'Entre como OPERADOR.','Procure Relatórios no menu.','Tente abrir <code>/relatorios.html</code> direto na barra de endereço.'],
  'e':'Não aparece no menu e a API recusa.','reg':True,'eps':['GET /api/relatorios']},
 {'id':'18.6','t':'Desempenho por loja','passos':['Abra <b>Desempenho</b>.'],
  'e':'Faturamento, custo e lucro por loja.','eps':['GET /api/desempenho']},
 {'id':'18.7','t':'Balancete da rede','passos':[
   'Com duas lojas, abra o balancete.','Some as lojas à mão.'],
  'e':'O total bate com a soma.','eps':['GET /api/rede/balancete']},
 {'id':'18.8','t':'Receita e contagem concordam','passos':[
   'Deixe um PIX pendente numa loja da rede.','Abra o balancete.',
   'Divida a receita pela contagem de pedidos e compare com o ticket mostrado.'],
  'e':'Bate.',
  'f':'A receita excluía o PIX pendente e a contagem o incluía — o ticket saía menor que a realidade.','reg':True,'eps':['GET /api/rede/balancete']},
 {'id':'18.9','t':'Limpeza de dados de teste','passos':[
   'Como ADMINISTRADOR_BORA, veja quantos dados de teste a loja tem.',
   'Rode a limpeza.','Abra Relatórios.'],
  'e':'Diz quantos são antes, e depois eles somem dos números.','reg':True,'eps':['GET /admin-bora/lojas/{lojaId}/dados-de-teste','POST /admin-bora/lojas/{lojaId}/limpar-dados-de-teste']},
]},

{'n':'19','t':'Rede e análise','tela':'rede.html','r':'Multi-loja e os painéis de análise.','testes':[
 {'id':'19.1','t':'Lojas da rede','passos':['Abra <b>Rede &amp; Análise</b>.'],
  'e':'Todas as lojas que você alcança.','eps':['GET /api/rede/lojas']},
 {'id':'19.2','t':'Análise por canal','passos':['Abra a análise de canais.','Escolha o período.'],
  'e':'Participação de cada canal, batendo com os pedidos do período.','eps':['GET /api/analise/canais']},
 {'id':'19.3','t':'Análise por horário','passos':['Abra a análise de horário.'],
  'e':'Os picos batem com o movimento real da loja.','eps':['GET /api/analise/horario']},
 {'id':'19.4','t':'Tempos de preparo e entrega','passos':['Abra a análise de tempos.'],
  'e':'Tempo médio por etapa, coerente com os pedidos do período.','eps':['GET /api/analise/tempos']},
 {'id':'19.5','t':'Dossiê da rede','passos':['Abra o dossiê.'],
  'e':'Resumo consolidado das lojas.','eps':['GET /api/ia/rede/dossie']},
 {'id':'19.6','t':'Sinais sem IA','passos':['Abra os sinais, sem pedir análise.'],
  'e':'Achados por regra, sem custo de IA.','eps':['GET /api/ia/rede/sinais']},
 {'id':'19.7','t':'Análise com IA','passos':['Clique em analisar.','Aguarde a resposta.'],
  'e':'Responde, ou diz com clareza que o módulo não foi contratado.','eps':['POST /api/ia/rede/analisar']},
]},

{'n':'20','t':'Módulo IA','tela':'configuracoes.html · rede.html','r':'Recuperador, gerente virtual e importação.','testes':[
 {'id':'20.1','t':'Gate do módulo','passos':[
   'Numa loja SEM o módulo, tente usar qualquer recurso de IA.'],
  'e':'403 dizendo que o módulo não foi contratado.','eps':['GET /api/ia/status']},
 {'id':'20.2','t':'WhatsApp do dono','passos':[
   'Cadastre o número que recebe o resumo diário.','Salve.','Recarregue.'],
  'e':'Salva e aparece de volta.','eps':['PUT /api/ia/whatsapp-dono']},
 {'id':'20.3','t':'Recuperador de clientes','passos':[
   'Numa loja com clientes sumidos há mais de 21 dias, clique em disparar o recuperador.',
   'Leia o resultado.'],
  'e':'Diz quantos foram contatados e quantas mensagens restam no mês.','eps':['POST /api/ia/recuperar']},
 {'id':'20.4','t':'WhatsApp fora do ar não trava','passos':[
   'Derrube a integração do WhatsApp trocando a credencial por uma errada.',
   'Dispare o recuperador numa loja com muitos clientes.','Cronometre.'],
  'e':'Termina rápido dizendo quantas falharam. NÃO fica horas tentando.',
  'f':'O contador só subia no sucesso: com a Meta fora, percorria a base inteira, uma espera de rede por cliente.','reg':True,'eps':['POST /api/ia/recuperar']},
 {'id':'20.5','t':'Retorno do recuperador','passos':['Abra o resumo de recuperação.'],
  'e':'Quantos voltaram a pedir depois do contato, e quanto isso deu.','eps':['GET /api/ia/recuperacao/resumo']},
 {'id':'20.6','t':'Gerente virtual','passos':['Peça o resumo do dia anterior.','Compare com Relatórios.'],
  'e':'Faturamento, pedidos e variação batendo com Relatórios.','eps':['POST /api/ia/gerente']},
]},

{'n':'21','t':'Ajustes de operação','tela':'ajustes.html','r':'Taxas, formas de pagamento, horários e motivos.','testes':[
 {'id':'21.1','t':'Taxa por bairro','passos':[
   'Abra <b>Ajustes Operação</b>.','Cadastre um bairro com taxa R$ 7.',
   'Abra o cardápio e escolha esse bairro: deve cobrar R$ 7.',
   'Volte e edite para R$ 9; confira no cardápio.','Exclua a taxa.'],
  'e':'O cardápio usa a taxa nova a cada mudança.','eps':['GET /api/taxas','POST /api/taxas','PUT /api/taxas/{id}','DELETE /api/taxas/{id}']},
 {'id':'21.2','t':'Formas de pagamento','passos':[
   'Cadastre uma forma nova.','Veja no cardápio e no PDV.',
   'Desative e confira que sumiu dos dois.','Exclua.'],
  'e':'As duas telas refletem cada mudança.','eps':['GET /api/formas-pagamento','POST /api/formas-pagamento','PUT /api/formas-pagamento/{id}','DELETE /api/formas-pagamento/{id}']},
 {'id':'21.3','t':'Horário de funcionamento','passos':[
   'Marque hoje como FECHADO e salve.','Abra o cardápio público.',
   'Volte a abrir o horário e confira o cardápio de novo.'],
  'e':'O cardápio mostra fechada e volta a aceitar pedido quando reabre.','eps':['GET /api/horarios','PUT /api/horarios']},
 {'id':'21.4','t':'Motivos de cancelamento','passos':[
   'Cadastre um motivo novo.','Cancele um pedido e veja a lista de motivos.',
   'Edite o texto do motivo.','Exclua.'],
  'e':'O motivo aparece, muda e some conforme você mexe.','eps':['GET /api/motivos','POST /api/motivos','PUT /api/motivos/{id}','DELETE /api/motivos/{id}']},
 {'id':'21.5','t':'Listas vazias explicadas','passos':['Abra Ajustes numa loja nova, sem nada cadastrado.'],
  'e':'Cada lista diz o que falta cadastrar, inclusive que sem horário a loja fica sempre fechada.','reg':True,'eps':['GET /api/horarios']},
]},

{'n':'22','t':'Configurações da loja','tela':'configuracoes.html','r':'Marca, cores, cashback e custo fixo.','testes':[
 {'id':'22.1','t':'Ver a configuração','passos':['Entre como ADMINISTRADOR_LOJA.','Abra <b>Configurações</b>.'],
  'e':'Nome de exibição, cores, logo, banner, cashback e custo fixo.','eps':['GET /api/configuracao']},
 {'id':'22.2','t':'Trocar marca','passos':[
   'Troque o nome de exibição, a logo e o banner.','Salve.',
   'Abra o cardápio público numa aba anônima.'],
  'e':'Aparecem no cardápio e no app instalável.','eps':['PUT /api/configuracao','GET /public/loja/{lojaId}/marca']},
 {'id':'22.3','t':'Cores do white-label','passos':['Troque a cor principal e salve.','Recarregue o painel.','Recarregue o cardápio.'],
  'e':'Os dois mudam.','eps':['PUT /api/configuracao']},
 {'id':'22.4','t':'Percentual de cashback','passos':[
   'Mude o percentual para 10% e salve.','Faça uma venda de R$ 50 para um cliente.','Veja o saldo dele.'],
  'e':'O saldo sobe R$ 5,00.','eps':['PUT /api/configuracao']},
 {'id':'22.5','t':'Logo e banner servidos','passos':[
   'Abra o endereço da logo direto no navegador.','Recarregue e olhe a aba Rede.'],
  'e':'Serve a imagem com o tipo certo, e na segunda vez vem do cache (304).','eps':['GET /public/loja/{lojaId}/{qual:logo|banner}']},
 {'id':'22.6','t':'Só o administrador da loja','passos':[
   'Entre como GERENTE.','Procure Configurações no menu.','Tente abrir a tela direto.'],
  'e':'Não aparece no menu e a API recusa.','reg':True,'eps':['PUT /api/configuracao']},
 {'id':'22.7','t':'Respostas prontas do WhatsApp','passos':[
   'Abra <b>Respostas WhatsApp</b>.','Copie uma resposta.','Cole num bloco de notas e leia.'],
  'e':'O texto traz o link do cardápio e o horário certos DESTA loja.','eps':['GET /public/loja/{lojaId}/cardapio']},
]},
]
