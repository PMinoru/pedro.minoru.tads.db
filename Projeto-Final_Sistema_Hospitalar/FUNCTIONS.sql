-- FUNCTION: FN_CALCULA_IDADE
-- Objetivo: Calcular a idade de um paciente com base na
-- data de nascimento.
CREATE OR REPLACE FUNCTION FN_CALCULA_IDADE (p_id_paciente NUMBER)
RETURN NUMBER
AS
    v_data_nasc DATE;
    v_idade NUMBER;
BEGIN
    -- Buscar a data de nascimento
    SELECT DATA_NASCIMENTO 
    INTO v_data_nasc
    FROM PACIENTE
    WHERE ID_PACIENTE = p_id_paciente;

    -- Calcular a idade
    v_idade := TRUNC(MONTHS_BETWEEN(SYSDATE, v_data_nasc) / 12);

    RETURN v_idade;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20020, 'Paciente não encontrado.');
END;
/

SELECT FN_CALCULA_IDADE(1) FROM dual;

-- FUNCTION: FN_TOTAL_EXAMES_ATENDIMENTO
-- Objetivo: Somar o valor total dos exames solicitados
-- para um atendimento específico.
CREATE OR REPLACE FUNCTION FN_TOTAL_EXAMES_ATENDIMENTO (p_id_atendimento NUMBER)
RETURN NUMBER
AS
    v_total NUMBER := 0;
BEGIN
    SELECT SUM(E.VALOR)
    INTO v_total
    FROM ATENDIMENTO_EXAME AE
    JOIN EXAME E ON AE.ID_EXAME = E.ID_EXAME
    WHERE AE.ID_ATENDIMENTO = p_id_atendimento;

    RETURN NVL(v_total, 0); -- Retorna 0 se for NULL
END;
/

-- FUNCTION: FN_LEITO_LIVRE
-- Objetivo: Verificar se um leito está disponível.
CREATE OR REPLACE FUNCTION FN_LEITO_LIVRE (p_id_leito NUMBER)
RETURN NUMBER
AS
    v_status VARCHAR2(200);
BEGIN
    SELECT STATUS_LEITO
    INTO v_status
    FROM LEITO
    WHERE ID_LEITO = p_id_leito;

    IF v_status = 'LIVRE' THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
    -- Leito inexistente também retorna 0
        RETURN 0;
END;
/