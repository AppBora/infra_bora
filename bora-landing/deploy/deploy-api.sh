#!/usr/bin/env bash
#
# Sobe uma versao nova da API, com backup antes e rollback automatico se ela nao ficar sadia.
#
# POR QUE ISTO EXISTE
# O deploy era um roteiro de memoria: build, docker save, scp, docker load, stop, rm, run. Nada disso
# estava no repositorio, e cada passo tinha uma pegadinha que so se descobria errando:
#   - a rede chama `bora`, nao `bora_rede`
#   - o container chama `api`, nao `bora-api` (um deploy inteiro foi perdido por isso: o container novo
#     passava no health e nao recebia trafego)
#   - o `docker rm -f api` apaga os logs do que estava rodando, justo quando se investiga um defeito
#   - se o `docker run` falhasse, a API ficava FORA DO AR ate alguem notar
# E o backup antes do deploy nunca aconteceu, porque dependia de alguem lembrar.
#
# COMO USAR
#   ./deploy-api.sh v113
# De dentro de bora-landing/deploy, com a chave em ~/.ssh/bora-lightsail.pem.
#
# O QUE ELE NAO FAZ
# Nao roda os testes: quem roda e o `mvn package` dentro do Dockerfile, no build da imagem. Se um teste
# falhar, a imagem nao nasce e este script nao chega a rodar.
# Nao sobe o frontend (e `scp` da pasta, outro caminho).

set -euo pipefail

TAG="${1:-}"
[ -n "$TAG" ] || { echo "uso: $0 vNNN"; exit 1; }

SRV="ubuntu@56.126.177.18"
KEY="$HOME/.ssh/bora-lightsail.pem"
BACKEND="$(cd "$(dirname "$0")/../../bora-fase-3-backend-java" && pwd)"
TGZ="/tmp/bora-api-$TAG.tgz"

dizer() { printf '\n=== %s\n' "$*"; }

dizer "1/9 a arvore do backend esta limpa?"
if [ -n "$(git -C "$BACKEND" status --porcelain)" ]; then
  echo "ABORTADO: ha mudanca nao commitada no backend." >&2
  echo "A imagem copia o src do disco, entao subiria codigo que nao esta no Git." >&2
  git -C "$BACKEND" status --short >&2
  exit 1
fi
COMMIT="$(git -C "$BACKEND" rev-parse --short HEAD)"
echo "commit $COMMIT"

dizer "2/9 a data dos Termos: codigo, checkout e PAGINA NO AR"
# A versao gravada no aceite de cada lojista aponta para ESTE texto. Se a constante e a pagina
# divergirem, o comprovante aponta para um documento que ninguem sabe qual e -- num texto que fala de
# pagamento, suspensao e reembolso.
#
# ESTE PASSO MEDE DUAS COISAS, e a segunda e o conserto (pente fino de 29/10/2026). O anuncio dizia
# "a pagina publicada" e media o ARQUIVO DO CHECKOUT: o VersaoDosTermosTest le
# `../bora-landing/termos.html`, do disco. E o proprio deploy-frontend.sh registra que a landing e
# publicada a parte -- entao o arquivo do checkout pode estar adiantado (ou atrasado) em relacao ao
# que o lojista le de verdade. O portao parecia cobrir o que nao cobria.
#
# O teste fica: ele guarda codigo contra checkout, e e ele que roda dentro do `mvn`. O que entra e a
# conferencia por HTTP da pagina que esta no ar.
( cd "$BACKEND" && mvn -q -o test -Dtest=VersaoDosTermosTest )   || { echo "ABORTADO: a data dos Termos no codigo nao bate com o termos.html DESTE checkout." >&2; exit 1; }

TERMOS_URL="${BORA_TERMOS_URL:-https://borahapp.com.br/termos.html}"
NO_CODIGO="$(grep -oE 'VERSAO_VIGENTE = "[0-9]{4}-[0-9]{2}-[0-9]{2}"' \
    "$BACKEND/src/main/java/br/com/bora/service/TermosService.java" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')"
