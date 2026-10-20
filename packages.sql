CREATE OR REPLACE PACKAGE pkg_fidelidad_cliente IS
    C_CATEGORIA_ORO    CONSTANT VARCHAR2(10) := 'Oro';
    C_CATEGORIA_PLATA  CONSTANT VARCHAR2(10) := 'Plata';
    C_CATEGORIA_BRONCE CONSTANT VARCHAR2(10) := 'Bronce';
    C_CATEGORIA_NUEVO  CONSTANT VARCHAR2(10) := 'Nuevo';

    g_anno_proceso NUMBER(4);

    PROCEDURE inicializar(p_anno IN NUMBER);
    PROCEDURE procesar_scoring;
    FUNCTION  pct_beneficio_cliente(p_numrun_cli IN NUMBER) RETURN NUMBER;
    FUNCTION  nombre_completo(p_numrun_cli IN NUMBER) RETURN VARCHAR2;
END pkg_fidelidad_cliente;
/

CREATE OR REPLACE PACKAGE BODY pkg_fidelidad_cliente IS
    v_registros NUMBER(8) := 0;

    FUNCTION determinar_categoria (p_puntaje IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        IF    p_puntaje >= 50 THEN RETURN C_CATEGORIA_ORO;
        ELSIF p_puntaje >= 20 THEN RETURN C_CATEGORIA_PLATA;
        ELSIF p_puntaje >= 10 THEN RETURN C_CATEGORIA_BRONCE;
        ELSE                        RETURN C_CATEGORIA_NUEVO;
        END IF;
    END determinar_categoria;

    PROCEDURE registrar_log (p_estado VARCHAR2, p_detalle VARCHAR2) IS
    BEGIN
        sp_registrar_control('PKG_FIDELIDAD_CLIENTE', v_registros, p_estado, p_detalle);
    END registrar_log;

    
    PROCEDURE inicializar (p_anno IN NUMBER) IS
    BEGIN
        g_anno_proceso := p_anno;
        v_registros    := 0;
    END inicializar;

    PROCEDURE procesar_scoring IS
        CURSOR c_cli IS
            SELECT numrun_cli, dvrun_cli,
                   TRIM(pnombre_cli || ' ' || NVL(snombre_cli,'') || ' '
                        || appaterno_cli || ' ' || apmaterno_cli) AS nombre
              FROM cliente
             ORDER BY numrun_cli;
        
        v_punt  NUMBER(7);
        v_cat   VARCHAR2(10);
    BEGIN
        IF g_anno_proceso IS NULL THEN
            g_anno_proceso := fn_anno_actual;
        END IF;

        FOR r IN c_cli LOOP
            v_punt  := fn_obtener_puntaje_cliente(r.numrun_cli, g_anno_proceso);
            v_cat   := determinar_categoria(v_punt);

            UPDATE scoring_cliente 
               SET puntaje             = v_punt,
                   categoria_fidelidad = v_cat,
                   cantidad_arriendos  = (v_punt / 10)
             WHERE numrun_cli   = r.numrun_cli 
               AND anno_proceso = g_anno_proceso;

            IF SQL%ROWCOUNT = 0 THEN
                INSERT INTO scoring_cliente 
                    (numrun_cli, dvrun_cli, nombre_cliente, anno_proceso,
                     cantidad_arriendos, puntaje, categoria_fidelidad)
                VALUES
                    (r.numrun_cli, r.dvrun_cli, r.nombre, g_anno_proceso,
                     (v_punt / 10), v_punt, v_cat);
            END IF;

            v_registros := v_registros + 1;
        END LOOP;

        registrar_log('OK', 'Scoring año ' || g_anno_proceso);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            registrar_log('ERROR', SQLERRM);
            ROLLBACK;
            RAISE;
    END procesar_scoring;

    FUNCTION pct_beneficio_cliente (p_numrun_cli IN NUMBER) RETURN NUMBER IS
        v_cat VARCHAR2(10);
        v_pct NUMBER(5,2) := 0;
    BEGIN
        SELECT categoria_fidelidad INTO v_cat
          FROM scoring_cliente
         WHERE numrun_cli = p_numrun_cli
           AND anno_proceso = NVL(g_anno_proceso, fn_anno_actual);

        SELECT pct_beneficio INTO v_pct
          FROM beneficio_fidelidad
         WHERE categoria = v_cat;

        RETURN v_pct;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
    END pct_beneficio_cliente;

    FUNCTION nombre_completo (p_numrun_cli IN NUMBER) RETURN VARCHAR2 IS
        v_nom VARCHAR2(100);
    BEGIN
        SELECT pnombre_cli || ' ' || appaterno_cli || ' ' || apmaterno_cli
          INTO v_nom
          FROM cliente
         WHERE numrun_cli = p_numrun_cli;
        RETURN v_nom;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 'CLIENTE INEXISTENTE';
    END nombre_completo;
BEGIN
    g_anno_proceso := fn_anno_actual;
    v_registros    := 0;
END pkg_fidelidad_cliente;
/


CREATE OR REPLACE PACKAGE pkg_auditoria IS
    PROCEDURE incrementar_evento(p_tipo IN VARCHAR2);
    FUNCTION  total_eventos RETURN NUMBER;
    FUNCTION  ultimo_evento RETURN VARCHAR2;
END pkg_auditoria;
/

CREATE OR REPLACE PACKAGE BODY pkg_auditoria IS
    g_contador NUMBER       := 0;
    g_ultimo   VARCHAR2(200):= 'SIN EVENTOS';

    PROCEDURE incrementar_evento (p_tipo IN VARCHAR2) IS
    BEGIN
        g_contador := g_contador + 1;
        g_ultimo   := p_tipo || ' @ ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS');
    END incrementar_evento;

    FUNCTION total_eventos RETURN NUMBER IS
    BEGIN
        RETURN g_contador;
    END total_eventos;

    FUNCTION ultimo_evento RETURN VARCHAR2 IS
    BEGIN
        RETURN g_ultimo;
    END ultimo_evento;

BEGIN
    g_contador := 0;
    g_ultimo   := 'PAQUETE INICIALIZADO ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS');
END pkg_auditoria;
/