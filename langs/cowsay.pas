program cowsaypas;
uses SysUtils;
var m:string;i:integer;
begin
  m:='';
  for i:=1 to ParamCount do begin
    if i>1 then m:=m+' ';
    m:=m+ParamStr(i);
  end;
  if m='' then m:='Hello, World!';
  write(' ',StringOfChar('_',Length(m)+2),#10,'< ',m,' >',#10,' ',StringOfChar('-',Length(m)+2),#10,
  '        \   ^__^',#10,
  '         \  (oo)\_______',#10,
  '            (__)\       )\/\',#10,
  '                ||----w |',#10,
  '                ||     ||',#10);
end.