[ -n "$NO_CODIGO" ] || { echo "ABORTADO: nao achei a constante VERSAO_VIGENTE no TermosService." >&2; exit 1; }
NO_AR_TEXTO="$(curl -fsS --max-time 20 "$TERMOS_URL" 2>/dev/null \
    | grep -oE 'Última atualização:</b> [0-9]{1,2} de [^<]+ de [0-9]{4}' | head -1)"
if [ -z "$NO_AR_TEXTO" ]; then
  echo "ABORTADO: nao consegui ler a data dos Termos em $TERMOS_URL." >&2
  echo "Sem isso este passo volta a medir so o arquivo do checkout, que nao e o que o lojista le." >&2
  echo "Se a pagina mudou de endereco, ajuste BORA_TERMOS_URL." >&2
  exit 1
fi
# "Última atualização:</b> 4 de outubro de 2026" -> "2026-10-04".
# Os campos sao contados DO FIM: ano=$NF, mes=$(NF-2), dia=$(NF-4). Contar do inicio ($2 para o dia)
# erra, porque o "Última atualização:</b>" ocupa os dois primeiros campos -- foi o que o ensaio
# mostrou, saindo 2026-10-00.
NO_AR="$(echo "$NO_AR_TEXTO" | awk '
  BEGIN{split("janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro",m," ");
        for(i=1;i<=12;i++) n[m[i]]=i}
  {printf "%s-%02d-%02d", $NF, n[$(NF-2)], $(NF-4)}')"
case "$NO_AR" in
  [0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]) ;;
  *) echo "ABORTADO: nao soube converter \"$NO_AR_TEXTO\" em data (saiu \"$NO_AR\")." >&2
     echo "A linha de Última atualização mudou de forma; ajuste este passo." >&2
     exit 1 ;;
esac
if [ "$NO_AR" != "$NO_CODIGO" ]; then
  echo "ABORTADO: a pagina NO AR diz \"$NO_AR_TEXTO\" (= $NO_AR) e o codigo diz $NO_CODIGO." >&2
  echo "O aceite de cada lojista aponta para a data do codigo. Publique a landing primeiro, ou" >&2
  echo "corrija a constante -- as duas metades andam juntas." >&2
  exit 1
fi
echo "ok: codigo, checkout e pagina no ar dizem $NO_CODIGO"

