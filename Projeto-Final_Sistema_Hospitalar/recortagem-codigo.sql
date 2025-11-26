

-------------------------------------------------------------
-- TRIGGER: TRG_DATA_SOLICITACAO_VALIDA
-- Impede que um exame seja registrado com data futura.
-- Valida a integridade temporal dos registros de exames.
-------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_DATA_SOLICITACAO_VALIDA
BEFORE INSERT OR UPDATE ON ATENDIMENTO_EXAME
FOR EACH ROW
BEGIN
    IF :NEW.DATA_SOLICITACAO > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'DATA_SOLICITACAO Não pode ser no futuro.');
        END IF;
END;
/



-------------------------------------------------------------
-- TRIGGER: TRG_OCUPAR_LEITO
-- Atualiza automaticamente o status do leito para OCUPADO
-- sempre que um atendimento for registrado com ID_LEITO.
-------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_OCUPAR_LEITO
AFTER INSERT ON ATENDIMENTO
FOR EACH ROW
BEGIN
    IF :NEW.ID_LEITO IS NOT NULL THEN
        UPDATE LEITO
        SET STATUS_LEITO = 'OCUPADO'
        WHERE ID_LEITO = :NEW.ID_LEITO;
    END IF;
END;
/

-------------------------------------------------------------
-- TRIGGER: TRG_IMPEDIR_DELETE_PACIENTE
-- Impede exclusão de um paciente se houver atendimentos
-- vinculados a ele.
-------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_IMPEDIR_DELETE_PACIENTE
BEFORE DELETE ON PACIENTE
FOR EACH ROW
DECLARE
    v_contador NUMBER;
BEGIN

    -- Verificar se existe atendimento associado ao paciente
    SELECT COUNT(*)
    INTO v_contador
    FROM ATENDIMENTO
    WHERE ID_PACIENTE = :OLD.ID_PACIENTE;

    -- Se houver atendimentos, impedir a exclusão
    IF v_contador > 0 THEN
    RAISE_APPLICATION_ERROR(
        -20003,
        'Não é possível excluir este PACIENTE: existem atendimentos vinculados.'
    );
    END IF;
END;
/

DELETE FROM PACIENTE
WHERE ID_PACIENTE = 1;

-------------------------------------------------------------
-- TRIGGER: TRG_REGISTRAR_DATA_ALTA
-- Registra automaticamente a DATA_ALTA quando a observação
-- do atendimento contiver a palavra "ALTA".
-------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_REGISTRAR_DATA_ALTA
BEFORE UPDATE ON ATENDIMENTO
FOR EACH ROW
BEGIN
    -- Se houver alteração indicando ALTA
    IF UPPER(:NEW.OBSERVACOES) LIKE '%ALTA%'
    AND :OLD.DATA_ALTA IS NULL THEN

    -- Preencher automaticamente a data da alta
    :NEW.DATA_ALTA := SYSDATE;
    END IF;
END;
/
    -- Teste
SELECT ID_ATENDIMENTO, DATA_ALTA
FROM ATENDIMENTO
WHERE ID_ATENDIMENTO = 1;

UPDATE ATENDIMENTO
SET OBSERVACOES = 'Paciente recebeu alta'
WHERE ID_ATENDIMENTO = 1;

-------------------------------------------------------------
-- TRIGGER: TRG_IMPEDIR_LEITO_OCUPADO
-- Impede que um atendimento utilize ou altere para um
-- leito que já esteja ocupado.
-------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_IMPEDIR_LEITO_OCUPADO
BEFORE INSERT OR UPDATE OF ID_LEITO ON ATENDIMENTO
FOR EACH ROW
DECLARE
    v_status VARCHAR2(200);
