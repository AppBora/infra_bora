// Bateria de testes de LÓGICA — porta fielmente os algoritmos do backend Java e executa.
// Uso:  node logic-e2e-test.js   (não precisa de backend nem rede)
let PASS=0, FAIL=0; const fails=[];
function eq(name, got, exp){ const g=JSON.stringify(got), e=JSON.stringify(exp);
  if(g===e){PASS++; console.log("  ✅ "+name);} else {FAIL++; fails.push(name); console.log("  ❌ "+name+"\n       esperado "+e+"\n       obtido   "+g);} }
function near(name, got, exp, tol=0.01){ if(Math.abs(got-exp)<=tol){PASS++;console.log("  ✅ "+name+" ("+got+")");}
  else {FAIL++;fails.push(name);console.log("  ❌ "+name+" esperado ~"+exp+" obtido "+got);} }
const r1=x=>Math.round(x*10)/10, r2=x=>Math.round(x*100)/100;

// ---------- canalDe (AnaliseRedeService) ----------
function canalDe(origem, canalExterno){
  const o=((origem||"")+" "+(canalExterno||"")).toUpperCase();
  if(o.includes("IFOOD")||o.includes("I-FOOD"))return"iFood";
  if(o.includes("99"))return"99Food";
  if(o.includes("RAPPI"))return"Rappi";
  if(o.includes("UBER"))return"Uber Eats";
  if(o.includes("GOOMER"))return"Goomer";
  if(o.includes("AIQ"))return"aiqfome";
  if(o.includes("WHATS")||o.includes("ZAP"))return"WhatsApp";
  if(o.includes("INSTA")||o.includes(" IG"))return"Instagram";
  if(o.includes("FONE")||o.includes("TELEF"))return"Telefone";
  if(o.includes("SITE")||o.includes("CARDAP")||o.includes("WEB"))return"Cardápio próprio";
  if(o.includes("BALC")||o.includes("LOJA")||o.includes("CAIXA")||o.includes("PDV"))return"Balcão";
  if(o.trim()==="")return"Não informado";
  return"Delivery";
}
console.log("\n== canalDe (normalização de canal) ==");
eq("iFood via origem", canalDe("iFood",""), "iFood");
eq("iFood via canalExterno", canalDe("","IFOOD"), "iFood");
eq("99Food", canalDe("99Food",""), "99Food");
eq("Balcão (PDV)", canalDe("PDV",""), "Balcão");
eq("WhatsApp", canalDe("WhatsApp",""), "WhatsApp");
eq("Cardápio próprio", canalDe("cardapio",""), "Cardápio próprio");
eq("vazio => Não informado", canalDe("",""), "Não informado");
eq("MANUAL => Delivery (fallback)", canalDe("MANUAL",""), "Delivery");

// ---------- canais + comissão + split (AnaliseRedeService.canais) ----------
const COMISSAO={iFood:.27,"99Food":.23,Rappi:.25,"Uber Eats":.30,Goomer:.12,aiqfome:.18};
function canais(orders){
  const fat={}, ped={}; let fatTotal=0, comissao=0;
  for(const o of orders){ const c=canalDe(o.origem,o.canalExterno);
    fat[c]=(fat[c]||0)+o.valor; ped[c]=(ped[c]||0)+1; fatTotal+=o.valor;
    if(COMISSAO[c]!=null) comissao+=o.valor*COMISSAO[c]; }
  const canaisOut=Object.keys(fat).map(c=>({canal:c,pedidos:ped[c],faturamento:r2(fat[c]),
    percentual:r1(fatTotal? fat[c]/fatTotal*100:0), comissaoEstimada:r2(fat[c]*(COMISSAO[c]||0))}));
  return {fatTotal:r2(fatTotal),comissaoTotal:r2(comissao),liquido:r2(fatTotal-comissao),canais:canaisOut};
}
console.log("\n== canais + comissão + líquido ==");
const cc=canais([{valor:100,origem:"iFood"},{valor:100,origem:"iFood"},
                 {valor:200,origem:"99Food"},{valor:100,origem:"WhatsApp"}]);
near("faturamento total", cc.fatTotal, 500);
near("comissão total (54+46)", cc.comissaoTotal, 100);
near("faturamento líquido", cc.liquido, 400);
eq("iFood 40%", cc.canais.find(c=>c.canal==="iFood").percentual, 40);
eq("WhatsApp sem comissão", cc.canais.find(c=>c.canal==="WhatsApp").comissaoEstimada, 0);

