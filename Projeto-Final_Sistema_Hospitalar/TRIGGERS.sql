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