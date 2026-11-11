import br.com.bora.config.SegredoGuardado;
public class Smoke {
    public static void main(String[] a) {
        SegredoGuardado.usarChave("chave-DESCARTAVEL-so-para-este-teste-local");
        if (!SegredoGuardado.ligado()) { System.out.println("FALHOU: nao ligou"); System.exit(1); }
        SegredoGuardado c = new SegredoGuardado();
        String[] amostras = {"aact_prod_EXEMPLO$com$dolar", "a", "token-com-acento-ç-e-emoji-😀",
                             "x".repeat(4000)};
        for (String claro : amostras) {
            String cif = c.convertToDatabaseColumn(claro);
            boolean prefixo = cif.startsWith("enc:v1:");
            boolean volta = claro.equals(c.convertToEntityAttribute(cif));
            System.out.println("  claro " + claro.length() + " car -> cifrado " + cif.length()
                    + " car | prefixo=" + prefixo + " ida-e-volta=" + volta);
            if (!prefixo || !volta) { System.out.println("FALHOU"); System.exit(1); }
        }
        // chave errada NAO abre (o GCM autentica): e esta a prova que a FASE 1 usa
        String cif = c.convertToDatabaseColumn("segredo");
        SegredoGuardado.usarChave("OUTRA-chave-qualquer");
        try { new SegredoGuardado().convertToEntityAttribute(cif);
              System.out.println("FALHOU: chave errada ABRIU"); System.exit(1); }
        catch (RuntimeException e) { System.out.println("  chave errada nao abriu: OK"); }
        System.out.println("SMOKE OK");
    }
}
