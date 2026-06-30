# Modelo de Dados

## lojas
id, nome, documento, telefone, plano_id, ativo, criado_em, atualizado_em

## planos
id, nome, preco, limite_pedidos_mes, limite_usuarios, permite_logo, permite_cores, permite_banner, permite_relatorio_logo, permite_subdominio, permite_whatsapp, permite_white_label

## usuarios
id, loja_id, nome, email, senha_hash, perfil, ativo, criado_em, atualizado_em

## configuracoes_loja
id, loja_id, nome_exibicao, nome_sistema, logo_url, favicon_url, cor_primaria, cor_secundaria, cor_fundo, banner_url, mensagem_boas_vindas, texto_rodape, mostrar_marca_bora, subdominio, dominio_personalizado

## clientes
id, loja_id, nome, telefone, endereco, bairro, referencia, criado_em, atualizado_em

## produtos
id, loja_id, nome, categoria, preco, ativo, criado_em, atualizado_em

## pedidos
id, loja_id, codigo, cliente_id, status, valor_total, forma_pagamento, origem, observacao, criado_em, atualizado_em, entregue_em, cancelado_em, motivo_cancelamento

## itens_pedido
id, loja_id, pedido_id, produto_id, quantidade, preco_unitario, observacao

## logs_status
id, loja_id, pedido_id, status_anterior, status_novo, usuario_id, data_hora
