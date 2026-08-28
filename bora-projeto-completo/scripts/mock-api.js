// Mock da API BoraHapp (Node puro, sem dependências) para rodar o smoke-test.sh
// sem precisar do backend Java/Postgres. Implementa o CONTRATO dos endpoints.
// Uso:
//   node mock-api.js &            # sobe em :8099
//   BASE=http://localhost:8099 ./smoke-test.sh
const http=require('http');
const signups={}; // email -> senha (cadastro self-service durante o teste)
const J=(res,code,obj)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(obj));};
const arr=(n,f)=>Array.from({length:n},(_,i)=>f(i));
function body(req){return new Promise(r=>{let d='';req.on('data',c=>d+=c);req.on('end',()=>{try{r(d?JSON.parse(d):{});}catch{r({});}});});}
const srv=http.createServer(async (req,res)=>{
  const p=new URL(req.url,'http://x').pathname; const m=req.method;
  const auth=(req.headers['authorization']||'').startsWith('Bearer ');
  if(p==='/api/health') return J(res,200,{status:'UP'});
  if(p==='/auth/login'&&m==='POST'){const b=await body(req);
    const ok=(b.email==='admin@bora.app'&&b.senha==='bora123')||(signups[b.email]&&signups[b.email]===b.senha);
    return ok?J(res,200,{token:'mocktoken-'+b.email,nome:'QA',papel:'ADMINISTRADOR_LOJA',lojaId:1})
             :J(res,401,{message:'credenciais inválidas'});}
  if(p==='/public/signup'&&m==='POST'){const b=await body(req);
    if(!b.nomeLoja||!b.adminEmail) return J(res,400,{message:'dados obrigatórios'});
    signups[b.adminEmail]=b.adminSenha; return J(res,200,{lojaId:Math.floor(Math.random()*1000)+10,plano:'UNICO',adminEmail:b.adminEmail});}
  if((p.startsWith('/api/')||p.startsWith('/admin-bora/'))&&!auth) return J(res,401,{message:'sem token'});
  if(p==='/auth/me') return J(res,200,{papel:'ADMINISTRADOR_LOJA',nome:'QA'});
  if(p==='/api/onboarding') return J(res,200,{prontidao:80,operavel:false,passos:[
    {chave:'marca',obrigatorio:true,concluido:true},{chave:'cardapio',obrigatorio:true,concluido:true},
    {chave:'entrega',obrigatorio:true,concluido:true},{chave:'horario',obrigatorio:true,concluido:true},
    {chave:'pagamento',obrigatorio:true,concluido:false},{chave:'equipe',obrigatorio:false,concluido:false},
    {chave:'recebimento',obrigatorio:false,concluido:false}]});
  if(p==='/api/formas-pagamento') return J(res,200,[{descricao:'Dinheiro'},{descricao:'PIX'},{descricao:'Cartão de crédito'},{descricao:'Cartão de débito'}]);
  if(p==='/api/motivos') return J(res,200,arr(5,i=>({descricao:'motivo '+i})));
  if(p==='/api/horarios') return J(res,200,arr(7,i=>({dia:i,abre:'18:00',fecha:'23:00'})));
  if(p==='/api/rede/lojas') return J(res,200,[{id:1,nome:'QA',atual:true}]);
  if(p==='/api/rede/balancete') return J(res,200,{lojas:[{loja:'QA',faturamento:100,representatividade:100}],
    total:{faturamento:100,pedidos:3,ticketMedio:33.33,representatividade:100}});
  if(p==='/api/analise/canais') return J(res,200,{canais:[],faturamentoTotal:0,comissaoTotal:0,faturamentoLiquido:0,produtosMais:[],produtosMenos:[]});
  if(p==='/api/analise/horario') return J(res,200,{diasUteis:[],fimSemana:[],pico:{horaPicoUteis:20,horaPicoFimSemana:21}});
  if(p==='/api/analise/tempos') return J(res,200,{tempos:[],cancelamentos:{total:0,pedidos:0,percentual:0,porMotivo:[],porLoja:[]}});
  if(p==='/api/recebimento') return J(res,200,{configuradoPlataforma:false,provisionada:false,status:'DESATIVADO',walletId:null,onboardingUrl:null});
  if(p==='/admin-bora/lojas') return J(res,200,[{id:1,nome:'QA Loja',plano:'UNICO',asaasStatus:'DESATIVADO'}]); // SEM asaasApiKey (anti-vazamento)
  return J(res,404,{message:'not found'});
});
srv.listen(process.env.PORT||8099,()=>console.log('mock BoraHapp on '+(process.env.PORT||8099)));
