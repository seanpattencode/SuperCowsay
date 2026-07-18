Module Cowsay
    Sub Main(a() As String)
        Dim m As String
        If a.Length > 0 Then m = String.Join(" ", a) Else m = "Hello, World!"
        Console.Write(" " & New String("_"c, m.Length + 2) & vbLf & "< " & m & " >" & vbLf & " " & New String("-"c, m.Length + 2) & vbLf & "        \   ^__^" & vbLf & "         \  (oo)\_______" & vbLf & "            (__)\       )\/\" & vbLf & "                ||----w |" & vbLf & "                ||     ||" & vbLf)
    End Sub
End Module