# ==================================================================================================
# A MIGRACAO NOVA DEIXA O ROLLBACK FUNCIONAR? (medido em 19/11/2026)
#
# O passo 9 deste script faz rollback quando a versao nova nao fica sadia -- e o rollback sobe a
# imagem ANTIGA contra o banco que a nova JA MIGROU. Isso nunca tinha sido testado, e era o maior
# risco nao medido da infra.
#
# EU TESTEI. Subi a `bora-api:v170` (que conhece ate a V76) contra um Postgres migrado em V77:
#
#   Successfully validated 77 migrations
#   WARN: Schema "public" has a version (77) that is newer than the latest available migration (76) !
#   Schema "public" is up to date. No migration necessary.
#   health CHEIO: HTTP 200   |   cardapio da loja 1: HTTP 200
#
# Ou seja: o Flyway TOLERA schema mais novo que o codigo, com um aviso, e a aplicacao antiga sobe e
# funciona. O rollback esta seguro -- PARA MIGRACAO ADITIVA.
#
# O QUE CONTINUA PERIGOSO, e e o que este bloco confere: migracao que APAGA ou RENOMEIA o que o
# codigo antigo le. Nesse caso o Flyway nao reclama de nada (ele valida historico, nao expectativa
# de codigo) e o rollback sobe uma aplicacao que consulta coluna que nao existe mais. Falha em
# tempo de consulta, com cliente no ar, e nao no health.
#
# Quais migracoes conferir: so as que entraram DESDE o commit da imagem que esta em producao. O
# proprio deploy grava esse commit como label `git` na imagem, e e dele que sai o intervalo.
# ==================================================================================================
dizer "2.5/9 a migracao nova deixa o rollback funcionar?"
COMMIT_NO_AR="$(ssh -i "$KEY" "$SRV" \
  'docker inspect api --format "{{index .Config.Labels \"git\"}}" 2>/dev/null' 2>/dev/null | tr -d '\r')"
if [ -z "$COMMIT_NO_AR" ]; then
  echo "   nao consegui ler o commit da imagem em producao (label 'git'). Sem o intervalo eu nao" >&2
  echo "   sei quais migracoes sao novas -- CONFIRA A MAO se alguma apaga ou renomeia coluna." >&2
elif ! git -C "$BACKEND" cat-file -e "$COMMIT_NO_AR^{commit}" 2>/dev/null; then
  echo "   o commit em producao ($COMMIT_NO_AR) nao existe neste repositorio. CONFIRA A MAO." >&2
else
  NOVAS="$(git -C "$BACKEND" diff --name-only --diff-filter=AM \
      "$COMMIT_NO_AR..HEAD" -- src/main/resources/db/migration || true)"
  if [ -z "$NOVAS" ]; then
    echo "   nenhuma migracao nova desde $COMMIT_NO_AR -- o rollback nao tem risco de schema."
  else
    echo "   migracoes novas desde $COMMIT_NO_AR:"
    printf '     %s\n' $NOVAS
    PERIGO=""
    for M in $NOVAS; do
      ARQ="$BACKEND/$M"
      [ -f "$ARQ" ] || continue
      # Sem comentario, para "-- drop column" nao virar alarme. E so o que o codigo ANTIGO poderia
      # estar lendo: apagar/renomear coluna ou tabela, e trocar tipo de coluna que ja existia.
      CORPO="$(sed -E 's/--.*$//' "$ARQ" | tr '\n' ' ' | tr -s ' ')"
      if echo "$CORPO" | grep -qiE 'drop +column|drop +table|rename +column|rename +to|alter +column +[a-z_]+ +type'; then
        PERIGO="$PERIGO $M"
      fi
    done
    if [ -n "$PERIGO" ]; then
      echo "" >&2
      echo "   !!! ATENCAO: estas migracoes NAO sao aditivas:$PERIGO" >&2
      echo "   O rollback do passo 9 sobe a imagem ANTIGA contra o banco JA MIGRADO. Com coluna" >&2
      echo "   apagada ou renomeada, a aplicacao antiga sobe e QUEBRA na consulta -- com cliente no" >&2
      echo "   ar, e nao no health. Medido em 19/11/2026: o Flyway nao reclama disso." >&2
      echo "   Se for seguir, tenha o dump a mao e saiba que o rollback automatico pode nao salvar." >&2
      echo "   Para seguir de proposito: PODA_MANTER=... ACEITO_RISCO_DE_ROLLBACK=1 ./deploy-api.sh $TAG" >&2
      [ "${ACEITO_RISCO_DE_ROLLBACK:-}" = "1" ] || exit 1
      echo "   (ACEITO_RISCO_DE_ROLLBACK=1 -- seguindo por decisao de quem rodou)" >&2
    else
      echo "   ok: todas aditivas -- o rollback sobe a imagem antiga sem quebrar."
    fi
  fi
fi

dizer "3/9 build da imagem (os testes rodam aqui dentro)"
docker build --label "git=$COMMIT" -t "bora-api:$TAG" "$BACKEND"

dizer "4/9 teste de subida contra banco inexistente"
# A causa raiz tem que ser "Connection refused" e nada mais. Isto pega bean quebrado, consulta JPQL
# malformada e coluna fora do lugar ANTES de o container de producao parar.
SAIDA="$(docker run --rm \
  -e SPRING_DATASOURCE_URL='jdbc:postgresql://127.0.0.1:1/naoexiste' \
  -e SPRING_DATASOURCE_USERNAME=x -e SPRING_DATASOURCE_PASSWORD=y \
  -e BORA_JWT_SECRET=um-segredo-de-teste-com-mais-de-32-bytes-aqui \
  "bora-api:$TAG" 2>&1 | grep -c 'Connection refused' || true)"
[ "$SAIDA" -gt 0 ] || { echo "ABORTADO: a aplicacao nao subiu por outro motivo que nao o banco." >&2; exit 1; }
echo "ok: a unica causa raiz foi Connection refused"

dizer "5/9 transferencia"
docker save "bora-api:$TAG" | gzip -1 > "$TGZ"
scp -i "$KEY" "$TGZ" "$SRV:/tmp/"
ssh -i "$KEY" "$SRV" "gunzip -c $TGZ | docker load && rm -f $TGZ"
rm -f "$TGZ"

dizer "6/9 a imagem que chegou e a mesma?"
# O ID da imagem muda na transferencia; a ULTIMA camada, que carrega o app.jar, nao.
CAMADA_LOCAL="$(docker inspect "bora-api:$TAG" --format '{{json .RootFS.Layers}}' | tr ',' '\n' | tail -1 | tr -d '"]')"
CAMADA_REMOTA="$(ssh -i "$KEY" "$SRV" "docker inspect bora-api:$TAG --format '{{json .RootFS.Layers}}'" | tr ',' '\n' | tail -1 | tr -d '"]')"
[ "$CAMADA_LOCAL" = "$CAMADA_REMOTA" ] || { echo "ABORTADO: a camada do app.jar difere." >&2; exit 1; }
echo "ok: $CAMADA_LOCAL"

