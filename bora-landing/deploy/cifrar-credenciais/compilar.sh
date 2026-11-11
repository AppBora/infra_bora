#!/usr/bin/env bash
#
# Compila o Cifrar com o SegredoGuardado DE VERDADE -- o arquivo do backend, sem uma letra mudada.
# Nada de reimplementar cripto: a copia e conferida por md5 antes de compilar.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
BACK="$(cd "$AQUI/../../../bora-fase-3-backend-java" && pwd)"
JDK="${JAVA_HOME:-/c/Java/jdk-21.0.2}"
M2="${HOME}/.m2/repository"
ORIGINAL="$BACK/src/main/java/br/com/bora/config/SegredoGuardado.java"

rm -rf "$AQUI/build"
mkdir -p "$AQUI/build/src/br/com/bora/config" "$AQUI/build/lib" "$AQUI/build/classes"
cp "$ORIGINAL" "$AQUI/build/src/br/com/bora/config/"
cp "$AQUI/Cifrar.java" "$AQUI/Smoke.java" "$AQUI/build/src/"

echo "md5 do SegredoGuardado (os dois tem de bater):"
md5sum "$ORIGINAL" "$AQUI/build/src/br/com/bora/config/SegredoGuardado.java"

for j in "jakarta/persistence/jakarta.persistence-api/3.1.0/jakarta.persistence-api-3.1.0.jar" \
         "org/slf4j/slf4j-api/2.0.13/slf4j-api-2.0.13.jar" \
         "org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar" \
         "org/projectlombok/lombok/1.18.32/lombok-1.18.32.jar"; do
  cp "$M2/$j" "$AQUI/build/lib/"
done

cd "$AQUI/build"
CP="lib/jakarta.persistence-api-3.1.0.jar;lib/slf4j-api-2.0.13.jar;lib/postgresql-42.7.3.jar;lib/lombok-1.18.32.jar"
"$JDK/bin/javac" -nowarn -encoding UTF-8 -cp "$CP" -d classes \
  src/br/com/bora/config/SegredoGuardado.java src/Cifrar.java src/Smoke.java

echo; echo "=== prova local (chave descartavel, nenhum banco):"
"$JDK/bin/java" -cp "classes;lib/jakarta.persistence-api-3.1.0.jar;lib/slf4j-api-2.0.13.jar" Smoke

rm -f lib/lombok-1.18.32.jar   # so de compilacao; nao vai para o servidor
echo; echo "pronto. Enviar com:"
echo "  scp -i ~/.ssh/bora-lightsail.pem -r build/classes build/lib rodar.sh ubuntu@56.126.177.18:/home/ubuntu/cifrar/"
