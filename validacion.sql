SET SERVEROUTPUT ON

-- 1. Prueba de Procedimientos Masivos
EXECUTE sp_procesar_scoring_anual(2025);
EXECUTE sp_generar_clasificacion_anual(2025);
EXECUTE sp_ejecutar_scoring_vigente; 

SELECT * FROM scoring_cliente WHERE anno_proceso=2025 ORDER BY puntaje DESC;
SELECT * FROM clasificacion_cliente WHERE anno_proceso=2025;

--Probar que las funcionen las funciones (ja)
SELECT c.numrun_cli,
       fn_cantidad_arriendos_cliente(c.numrun_cli,2025) as arriendos,
       fn_obtener_puntaje_cliente(c.numrun_cli,2025) as puntaje
FROM   cliente c ;

-- Prueba de Package
BEGIN
    pkg_fidelidad_cliente.inicializar(2025);
    pkg_fidelidad_cliente.procesar_scoring;
    DBMS_OUTPUT.put_line('Beneficio cliente 15234567: '||
         pkg_fidelidad_cliente.pct_beneficio_cliente(15234567)||'%');
END;
/

-- Prueba de Triggers
-- Insertar válido
INSERT INTO arriendo_moto(id_arriendo,placa,numrun_cli,fecha_ini_arriendo,dias_solicitados)
VALUES (seq_arriendo.NEXTVAL,'MR012',15234567,TO_DATE('01/06/2027','DD/MM/YYYY'),3);
COMMIT;

-- Insertar con conflicto (Debe fallar)
BEGIN
    INSERT INTO arriendo_moto(id_arriendo,placa,numrun_cli,fecha_ini_arriendo,dias_solicitados)
    VALUES (seq_arriendo.NEXTVAL,'MR012',16789012,TO_DATE('02/06/2027','DD/MM/YYYY'),2);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.put_line('Error esperado capturado: ' || SQLERRM);
END;
/

-- Actualizar renta (Debe auditar)
UPDATE cliente SET renta=2700000 WHERE numrun_cli=15234567;
COMMIT;

SELECT * FROM auditoria_cliente ORDER BY id_auditoria DESC;
SELECT pkg_auditoria.total_eventos, pkg_auditoria.ultimo_evento FROM dual;
SELECT * FROM control_proceso ORDER BY id_proceso DESC;