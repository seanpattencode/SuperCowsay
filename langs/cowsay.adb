with Ada.Command_Line, Ada.Text_IO, Ada.Text_IO.Text_Streams, Ada.Strings.Unbounded;
use Ada.Command_Line, Ada.Text_IO, Ada.Strings.Unbounded;
procedure Cowsay is
   M : Unbounded_String;
begin
   for I in 1 .. Argument_Count loop
      if I > 1 then Append (M, " "); end if;
      Append (M, Argument (I));
   end loop;
   if Argument_Count = 0 then M := To_Unbounded_String ("Hello, World!"); end if;
   declare
      U : constant String (1 .. Length (M) + 2) := (others => '_');
      D : constant String (1 .. Length (M) + 2) := (others => '-');
   begin
      String'Write (Text_Streams.Stream (Standard_Output),
        " " & U & ASCII.LF & "< " & To_String (M) & " >" & ASCII.LF & " " & D & ASCII.LF
        & "        \   ^__^" & ASCII.LF
        & "         \  (oo)\_______" & ASCII.LF
        & "            (__)\       )\/\" & ASCII.LF
        & "                ||----w |" & ASCII.LF
        & "                ||     ||" & ASCII.LF);
   end;
end Cowsay;