dizer "7/9 BACKUP antes de trocar"
ssh -i "$KEY" "$SRV" '/home/ubuntu/backup-bora.sh && ls -t ~/backups/*.dump | head -1'

# ITEM 9.2 DA VARREDURA: o passo 8 nao tinha rollback.
#
# Ele ja paravam e RENOMEIA o container antigo antes de subir o novo. Se o `docker run` falhasse --
# imagem ruim, env-file faltando, porta ocupada --, o `set -e` matava o script ANTES do passo 9, e nao
# existia mais container chamado `api`: o site ficava no chao, e o rollback que o passo 9 tem nunca
# era alcancado. O proprio cabecalho deste script dizia que era isso que ele queria evitar.
#
# Agora os dois passos usam o MESMO rollback, e ele e uma funcao.
#
# E O ROLLBACK APAGAVA O CONTAINER SADIO (achado pelo QA em 18/11/2026).
# -----------------------------------------------------------------------------------------------
# Ele comecava SEMPRE com `docker rm -f api`, partindo de que o `api` que esta la e o container NOVO
# e ruim, e que o bom esta guardado em `api-anterior`. Isso e verdade em UM dos quatro pontos em que
# o passo 8 pode falhar. Nos outros tres o `api` que esta la E O BOM, e o rollback o destruia:
#
#   docker tag bora-api:$TAG bora-api:latest   <- falha (tag inexistente, disco cheio)
#        estado: `api` RODANDO e sadio, servindo o site. `api-anterior` nao existe.
#        rollback antigo: rm -f api (DESTROI O SADIO) -> rename falha -> start falha.
#        resultado: NAO EXISTE container api. Site no chao.
#
#   docker stop -t 30 api                      <- falha
#        estado: `api` existe (talvez rodando). `api-anterior` nao existe.
#        resultado: o mesmo. Site no chao.
#
#   docker rename api api-anterior             <- falha
#        estado: `api` existe PARADO, com a imagem boa. `api-anterior` nao existe.
#        resultado: o mesmo. Site no chao.
#
#   docker run -d --name api ...               <- falha
#        estado: `api` nao existe; `api-anterior` e o bom.  <-- O UNICO caso que o rollback tratava.
#
# E nao havia volta depois: eu li o vigia-bora.sh para conferir, e quando nao existe `api` ele tenta
# `api-anterior` e, nao achando, escreve "ISTO PRECISA DE MAO HUMANA" e desiste. Ou seja: uma falha
# num passo inofensivo -- um nome de tag errado -- derrubava a producao ate alguem entrar no servidor
# de madrugada e rodar `docker run` a mao.
#
# AGORA A DECISAO E POR FATO, NAO POR SUPOSICAO: existe `api-anterior`?
#   existe   -> o rename aconteceu, logo o `api` de agora e o novo. Apaga e devolve o anterior.
#   nao existe -> o rename NAO aconteceu, logo o `api` de agora E O BOM. NAO SE APAGA.
#                 So religa (o `stop` pode ter passado) e desfaz a tag.
#
# A logica fica entre os marcadores abaixo porque `deploy/teste-do-rollback.sh` a EXTRAI e roda
# contra containers de mentira no docker local, nos quatro casos. Nao da para ensaiar um deploy de
# verdade sem derrubar o site, mas da para provar a decisao.
rollback() {
  echo "ROLLBACK: devolvendo a versao anterior." >&2
  ssh -i "$KEY" "$SRV" 'docker logs --tail 40 api 2>&1 | tail -40' >&2 || true
  ssh -i "$KEY" "$SRV" "bash -s" <<'FIM_DO_ROLLBACK'
# >>>>> INICIO DA LOGICA DO ROLLBACK (extraida pelo teste-do-rollback.sh) >>>>>
if docker inspect api-anterior >/dev/null 2>&1; then
  echo "rollback: existe api-anterior, entao o 'api' de agora e o container NOVO. Trocando."
  docker rm -f api >/dev/null 2>&1 || true
  docker rename api-anterior api
  docker start api >/dev/null
else
  echo "rollback: NAO existe api-anterior, entao o 'api' de agora E O BOM. NAO vou apagar."
  # O `stop` do passo 8 pode ter passado antes da falha: religa. Se ja estiver de pe, start nao faz
  # nada e devolve 0.
  docker start api >/dev/null 2>&1 || true
fi
# A tag volta nos dois casos: `anterior` foi gravada no inicio do passo 8 e aponta para a imagem que
# estava no ar. Quando o `docker tag ... latest` nem chegou a rodar, isto e um no-op.
docker tag bora-api:anterior bora-api:latest 2>/dev/null || true
# <<<<< FIM DA LOGICA DO ROLLBACK <<<<<
FIM_DO_ROLLBACK
  # Nao anuncia sucesso sem olhar: rollback que falha calado e pior que o deploy que falhou.
  if ssh -i "$KEY" "$SRV" 'for i in $(seq 1 20); do
        docker exec api curl -fs localhost:8080/actuator/health 2>/dev/null | grep -q UP && exit 0
        sleep 3
      done; exit 1'; then
    echo "rollback feito: a versao anterior esta de volta e SADIA." >&2
  else
    echo "!!! O ROLLBACK NAO FICOU SADIO. O SITE PODE ESTAR FORA DO AR. Entre no servidor:" >&2
    echo "    ssh -i $KEY $SRV 'docker ps -a; docker logs --tail 50 api'" >&2
    ssh -i "$KEY" "$SRV" 'docker ps -a --format "{{.Names}}  {{.Status}}"' >&2 || true
  fi
  exit 1
}

