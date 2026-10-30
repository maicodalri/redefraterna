unit RedeFraterna.Middlewares;

{$mode Delphi}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils,
  Horse, Horse.Commons,
  twapi.Types, twapi.Auth;

procedure RegisterRedeFraternaMiddlewares;
procedure RedeFraternaStaticFilesMiddleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
procedure RedeFraternaCorsMiddleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
procedure RedeFraternaPermissionsMiddleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
procedure HandleGetPing(Req: THorseRequest; Res: THorseResponse);
function ResolveWebFilePath(const AFileName: string): string;
function ReadFileRawUTF8(const AFileName: string): string;

implementation

function ResolveWebFilePath(const AFileName: string): string;
var
  LExeDir: string;
begin
  LExeDir := ExtractFilePath(ParamStr(0));

  // Prioriza a pasta web do projeto RedeFraterna durante desenvolvimento
  Result := ExpandFileName('D:\Desenv\lazarus\RedeFraterna\web\' + AFileName);
  if FileExists(Result) then Exit;

  Result := ExpandFileName(LExeDir + '..' + PathDelim + 'RedeFraterna' + PathDelim + 'web' + PathDelim + AFileName);
  if FileExists(Result) then Exit;

  Result := LExeDir + 'web' + PathDelim + AFileName;
end;

function ReadFileRawUTF8(const AFileName: string): string;
var
  LStream: TFileStream;
  LRaw: RawByteString;
begin
  Result := '';
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if LStream.Size > 0 then
    begin
      SetLength(LRaw, LStream.Size);
      LStream.ReadBuffer(LRaw[1], LStream.Size);
      if (Length(LRaw) >= 3) and (Ord(LRaw[1]) = $EF) and (Ord(LRaw[2]) = $BB) and (Ord(LRaw[3]) = $BF) then
        Delete(LRaw, 1, 3);
      SetCodePage(LRaw, CP_UTF8, False);
      Result := LRaw;
    end;
  finally
    LStream.Free;
  end;
end;

procedure RedeFraternaCorsMiddleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  Res.AddHeader('Access-Control-Allow-Origin', '*');
  Res.AddHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  Res.AddHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Sort, X-Order');
  Res.AddHeader('Access-Control-Expose-Headers', 'X-Total-Count, X-Total-Pages, X-Page, X-Limit');

  if SameText(Req.RawWebRequest.Method, 'OPTIONS') then
  begin
    Res.Status(204).Send('');
    raise EHorseCallbackInterrupted.Create;
  end;

  Next();
end;

procedure RedeFraternaStaticFilesMiddleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LMethod, LPath, LRelPath, LFilePath, LExt, LContentType: string;
begin
  LMethod := UpperCase(Trim(Req.RawWebRequest.Method));

  if LMethod <> 'GET' then
  begin
    Next();
    Exit;
  end;

  LPath := Trim(Req.RawWebRequest.PathInfo);

  if SameText(Copy(LPath, 1, 5), '/api/') or SameText(Copy(LPath, 1, 8), '/public/') then
  begin
    Next();
    Exit;
  end;

  if (LPath = '') or (LPath = '/') or SameText(LPath, '/index.html') then
    LRelPath := 'index.html'
  else
  begin
    LRelPath := LPath;
    if (Length(LRelPath) > 0) and (LRelPath[1] = '/') then
      Delete(LRelPath, 1, 1);
    LRelPath := StringReplace(LRelPath, '/', PathDelim, [rfReplaceAll]);
  end;

  LFilePath := ResolveWebFilePath(LRelPath);

  if FileExists(LFilePath) and (not DirectoryExists(LFilePath)) then
  begin
    LExt := LowerCase(ExtractFileExt(LFilePath));
    if LExt = '.js' then
      LContentType := 'application/javascript; charset=utf-8'
    else if LExt = '.css' then
      LContentType := 'text/css; charset=utf-8'
    else if (LExt = '.html') or (LExt = '.htm') then
      LContentType := 'text/html; charset=utf-8'
    else if LExt = '.json' then
      LContentType := 'application/json; charset=utf-8'
    else if LExt = '.png' then
      LContentType := 'image/png'
    else if (LExt = '.jpg') or (LExt = '.jpeg') then
      LContentType := 'image/jpeg'
    else if LExt = '.svg' then
      LContentType := 'image/svg+xml'
    else if LExt = '.ico' then
      LContentType := 'image/x-icon'
    else
      LContentType := 'text/plain; charset=utf-8';

    Res.Send(ReadFileRawUTF8(LFilePath)).ContentType(LContentType);
    raise EHorseCallbackInterrupted.Create;
  end;

  Next();
end;

procedure RedeFraternaPermissionsMiddleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LPath, LMethod, LTp, LToken: string;
  LTokenData: TTokenData;
begin
  LPath := LowerCase(Trim(Req.RawWebRequest.PathInfo));
  LMethod := UpperCase(Trim(Req.RawWebRequest.Method));

  if (not SameText(Copy(LPath, 1, 5), '/api/')) or
     (LPath = '/api/login') or
     SameText(LMethod, 'OPTIONS') then
  begin
    Next();
    Exit;
  end;

  LToken := GetTokenByReq(Req);
  LTokenData := ValidateToken(LToken);
  if not LTokenData.IsValid then
  begin
    Next();
    Exit;
  end;

  LTp := UpperCase(Trim(LTokenData.UserType));
  if (LTp = 'N') or (LTp = '') then LTp := 'F';

  // 1. Administrador ('A'): acesso total a todo o sistema
  if LTp = 'A' then
  begin
    Next();
    Exit;
  end;

  // 2. Cadastro de Usuários (/api/usuarios): exclusivo para Administradores ('A')
  if Pos('/api/usuarios', LPath) = 1 then
  begin
    Res.Status(403).Send('{"error": "Acesso negado. Apenas usuários Administradores possuem acesso ao cadastro de usuários."}').ContentType(CONTENT_TYPE_JSON);
    raise EHorseCallbackInterrupted.Create;
  end;

  // 3. Operador da Família ('F'):
  //    - Pode cadastrar, editar e vincular famílias (/api/familias) e seus integrantes (/api/integrantes)
  //    - Pode consultar (GET) centros, agenda, notícias, auxílios, dashboard e logs para realizar o vínculo e acompanhamento
  //    - Não pode criar, editar ou excluir Centros Espíritas, Trabalhadores, Agenda Semanal ou Notícias
  if LTp = 'F' then
  begin
    if (LMethod <> 'GET') and (
       (Pos('/api/centros', LPath) = 1) or
       (Pos('/api/trabalhadores', LPath) = 1) or
       (Pos('/api/agenda', LPath) = 1) or
       (Pos('/api/noticias', LPath) = 1)
    ) then
    begin
      Res.Status(403).Send('{"error": "Acesso restrito. O perfil Operador da Família possui permissão apenas para gerenciar e vincular famílias e seus integrantes."}').ContentType(CONTENT_TYPE_JSON);
      raise EHorseCallbackInterrupted.Create;
    end;

    // Exclusão de famílias é restrita a Operador do Sistema ou Administrador
    if (LMethod = 'DELETE') and (Pos('/api/familias', LPath) = 1) then
    begin
      Res.Status(403).Send('{"error": "O perfil Operador da Família não possui permissão para excluir famílias."}').ContentType(CONTENT_TYPE_JSON);
      raise EHorseCallbackInterrupted.Create;
    end;
  end;

  // 4. Operador do Sistema ('O'): tem acesso a todos os cadastros (adicionar, editar, excluir), exceto usuários
  Next();
end;

procedure HandleGetPing(Req: THorseRequest; Res: THorseResponse);
begin
  Res.Send('{"status": "online", "system": "Rede Fraterna - UME"}').ContentType(CONTENT_TYPE_JSON);
end;

procedure RegisterRedeFraternaMiddlewares;
begin
  THorse.Use(RedeFraternaCorsMiddleware);
  THorse.Use(RedeFraternaStaticFilesMiddleware);
  THorse.Use(RedeFraternaPermissionsMiddleware);
  THorse.Get('/ping', HandleGetPing);
end;

end.
