#include <stdio.h>
#include <string.h>
int main(int c,char**v){
    char m[4096]="";
    if(c<2)strcpy(m,"Hello, World!");
    else for(int i=1;i<c;i++){if(i>1)strcat(m," ");strcat(m,v[i]);}
    int l=strlen(m);
    char b[4098];memset(b,'_',l+2);b[l+2]=0;
    printf(" %s\n< %s >\n",b,m);
    memset(b,'-',l+2);
    printf(" %s\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n",b);
    return 0;
}
