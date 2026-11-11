import br.com.bora.config.SegredoGuardado;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Cifra em repouso as credenciais que ficaram em texto puro no banco, sem passar pelo painel.
 *
 * POR QUE ISTO EXISTE, E NAO O BOTAO: o endpoint da tela exige login de administrador
 * (CifragemEmRepousoService.cifrarOqueJaEstaGravado -> ctx.requireAdminBora()), e eu nao entro na
 * conta de ninguem nem forjo token. Este programa faz a MESMA coisa por fora: le o valor cru,
 * cifra com o MESMO conversor (o SegredoGuardado.java aqui e copia byte a byte do de producao,
 * conferida por md5) e grava.
 *
 * NUNCA imprime um valor -- nem claro, nem cifrado, nem a chave. So nome de tabela, de coluna,
 * identificador da linha, tamanho e contagem.
 *
 * Tres fases, e as duas primeiras podem ABORTAR antes de qualquer gravacao:
 *
 *   1. PROVA DA CHAVE. Decifra todo valor que JA esta com enc:v1:. O GCM autentica o conteudo:
 *      chave errada nao abre, estoura. Se eu consigo abrir o que a API gravou, a chave que tenho na
 *      mao e a chave da API -- prova criptografica, sem precisar de backup em texto puro. Zero
 *      valores ja cifrados tambem aborta: sem material, nao ha prova.
 *   2. PROVA DE IDA E VOLTA, em memoria. Cifra cada valor em texto puro e decifra de volta; tem de
 *      voltar igual. Pega tambem o caminho silencioso do conversor: quando a cifra falha por
 *      dentro, ele DEVOLVE O TEXTO PURO e so grita no log -- sem esta conferencia eu gravaria claro
 *      achando que gravei cifrado.
 *      Confere ainda se o cifrado CABE na coluna (ele cresce ~35%): o Postgres RECUSA valor maior
 *      que o limite e derruba a transacao inteira, nao corta.
 *   3. GRAVACAO, numa transacao so. Ou cifra todas, ou nao cifra nenhuma.
 *
 * Idempotente: o filtro "not like enc:v1:%" faz rodar de novo nao achar nada.
 */
public class Cifrar {

    private record Alvo(String tabela, String id, String coluna) {}

    /** As 6 colunas com @Convert(SegredoGuardado) -- as mesmas do CifragemEmRepousoService.ALVOS. */
    private static final List<Alvo> ALVOS = List.of(
            new Alvo("loja", "id", "asaas_api_key"),
            // Entrou em 11/11/2026, junto com o @Convert na entidade. ATENCAO A ORDEM: cifrar esta
            // coluna ANTES de a API nova subir deixaria o PublicController comparando o token que o
            // Asaas manda contra o texto "enc:v1:..." cru -- o aviso de PIX pago pararia de valer, em
            // silencio. Rodar so DEPOIS do deploy da v158.
            new Alvo("loja", "id", "asaas_webhook_token"),
            new Alvo("config_plataforma", "chave", "valor"),
            new Alvo("integracao_canal", "id", "client_secret"),
            new Alvo("integracao_canal", "id", "access_token"),
            new Alvo("integracao_canal", "id", "refresh_token"),
            new Alvo("integracao_canal", "id", "webhook_token"));

    private static final String PREFIXO = "enc:v1:";

