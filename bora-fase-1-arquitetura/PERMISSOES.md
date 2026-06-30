# Segurança e Permissões

## Perfis
- OPERADOR: cria pedidos e atualiza status.
- GERENTE: acessa relatórios, corrige dados e acompanha indicadores.
- ADMINISTRADOR_LOJA: gerencia usuários, configurações e integrações da loja.
- ADMINISTRADOR_BORA: gerencia planos, lojas e operação global.

## Segurança
- Autenticação por e-mail e senha.
- Senhas criptografadas com BCrypt.
- JWT para sessão API.
- HTTPS em produção.
- Isolamento multi-loja por loja_id.
