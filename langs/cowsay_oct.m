a=argv();
m=strjoin(a," ");
if isempty(m) m="Hello, World!"; end
printf(" %s\n< %s >\n %s\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n",repmat("_",1,length(m)+2),m,repmat("-",1,length(m)+2))
