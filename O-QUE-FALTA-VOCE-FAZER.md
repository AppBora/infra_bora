# O que falta, e é só você que pode fazer

Atualizado em **23/10/2026**. Três coisas. Nenhuma delas é código — todas dependem de uma conta que
é sua. Em todas eu já deixei o terreno pronto: o que falta é o clique.

Estão em ordem de prazo.

---

## 1. A Zirá perde o acesso em **26/10** — faltam 3 dias

### O que eu medi na produção

- Ela **pagou R$ 398** em 15/10. Os dois pagamentos de R$ 199 **estão registrados** no nosso banco,
  um deles pelo "Recebi o pagamento" (PIX direto na conta).
- O registro liberou o acesso dela **sem data de fim**, que é o correto.
- **Depois disso, o Asaas desfez:** a assinatura lá está **CANCELADA**, e o evento de cancelamento
  colocou o acesso dela de volta em `26/10`.
- O corte por falta de pagamento **está ligado** no servidor (confirmei no log de subida da API). Em
  26/10 ela sai do ar.

O código já previa esse risco — está escrito no comentário do próprio método: *"o registro manual
seria desfeito pelo próprio Asaas"*. O que faltava era a guarda que impedisse: o ramo de
cancelamento **encurtava** o prazo de quem já tinha mais. **Isso foi consertado na v139** e não
acontece mais com ninguém. Mas o prazo dela já está em 26/10, e isso é uma decisão sua.

### Opção A — liberar o acesso pelo painel (1 minuto, feito na v139)

1. Entre em **Configurações › Plataforma** com sua conta de administrador.
2. Na linha da **Zirá Açaíteria**, clique em **🔓 Liberar acesso**.
3. Informe até quando (sugiro 30 dias) e o motivo. Exemplo de motivo:
   `pagou R$ 398 em 15/10, o Asaas cancelou a assinatura depois`.

Isso **não registra pagamento nenhum**, não mexe no Asaas e não muda o status da assinatura — mexe só
na data que o bloqueio olha, e fica registrado quem liberou e por quê. Máximo de 180 dias por vez, de
propósito: liberar sem fim por engano é fácil de fazer e difícil de notar.

### Opção B — refazer a assinatura no Asaas

Você recria a assinatura dela lá, o webhook chega e o acesso volta sozinho. Eu não mexo na sua conta
financeira. Me avise depois que eu confiro se entrou.

> As duas resolvem o acesso. A diferença é que a **A** não volta a cobrar, e a **B** volta.

---

## 2. Backup para fora da instância — e a boa notícia: **nenhuma chave precisa ser criada**

### O que eu medi

- **Não existe cópia para fora feita pelo servidor.** Hoje a segunda perna é só a cópia para o seu
  computador (`C:\bora-backups`, que agora está fora do OneDrive).
- A instância **já tem um papel IAM** (`AmazonLightsailInstanceRole`) e ele **já devolve credencial
  temporária**. Testei: o que falta é só a permissão de S3. Um `aws s3 ls` volta
  `AccessDenied ... no identity-based policy allows s3:ListAllMyBuckets`.
- Também não havia o `aws` instalado na máquina — a linha do script nunca teria funcionado. **Isso já
  foi consertado:** agora a cópia roda pelo container oficial da AWS.

Isso muda o que falta, e para melhor: **você não precisa criar chave de acesso nenhuma.** Sem chave
criada, sem chave guardada, sem chave para vazar — a credencial é temporária e a própria AWS a troca.

### Os três passos

**Passo 1 — criar o bucket** (Console AWS › S3 › *Criar bucket*):

- Nome: algo único, por exemplo `bora-backups-prod`
- Região: **América do Sul (São Paulo) · sa-east-1** — a mesma da instância
- **Bloquear todo o acesso público: LIGADO** (é o padrão; não mude)
- Versionamento: ligado, se quiser proteção extra contra apagar por engano