// ---------- representatividade (RedeService.balancete) — números reais do cliente ----------
function representatividade(fats){ const total=fats.reduce((a,b)=>a+b,0);
  return fats.map(f=> total? r2(f/total*100):0); }
console.log("\n== representatividade (dados reais Zirá Açaí) ==");
const reps=representatividade([2579.62,1649.22,1129.24,102.81,0]);
near("Zona Norte 47,24%", reps[0], 47.24);
near("Vila Hortência 30,20%", reps[1], 30.20);
near("Nova Esperança 20,68%", reps[2], 20.68);
near("Vitória Régia 1,88%", reps[3], 1.88);
near("soma ~100%", reps.reduce((a,b)=>a+b,0), 100, 0.02);

// ---------- tempo por status (AnaliseRedeService.tempos) ----------
function temposPorStatus(pedidos){ const acc={};
  for(const p of pedidos){ let prev=p.criadoEm;
    for(const l of p.logs){ const de=l.statusAnterior||"RECEBIDO";
      const secs=Math.max(0,(l.dataHora-prev)); acc[de]=acc[de]||[0,0]; acc[de][0]+=secs; acc[de][1]++; prev=l.dataHora; } }
  const ordem=["RECEBIDO","CONFIRMADO","EM_PREPARO","PRONTO","SAIU_PARA_ENTREGA"];
  return ordem.map(s=>({status:s, min: acc[s]? r1(acc[s][0]/acc[s][1]/60):0})); }
console.log("\n== tempo médio por status ==");
const tps=temposPorStatus([{criadoEm:0, logs:[
  {statusAnterior:"RECEBIDO",dataHora:120},
  {statusAnterior:"CONFIRMADO",dataHora:480},
  {statusAnterior:"EM_PREPARO",dataHora:1740}]}]);
eq("RECEBIDO 2.0 min", tps[0].min, 2);
eq("CONFIRMADO 6.0 min", tps[1].min, 6);
eq("EM_PREPARO 21.0 min", tps[2].min, 21);

// ---------- cancelamento % ----------
function cancelPct(canc,tot){ return tot? r1(canc*100/tot):0; }
console.log("\n== cancelamento % ==");
eq("2/10 = 20%", cancelPct(2,10), 20);
eq("0/0 = 0%", cancelPct(0,0), 0);

// ---------- onboarding prontidão (OnboardingService) ----------
function prontidao(passos){ let ob=0,ok=0; for(const p of passos){ if(p.obrigatorio){ob++; if(p.concluido)ok++;}}
  return {prontidao: ob? Math.round(ok*100/ob):100, operavel: ok===ob}; }
console.log("\n== onboarding prontidão ==");
const req5=[{obrigatorio:true,concluido:true},{obrigatorio:true,concluido:true},{obrigatorio:true,concluido:true},
            {obrigatorio:true,concluido:false},{obrigatorio:true,concluido:false},{obrigatorio:false,concluido:false}];
eq("3/5 obrig => 60%", prontidao(req5).prontidao, 60);
eq("3/5 => não operável", prontidao(req5).operavel, false);
eq("5/5 => 100% operável", prontidao(req5.map(p=>({obrigatorio:p.obrigatorio,concluido:true}))).operavel, true);

// ---------- split do PIX (PixService) ----------
function incluiSplit(viaSubconta, wallet, taxa){ return !!(viaSubconta && wallet && wallet.trim()!=="" && taxa>0); }
console.log("\n== regra de split do PIX ==");
eq("subconta+wallet+taxa>0 => split", incluiSplit(true,"wlt_1",5), true);
eq("sem wallet => sem split", incluiSplit(true,"",5), false);
eq("taxa 0 => sem split", incluiSplit(true,"wlt_1",0), false);
eq("sem subconta => sem split", incluiSplit(false,"wlt_1",5), false);

console.log("\n════════════════════════════════════");
console.log("  LÓGICA:  "+PASS+" PASS  /  "+FAIL+" FAIL");
console.log("════════════════════════════════════");
if(FAIL) { console.log("Falhas: "+fails.join(", ")); process.exit(1); }
