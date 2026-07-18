#include <cstdio>
#include <string>
int main(int c,char**v){
    std::string m;
    for(int i=1;i<c;i++){if(i>1)m+=" ";m+=v[i];}
    if(m.empty())m="Hello, World!";
    std::string b(m.size()+2,'_'),d(m.size()+2,'-');
    printf(" %s\n< %s >\n %s\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n",b.c_str(),m.c_str(),d.c_str());
}