dizer "8/9 troca do container, guardando o anterior"
# O `api-anterior` SOBRANDO e removido ANTES de qualquer coisa (pente fino de 29/10/2026).
#
# O bloco abaixo roda com `set -e` e faz `docker rename api api-anterior`. Esse rename FALHA se ja
# existir um container com esse nome -- e a limpeza do passo 9 era `docker rm api-anterior ... || true`,
# sem `-f`: ela falha calada quando o container esta de pe por qualquer motivo, e o `|| true` engole.
#
# O estrago nao e o deploy falhar, e o que vem depois: com o rename falhando, o script cai no
# rollback, que faz `docker rm -f api` (apagando o container BOM, que acabou de ser parado) e depois
# `docker rename api-anterior api` -- ou seja, sobe o SOBRADO, que e a versao de DOIS deploys atras.
# Deploy interrompido devolvendo producao para tras, em silencio.
#
# Aqui a remocao e `-f`, e ela AVISA quando havia algo para remover: sobra de api-anterior significa
# que um deploy anterior nao terminou, e isso merece ser visto em vez de limpo calado.
if ssh -i "$KEY" "$SRV" 'docker ps -a --format "{{.Names}}" | grep -qx api-anterior'; then
  echo "AVISO: havia um api-anterior sobrando de um deploy que nao terminou. Removendo:" >&2
  ssh -i "$KEY" "$SRV" 'docker ps -a --format "   {{.Names}}  {{.Status}}" | grep api-anterior' >&2 || true
  if ! ssh -i "$KEY" "$SRV" 'docker rm -f api-anterior >/dev/null'; then
    echo "ABORTADO: nao consegui remover o api-anterior sobrando. NADA foi trocado," >&2
    echo "e a versao que esta no ar continua no ar. Entre no servidor e resolva antes." >&2
    exit 1
  fi
