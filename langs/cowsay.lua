local m=#arg>0 and table.concat(arg," ") or "Hello, World!"
io.write(" ",("_"):rep(#m+2),"\n< ",m," >\n ",("-"):rep(#m+2),"\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n")
