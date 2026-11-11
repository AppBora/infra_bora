# Cifrar as credenciais que ficaram em texto puro no banco

Cifra em repouso (AES-256/GCM) as credenciais de terceiros que já estavam gravadas **antes** de a
chave `BORA_SEGREDO_COLUNAS` ser ligada, em 30/10/2026.

## Por que isto existe, e não o botão do painel

O painel tem o botão certo — **Configurações → Plataforma → "Cifrar o que já está gravado"** — e ele
faz exatamente isto. Use o botão sempre que der. Este programa é o mesmo trabalho por fora, para
quando quem está na frente do teclado **não tem login de administrador da plataforma**: o endpoint
exige `ctx.requireAdminBora()`.

Ele não reimplementa criptografia nenhuma. O `compilar.sh` **copia o
`SegredoGuardado.java` do backend** e confere o `md5` antes de compilar. Se o conversor mudar, este
programa muda com ele.

## O que ele nunca faz

Não imprime valor nenhum — nem claro, nem cifrado, nem a chave. Só nome de tabela, de coluna,
identificador da linha, tamanho e contagem. A chave entra **só** por `--env-file`, dentro do
container, e nunca aparece numa linha de comando.

## As três fases

As duas primeiras abortam **antes** de qualquer gravação:

1. **Prova da chave.** Decifra todo valor que já está com `enc:v1:` no banco. O GCM autentica o
   conteúdo: chave errada não abre, estoura. Abrir o que a API gravou prova que a chave na mão é a
   chave da API — prova criptográfica, sem precisar de backup em texto puro para poder voltar atrás.
   Zero valores já cifrados também aborta: sem material, não há prova.
2. **Prova de ida e volta**, em memória. Cifra cada valor em texto puro e decifra de volta; tem de
   voltar igual. Isto pega o caminho silencioso do conversor: quando a cifra falha por dentro, ele
   **devolve o texto puro** e só grita no log — sem esta conferência, gravaríamos claro achando que
   gravamos cifrado. Confere também se o cifrado **cabe** na coluna, porque o Postgres não corta
   valor maior que o limite: ele recusa, e a recusa desfaz a transação inteira.
3. **Gravação**, numa transação só. Ou cifra todas, ou não cifra nenhuma.

É idempotente: o filtro `not like 'enc:v1:%'` faz rodar de novo não achar nada.

## Como usar

```bash
# no PC, dentro desta pasta
./compilar.sh
scp -i ~/.ssh/bora-lightsail.pem -r build/classes build/lib rodar.sh \
    ubuntu@56.126.177.18:/home/ubuntu/cifrar/

# no servidor
/home/ubuntu/cifrar/rodar.sh conferir   # só mede, não grava
/home/ubuntu/cifrar/rodar.sh aplicar    # grava

# e depois, porque isto é ferramenta que escreve credencial:
rm -rf /home/ubuntu/cifrar
```

## A ordem importa quando uma coluna ENTRA na lista

Acrescentar uma coluna em `ALVOS` é sempre **duas coisas**: o `@Convert(SegredoGuardado)` na
entidade e a entrada na lista. **Cifrar antes de a API nova subir quebra a leitura daquela coluna**,
porque o código antigo lê o `enc:v1:...` cru e o usa como se fosse o valor. Primeiro o deploy,
depois o `aplicar`.

## O que já foi feito com ele

**11/11/2026** — 20 credenciais cifradas em produção, numa transação, em 1 segundo:
6 `config_plataforma.valor`, 4 `integracao_canal.client_secret`, 8 `webhook_token`,
1 `access_token`, 1 `refresh_token`. A prova da chave abriu os 19 valores que a API já havia
cifrado; depois do commit, 39 cifradas e 0 em texto puro. Dois segundos depois, as 5 lojas da Zirá e
o iFood da loja 1 buscaram pedido normalmente, com 0 erro no log — a API lendo as credenciais já
cifradas.

**11/11/2026, mais tarde** — a 21ª, `loja.asaas_webhook_token` da loja 18, **depois** do deploy da
v158 (a ordem da seção acima). Ficaram 40 cifradas e 0 em texto puro.

A prova de que a API passou a ler o valor **decifrado**, e não o `enc:v1:` cru, foi um teste que
**distingue as duas coisas**: mandar no webhook do PIX o próprio texto cifrado como token. Na v157
isso seria **aceito** (200); na v158 voltou **401 "Token inválido"**. Um 401 sozinho não provaria
nada — token errado dá 401 de qualquer jeito —; prova porque na versão errada o mesmo request dava
200. Vale como molde para qualquer coluna cifrada que seja **comparada** em vez de apenas lida.

E duas armadilhas que custaram tempo: dentro do container **não existe o prefixo `/api`** (o Caddy
é que o remove), então `/api/public/...` cai em "Não autenticado" e devolve 401 sem chegar ao
método — por isso o teste acima lê o **corpo** da resposta, não só o código. E os dumps antigos
continuam com as credenciais em texto puro: cifrar o banco não limpa backup nenhum.
