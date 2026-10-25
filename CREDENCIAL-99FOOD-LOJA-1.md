# A credencial do 99Food da loja 1 — o que eu medi

Tudo lido na produção em **25/10/2026**, somente-leitura. **Não imprimi nenhum segredo** aqui: só
tamanho e formato, que é o que basta para você reconhecer qual valor foi colado onde.

---

## O diagnóstico, em uma frase

A loja 1 usa a credencial **da plataforma**, e o `client_secret` da plataforma tem **13 caracteres**
— enquanto o único segredo de 99Food que comprovadamente funciona neste sistema tem **32**. A 99Food
responde **401** (credencial recusada). **A credencial da plataforma nunca funcionou para loja
nenhuma.**

---

## Como cheguei nisso

### 1. As duas lojas com 99Food não estão na mesma situação

| | loja 18 (Zirá) | loja 1 (Sorveteria da Rosa) |
|---|---|---|
| App Shop ID (`merchant_id`) | `zira-acaiteria` | `boraloja2` |
| credencial **própria** da loja | ✅ client_id de 34 caracteres + secret de **32** | ❌ **nenhuma** |
| usa a credencial de quem | **dela** | **da plataforma** |
| status | **CONECTADO**, buscando pedido | **ERRO** |
| pedidos recebidos | 0 | 0 |

**A Zirá funciona com um aplicativo próprio na 99** — conferi que o app dela **não é** o mesmo da
plataforma (comparei por igualdade, sem ver os valores: deu diferente). Então o fato de a Zirá estar
conectada **não prova nada** sobre a credencial da plataforma.

### 2. A credencial da plataforma existe, e o formato chama atenção

| chave em `config_plataforma` | tamanho |
|---|---|
| `credencial.opendelivery.client-id` | 19 caracteres |
| `credencial.opendelivery.client-secret` | **13 caracteres** |

Para comparar: o segredo do app da Zirá, que funciona, tem **32**. E o nosso de 13 **começa com duas
letras e um sublinhado** — parece mais um rótulo ou um valor de homologação que alguém colou no
campo errado do que um segredo.

**Não foi corte de coluna:** a coluna é `varchar(255)`. Os 13 caracteres são o que foi salvo.

### 3. O erro da 99Food aponta para a credencial, não para liberação

O código separa os dois casos, e isso ajuda:

- **404 Not Found** → o aplicativo ainda não está liberado na AllowList deles.
- **401 Unauthorized** → *"A 99Food recusou a credencial"*.

Estamos recebendo **401**. Ou seja: eles **reconhecem** o aplicativo; o que está errado é o par
id+segredo.

### 4. É o ambiente de produção deles

Nenhuma variável sobrescreve a URL, então vale o padrão: `https://openapi.99food.com/v4/opendelivery`
— **produção**. Se o segredo salvo for de homologação, 401 é exatamente o que se espera.

---

## O que falta, e é seu

**Compare o App Secret no portal da 99Food com o que está salvo** (13 caracteres, começando com duas
letras e um sublinhado). Se for diferente, é esse o problema.

**Eu não digito segredo** — essa linha eu não cruzo. E também **não vou ficar tentando autenticar
contra a 99** para descobrir por eliminação: o próprio código avisa que martelar com credencial
errada arrisca bloqueio, e por isso a retentativa já é espaçada em 10 minutos.

---

## 🔴 E aqui está o problema maior que eu achei no caminho

**Não existe tela para salvar a credencial da plataforma.** Procurei em tudo:

- o `GET /admin-bora/config` **exclui de propósito** as chaves `credencial.*` (certo — elas não devem
  sair em claro numa resposta);
- o único `PUT` de configuração é o `/config/fiscal`, que liga e desliga a NFC-e;
- a tela de Integrações tem campos de credencial, mas são da **loja** ("Client ID do aplicativo da sua
  loja"), não da plataforma.

Ou seja: **mesmo com o segredo certo na mão, você não tem como salvá-lo pelo painel.** Os valores que
estão lá hoje chegaram por escrita direta no banco ou por carga inicial.

Isso é o que transforma "credencial errada" em "credencial errada para sempre": todo marketplace que
usar o app da plataforma — iFood, 99Food, os próximos — depende de um valor que ninguém consegue
corrigir sem mexer no banco.

**Posso construir essa tela.** Ela precisa: aceitar o valor, nunca devolvê-lo (mostrar só "salvo ✓" e
o tamanho), exigir `ADMINISTRADOR_BORA`, e gravar cifrado como as credenciais de loja já são. Me diz
se quer, e com que prioridade — não vou mexer nisso sem você decidir, porque é tela que lida com
segredo.