fi
if ! ssh -i "$KEY" "$SRV" "bash -s" <<SCRIPT
set -e
docker tag bora-api:latest bora-api:anterior 2>/dev/null || true
docker tag bora-api:$TAG bora-api:latest
docker stop -t 30 api
docker rename api api-anterior          # guarda os logs do que estava rodando
docker run -d --name api --restart unless-stopped --network bora \
  --env-file /home/ubuntu/bora/api.env \
  --log-opt max-size=20m --log-opt max-file=5 \
  bora-api:latest
SCRIPT
then
  echo "A troca do container FALHOU (o container novo nao subiu)." >&2
  rollback
fi

# ITEM 9.7 DA VARREDURA: aqui o health CHEIO esta certo -- versao que nao fala com o banco nao serve,
# e rollback e a decisao acertada. O que faltava era dizer QUAL dos dois caiu. Sem isso, um RDS fora
# do ar aparecia como "a versao nova nao ficou sadia", e o proximo passo de quem le seria procurar
# defeito num codigo que esta bom.
diagnostico_da_falha() {
  local viva
  viva=$(ssh -i "$KEY" "$SRV" "docker exec api curl -s -o /dev/null -w '%{http_code}' --max-time 10 localhost:8080/actuator/health/viva 2>/dev/null" || true)
  if [ "$viva" = "200" ]; then
    echo "DIAGNOSTICO: o processo SUBIU e responde (grupo viva = 200). O que esta DOWN e um" >&2
    echo "indicador de fora -- quase sempre o banco. O codigo provavelmente esta bom: olhe o RDS" >&2
    echo "antes de procurar defeito na versao nova. Ver varredura 9.7." >&2
  else
    echo "DIAGNOSTICO: o processo nao responde nem no grupo viva (HTTP ${viva:-sem resposta})." >&2
    echo "A falha e da propria aplicacao: veja o log do container." >&2
  fi
}

dizer "9/9 esperando ficar sadio (rollback se nao ficar)"
if ssh -i "$KEY" "$SRV" 'for i in $(seq 1 40); do
      docker exec api curl -fs localhost:8080/actuator/health 2>/dev/null | grep -q UP && exit 0
      sleep 3
    done; exit 1'; then
  # `-f`: sem ele a remocao falha quando o container esta de pe, o `|| true` engole a falha, e a
  # sobra derruba o PROXIMO deploy -- ver a nota do passo 8.
  ssh -i "$KEY" "$SRV" 'docker rm -f api-anterior >/dev/null 2>&1 || true'
  echo "NO AR: $TAG (commit $COMMIT)"
  ssh -i "$KEY" "$SRV" 'docker ps --format "{{.Names}}  {{.Status}}"'

  # ------------------------------------------------------------------------------------------------
  # PODA (item 3.15 da varredura de 18/11/2026). Roda DEPOIS de o deploy dar certo, de proposito.
  #
  # O QUE FOI MEDIDO em 18/11: 70 imagens somando 11,46 GB, sendo 62 tags `bora-api:v110` a `v170`.
  # Em uso: so a `latest` (o container) e a `anterior` (o rollback). Crescimento de 164 MB/dia --
  # 49 imagens / 7,86 GB em 27/10 viraram 70 / 11,46 GB em 18/11. Mais 2 volumes orfaos de 148 MB.
  # Nada podava nada; o vigia so avisava quando o disco passasse de 85%.
  #
  # POR QUE AQUI E NAO NUM CRON SEPARADO: quem cria a imagem e este script. Lixo se poda onde se
  # produz, e assim o dono aprova uma vez em vez de aprovar um cron novo.
  #
  # POR QUE DEPOIS DO HEALTH E NAO ANTES: enquanto a versao nova nao esta sadia, a imagem antiga e o
  # caminho de volta. Podar antes seria serrar o galho do rollback.
  #
  # O QUE ELA NUNCA REMOVE: a imagem que algum container USA (`docker image prune` e o filtro por
  # tag respeitam isso), a `latest`, a `anterior`, e as PODA_MANTER tags mais novas. O `docker rmi`
  # sem `-f` recusa imagem em uso -- e e de proposito que nao ha `-f` aqui.
  PODA_MANTER=${PODA_MANTER:-6}
  dizer "poda: mantendo as $PODA_MANTER versoes mais novas"
  ssh -i "$KEY" "$SRV" "bash -s" <<PODA || echo "   (a poda falhou; nao e motivo para desfazer o deploy)" >&2
