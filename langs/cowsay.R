a<-commandArgs(TRUE)
m<-if(length(a))paste(a,collapse=" ") else "Hello, World!"
cat(" ",strrep("_",nchar(m)+2),"\n< ",m," >\n ",strrep("-",nchar(m)+2),"\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n",sep="")
