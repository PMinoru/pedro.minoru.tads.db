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