BEGIN
    -- Só verifica quando o ID_LEITO for alterado
    IF :NEW.ID_LEITO IS NOT NULL AND :NEW.ID_LEITO != :OLD.ID_LEITO THEN

        -- Buscar status atual do leito
        SELECT STATUS_LEITO
        INTO v_status
        FROM LEITO
        WHERE ID_LEITO = :NEW.ID_LEITO;

        -- Se estiver ocupado, impedir troca
        IF v_status = 'OCUPADO' THEN
            RAISE_APPLICATION_ERROR(
                -20002,
                'Este leito já está OCUPADO.'
            );
        END IF;

    END IF;
END;
/

-------------------------------------------------------------
-- TRIGGER: TRG_HISTORICO_ATENDIMENTO
-- Registra automaticamente as alterações feitas nos campos
-- DIAGNOSTICO e OBSERVACOES do atendimento.
-------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_HISTORICO_ATENDIMENTO
AFTER UPDATE ON ATENDIMENTO
FOR EACH ROW
BEGIN
    -- Se o diagnóstico mudou
    IF :OLD.DIAGNOSTICO != :NEW.DIAGNOSTICO THEN
        INSERT INTO HISTORICO_ATENDIMENTO (
            ID_ATENDIMENTO, CAMPO_ALTERADO, VALOR_ANTIGO, VALOR_NOVO
        ) VALUES (
            :OLD.ID_ATENDIMENTO, 
            'DIAGNOSTICO',
            :OLD.DIAGNOSTICO,
            :NEW.DIAGNOSTICO
        );
    END IF;

    -- Se as observações mudaram
    IF :OLD.OBSERVACOES != :NEW.OBSERVACOES THEN
        INSERT INTO HISTORICO_ATENDIMENTO (
            ID_ATENDIMENTO, CAMPO_ALTERADO, VALOR_ANTIGO, VALOR_NOVO
        ) VALUES (
            :OLD.ID_ATENDIMENTO, 
            'OBSERVACOES',
            :OLD.OBSERVACOES,
            :NEW.OBSERVACOES
        );
    END IF;
END;
/

-------------------------------------------------------------
-- TRIGGER: TRG_AUDITORIA_FINANCEIRO
-- Objetivo: Registrar alterações nos campos VALOR e
-- TIPO_PAGAMENTO da tabela FINANCEIRO, criando um histórico
-- de auditoria para rastreabilidade.
-------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_FINANCEIRO
AFTER UPDATE ON FINANCEIRO
FOR EACH ROW
BEGIN
    -- Caso o VALOR seja alterado
    IF :OLD.VALOR != :NEW.VALOR THEN
        INSERT INTO HISTORICO_FINANCEIRO (
            ID_FINANCEIRO, CAMPO_ALTERADO, VALOR_ANTIGO, VALOR_NOVO
        ) VALUES (
            :OLD.ID_FINANCEIRO,
            'VALOR',
            TO_CHAR(:OLD.VALOR),
            TO_CHAR(:NEW.VALOR)
        );
    END IF;

    -- Caso o TIPO_PAGAMENTO seja alterado
    IF :OLD.TIPO_PAGAMENTO != :NEW.TIPO_PAGAMENTO THEN
        INSERT INTO HISTORICO_FINANCEIRO (
            ID_FINANCEIRO, CAMPO_ALTERADO, VALOR_ANTIGO, VALOR_NOVO
        ) VALUES (
            :OLD.ID_FINANCEIRO,
            'TIPO_PAGAMENTO',
            :OLD.TIPO_PAGAMENTO,
            :NEW.TIPO_PAGAMENTO
        );
    END IF;
END;
/
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

-------------------------------------------------------------
-- VIEW: VW_RESUMO_ATENDIMENTO
-- Objetivo: Exibir um resumo completo dos atendimentos,
-- agrupando informações de várias tabelas em uma única visão.
-------------------------------------------------------------
CREATE OR REPLACE VIEW VW_RESUMO_ATENDIMENTO AS
SELECT 
    A.ID_ATENDIMENTO,
    P.NOME AS NOME_PACIENTE,  -- Paciente relacionado
    M.CRM AS CRM_MEDICO,      -- CRM do médico responsável
    M.ESPECIALIDADE,
    A.DIAGNOSTICO,
    A.OBSERVACOES,
    A.AGENDAMENTO,
    A.DATA_ALTA,              -- Data de alta (se houver)
    L.ID_LEITO,
    L.STATUS_LEITO
