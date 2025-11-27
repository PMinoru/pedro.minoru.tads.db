

-- PACKAGE: PKG_HOSPITAL (SPECIFICATION)
-- Objetivo: Centralizar funções e procedimentos relacionados
-- à gestão hospitalar.
CREATE OR REPLACE PACKAGE PKG_HOSPITAL AS
    
    -- Funções
    FUNCTION FN_CALCULA_IDADE (p_id_paciente NUMBER) RETURN NUMBER;
    FUNCTION FN_LEITO_LIVRE (p_id_leito NUMBER) RETURN NUMBER;

    -- Procedures
    PROCEDURE CADASTRAR_PACIENTE (
        p_nome  IN  VARCHAR2,
        p_cpf   IN  NUMBER,
        p_plano IN  VARCHAR2,
        p_data_nasc IN DATE
    );

    PROCEDURE AGENDAR_ATENDIMENTO (
        p_agendamento   IN VARCHAR2,
        p_diagnostico   IN VARCHAR2,
        p_observacoes   IN VARCHAR2,
        p_id_paciente   IN NUMBER,
        p_id_medico     IN NUMBER,
        p_id_leito      IN NUMBER DEFAULT NULL
    );

    PROCEDURE LIBERAR_LEITO (p_id_leito NUMBER);

    PROCEDURE DAR_ALTA (p_id_atendimento NUMBER);

END PKG_HOSPITAL;
/
    
-- IMPLEMENTAÇÃO DO PACKAGE BODY PKG_HOSPITAL
-- Contém funções e procedures utilizadas no sistema hospitalar
CREATE OR REPLACE PACKAGE BODY PKG_HOSPITAL AS

    -- FUNÇÃO 1: idade do paciente

    FUNCTION FN_CALCULA_IDADE (p_id_paciente NUMBER)
    RETURN NUMBER AS
        v_data DATE;
    BEGIN
        SELECT DATA_NASCIMENTO INTO v_data
        FROM PACIENTE
        WHERE ID_PACIENTE = p_id_paciente;

        -- Calcula idade em anos
        RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, v_data) / 12);
    END FN_CALCULA_IDADE;

    -- FUNÇÃO 2: leito livre

    FUNCTION FN_LEITO_LIVRE (p_id_leito NUMBER)
    RETURN NUMBER AS
        v_status VARCHAR2(200);
    BEGIN
        SELECT STATUS_LEITO INTO v_status
        FROM LEITO
        WHERE ID_LEITO = p_id_leito;

        IF v_status = 'LIVRE' THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END FN_LEITO_LIVRE;

    -- PROCEDURE: cadastrar paciente
    PROCEDURE CADASTRAR_PACIENTE (
        p_nome  IN  VARCHAR2,
        p_cpf   IN  NUMBER,
        p_plano IN  VARCHAR2,
        p_data_nasc IN DATE
    ) AS
        v_count NUMBER;
    BEGIN
        -- Verifica se já existe CPF cadastrado
        SELECT COUNT(*) INTO v_count FROM PACIENTE WHERE CPF = p_cpf;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'CPF já cadastrado.');
        END IF;

        -- Insere novo paciente no sistema
        INSERT INTO PACIENTE (NOME, CPF, PLANO, DATA_NASCIMENTO)
        VALUES (p_nome, p_cpf, p_plano, p_data_nasc);

        COMMIT;
    END CADASTRAR_PACIENTE;

    -- PROCEDURE: agendar atendimento
    -- Cria um novo atendimento e verifica se o leito está disponível
    PROCEDURE AGENDAR_ATENDIMENTO (
        p_agendamento   IN VARCHAR2,
        p_diagnostico   IN VARCHAR2,
        p_observacoes   IN VARCHAR2,
        p_id_paciente   IN NUMBER,
        p_id_medico     IN NUMBER,
        p_id_leito      IN NUMBER DEFAULT NULL
    ) AS
        v_status VARCHAR2(200);
    BEGIN
        -- Caso exista leito, verificar se está disponível
        IF p_id_leito IS NOT NULL THEN
            SELECT STATUS_LEITO INTO v_status
            FROM LEITO
            WHERE ID_LEITO = p_id_leito
            FOR UPDATE;

            IF v_status = 'OCUPADO' THEN
                RAISE_APPLICATION_ERROR(-20015, 'Leito ocupado.');
            END IF;
        END IF;

        INSERT INTO ATENDIMENTO (
            AGENDAMENTO, DIAGNOSTICO, OBSERVACOES,
            ID_PACIENTE, ID_MEDICO, ID_LEITO
        ) VALUES (
            p_agendamento, p_diagnostico, p_observacoes,
            p_id_paciente, p_id_medico, p_id_leito
        );

        COMMIT;
    END AGENDAR_ATENDIMENTO;

    -- PROCEDURE: LIBERAR_LEITO
    -- Atualiza o status do leito para "LIVRE"-- PROCEDURE: liberar leito
    PROCEDURE LIBERAR_LEITO (p_id_leito NUMBER) AS
    BEGIN
        UPDATE LEITO
        SET STATUS_LEITO = 'LIVRE'
        WHERE ID_LEITO = p_id_leito;

        COMMIT;
    END LIBERAR_LEITO;

-- PROCEDURE: DAR_ALTA
-- Marca o atendimento como finalizado, registrando alta
    PROCEDURE DAR_ALTA (p_id_atendimento NUMBER) AS
    BEGIN
        UPDATE ATENDIMENTO
        SET OBSERVACOES = 'Paciente recebeu alta'
        WHERE ID_ATENDIMENTO = p_id_atendimento;

        COMMIT;
    END DAR_ALTA;

END PKG_HOSPITAL;
/
-- FIM DO PACKAGE BODY



-- ÍNDICES
-- Índice para acelerar buscas por paciente nos atendimentos
CREATE INDEX IDX_ATEND_PACIENTE 
ON ATENDIMENTO(ID_PACIENTE);

CREATE INDEX IDX_ATEND_MEDICO 
ON ATENDIMENTO(ID_MEDICO);

-- Dica de performance: leitura completa da tabela PACIENTE
SELECT /*+ FULL(P) */ 
    P.NOME, A.DIAGNOSTICO
FROM PACIENTE P
JOIN ATENDIMENTO A ON A.ID_PACIENTE = P.ID_PACIENTE;