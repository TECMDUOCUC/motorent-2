CREATE OR REPLACE FUNCTION fn_obtener_puntaje_cliente (
    p_numrun_cli IN NUMBER,
    p_anno       IN NUMBER
) RETURN NUMBER IS
    v_cantidad NUMBER(5) := 0;
BEGIN
    SELECT COUNT(*)
      INTO v_cantidad
      FROM arriendo_moto
     WHERE numrun_cli = p_numrun_cli
       AND EXTRACT(YEAR FROM fecha_ini_arriendo) = p_anno;
       
    RETURN v_cantidad * 10; 
END fn_obtener_puntaje_cliente;
/

CREATE OR REPLACE FUNCTION fn_cantidad_arriendos_cliente (
    p_numrun_cli IN NUMBER,
    p_anno       IN NUMBER
) RETURN NUMBER IS
    v_cantidad NUMBER(5) := 0;
BEGIN
    SELECT COUNT(*)
      INTO v_cantidad
      FROM arriendo_moto
     WHERE numrun_cli = p_numrun_cli
       AND EXTRACT(YEAR FROM fecha_ini_arriendo) = p_anno;
    RETURN v_cantidad;
END fn_cantidad_arriendos_cliente;
/


CREATE OR REPLACE FUNCTION fn_total_dias_cliente (
    p_numrun_cli IN NUMBER,
    p_anno       IN NUMBER
) RETURN NUMBER IS
    v_dias NUMBER(6) := 0;
BEGIN
    SELECT NVL(SUM(dias_solicitados), 0)
      INTO v_dias
      FROM arriendo_moto
     WHERE numrun_cli = p_numrun_cli
       AND EXTRACT(YEAR FROM fecha_ini_arriendo) = p_anno;
    RETURN v_dias;
END fn_total_dias_cliente;
/

CREATE OR REPLACE FUNCTION fn_monto_arriendos_cliente (
    p_numrun_cli IN NUMBER,
    p_anno       IN NUMBER
) RETURN NUMBER IS
    v_monto NUMBER(14) := 0;
BEGIN
    SELECT NVL(SUM(a.dias_solicitados * m.valor_arriendo_dia), 0)
      INTO v_monto
      FROM arriendo_moto a
      JOIN motocicleta  m ON m.placa = a.placa
     WHERE a.numrun_cli = p_numrun_cli
       AND EXTRACT(YEAR FROM a.fecha_ini_arriendo) = p_anno;
    RETURN v_monto;
END fn_monto_arriendos_cliente;
/

CREATE OR REPLACE FUNCTION fn_anno_actual RETURN NUMBER IS
BEGIN
    RETURN EXTRACT(YEAR FROM SYSDATE);
END fn_anno_actual;
/

CREATE OR REPLACE FUNCTION fn_total_clientes RETURN NUMBER IS
    v_total NUMBER(6);
BEGIN
    SELECT COUNT(*) INTO v_total FROM cliente;
    RETURN v_total;
END fn_total_clientes;
/