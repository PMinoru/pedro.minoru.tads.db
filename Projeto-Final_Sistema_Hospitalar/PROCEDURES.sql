-------------------------------------------------------------
-- PROCEDURE: CADASTRAR_PACIENTE
-- Objetivo: Cadastrar um novo paciente garantindo que o CPF
-- não esteja duplicado. Caso exista, é lançada uma exceção.
-------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CADASTRAR_PACIENTE (
    p_nome  IN  VARCHAR2,
    p_cpf   IN  NUMBER,
    p_plano IN  VARCHAR2
) AS
    v_count NUMBER;
BEGIN
    -- Verificando duplicidade do CPF
    SELECT COUNT(*) INTO v_count FROM PACIENTE WHERE CPF = p_cpf;
    
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'CPF já cadastrado.');
    END IF;

-- Inserção do novo paciente
    INSERT INTO PACIENTE (NOME, CPF, PLANO)
    VALUES (p_nome, p_cpf, p_plano);

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
    -- Em caso de erro, desfaz a transação
        ROLLBACK;
        RAISE;
END;
/

EXEC CADASTRAR_PACIENTE('Maria de Souza', 55555555555, 'Unimed');

-------------------------------------------------------------
-- PROCEDURE: AGENDAR_ATENDIMENTO
-- Objetivo: Registrar um atendimento garantindo validações:
--   1) Paciente existe
--   2) Médico existe
--   3) Leito (se informado) está livre
--   4) Insere o atendimento
-- Contém controle de transação (COMMIT/ROLLBACK)
-------------------------------------------------------------
CREATE OR REPLACE PROCEDURE AGENDAR_ATENDIMENTO (
    p_agendamento   IN VARCHAR2,
    p_diagnostico   IN VARCHAR2,
    p_observacoes   IN VARCHAR2,
    p_id_paciente   IN NUMBER,
    p_id_medico     IN NUMBER,
    p_id_leito      IN NUMBER DEFAULT NULL
) AS
    v_exists NUMBER;
    v_status VARCHAR2(200);
BEGIN
    -- Validar paciente
    SELECT COUNT(*) INTO v_exists FROM PACIENTE WHERE ID_PACIENTE = p_id_paciente;
    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Paciente inexistente.');
    END IF;

    -- Validar médico
    SELECT COUNT(*) INTO v_exists FROM MEDICO WHERE ID_MEDICO = p_id_medico;
    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Médico inexistente.');
    END IF;

    -- Validar leito
    IF p_id_leito IS NOT NULL THEN
        SELECT STATUS_LEITO INTO v_status
        FROM LEITO
        WHERE ID_LEITO = p_id_leito
        FOR UPDATE; -- Garante que ninguém edite o leito ao mesmo tempo

        IF v_status = 'OCUPADO' THEN
            RAISE_APPLICATION_ERROR(-20013, 'Leito já está ocupado.');
        END IF;
    END IF;

-- Inserção do atendimento
    INSERT INTO ATENDIMENTO (
        AGENDAMENTO, DIAGNOSTICO, OBSERVACOES,
        ID_PACIENTE, ID_MEDICO, ID_LEITO
    )
    VALUES (
        p_agendamento, p_diagnostico, p_observacoes,
        p_id_paciente, p_id_medico, p_id_leito
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
    -- Desfaz a transação em caso de erro
        ROLLBACK;
        RAISE;
END;
/

BEGIN
    CADASTRAR_PACIENTE('Maria de Souza', 55555555555, 'Unimed');
END;
/



