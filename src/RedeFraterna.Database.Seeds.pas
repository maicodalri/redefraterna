unit RedeFraterna.Database.Seeds;

{$mode Delphi}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, IniFiles,
  ZConnection, ZDataset,
  twapi.SQLBuilder,
  sha1;

type
  { TRedeFraternaSeeds }
  TRedeFraternaSeeds = class
  public
    class procedure SeedInitialData(AConn: TZConnection);
  end;

implementation

class procedure TRedeFraternaSeeds.SeedInitialData(AConn: TZConnection);
var
  LQry: TZQuery;
  LSenhaHash, LConfFile, LNomeMantenedora, LSiglaMantenedora, LCidadeMantenedora, LUFMantenedora: string;
  LIni: TIniFile;
begin
  if (AConn = nil) or (not AConn.Connected) then Exit;

  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;

    // Garante registro padrão na tabela configuracoes (Entidade Mantenedora)
    LQry.SQL.Text := 'SELECT COUNT(*) FROM configuracoes';
    LQry.Open;
    if LQry.Fields[0].AsInteger = 0 then
    begin
      LQry.Close;
      LNomeMantenedora := 'UME - Cachoeira do Sul';
      LSiglaMantenedora := 'UME';
      LCidadeMantenedora := 'Cachoeira do Sul';
      LUFMantenedora := 'RS';

      LConfFile := ChangeFileExt(ParamStr(0), '.conf');
      if FileExists(LConfFile) then
      begin
        LIni := TIniFile.Create(LConfFile);
        try
          LNomeMantenedora := Trim(LIni.ReadString('Entidade', 'NomeMantenedora', LNomeMantenedora));
          LSiglaMantenedora := Trim(LIni.ReadString('Entidade', 'SiglaMantenedora', LSiglaMantenedora));
          LCidadeMantenedora := Trim(LIni.ReadString('Entidade', 'CidadeMantenedora', LCidadeMantenedora));
          LUFMantenedora := Trim(LIni.ReadString('Entidade', 'UFMantenedora', LUFMantenedora));
        finally
          LIni.Free;
        end;
      end;

      LQry.SQL.Text :=
        'INSERT INTO configuracoes (nome_mantenedora, sigla_mantenedora, subtitulo_sistema, cidade_mantenedora, uf_mantenedora) ' +
        'VALUES (:nome, :sigla, :sub, :cidade, :uf)';
      LQry.ParamByName('nome').AsString := LNomeMantenedora;
      LQry.ParamByName('sigla').AsString := LSiglaMantenedora;
      LQry.ParamByName('sub').AsString := 'Gestão Integrada de Centros Espíritas e Assistência Social';
      LQry.ParamByName('cidade').AsString := LCidadeMantenedora;
      LQry.ParamByName('uf').AsString := LUFMantenedora;
      LQry.ExecSQL;
    end;

    LQry.Close;
    LQry.SQL.Text := SQLSelectFrom('usuarios', AConn.Protocol).BuildCount;
    LQry.Open;
    if LQry.Fields[0].AsInteger = 0 then
    begin
      LQry.Close;
      LSenhaHash := SHA1Print(SHA1String('admin123'));
      LQry.SQL.Text :=
        'INSERT INTO usuarios (login, nome, senha_hash, tipo, ativo) ' +
        'VALUES (:login, :nome, :senha_hash, :tipo, :ativo)';
      LQry.ParamByName('login').AsString := 'admin';
      LQry.ParamByName('nome').AsString := 'Administrador UME';
      LQry.ParamByName('senha_hash').AsString := LSenhaHash;
      LQry.ParamByName('tipo').AsString := 'A';
      LQry.ParamByName('ativo').AsString := 'S';
      LQry.ExecSQL;

      // Insere também perfis de exemplo vinculados ao Centro Espírita #1 (CEAK) para facilitar os testes iniciais
      LQry.Close;
      LQry.SQL.Text :=
        'INSERT INTO usuarios (centro_id, login, nome, senha_hash, tipo, ativo) ' +
        'VALUES (:centro_id, :login, :nome, :senha_hash, :tipo, :ativo)';
      LQry.ParamByName('centro_id').AsInteger := 1;
      LQry.ParamByName('login').AsString := 'operador';
      LQry.ParamByName('nome').AsString := 'Operador do Sistema (CEAK)';
      LQry.ParamByName('senha_hash').AsString := SHA1Print(SHA1String('123456'));
      LQry.ParamByName('tipo').AsString := 'O';
      LQry.ParamByName('ativo').AsString := 'S';
      LQry.ExecSQL;

      LQry.Close;
      LQry.SQL.Text :=
        'INSERT INTO usuarios (centro_id, login, nome, senha_hash, tipo, ativo) ' +
        'VALUES (:centro_id, :login, :nome, :senha_hash, :tipo, :ativo)';
      LQry.ParamByName('centro_id').AsInteger := 1;
      LQry.ParamByName('login').AsString := 'familia';
      LQry.ParamByName('nome').AsString := 'Operador da Família (CEAK)';
      LQry.ParamByName('senha_hash').AsString := SHA1Print(SHA1String('123456'));
      LQry.ParamByName('tipo').AsString := 'F';
      LQry.ParamByName('ativo').AsString := 'S';
      LQry.ExecSQL;

      // Dados iniciais de demonstração em SQLite
      if SameText(AConn.Protocol, 'sqlite') then
      begin
        AConn.ExecuteDirect(
          'INSERT INTO centros_espiritas (nome, sigla, cnpj, logradouro, numero, bairro, cidade, uf, cep, telefone, email, presidente, data_fundacao, observacoes, ativo) VALUES ' +
          '(''Centro Espírita Allan Kardec'', ''CEAK'', ''11.222.333/0001-44'', ''Rua da Fraternidade'', ''150'', ''Centro'', ''São Paulo'', ''SP'', ''01001-000'', ''(11) 3222-1111'', ''contato@ceak.org.br'', ''Maria Helena Souza'', ''1958-04-18'', ''Sede própria vinculada à UME'', ''S''), ' +
          '(''Sociedade Espírita Bezerra de Menezes'', ''SEBM'', ''22.333.444/0001-55'', ''Av. da Paz'', ''840'', ''Jardim América'', ''São Paulo'', ''SP'', ''01420-000'', ''(11) 3444-2222'', ''secretaria@sebm.org.br'', ''Carlos Alberto Mendes'', ''1975-08-29'', ''Atendimento fraterno e assistência social'', ''S''), ' +
          '(''Grupo Espírita Nosso Lar'', ''GENL'', ''33.444.555/0001-66'', ''Rua Emmanuel'', ''45'', ''Vila Mariana'', ''São Paulo'', ''SP'', ''04112-010'', ''(11) 5571-3333'', ''nossolar@genl.org.br'', ''Roberto Farias'', ''1992-10-03'', ''Foco em evangelização infantil e juventude'', ''S'');'
        );

        AConn.ExecuteDirect(
          'INSERT INTO trabalhadores (centro_id, nome, cpf, data_nascimento, telefone, email, funcao, departamento, data_ingresso, observacoes, ativo) VALUES ' +
          '(1, ''Maria Helena Souza'', ''111.222.333-44'', ''1965-03-12'', ''(11) 99111-2222'', ''maria@ceak.org.br'', ''Presidente / Expositora'', ''Diretoria'', ''1998-02-10'', ''Trabalhadora veterana'', ''S''), ' +
          '(1, ''João Batista Oliveira'', ''222.333.444-55'', ''1972-07-25'', ''(11) 99222-3333'', ''joao@ceak.org.br'', ''Coordenador de Assistência Social'', ''Promoção Social'', ''2005-05-15'', ''Responsável pelas visitas e cestas básicas'', ''S''), ' +
          '(2, ''Carlos Alberto Mendes'', ''333.444.555-66'', ''1960-11-08'', ''(11) 99333-4444'', ''carlos@sebm.org.br'', ''Presidente'', ''Diretoria'', ''1995-01-20'', ''Coordenador geral'', ''S''), ' +
          '(2, ''Ana Paula Ribeiro'', ''444.555.666-77'', ''1984-09-19'', ''(11) 99444-5555'', ''ana@sebm.org.br'', ''Passista e Atendimento Fraterno'', ''Assistência Espiritual'', ''2014-03-01'', ''Plantonista de quarta-feira'', ''S'');'
        );

        AConn.ExecuteDirect(
          'INSERT INTO agenda_centro (centro_id, dia_semana, horario_inicio, horario_fim, tipo_evento, titulo, descricao, responsavel, sala_local, ativo) VALUES ' +
          '(1, 1, ''20:00'', ''21:30'', ''EXPOSICAO_PUBLICA'', ''Palestra Pública e Passes'', ''Exposição do Evangelho segundo o Espiritismo seguida de passe espiritual'', ''Maria Helena Souza'', ''Salão Principal'', ''S''), ' +
          '(1, 3, ''19:30'', ''21:00'', ''ESTUDO_SISTEMATIZADO'', ''ESDE - Estudo Sistematizado da Doutrina Espírita'', ''Tomo I e II para iniciantes e veteranos'', ''João Batista Oliveira'', ''Sala 02'', ''S''), ' +
          '(1, 6, ''09:00'', ''11:30'', ''ASSISTENCIA_SOCIAL'', ''Acolhimento Fraterno e Entrega de Cestas'', ''Atendimento às famílias cadastradas e evangelização'', ''João Batista Oliveira'', ''Pátio Social'', ''S''), ' +
          '(2, 2, ''20:00'', ''21:15'', ''EXPOSICAO_PUBLICA'', ''Exposição Doutrinária da Terça'', ''Palestra aberta ao público com atendimento fraterno às 19h'', ''Carlos Alberto Mendes'', ''Auditório Bezerra'', ''S''), ' +
          '(2, 4, ''19:30'', ''21:00'', ''REUNIAO_MEDIUNICA'', ''Grupo de Educação e Prática Mediúnica'', ''Reunião privativa para trabalhadores cadastrados'', ''Ana Paula Ribeiro'', ''Sala reservada'', ''S'');'
        );

        AConn.ExecuteDirect(
          'INSERT INTO familias (centro_id, nome_referencia, cpf_responsavel, telefone, cep, logradouro, numero, complemento, bairro, cidade, uf, situacao, renda_familiar, observacoes, ativo) VALUES ' +
          '(1, ''Família Silva (Resp: Dona Aparecida)'', ''555.666.777-88'', ''(11) 98765-4321'', ''01015-000'', ''Rua das Oliveiras'', ''42'', ''Fundos'', ''Bela Vista'', ''São Paulo'', ''SP'', ''ATIVA'', 1412.00, ''Família acompanhada desde o início do ano. Necessita apoio alimentar e escolar.'', ''S''), ' +
          '(2, ''Família Santos (Resp: Sr. José Carlos)'', ''888.999.000-11'', ''(11) 97654-3210'', ''01430-000'', ''Travessa Esperança'', ''18'', ''Casa 2'', ''Jardim Paulista'', ''São Paulo'', ''SP'', ''ATIVA'', 950.00, ''Idoso em recuperação de saúde, esposa desempregada.'', ''S'');'
        );

        AConn.ExecuteDirect(
          'INSERT INTO familia_integrantes (familia_id, nome, cpf, data_nascimento, papel_familia, info_adicionais, ativo) VALUES ' +
          '(1, ''Aparecida Conceição da Silva'', ''555.666.777-88'', ''1978-05-14'', ''Mãe / Responsável'', ''Trabalha como diarista autônoma. Hipertensa.'', ''S''), ' +
          '(1, ''Lucas Gabriel da Silva'', ''666.777.888-99'', ''2012-08-22'', ''Filho'', ''Cursa o 7º ano do Ensino Fundamental. Participa da evangelização infantil.'', ''S''), ' +
          '(1, ''Sofia Mariana da Silva'', ''777.888.999-00'', ''2016-11-03'', ''Filha'', ''Cursa o 3º ano. Usa calçado nº 30 e roupa tam. 8.'', ''S''), ' +
          '(2, ''José Carlos dos Santos'', ''888.999.000-11'', ''1954-02-19'', ''Responsável / Esposo'', ''Aposentado por invalidez parcial, necessita medicamentos contínuos.'', ''S''), ' +
          '(2, ''Marta Ferreira dos Santos'', ''999.000.111-22'', ''1959-12-01'', ''Esposa'', ''Cuida do esposo e faz costuras eventuais.'', ''S'');'
        );

        AConn.ExecuteDirect(
          'INSERT INTO familia_auxilios (familia_id, centro_id, data_auxilio, tipo_auxilio, descricao, valor_estimado, quantidade, responsavel_entrega, observacoes, usuario_id, usuario_nome) VALUES ' +
          '(1, 1, ''2026-09-12'', ''CESTA_BASICA'', ''Cesta básica padrão (25kg) + Kit higiene'', 165.00, ''1 unidade'', ''João Batista Oliveira'', ''Entregue no plantão social de sábado'', 1, ''admin''), ' +
          '(1, 1, ''2026-10-10'', ''MATERIAL_ESCOLAR'', ''Kit cadernos, lápis de cor e mochila para os filhos'', 120.00, ''2 kits'', ''Maria Helena Souza'', ''Doação da campanha de primavera'', 1, ''admin''), ' +
          '(2, 2, ''2026-10-05'', ''SAUDE_MEDICAMENTO'', ''Auxílio na compra de medicamentos para pressão e diabetes'', 185.50, ''3 caixas'', ''Ana Paula Ribeiro'', ''Receita médica apresentada no atendimento fraterno'', 1, ''admin''), ' +
          '(2, 2, ''2026-10-15'', ''DINHEIRO'', ''Auxílio emergencial para pagamento de conta de energia elétrica'', 140.00, ''1 guia'', ''Carlos Alberto Mendes'', ''Aprovado pelo conselho diretor do centro'', 1, ''admin'');'
        );

        AConn.ExecuteDirect(
          'INSERT INTO familia_logs (familia_id, centro_id, usuario_id, usuario_nome, acao, entidade, entidade_id, resumo_alteracao, dados_anteriores, dados_novos) VALUES ' +
          '(1, 1, 1, ''admin'', ''CRIACAO'', ''FAMILIA'', 1, ''Cadastro inicial da Família Silva e vínculo ao Centro Espírita Allan Kardec'', NULL, ''{"nome_referencia":"Família Silva (Resp: Dona Aparecida)","centro_id":1}''), ' +
          '(2, 2, 1, ''admin'', ''CRIACAO'', ''FAMILIA'', 2, ''Cadastro inicial da Família Santos e vínculo à Sociedade Espírita Bezerra de Menezes'', NULL, ''{"nome_referencia":"Família Santos (Resp: Sr. José Carlos)","centro_id":2}'');'
        );
      end;
    end;

    // Garante vínculo de centro nos usuários não-administradores pré-existentes e notícias iniciais de exemplo
    AConn.ExecuteDirect(
      'UPDATE usuarios SET centro_id = (SELECT MIN(c.id) FROM centros_espiritas c WHERE c.ativo = ''S'') ' +
      'WHERE tipo <> ''A'' AND (centro_id IS NULL OR centro_id = 0) ' +
      'AND EXISTS (SELECT 1 FROM centros_espiritas c2 WHERE c2.ativo = ''S'')'
    );

    if SameText(AConn.Protocol, 'sqlite') then
    begin
      AConn.ExecuteDirect('UPDATE familias SET cpf_responsavel = ''555.666.777-88'' WHERE id = 1 AND (cpf_responsavel IS NULL OR cpf_responsavel = '''')');
      AConn.ExecuteDirect('UPDATE familias SET cpf_responsavel = ''888.999.000-11'' WHERE id = 2 AND (cpf_responsavel IS NULL OR cpf_responsavel = '''')');

      LQry.Close;
      LQry.SQL.Text := 'SELECT COUNT(*) FROM noticias';
      LQry.Open;
      if LQry.Fields[0].AsInteger = 0 then
      begin
        AConn.ExecuteDirect(
          'INSERT INTO noticias (centro_id, titulo, resumo, conteudo, categoria, autor, imagem_url, destaque, publicado, data_publicacao, ativo) VALUES ' +
          '(NULL, ''Encontro Anual de Trabalhadores da União Municipal Espírita (UME)'', ' +
          '''Reunião fraterna de integração das casas espíritas do município com oficinas de acolhimento, estudo e promoção social.'', ' +
          '''A União Municipal Espírita (UME) convida todos os trabalhadores, dirigentes e voluntários dos Centros Espíritas vinculados à Rede Fraterna para o nosso Encontro Anual de Integração.' + #10#10 +
          'O evento tem como objetivo fortalecer o intercâmbio entre as casas espíritas, compartilhar boas práticas no atendimento fraterno e alinhar as ações de assistência social às famílias acompanhadas.' + #10#10 +
          'Programação:' + #10 +
          '• 08h30 — Recepção fraterna e café compartilhado' + #10 +
          '• 09h15 — Palestra de abertura: "O Papel do Trabalhador Espírita na Caridade Moral e Material"' + #10 +
          '• 10h30 — Oficinas temáticas por área (Assistência Social, Evangelização, ESDE e Atendimento Fraterno)' + #10 +
          '• 12h15 — Prece de encerramento'', ' +
          '''EVENTO'', ''Coordenação Geral UME'', '''', ''S'', ''S'', ''2026-10-25'', ''S''), ' +

          '(1, ''Campanha Permanente de Arrecadação de Alimentos e Cestas Básicas'', ' +
          '''O Departamento de Assistência Social recebe doações de alimentos não perecíveis aos sábados das 9h às 11h30.'', ' +
          '''O Centro Espírita Allan Kardec (CEAK) informa que a Campanha Fraterna do Quilo e de arrecadação de alimentos não perecíveis segue ativa durante todo o trimestre.' + #10#10 +
          'Os itens arrecadados são destinados diretamente à montagem das cestas básicas entregues às famílias cadastradas e acompanhadas pela nossa equipe de promoção social.' + #10#10 +
          'Itens de maior necessidade neste mês: arroz, feijão, óleo de soja, leite em pó, macarrão e itens de higiene pessoal.' + #10#10 +
          'As entregas podem ser feitas na secretaria do centro antes das palestras públicas ou aos sábados pela manhã.'', ' +
          '''CAMPANHA'', ''João Batista Oliveira (Assistência Social)'', '''', ''N'', ''S'', ''2026-10-22'', ''S''), ' +

          '(2, ''Abertura de Novas Turmas do Estudo Sistematizado da Doutrina Espírita (ESDE)'', ' +
          '''Inscrições abertas na secretaria da casa para iniciantes e grupos de aprofundamento nas noites de quarta-feira.'', ' +
          '''Comunicamos aos frequentadores e amigos que estão abertas as inscrições para as novas turmas do Estudo Sistematizado da Doutrina Espírita (ESDE).' + #10#10 +
          'O estudo é gratuito, aberto a todos os interessados e aborda de maneira metódica e dialogada os princípios fundamentais da codificação espírita e do Evangelho de Jesus.' + #10#10 +
          'Para participar, basta comparecer à secretaria da casa espírita com 15 minutos de antecedência.'', ' +
          '''ESTUDO'', ''Departamento Doutrinário'', '''', ''N'', ''S'', ''2026-10-18'', ''S'');'
        );
      end;
    end;
  finally
    LQry.Free;
  end;
end;

end.