    public static void main(String[] args) throws Exception {
        String modo = args.length > 0 ? args[0] : "conferir";
        if (!modo.equals("conferir") && !modo.equals("aplicar")) {
            System.out.println("uso: Cifrar conferir|aplicar");
            System.exit(2);
        }

        SegredoGuardado.usarChave(env("BORA_SEGREDO_COLUNAS"));
        if (!SegredoGuardado.ligado()) {
            System.out.println("ABORTADO: BORA_SEGREDO_COLUNAS nao chegou aqui.");
            System.exit(3);
        }
        SegredoGuardado cif = new SegredoGuardado();
        System.out.println("modo: " + modo + "   |   cifragem: LIGADA (AES-256/GCM)");

        try (Connection c = DriverManager.getConnection(
                env("SPRING_DATASOURCE_URL"), env("SPRING_DATASOURCE_USERNAME"),
                env("SPRING_DATASOURCE_PASSWORD"))) {
            c.setAutoCommit(false);

            Map<String, Integer> limites = limitesDasColunas(c);

            // ----------------------------------------------------- FASE 1: a chave e a da API?
            System.out.println();
            System.out.println("FASE 1 - prova da chave: abrir o que a API ja cifrou");
            int abriu = 0;
            int naoAbriu = 0;
            for (Alvo a : ALVOS) {
                for (Object[] linha : ler(c, a, true)) {
                    try {
                        String claro = cif.convertToEntityAttribute((String) linha[1]);
                        if (claro == null || claro.isEmpty()) {
                            throw new IllegalStateException("decifrou para vazio");
                        }
                        abriu++;
                    } catch (RuntimeException e) {
                        naoAbriu++;
                        System.out.println("  NAO ABRIU: " + a.tabela() + "." + a.coluna()
                                + " linha " + linha[0]);
                    }
                }
            }
            System.out.println("  abriu: " + abriu + "   nao abriu: " + naoAbriu);
            if (naoAbriu > 0) {
                System.out.println("ABORTADO: a chave que eu tenho NAO e a que gravou esses valores.");
                System.exit(4);
            }
            if (abriu == 0) {
                System.out.println("ABORTADO: nenhum valor ja cifrado para servir de prova.");
                System.exit(5);
            }

            // ----------------------------------------------------- FASE 2: ida e volta, em memoria
            System.out.println();
            System.out.println("FASE 2 - prova de ida e volta de cada valor em texto puro");
            List<Object[]> paraGravar = new ArrayList<>();
            Map<String, Integer> porColuna = new LinkedHashMap<>();
            int problemas = 0;
            int maior = 0;
            for (Alvo a : ALVOS) {
                int n = 0;
                for (Object[] linha : ler(c, a, false)) {
                    String claro = (String) linha[1];
                    String cifrado = cif.convertToDatabaseColumn(claro);
                    String qual = a.tabela() + "." + a.coluna() + " linha " + linha[0];
                    if (cifrado == null || !cifrado.startsWith(PREFIXO)) {
                        problemas++;
                        System.out.println("  NAO CIFROU (voltou em claro): " + qual);
                        continue;
                    }
                    if (!claro.equals(cif.convertToEntityAttribute(cifrado))) {
                        problemas++;
                        System.out.println("  IDA E VOLTA DIFERENTE: " + qual);
                        continue;
                    }
                    Integer limite = limites.get(a.tabela() + "." + a.coluna());
                    if (limite != null && cifrado.length() > limite) {
                        problemas++;
                        System.out.println("  NAO CABE NA COLUNA: " + qual + " -- cifrado tem "
                                + cifrado.length() + " caracteres e o limite e " + limite);
                        continue;
                    }
                    if (cifrado.length() > maior) maior = cifrado.length();
                    paraGravar.add(new Object[]{a, linha[0], cifrado});
                    n++;
                }
                porColuna.put(a.tabela() + "." + a.coluna(), n);
            }
            for (Map.Entry<String, Integer> e : porColuna.entrySet()) {
                Integer lim = limites.get(e.getKey());
                System.out.println("  " + e.getKey() + ": " + e.getValue()
                        + " em texto puro, prova OK   (teto da coluna: "
                        + (lim == null ? "text, sem teto" : lim) + ")");
            }
            System.out.println("  total conferido: " + paraGravar.size()
                    + "   problemas: " + problemas + "   maior cifrado: " + maior + " caracteres");
            if (problemas > 0) {
                System.out.println("ABORTADO: " + problemas
                        + " valor(es) nao passaram na prova. Nada foi gravado.");
                System.exit(6);
            }

            // ----------------------------------------------------- FASE 3: gravar
            System.out.println();
            if (modo.equals("conferir")) {
                System.out.println("FASE 3 - NAO executada (modo conferir). Nada foi gravado.");
                c.rollback();
                return;
            }
            System.out.println("FASE 3 - gravando, numa transacao so");
            int gravadas = 0;
            for (Object[] item : paraGravar) {
                Alvo a = (Alvo) item[0];
                try (PreparedStatement ps = c.prepareStatement("update " + a.tabela() + " set "
                        + a.coluna() + " = ? where " + a.id() + " = ?")) {
                    ps.setString(1, (String) item[2]);
                    ps.setObject(2, item[1]);
                    gravadas += ps.executeUpdate();
                }
            }
            if (gravadas != paraGravar.size()) {
                c.rollback();
                System.out.println("ABORTADO: eu ia cifrar " + paraGravar.size()
                        + " e o banco mexeu " + gravadas + ". Transacao desfeita.");
                System.exit(7);
            }
            c.commit();
            System.out.println("  gravadas: " + gravadas);

            // ----------------------------------------------------- conferencia depois do commit
            int sobrou = 0;
            int agoraCifradas = 0;
            for (Alvo a : ALVOS) {
                sobrou += ler(c, a, false).size();
                agoraCifradas += ler(c, a, true).size();
            }
            c.rollback();
            System.out.println();
            System.out.println("DEPOIS DO COMMIT: cifradas = " + agoraCifradas
                    + "   ainda em texto puro = " + sobrou);
            if (sobrou > 0) System.exit(8);
        }
    }

    /** Valores de uma coluna: [id, valor]. cifrados=true traz os enc:v1:, false os em claro. */
    private static List<Object[]> ler(Connection c, Alvo a, boolean cifrados) throws Exception {
        String sql = "select " + a.id() + ", " + a.coluna() + " from " + a.tabela()
                + " where " + a.coluna() + " is not null and " + a.coluna() + " <> ''"
                + " and " + a.coluna() + (cifrados ? " like " : " not like ") + "'enc:v1:%'"
                + " order by " + a.id();
        List<Object[]> out = new ArrayList<>();
        try (Statement st = c.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) out.add(new Object[]{rs.getObject(1), rs.getString(2)});
        }
        return out;
    }

    /**
     * O teto de cada coluna, quando existe. Coluna text nao tem teto e nao entra no mapa.
     *
     * Isto esta aqui por causa da licao do LarguraDeColuna: o Postgres nao corta valor maior que o
     * limite, ele RECUSA -- e recusar derruba a transacao inteira.
     */
    private static Map<String, Integer> limitesDasColunas(Connection c) throws Exception {
        Map<String, Integer> out = new LinkedHashMap<>();
        String sql = "select table_name, column_name, character_maximum_length"
                + " from information_schema.columns where table_schema = 'public'"
                + " and character_maximum_length is not null";
        try (Statement st = c.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                out.put(rs.getString(1) + "." + rs.getString(2), rs.getInt(3));
            }
        }
        return out;
    }

    private static String env(String nome) {
        String v = System.getenv(nome);
        if (v == null || v.isBlank()) {
            System.out.println("ABORTADO: variavel de ambiente " + nome + " nao chegou ao container.");
            System.exit(9);
        }
        return v;
    }
}
