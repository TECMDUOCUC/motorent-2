CREATE TABLE auditoria_cliente (
    id_auditoria      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numrun_cli        NUMBER(10),
    usuario           VARCHAR2(50)  DEFAULT USER,
    fecha_evento      DATE          DEFAULT SYSDATE,
    tipo_operacion    VARCHAR2(10),
    campo_modificado  VARCHAR2(30),
    valor_anterior    VARCHAR2(100),
    valor_nuevo       VARCHAR2(100)
);

CREATE TABLE control_proceso (
    id_proceso       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_proceso   VARCHAR2(60),
    fecha_ejecucion  DATE          DEFAULT SYSDATE,
    registros_proc   NUMBER(8),
    estado           VARCHAR2(20),
    detalle          VARCHAR2(200)
);

CREATE OR REPLACE PROCEDURE sp_registrar_control (
    p_nombre    IN VARCHAR2,
    p_registros IN NUMBER,
    p_estado    IN VARCHAR2,
    p_detalle   IN VARCHAR2
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO control_proceso (nombre_proceso, registros_proc, estado, detalle)
    VALUES (p_nombre, p_registros, p_estado, p_detalle);
    COMMIT;
END sp_registrar_control;
/


CREATE OR REPLACE PROCEDURE sp_procesar_scoring_anual (
    p_anno IN NUMBER
) IS
    CURSOR c_clientes IS
        SELECT numrun_cli, dvrun_cli,
               TRIM(pnombre_cli || ' ' || NVL(snombre_cli,'') || ' '
                    || appaterno_cli || ' ' || apmaterno_cli) AS nombre
          FROM cliente
         ORDER BY numrun_cli;

    v_cantidad  NUMBER(5);
    v_dias      NUMBER(6);
    v_monto     NUMBER(14);
    v_puntaje   NUMBER(7);
    v_categoria VARCHAR2(10);
    v_registros NUMBER(8) := 0;
BEGIN
    FOR rec IN c_clientes LOOP
        
        v_cantidad := fn_cantidad_arriendos_cliente(rec.numrun_cli, p_anno);
        v_dias     := fn_total_dias_cliente(rec.numrun_cli, p_anno);
        v_monto    := fn_monto_arriendos_cliente(rec.numrun_cli, p_anno);
        
        v_puntaje := fn_obtener_puntaje_cliente(rec.numrun_cli, p_anno);

        IF    v_puntaje >= 50 THEN v_categoria := 'Oro';
        ELSIF v_puntaje >= 20 THEN v_categoria := 'Plata';
        ELSIF v_puntaje >= 10 THEN v_categoria := 'Bronce';
        ELSE                        v_categoria := 'Nuevo';
        END IF;

        UPDATE scoring_cliente 
           SET cantidad_arriendos  = v_cantidad,
               total_dias          = v_dias,
               monto_total         = v_monto,
               puntaje             = v_puntaje,
               categoria_fidelidad = v_categoria
         WHERE numrun_cli   = rec.numrun_cli 
           AND anno_proceso = p_anno;

        IF SQL%ROWCOUNT = 0 THEN
            INSERT INTO scoring_cliente 
                (numrun_cli, dvrun_cli, nombre_cliente, anno_proceso,
                 cantidad_arriendos, total_dias, monto_total, puntaje, categoria_fidelidad)
            VALUES
                (rec.numrun_cli, rec.dvrun_cli, rec.nombre, p_anno,
                 v_cantidad, v_dias, v_monto, v_puntaje, v_categoria);
        END IF;

        v_registros := v_registros + 1;
    END LOOP;

    sp_registrar_control('SP_PROCESAR_SCORING_ANUAL', v_registros, 'OK', 'Año ' || p_anno);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        sp_registrar_control('SP_PROCESAR_SCORING_ANUAL', v_registros, 'ERROR', SQLERRM);
        ROLLBACK;
        RAISE;
END sp_procesar_scoring_anual;
/

CREATE OR REPLACE PROCEDURE sp_generar_clasificacion_anual (
    p_anno IN NUMBER
) IS
    CURSOR c_clientes IS
        SELECT numrun_cli, dvrun_cli,
               TRIM(pnombre_cli || ' ' || appaterno_cli || ' ' || apmaterno_cli) AS nombre
          FROM cliente;

    v_cantidad  NUMBER(5);
    v_categoria VARCHAR2(15);
    v_registros NUMBER(8) := 0;
BEGIN
    FOR rec IN c_clientes LOOP
        v_cantidad := fn_cantidad_arriendos_cliente(rec.numrun_cli, p_anno);

        IF    v_cantidad >= 4 THEN v_categoria := 'Preferente';
        ELSIF v_cantidad >= 2 THEN v_categoria := 'Frecuente';
        ELSIF v_cantidad = 1  THEN v_categoria := 'Ocasional';
        ELSE                       v_categoria := 'Inactivo';
        END IF;

        UPDATE clasificacion_cliente 
           SET cantidad_arriendos = v_cantidad,
               categoria_cliente  = v_categoria
         WHERE numrun_cli   = rec.numrun_cli 
           AND anno_proceso = p_anno;

        IF SQL%ROWCOUNT = 0 THEN
            INSERT INTO clasificacion_cliente 
                (numrun_cli, dvrun_cli, nombre_cliente, anno_proceso,
                 cantidad_arriendos, categoria_cliente)
            VALUES
                (rec.numrun_cli, rec.dvrun_cli, rec.nombre, p_anno,
                 v_cantidad, v_categoria);
        END IF;

        v_registros := v_registros + 1;
    END LOOP;

    sp_registrar_control('SP_GENERAR_CLASIFICACION_ANUAL', v_registros, 'OK', 'Año ' || p_anno);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        sp_registrar_control('SP_GENERAR_CLASIFICACION_ANUAL', v_registros, 'ERROR', SQLERRM);
        ROLLBACK;
        RAISE;
END sp_generar_clasificacion_anual;
/

CREATE OR REPLACE PROCEDURE sp_ejecutar_scoring_vigente IS
BEGIN
    sp_procesar_scoring_anual(fn_anno_actual);
END sp_ejecutar_scoring_vigente;
/