set -u
ANTES_IMG=\$(docker images bora-api --format '{{.Repository}}:{{.Tag}}' | wc -l)
ANTES_GB=\$(docker system df --format '{{.Type}} {{.Size}}' | awk '/^Images/{print \$2}')

# As tags vXXX, da mais nova para a mais velha, tirando latest e anterior. Ordem por numero, nao por
# texto: por texto, v99 vem depois de v170.
TAGS=\$(docker images bora-api --format '{{.Tag}}'         | grep -E '^v[0-9]+\$'         | sed 's/^v//' | sort -rn | sed 's/^/v/')
MANTER=\$(echo "\$TAGS" | head -n $PODA_MANTER)
APAGAR=\$(echo "\$TAGS" | tail -n +\$(( $PODA_MANTER + 1 )))

if [ -n "\$APAGAR" ]; then
  echo "   mantendo: \$(printf '%s ' \$MANTER)"
  for TG in \$APAGAR; do
    docker rmi "bora-api:\$TG" >/dev/null 2>&1       && echo "   removida bora-api:\$TG"       || echo "   bora-api:\$TG ficou (em uso ou referenciada)"
  done
else
  echo "   nada a remover: ha \$(echo "\$TAGS" | grep -c . ) versao(oes) guardada(s)"
fi

# Camadas soltas e volumes sem dono. Os dois sao conservadores: `image prune` sem `-a` so remove
# camada que nenhuma imagem com tag referencia, e `volume prune` so remove volume que nenhum
# container usa. O dump do banco NAO mora em volume -- mora em /home/ubuntu/backups, no disco.
docker image prune -f >/dev/null 2>&1 || true
docker volume prune -f >/dev/null 2>&1 || true

DEPOIS_IMG=\$(docker images bora-api --format '{{.Repository}}:{{.Tag}}' | wc -l)
DEPOIS_GB=\$(docker system df --format '{{.Type}} {{.Size}}' | awk '/^Images/{print \$2}')
echo "   imagens bora-api: \$ANTES_IMG -> \$DEPOIS_IMG   |   total de imagens: \$ANTES_GB -> \$DEPOIS_GB"
df -h / | awk 'NR==2{print "   disco: "\$3" usados de "\$2" ("\$5"), "\$4" livres"}'
PODA

  # E A PODA DAQUI, DA MAQUINA QUE CONSTROI. Medido em 19/11/2026 nesta maquina: 143 imagens
  # `bora-api`, 297 imagens no total somando 25,39 GB -- 21,64 GB (85%) recuperaveis. O servidor
  # tinha 62 tags; aqui tinha mais que o dobro, porque cada deploy constroi aqui ANTES de enviar e
  # nada nunca podou. Mesma regra, mesmo cuidado: nunca a `latest`, nunca imagem em uso, nunca as
  # PODA_MANTER mais novas.
  TAGS_L=$(docker images bora-api --format '{{.Tag}}' | grep -E '^v[0-9]+$' | sed 's/^v//' | sort -rn | sed 's/^/v/')
  APAGAR_L=$(echo "$TAGS_L" | tail -n +$(( PODA_MANTER + 1 )))
  if [ -n "$APAGAR_L" ]; then
    QUANTAS=$(echo "$APAGAR_L" | grep -c .)
    dizer "poda local: $QUANTAS imagem(ns) antiga(s) desta maquina"
    for TG in $APAGAR_L; do docker rmi "bora-api:$TG" >/dev/null 2>&1 || true; done
    echo "   imagens bora-api aqui: $(docker images bora-api --format '{{.Tag}}' | grep -cE '^v[0-9]+$') versao(oes)"
  fi
  # O cache de build e os volumes anonimos NAO sao podados automaticamente aqui, de proposito: podar
  # o cache deixa o proximo build lento, e volume anonimo pode guardar algo que alguem quer. Quando
  # apertar, os dois comandos sao `docker builder prune` e `docker volume prune` -- decisao do dono.
else
  echo "A versao nova nao ficou sadia." >&2
  diagnostico_da_falha
  rollback
fi
