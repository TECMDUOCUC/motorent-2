CREATE OR REPLACE TRIGGER trg_bi_arriendo_valida
BEFORE INSERT ON arriendo_moto
FOR EACH ROW
DECLARE
    v_overlap NUMBER;
BEGIN
    IF :NEW.fecha_devolucion IS NULL AND :NEW.dias_solicitados IS NOT NULL THEN
        :NEW.fecha_devolucion := :NEW.fecha_ini_arriendo + :NEW.dias_solicitados;
    END IF;

    SELECT COUNT(*)
        INTO v_overlap
        FROM arriendo_moto
    WHERE placa = :NEW.placa
        AND fecha_ini_arriendo < NVL(:NEW.fecha_devolucion, :NEW.fecha_ini_arriendo + 1)
        AND NVL(fecha_devolucion, fecha_ini_arriendo + dias_solicitados) > :NEW.fecha_ini_arriendo;

    IF v_overlap > 0 THEN
        pkg_auditoria.incrementar_evento('SOLAPAMIENTO_RECHAZADO');
        RAISE_APPLICATION_ERROR(-20001,
            'La motocicleta ' || :NEW.placa || ' ya tiene un arriendo en ese rango.');
    END IF;

    pkg_auditoria.incrementar_evento('ARRIENDO_INSERTADO');
END trg_bi_arriendo_valida;
/

CREATE OR REPLACE TRIGGER trg_au_cliente_renta
AFTER UPDATE OF renta ON cliente
FOR EACH ROW
BEGIN
    IF :OLD.renta <> :NEW.renta THEN
        INSERT INTO auditoria_cliente
            (numrun_cli, usuario, tipo_operacion, campo_modificado, valor_anterior, valor_nuevo)
        VALUES
            (:NEW.numrun_cli, USER, 'UPDATE', 'RENTA', TO_CHAR(:OLD.renta), TO_CHAR(:NEW.renta));
        pkg_auditoria.incrementar_evento('RENTA_MODIFICADA');
    END IF;
END trg_au_cliente_renta;
/


CREATE OR REPLACE TRIGGER trg_ai_arriendo_log
AFTER INSERT ON arriendo_moto
BEGIN
    INSERT INTO control_proceso (nombre_proceso, registros_proc, estado, detalle)
    VALUES ('TRG_AI_ARRIENDO_LOG', 0, 'OK', 'Carga de arriendos ejecutada por ' || USER);
END trg_ai_arriendo_log;
/

CREATE OR REPLACE TRIGGER trg_ai_scoring_pkg
AFTER INSERT ON scoring_cliente
FOR EACH ROW
BEGIN
    pkg_auditoria.incrementar_evento('SCORING_GENERADO');
END trg_ai_scoring_pkg;
/