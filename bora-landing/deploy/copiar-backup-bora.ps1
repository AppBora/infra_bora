# Traz para este computador o backup do banco do BoraHapp que está no servidor.
#
# Por que isto existe: os backups diários nascem e ficam no MESMO disco da instância da AWS. Se a
# instância se perder, eles se perdem junto — e aí não há backup nenhum. Esta cópia é a segunda
# perna. Quando houver credencial da AWS, o lugar certo passa a ser um bucket S3 (o comando já está
# marcado no fim de /home/ubuntu/backup-bora.sh no servidor), e aí isto aqui vira redundância.
#
# Roda sozinho pela tarefa agendada "BoraHapp - copia do backup", uma vez por dia. Se o computador
# estiver desligado na hora, o Windows roda assim que ele ligar.
#
# ITEM 9.10 DA VARREDURA (medido em 23/10/2026)
#
# O destino era 'C:\Users\user\OneDrive\Desktop\Bora\backups-bora' -- DENTRO do OneDrive. Medindo:
# 53 dumps, 171 MB, cada um com o banco inteiro: telefone, endereco e CPF de todo cliente de todas
# as lojas. No servidor esses arquivos nascem 600 de proposito; a protecao nao atravessa a copia, e
# dali em diante eles viravam copia sincronizada na nuvem da Microsoft, com o alcance de quem tiver
# acesso aquela conta.
#
# O destino agora e uma pasta LOCAL, fora de qualquer sincronizacao. A funcao de "segunda perna"
# continua valendo -- o arquivo esta noutra maquina, que e o que importa se a instancia da AWS se
# perder; so nao esta mais na nuvem de terceiro.
#
# OS ARQUIVOS ANTIGOS CONTINUAM NO ONEDRIVE. Mover ou apagar dado de cliente ja copiado e decisao do
# dono, nao deste script -- e o log de cada copia volta a avisar enquanto houver algum la.

$ErrorActionPreference = 'Stop'

$Destino  = 'C:\bora-backups'
$Antigo   = 'C:\Users\user\OneDrive\Desktop\Bora\backups-bora'
$Chave    = 'C:\Users\user\.ssh\bora-lightsail.pem'
$Servidor = 'ubuntu@18.230.57.33'
$Log      = Join-Path $Destino 'copias.log'
$DiasQueGuardamos = 30

function Anotar($texto) {
    $linha = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $texto
    Add-Content -Path $Log -Value $linha -Encoding UTF8
}

try {
    if (-not (Test-Path $Destino)) { New-Item -ItemType Directory -Path $Destino | Out-Null }

    # Traz todos os dumps que o servidor tem (ele já guarda só os 14 últimos). O scp sobrescreve o
    # que for igual, então rodar duas vezes no mesmo dia não duplica nada.
    $antes = @(Get-ChildItem -Path $Destino -Filter 'bora-*.dump' -ErrorAction SilentlyContinue).Count
    & 'C:\Windows\System32\OpenSSH\scp.exe' -i $Chave -o StrictHostKeyChecking=no -q `
        "$Servidor`:/home/ubuntu/backups/bora-*.dump" $Destino
    if ($LASTEXITCODE -ne 0) { throw "scp terminou com codigo $LASTEXITCODE" }

    $arquivos = @(Get-ChildItem -Path $Destino -Filter 'bora-*.dump' | Sort-Object LastWriteTime -Descending)
    if ($arquivos.Count -eq 0) { throw 'nenhum backup veio do servidor' }

    # Um dump do Bora tem cerca de 3 MB. Arquivo muito menor que isso é sinal de cópia truncada —
    # melhor gritar agora do que descobrir no dia em que precisar restaurar.
    $maisNovo = $arquivos[0]
    if ($maisNovo.Length -lt 500KB) { throw "o backup mais novo veio pequeno demais ($($maisNovo.Length) bytes)" }

    # A assinatura PGDMP NAO prova nada sobre o arquivo estar inteiro: ela esta nos primeiros 5
    # bytes e sobrevive a qualquer truncamento -- provado em 21/10 (item 9.8), com um dump cortado em
    # 90% passando nesta mesma conferencia. Fica como sanidade de formato, e nada mais.
    $marca = [System.Text.Encoding]::ASCII.GetString([byte[]](Get-Content $maisNovo.FullName -Encoding Byte -TotalCount 5))
    if ($marca -ne 'PGDMP') { throw "o arquivo nao parece um backup do Postgres (comeca com '$marca')" }

    # O que PROVA que a copia chegou inteira: o tamanho tem que ser o MESMO do arquivo no servidor.
    # (Que o dump em si nao esta cortado, quem garante e o conferir-dump.sh, que roda LA, com
    # pg_restore de verdade, antes deste arquivo existir.)
    $tamanhoLa = & 'C:\Windows\System32\OpenSSH\ssh.exe' -i $Chave -o StrictHostKeyChecking=no `
        $Servidor "stat -c %s /home/ubuntu/backups/$($maisNovo.Name)"
    if ($LASTEXITCODE -eq 0 -and $tamanhoLa) {
        if ([int64]$tamanhoLa -ne $maisNovo.Length) {
            throw "a copia chegou incompleta: $($maisNovo.Length) bytes aqui, $tamanhoLa no servidor"
        }
    } else {
        Anotar 'ATENCAO: nao consegui conferir o tamanho no servidor; a copia nao foi verificada.'
    }

    Get-ChildItem -Path $Destino -Filter 'bora-*.dump' |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DiasQueGuardamos) } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $novos = $arquivos.Count - $antes
    Anotar ("ok: {0} arquivo(s) aqui, {1} novo(s). Mais recente: {2} ({3:N1} MB)" -f `
        $arquivos.Count, [Math]::Max($novos, 0), $maisNovo.Name, ($maisNovo.Length / 1MB))

    # Item 9.10: enquanto houver dump na pasta antiga, ele esta sincronizado na nuvem. O aviso fica
    # no log de TODA copia, em vez de ser dito uma vez e esquecido.
    $sobrando = @(Get-ChildItem -Path $Antigo -Filter 'bora-*.dump' -ErrorAction SilentlyContinue)
    if ($sobrando.Count -gt 0) {
        $mb = [Math]::Round(($sobrando | Measure-Object -Property Length -Sum).Sum / 1MB, 0)
        Anotar ("ATENCAO (item 9.10): ainda ha {0} dump(s), {1} MB, em '{2}' -- pasta SINCRONIZADA na " +
                "nuvem. Cada um tem telefone, endereco e CPF de todo cliente. Mover ou apagar e " +
                "decisao do dono." -f $sobrando.Count, $mb, $Antigo)
    }
}
catch {
    Anotar "FALHOU: $($_.Exception.Message)"
    exit 1
}