FROM ATENDIMENTO A
JOIN PACIENTE P ON A.ID_PACIENTE = P.ID_PACIENTE
JOIN MEDICO M ON A.ID_MEDICO = M.ID_MEDICO
LEFT JOIN LEITO L ON A.ID_LEITO = L.ID_LEITO;

SELECT ID_ATENDIMENTO, NOME_PACIENTE, CRM_MEDICO
FROM VW_RESUMO_ATENDIMENTO;

-- VIEW: VW_OCUPACAO_LEITOS
-- Objetivo: Mostrar o status dos leitos e seus respectivos
-- setores, facilitando o controle da ocupação hospitalar.
CREATE OR REPLACE VIEW VW_OCUPACAO_LEITOS AS
SELECT 
    S.NOME_SETOR,
    S.BLOCO,
    L.ID_LEITO,
    L.STATUS_LEITO
FROM LEITO L
JOIN SETOR S ON L.ID_SETOR = S.ID_SETOR;

SELECT NOME_SETOR, BLOCO, ID_LEITO, STATUS_LEITO
FROM VW_OCUPACAO_LEITOS;

-------------------------------------------------------------
-- VIEW: VW_HISTORICO_ATENDIMENTO
-- Objetivo: Mostrar os registros de auditoria de alterações
-- ocorridas nos atendimentos.
-------------------------------------------------------------
CREATE OR REPLACE VIEW VW_HISTORICO_ATENDIMENTO AS
SELECT 
    H.ID_HISTORICO,
    H.ID_ATENDIMENTO,
    H.CAMPO_ALTERADO,
    H.VALOR_ANTIGO,
    H.VALOR_NOVO,
    H.DATA_ALTERACAO
FROM HISTORICO_ATENDIMENTO H;

SELECT 
    ID_HISTORICO,
    ID_ATENDIMENTO,
    CAMPO_ALTERADO,
    VALOR_ANTIGO,
    VALOR_NOVO,
    DATA_ALTERACAO
FROM VW_HISTORICO_ATENDIMENTO
WHERE ID_ATENDIMENTO = 1;

-- VIEW: VW_FINANCEIRO_RESUMO
-- Objetivo: Mostrar os registros financeiros junto com
-- informações do atendimento, paciente e setor.
CREATE OR REPLACE VIEW VW_FINANCEIRO_RESUMO AS
SELECT
    F.ID_FINANCEIRO,
    F.ID_ATENDIMENTO,
    P.NOME AS NOME_PACIENTE,
    M.CRM AS CRM_MEDICO,
    F.VALOR,
    F.TIPO_PAGAMENTO,
    A.DIAGNOSTICO,
    L.ID_LEITO,
    S.NOME_SETOR AS SETOR
FROM FINANCEIRO F
JOIN ATENDIMENTO A ON F.ID_ATENDIMENTO = A.ID_ATENDIMENTO
JOIN PACIENTE P ON A.ID_PACIENTE = P.ID_PACIENTE
JOIN MEDICO M ON A.ID_MEDICO = M.ID_MEDICO
LEFT JOIN LEITO L ON A.ID_LEITO = L.ID_LEITO
LEFT JOIN SETOR S ON L.ID_SETOR = S.ID_SETOR;

SELECT 
    ID_ATENDIMENTO,
    NOME_PACIENTE,
    VALOR,
    TIPO_PAGAMENTO,
    SETOR
FROM VW_FINANCEIRO_RESUMO;

-- Inserindo dado de teste
UPDATE PACIENTE 
SET DATA_NASCIMENTO = TO_DATE('12/05/2000', 'DD/MM/YYYY')
WHERE ID_PACIENTE = 1;

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