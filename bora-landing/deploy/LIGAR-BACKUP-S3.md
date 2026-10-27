# Pôr os backups fora da instância

Hoje os 23 dumps do servidor existem **só no disco daquela máquina**. Se ela se perder, vão junto.
A única cópia fora é a pasta neste computador, que depende de ele estar ligado.

O script de backup **já está pronto** para isso desde a v135 — `backup-bora.sh:91` copia para o S3
quando `BORA_BACKUP_S3` está definida, e grita no log quando não está. O que falta é só do lado da
AWS, e é por isso que eu não consigo fazer: **o papel da instância não tem permissão nenhuma de S3**.

Medido em 23/10/2026, no servidor:

```
aws: [ERROR] ... assumed-role/AmazonLightsailInstanceRole/i-0d826e3a893c9b57a
     is not authorized to perform: s3:CreateBucket
```

**Reconferido em 27/10/2026, e segue igual** — o dono pediu para eu configurar e eu medi antes de
tentar:

```
aws: [ERROR]: An error occurred (AccessDenied) when calling the ListBuckets operation:
User: arn:aws:sts::938184885183:assumed-role/AmazonLightsailInstanceRole/i-0d826e3a893c9b57a
is not authorized to perform: s3:ListAllMyBuckets because no identity-based policy allows
the s3:ListAllMyBuckets action
```

E do lado de fora também não dá: o `aws` desta máquina responde `InvalidClientTokenId` — a
credencial configurada aqui não vale. Mesmo que valesse, anexar política no IAM é mudança de
permissão da conta, e isso não é coisa que eu faça sem ser eu quem assina.

A imagem `amazon/aws-cli:latest` **já está no servidor** (650 MB, conferido em 27/10), então a
primeira cópia não vai precisar baixar nada.

Criar bucket e anexar política são ações de conta, feitas no console da AWS com a sua credencial de
administrador. Eu não tenho, e não vou pedir.

**A boa notícia: nenhuma chave de acesso precisa ser criada.** O papel já existe e já devolve
credencial temporária para a instância. Falta só dar a ele a permissão de escrever num bucket.

---

## 1. Criar o bucket

No console da AWS, em **S3 → Create bucket**, ou pelo CloudShell:

```bash
aws s3api create-bucket \
  --bucket bora-backups-938184885183 \
  --region sa-east-1 \
  --create-bucket-configuration LocationConstraint=sa-east-1
```

O nome leva o número da conta porque **nome de bucket é global na AWS inteira** — sem algo único,
a criação falha com `BucketAlreadyExists` por causa de um bucket de outra pessoa.

Região **sa-east-1** (São Paulo), a mesma da instância: cópia dentro da região não paga tráfego.

Duas coisas que valem ligar junto, no mesmo lugar:

```bash
# Bloquear acesso público. Backup nunca é público.
aws s3api put-public-access-block --bucket bora-backups-938184885183 \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Apagar sozinho o que passar de 60 dias, para a conta não crescer para sempre.
# O backup local já se limpa em 14 dias; 60 no S3 dá folga para perceber um estrago antigo.
aws s3api put-bucket-lifecycle-configuration --bucket bora-backups-938184885183 \
  --lifecycle-configuration '{"Rules":[{"ID":"apagar-com-60-dias","Status":"Enabled","Filter":{"Prefix":"bora/"},"Expiration":{"Days":60}}]}'
```

## 2. Dar ao papel a permissão de escrever ali

Em **IAM → Roles → AmazonLightsailInstanceRole → Add permissions → Create inline policy**, aba
JSON, cole:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EscreverBackupDoBora",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::bora-backups-938184885183",
        "arn:aws:s3:::bora-backups-938184885183/bora/*"
      ]
    }
  ]
}
```

É o mínimo de propósito: **escrever e listar, e só**. Sem `s3:DeleteObject` — assim, mesmo que
alguém entre na instância, ele não apaga os backups antigos de lá. E sem `s3:GetObject`: para
restaurar você baixa pelo console, que é uma operação de gente, não de máquina.

## 3. Testar a cópia À MÃO, antes de ligar a variável

**Esta ordem não é capricho.** Quando a cópia para fora falha, o `backup-bora.sh` faz `exit 1`. E o
`deploy-api.sh` chama esse mesmo script no passo 7, com `set -euo pipefail`:

```bash
ssh ... '/home/ubuntu/backup-bora.sh && ls -t ~/backups/*.dump | head -1'
```

Então **variável ligada com a política errada = todo deploy aborta no passo 7**. Aborta do lado
seguro (antes de trocar o container, o site não cai), mas você fica sem conseguir subir versão até
arrumar. Medido no código em 27/10/2026.

Por isso: primeiro prove que a permissão funciona, com o mesmo container que o script usa, e só
depois ligue a variável.

```bash
ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33

# (a) listar o bucket — prova o s3:ListBucket
docker run --rm --network host -e AWS_REGION=sa-east-1 amazon/aws-cli:latest \
  s3 ls s3://bora-backups-938184885183/bora/

# (b) copiar o dump mais novo — prova o s3:PutObject, que é o que o backup faz
ARQ=$(ls -t ~/backups/bora-*.dump | head -1)
docker run --rm --network host -e AWS_REGION=sa-east-1 -v ~/backups:/bkp amazon/aws-cli:latest \
  s3 cp "/bkp/$(basename "$ARQ")" s3://bora-backups-938184885183/bora/ --storage-class STANDARD_IA
```

O (a) pode voltar vazio — bucket novo não tem nada dentro, e vazio é sucesso. O que importa é **não**
voltar `AccessDenied`.

## 4. Dizer ao script para onde copiar

Só depois do teste acima passar:

```bash
ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33
echo 'BORA_BACKUP_S3=s3://bora-backups-938184885183/bora' | sudo tee -a /etc/environment
```

O `backup-bora.sh` roda pelo cron, que não lê o `api.env` — por isso a variável vai no
`/etc/environment`, que o cron enxerga.

## 5. Conferir

```bash
/home/ubuntu/backup-bora.sh
```

Tem de aparecer no log:

```
copia para fora ok: s3://bora-backups-938184885183/bora/bora-AAAAMMDD-HHMM.dump
```

Em vez do aviso de hoje:

```
ATENCAO: sem copia para fora (BORA_BACKUP_S3 nao definido).
```

Se falhar, o script já diz o que rodar para descobrir o motivo — e o dump local continua bom e
conferido de qualquer jeito: a cópia para fora falhar nunca estraga o backup que já existe.

**Me avise quando terminar que eu confiro**: que o objeto chegou lá, que o log parou de avisar, e
que a permissão ficou restrita ao que está acima — nada a mais.

---

## Uma coisa que eu achei no caminho e que não é deste item

O `api.env` **não entra em backup nenhum**. O `backup-bora.sh` só o lê (`--env-file`, para pegar a
senha do banco); não copia. Hoje isso é contornável — o que tem lá são credenciais que se pegam de
volta com os provedores.

Mas **não ponha o `api.env` dentro do backup para resolver isso**: o dia em que a cifragem estiver
ligada, guardar a chave junto com os dados cifrados é a mesma coisa que não cifrar. A chave da
cifragem mora no gerenciador de senhas, e em nenhum outro lugar.
