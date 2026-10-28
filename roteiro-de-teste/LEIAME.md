# O roteiro de teste da aplicação inteira

`ROTEIRO-DE-TESTE.html` (na raiz do projeto) não é escrito à mão. Ele é **gerado** a partir
dos arquivos desta pasta. Mexa aqui e gere de novo; nunca edite o HTML direto, porque a
próxima geração apaga o que você escreveu.

Ele também está no ar, servido pelo Caddy junto com o painel:
<https://borahapp.com.br/ROTEIRO-DE-TESTE.html> — qualquer um com o endereço abre.

## O que tem hoje

- **333 testes** em **38 seções** (atualizado em 28/10/2026, na v154)
- cobrem as **35 telas** e os **162 endpoints** que o sistema tem
- **136 são de regressão**: bug que já aconteceu de verdade e não pode voltar
- as 6 últimas seções (I-A a I-F) são **integradas** — cruzam funcionalidades, como
  pedido → motoboy → acerto → caixa → relatório

## Os arquivos

| arquivo | o que é |
|---|---|
| `conteudo_a.py` | seções 1 a 12 — entrada, pedidos, PDV, KDS, entregas, acerto, caixa, canais |
| `conteudo_b1.py` | seções 13 a 22 — produtos, estoque, insumos, clientes, promoções, relatórios, ajustes |
| `conteudo_b2.py` | seções 23 a 32 — equipe, planos, integrações, fiscal, plataforma, cardápio, webhooks, celular |
| `conteudo_b.py` | só junta as duas metades acima |
| `conteudo_c.py` | seções I-A a I-F — os testes integrados |
| `endpoints.txt` | os 159 endpoints, levantados do código do backend |
| `telas.txt` | as 34 telas, levantadas do frontend |
| `conferir.py` | prova que todo endpoint tem teste e que nenhum teste aponta para o vazio |
| `gerar.py` | monta o HTML |

## Como um teste é escrito

```python
{'id':'13.4','t':'Desativado não volta sozinho','passos':[
   'Desmarque "ativo" num produto e salve.',
   'Confira que sumiu do cardápio.',
   'Edite de novo esse produto, mude só o preço e salve.',
   'Recarregue a lista.'],
  'e':'Continua desativado, com o selo "fora do cardápio".',
  'f':'A tela mandava "ativo: true" fixo e religava o que tinha sido desligado.',
  'reg':True,
  'eps':['PUT /api/produtos/{id}']},
```

- `passos` — **o passo a passo numerado de como executar**. Cada linha é um clique ou uma
  conferência. Quem for testar não pode precisar adivinhar nada.
- `e` — o que tem que acontecer. É isso que decide passou ou falhou.
- `f` — só nos de regressão: **por que isso importa**, ou seja, qual bug já aconteceu ali.
- `reg` — marca o item como regressão.
- `eps` — os endpoints que o item exercita. É o que `conferir.py` usa para provar cobertura.

## Como mexer

1. Edite o `conteudo_*.py` da seção.
2. `python conferir.py` — tem que terminar em **COBERTURA COMPLETA**. Se acusar endpoint
   sem teste, escreva o teste; se acusar endpoint que não existe, corrija o `eps`.
3. `python gerar.py` — reescreve `../ROTEIRO-DE-TESTE.html`.
4. Para publicar: `scp ROTEIRO-DE-TESTE.html ubuntu@18.230.57.33:/home/ubuntu/bora/frontend/`
   e confira o md5 do que é servido contra o local.

## Quando a aplicação ganhar um endpoint novo

`endpoints.txt` e `telas.txt` são inventários mecânicos, não opinião. Se o backend ganhar
rota, acrescente a linha lá **antes** de escrever o teste — aí o `conferir.py` passa a
cobrar o teste que falta, em vez de deixar a rota nova passar despercebida.

## Quem usa isto

Os agentes `qa-sdet` e `qa-visual` trabalham a partir deste roteiro e reportam por **id de
item**. A divisão de quem testa o quê está na definição de cada um, em `.claude/agents/`.

## Onde fica a copia publicada

O `gerar.py` escreve `../ROTEIRO-DE-TESTE.html` (raiz do projeto) — é esse que você abre
no dia a dia, e ele **não** é versionado aqui. A cópia versionada e publicada é a de
`bora-fase-2-frontend/ROTEIRO-DE-TESTE.html`. Depois de gerar, copie para lá, commite no
repositório do frontend, e só então mande para o servidor.


## A versão para imprimir

`python gerar_pdf.py` escreve `../ROTEIRO-DE-TESTE.pdf` — **25 páginas**, um quadrado para marcar
por teste e uma linha para escrever a mão. Mesma fonte de dados dos `conteudo_*.py`: o HTML e o
PDF nunca divergem porque nenhum dos dois é escrito à mão.

**A armadilha que ele guarda:** as fontes embutidas do PDF só têm Latin-1. Seta, travessão e os
emoji dos botões saem como **quadrado preto**, e saem calados — o PDF gera sem erro nenhum. Por
isso o `gerar_pdf.py` tem uma tabela de tradução e uma conferência que **estoura** se sobrou
qualquer caractere que a fonte não desenha. Ao acrescentar texto com símbolo novo, o gerador
reclama antes; é só pôr a tradução no `TRADUCAO`, no topo do arquivo.

## O que mudou em 28/10/2026

| | |
|---|---|
| `endpoints.txt` | 158 → **161** — entraram `GET /api/categorias`, `PUT /api/categorias/ordem` e `POST /api/integracoes/{canal}/aviso-lido` |
| `telas.txt` | 34 → **35** — entrou `cardapio-folha.html` |
| seção 12 | +2: a folha impressa, e ela dizer o mesmo preço que o cliente paga |
| seção 13 | +5: a ordem das seções do cardápio (a tela nova da v154) |
| seção 25 | +1: o recado do marketplace que espera ser marcado como lido |

**De passagem, um erro meu que vale registrar:** o extrator que eu escrevi para comparar os
endpoints do código com o inventário acusou 4 rotas novas e 1 sumida. Eram **3 novas e nenhuma
sumida** — o meu regex não casava `@GetMapping(value = "...", produces = "...")`, e por isso a
rota do `manifest` virava `GET /public` na minha lista. O inventário estava certo; o extrator é
que estava errado.
