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
$Servidor = 'ubuntu@56.126.177.18'
$Log      = Join-Path $Destino 'copias.log'
$DiasQueGuardamos = 30

function Anotar($texto) {
    $linha = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $texto
    Add-Content -Path $Log -Value $linha -Encoding UTF8
}

# ---------------------------------------------------------------------------------------------
# ENSAIO DE RESTAURACAO DA COPIA LOCAL, PENDURADO NESTA TAREFA
#
# ATE 18/11/2026 ESTA COPIA NUNCA HAVIA SIDO RESTAURADA. O que existia:
#   - `conferir-dump.sh`     prova que o arquivo esta INTEIRO ................ no servidor
#   - `ensaio-de-restauracao.sh` restaura e conta linhas, todo domingo ....... no servidor
#   - este script            confere que o byte count bate com o do servidor . aqui
# O byte count provando transferencia completa e forte, mas nao e a mesma coisa que provar que o
# arquivo RESTAURA. E justamente esta copia -- a unica fora da AWS -- era a que ninguem ensaiava.
# Eu rodei a mao em 18/11: restaurou, com 8 lojas, 13 usuarios, 268 produtos, 43 pedidos, schema V74.
# Mas "eu rodei uma vez" nao diz nada sobre o dump da semana que vem. Dai isto aqui.
#
# POR QUE PENDURADO NESTA TAREFA, E NAO NUMA TAREFA PROPRIA
# Porque esta tarefa PROVADAMENTE roda. Medido no copias.log: 45 dias, 2 falhas (07 e 08/11, o IP
# morto depois da queda da conta), e o `StartWhenAvailable` recupera dia perdido -- o atraso de
# 16/11 rodou as 08:28 de 17/11 e trouxe 8 arquivos. Uma tarefa agendada NOVA so vale depois de o
# dono registrar, e ja existe uma pendente de registro desde 08/11 (`vigia-site.ps1`). Mais uma
# nao-registrada seria mais uma coisa que nao roda.
#
# O ensaio NUNCA pode derrubar a copia: copia e o critico, ensaio e a conferencia. Por isso tudo
# aqui dentro de try/catch, chamado DEPOIS de a copia estar gravada e anotada.
function Ensaiar {
    $marca = Join-Path $Destino 'ULTIMO-ENSAIO.txt'
    $bash  = 'C:\Program Files\Git\bin\bash.exe'
    $script = Join-Path (Split-Path -Parent $PSCommandPath) 'ensaio-de-restauracao.sh'

    try {
        $ultimoOk = $null
        if (Test-Path $marca) {
            $t = (Get-Content $marca -First 1 -ErrorAction SilentlyContinue)
            if ($t -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+OK') {
                $ultimoOk = [datetime]::ParseExact($matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
            }
        }
        $dias = if ($ultimoOk) { ((Get-Date) - $ultimoOk).TotalDays } else { 9999 }

        # O AVISO VEM ANTES DA TENTATIVA, e sai em TODA copia enquanto estiver velho. Ensaio que
        # falha calado deixa a copia parecendo boa -- que e exatamente o estado em que ela estava.
        #
        # TUDO O QUE SAI PARA O LOG E ASCII, SEM ACENTO. Nao e desleixo: o PowerShell 5.1 le um
        # `.ps1` SEM BOM como ANSI, entao um "ha" com acento no fonte vira DOIS caracteres e o log
        # grava "hÃ¡". Medido em 18/11/2026 -- a primeira versao desta mensagem saiu assim. Todas as
        # mensagens originais deste script sao ASCII, e agora eu sei por que.
        if ($dias -gt 14) {
            $quanto = if ($ultimoOk) { "$([math]::Round($dias)) dia(s) atras" } else { 'NUNCA' }
            Anotar ("ATENCAO: a copia local nao e restaurada com sucesso desde: $quanto. " +
                    "Ela e a unica copia fora da AWS, e backup que ninguem restaura e esperanca.")
        }
        if ($dias -lt 7) { return }   # ensaiado esta semana: nada a fazer

        if (-not (Test-Path $bash))   { Anotar 'ensaio pulado: nao achei o bash do Git.'; return }
        if (-not (Test-Path $script)) { Anotar "ensaio pulado: nao achei $script."; return }
        # Docker desligado nao e defeito do backup: PULA sem mexer na marca, para tentar amanha.
        & docker version --format '{{.Server.Version}}' *> $null
        if ($LASTEXITCODE -ne 0) { Anotar 'ensaio pulado: o Docker nao esta respondendo. Tento amanha.'; return }

        $saida = & $bash $script '/c/bora-backups' 2>&1
        $codigo = $LASTEXITCODE
        # So as linhas de CONTAGEM ("ok: loja com 8 linha(s)"), mais qualquer FALHOU.
        #
        # Duas pedras aqui, as duas minhas, as duas medidas em 18/11/2026:
        #  1. A linha de veredito "ENSAIO OK: ... (Isto nao substitui a copia para FORA da
        #     instancia:" tem o parentese abrindo numa linha e fechando na seguinte. Entrando no
        #     resumo, o log terminava cortado no meio de uma frase.
        #  2. `-match` no PowerShell e INSENSIVEL a maiusculas por padrao, entao filtrar por 'ok: '
        #     casava tambem o 'ENSAIO OK:' -- e a correcao do item 1 nao funcionou. Por isso
        #     `-cmatch`: as contagens sao 'ok:' minusculo, o veredito e 'OK:' maiusculo.
        $resumo = ($saida | Where-Object { ($_ -cmatch '\sok: ') -or ($_ -match 'FALHOU') } |
                   ForEach-Object { ($_ -replace '^\S+\s+', '') -replace '^ok: ', '' }) -join ', '

        if ($codigo -eq 0) {
            Anotar "ENSAIO DE RESTAURACAO OK -- $resumo"
            Set-Content -Path $marca -Encoding UTF8 -Value @(
                ("{0} OK" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
                $resumo,
                'Este arquivo e lido pelo copiar-backup-bora.ps1 para saber quando ensaiar de novo.',
                'Uma linha que NAO comece com data + OK faz o proximo ensaio rodar.')
        } else {
            # NAO atualiza a marca: o aviso continua saindo em toda copia ate alguem resolver.
            Anotar "!!! O ENSAIO DE RESTAURACAO FALHOU (codigo $codigo). A COPIA LOCAL PODE NAO SERVIR."
            Anotar "    $resumo"
            $saida | Select-Object -Last 8 | ForEach-Object { Anotar "    $_" }
        }
    }
    catch {
        Anotar "ensaio nao rodou: $($_.Exception.Message)"
    }
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

    Ensaiar
}
catch {
    Anotar "FALHOU: $($_.Exception.Message)"
    exit 1
}
