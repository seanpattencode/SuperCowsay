BEGIN{
    m="";for(i=1;i<ARGC;i++)m=m (i>1?" ":"") ARGV[i]
    if(m=="")m="Hello, World!"
    u="";d="";for(i=0;i<length(m)+2;i++){u=u"_";d=d"-"}
    printf " %s\n< %s >\n %s\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n",u,m,d
    exit
}
