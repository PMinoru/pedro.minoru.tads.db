-- Inserindo setor

INSERT INTO SETOR (NOME_SETOR, BLOCO, TIPO_SETOR)
VALUES ('Emergencia', 'A', 'Atendimento');

-- Inserindo paciente

INSERT INTO PACIENTE (NOME, CPF, PLANO)
VALUES ('Joao da Silva', 12345678900, 'Unimed');


-- Inserindo médico

INSERT INTO MEDICO (CRM, ESPECIALIDADE)
VALUES (12345, 'Clinico Geral');

-- Inserindo leito

INSERT INTO LEITO (STATUS_LEITO, ID_SETOR)
VALUES ('LIVRE', 1);

-- Inserindo atendimento

INSERT INTO ATENDIMENTO (
    AGENDAMENTO, DIAGNOSTICO, OBSERVACOES,
    ID_PACIENTE, ID_MEDICO, ID_LEITO
)
VALUES (
    'Consulta Geral', 'Dor de cabeca', 'Paciente estavel',
    1, 1, 1
);

-- Inserindo exame

INSERT INTO EXAME (NOME, TIPO_EXAME, DESCRICAO)
VALUES ('Exame de Sangue', 'Laboratorio', 'Hemograma Completo');

INSERT INTO ATENDIMENTO_EXAME (
    DATA_SOLICITACAO, ID_ATENDIMENTO, ID_EXAME
)
VALUES (
    TO_DATE('30/12/2099', 'DD/MM/YYYY'), -- DATA FUTURA PROPOSITAL
    1,
    1
);


INSERT INTO ATENDIMENTO_EXAME (
    DATA_SOLICITACAO, ID_ATENDIMENTO, ID_EXAME
)
VALUES (
    SYSDATE,
    1,
    1
);