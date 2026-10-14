#!/bin/bash
# Vigia do Bora (29/09/2026): a revisao apontou que se o sistema cair de madrugada ninguem fica
# sabendo. Isto nao substitui um alarme externo (UptimeRobot) — ele so age DE DENTRO: se o site nao
# responder em duas checagens seguidas, reinicia o container e registra. Se o servidor inteiro cair,
# este script cai junto; por isso o alarme externo continua necessario.
LOG=/home/ubuntu/backups/vigia.log
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health)
if [ "$CODE" = "200" ]; then rm -f /tmp/bora-falhou; exit 0; fi
if [ -f /tmp/bora-falhou ]; then
  echo "$(date -Is) FORA DO AR (HTTP $CODE) duas vezes seguidas — reiniciando a api" >> "$LOG"
  docker restart api >> "$LOG" 2>&1
  sleep 45
  echo "$(date -Is) depois do restart: HTTP $(curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://borahapp.com.br/actuator/health)" >> "$LOG"
  rm -f /tmp/bora-falhou
else
  echo "$(date -Is) primeira falha (HTTP $CODE) — vou conferir de novo no proximo ciclo" >> "$LOG"
  touch /tmp/bora-falhou
fi
