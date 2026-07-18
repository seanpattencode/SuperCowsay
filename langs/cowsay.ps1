$m=if($args){$args -join " "}else{"Hello, World!"}
[Console]::Write(" "+"_"*($m.Length+2)+"`n< $m >`n "+"-"*($m.Length+2)+"`n        \   ^__^`n         \  (oo)\_______`n            (__)\       )\/\`n                ||----w |`n                ||     ||`n")