**Passo 2 — dar permissão ao papel que já existe** (Console AWS › IAM › Funções ›
`AmazonLightsailInstanceRole` › *Adicionar permissões* › *Criar política em linha* › aba JSON):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::bora-backups-prod",
        "arn:aws:s3:::bora-backups-prod/*"
      ]
    }
  ]
}
```

Troque `bora-backups-prod` pelo nome que você deu. Só `PutObject` e `ListBucket`: a instância precisa
**escrever** backup, não apagar nem ler os antigos.

**Passo 3 — me avisar.** Eu acrescento `BORA_BACKUP_S3=s3://bora-backups-prod/bora` no servidor, rodo
um backup e confiro que o arquivo chegou lá. A partir daí toda cópia é automática, de 6 em 6 horas.

---

## 3. Credenciais de terceiros em texto puro no banco

### O que eu medi

`BORA_SEGREDO_COLUNAS` **não está definida**. A API avisa isso toda vez que sobe:

> `BORA_SEGREDO_COLUNAS não definido: as credenciais de Asaas e marketplace continuam em TEXTO PURO
> no banco e nos dumps.`

Na prática: a chave do Asaas de cada loja, os segredos de iFood e 99, e os tokens de webhook estão
legíveis para quem abrir o banco — ou qualquer um dos dumps.

### Por que eu não faço

**Eu não crio nem digito segredo.** Essa linha eu não cruzo, nem com permissão. O valor tem que
nascer com você e ser guardado por você.

### O que fazer

**Passo 1 — gerar a chave**, no seu computador (PowerShell):

```bash
powershell -NoProfile -Command "[Convert]::ToBase64String((1..32|%{Get-Random -Max 256}))"
```

**Passo 2 — guardar essa chave fora do servidor**, antes de qualquer outra coisa. Gerenciador de
senhas, cofre, papel no cofre — onde você quiser, mas **fora da instância**.

> **Se essa chave se perder, as credenciais cifradas não voltam.** É o único passo sem volta aqui.

**Passo 3 — colocar no servidor:**

```bash
ssh -i "$HOME/.ssh/bora-lightsail.pem" ubuntu@18.230.57.33 "echo 'BORA_SEGREDO_COLUNAS=COLE_AQUI' >> /home/ubuntu/bora/api.env && docker restart api"
```

**Passo 4 — me avisar.** Ligar a chave cifra só o que for gravado **dali para frente**; o que já está
no banco continua em texto puro. Eu rodo o serviço que recifra o que já está gravado (`POST
/admin-bora/seguranca/cifragem`), confiro no banco que não sobrou nada legível, e te mostro o número.
Isso já tem 9 testes contra Postgres de verdade provando que funciona e que rodar duas vezes não
estraga nada.

---

## O que **não** depende de você, e já está feito

- Os 53 dumps com dado de cliente **saíram do OneDrive** (movidos, não apagados, para
  `C:\bora-backups`). A cópia nova já vai direto para lá.
- O backup passou a rodar **de 6 em 6 horas** em vez de uma vez por dia.
- O backup agora é **ensaiado toda semana**: ele é restaurado de verdade num banco descartável e as
  linhas são contadas. O primeiro ensaio rodou em 23/10: 5 lojas, 13 usuários, 125 produtos, 32
  pedidos.
- O cancelamento no Asaas **não encurta mais** o prazo de quem já tinha acesso maior.

---

## Duas decisões que continuam suas (sem prazo)

1. **Pedido de teste de marketplace conta no faturamento.** Hoje são R$ 104, tudo de setembro.
2. **A taxa de entrega que o marketplace fica conta no faturamento.** Hoje são R$ 10.

As duas mudam um número que você olha todo dia, por isso não mexi. A tela de Relatórios já mostra o
tamanho da taxa embaixo do faturamento. Quando quiser, é meio dia de trabalho cada uma.
