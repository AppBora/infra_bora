#!/usr/bin/env python3
"""99Food de mentira, para ensaiar a homologacao sem depender da 99 de verdade.

Fala Open Delivery como a 99 fala: entrega o token, devolve eventos no polling, entrega o detalhe do
pedido e ANOTA tudo o que o Bora manda de volta. No fim o ensaio pergunta a ela o que recebeu.

Dois pedidos, de proposito:
  - 99-DELIVERY-1 : entrega normal pela loja (fluxo confirm > readyForPickup > dispatch > delivered)
  - 99-TAKEOUT-1  : retirada no balcao (type TAKEOUT, sem objeto delivery, com objeto takeout;
                    fecha em pickedUp e NAO aceita dispatch)

Os payloads seguem o Open Delivery 1.7.1 com os campos que o normalizador do Bora le de verdade.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORTA = int(sys.argv[1]) if len(sys.argv) > 1 else 8077

# O que o Bora mandou para a "99". O ensaio le isso no final.
recebido = {"token": 0, "polling": 0, "ack": [], "status": []}

PEDIDOS = {
    "99-DELIVERY-1": {
        "id": "99-DELIVERY-1",
        "displayId": "4455",
        "type": "DELIVERY",
        "orderTiming": "INSTANT",
        "createdAt": "2026-10-05T18:00:00Z",
        "customer": {"name": "Bruno Carvalho", "phone": {"number": "5515998887777"}},
        "delivery": {
            "deliveredBy": "MERCHANT",
            "observations": "Portao azul, interfone quebrado",
            "deliveryAddress": {
                "street": "Rua das Flores", "number": "180", "complement": "Fundos",
                "neighborhood": "Centro", "city": "Sorocaba", "state": "SP", "postalCode": "18000000",
                "reference": "ao lado da farmacia",
            },
        },
        "items": [
            {"name": "Acai 500ml", "quantity": 2, "unitPrice": {"value": 18.00},
             "options": [{"name": "Leite condensado", "quantity": 1, "unitPrice": {"value": 2.00}}],
             "observations": "sem banana"},
            {"name": "Guarana lata", "quantity": 1, "unitPrice": {"value": 6.00}},
        ],
        # Schema oficial v1.7.1: itemsPrice = so os itens; orderAmount = o TOTAL do pedido
        # (itens + taxas - desconto). A primeira versao daqui inventou um "orderTotal" que nao existe
        # e poe 44 em orderAmount: eu li o resultado do meu proprio erro como se fosse defeito do Bora.
        "total": {"itemsPrice": {"value": 44.00}, "otherFees": {"value": 7.00},
                  "discount": {"value": 0.00}, "orderAmount": {"value": 51.00}},
        "payments": {"prepaid": 0.00, "pending": 51.00,
                     "methods": [{"type": "OFFLINE", "method": "CASH", "value": 51.00,
                                  "changeFor": 60.00}]},
        "extraInfo": "Trocar o troco em nota de 10, por favor",
    },
    "99-TAKEOUT-1": {
        "id": "99-TAKEOUT-1",
        "displayId": "4456",
        "type": "TAKEOUT",
        "orderTiming": "INSTANT",
        "createdAt": "2026-10-05T18:05:00Z",
        "customer": {"name": "Ana Paula Reis", "phone": {"number": "5515997776666"}},
        # Conforme o comunicado de 05/10: em retirada o objeto delivery NAO vem.
        "takeout": {"mode": "PICKUP_AREA", "takeoutDateTime": "2026-10-05T18:40:00Z"},
        "items": [
            {"name": "Acai 300ml", "quantity": 1, "unitPrice": {"value": 14.00}},
        ],
        "total": {"itemsPrice": {"value": 14.00}, "otherFees": {"value": 0.00},
                  "discount": {"value": 0.00}, "orderAmount": {"value": 14.00}},
        "payments": {"prepaid": 14.00, "pending": 0.00,
                     "methods": [{"type": "ONLINE", "method": "PIX", "value": 14.00, "prepaid": True}]},
    },
}

EVENTOS = [
    {"id": "ev-1", "orderId": "99-DELIVERY-1", "eventType": "CREATED",
     "createdAt": "2026-10-05T18:00:01Z"},
    {"id": "ev-2", "orderId": "99-TAKEOUT-1", "eventType": "CREATED",
     "createdAt": "2026-10-05T18:05:01Z"},
]


def _anotar(linha):
    """Toda requisicao vai para um arquivo. Sem isto, erro dentro do handler some: o servidor e
    iniciado com `docker exec -d` e a saida dele nao aparece no `docker logs`. Foi o que me fez
    perder tempo caçando um defeito do Bora que nao existia."""
    try:
        with open("/app/requisicoes.log", "a", encoding="utf-8") as f:
            f.write(linha + chr(10))
    except Exception:
        pass


class Falsa99(BaseHTTPRequestHandler):
    def log_message(self, *a):  # silencio: o ensaio e quem imprime
        pass

    def _json(self, codigo, corpo):
        dados = json.dumps(corpo).encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)

    def do_GET(self):
        caminho = self.path.split("?")[0]
        if caminho != "/relatorio":
            _anotar("GET " + caminho)
        if caminho.endswith("/v1/events:polling"):
            recebido["polling"] += 1
            # So entrega os eventos uma vez, como a 99 faz depois do acknowledgment.
            self._json(200, EVENTOS if recebido["polling"] == 1 else [])
            return
        if "/v1/orders/" in caminho:
            pedido = caminho.rsplit("/", 1)[-1]
            if pedido in PEDIDOS:
                self._json(200, PEDIDOS[pedido])
                return
        if caminho == "/relatorio":
            self._json(200, recebido)
            return
        self._json(404, {"erro": "nao existe aqui: " + caminho})

    def _ler_corpo(self):
        """Le o corpo com ou sem Content-Length.

        O Spring manda o acknowledgment em "chunked", SEM Content-Length. A primeira versao daqui lia
        so o Content-Length, via zero, e eu passei um bom tempo achando que o Bora nao estava
        confirmando o recebimento — estava; quem nao sabia ler era a 99 de mentira.
        """
        tamanho = self.headers.get("Content-Length")
        if tamanho:
            return self.rfile.read(int(tamanho)).decode("utf-8")
        if "chunked" in (self.headers.get("Transfer-Encoding") or "").lower():
            partes = []
            while True:
                linha = self.rfile.readline().strip()
                n = int(linha.split(b";")[0], 16) if linha else 0
                if n == 0:
                    self.rfile.readline()  # o CRLF final
                    break
                partes.append(self.rfile.read(n))
                self.rfile.readline()
            return b"".join(partes).decode("utf-8")
        return ""

    def do_POST(self):
        caminho = self.path.split("?")[0]
        _anotar("POST " + caminho)
        corpo = self._ler_corpo()

        if caminho.endswith("/oauth/token"):
            recebido["token"] += 1
            self._json(200, {"accessToken": "token-de-ensaio", "expiresIn": 3600,
                             "access_token": "token-de-ensaio", "expires_in": 3600,
                             "tokenType": "bearer"})
            return
        if caminho.endswith("/v1/events/acknowledgment"):
            try:
                recebido["ack"].extend(json.loads(corpo) if corpo else [])
            except Exception:
                recebido["ack"].append({"corpo_invalido": corpo[:200]})
            self._json(200, {})
            return
        if "/v1/orders/" in caminho:
            partes = caminho.rsplit("/", 2)  # .../orders/{id}/{verbo}
            if len(partes) == 3:
                recebido["status"].append({"pedido": partes[1], "verbo": partes[2]})
                self._json(200, {})
                return
        self._json(404, {"erro": "nao existe aqui: " + caminho})


if __name__ == "__main__":
    print("99 de mentira escutando na porta %d" % PORTA, flush=True)
    HTTPServer(("0.0.0.0", PORTA), Falsa99).serve_forever()
