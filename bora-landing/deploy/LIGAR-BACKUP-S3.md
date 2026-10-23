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

## 3. Dizer ao script para onde copiar

No servidor:

```bash
ssh -i ~/.ssh/bora-lightsail.pem ubuntu@18.230.57.33
echo 'BORA_BACKUP_S3=s3://bora-backups-938184885183/bora' | sudo tee -a /etc/environment
```

O `backup-bora.sh` roda pelo cron, que não lê o `api.env` — por isso a variável vai no
`/etc/environment`, que o cron enxerga.

## 4. Conferir

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
