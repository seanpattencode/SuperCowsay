local m=#ARGV>0 and table.concat(ARGV," ") or "Hello, World!"
return " "..("_"):rep(#m+2).."\n< "..m.." >\n "..("-"):rep(#m+2).."\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||"
