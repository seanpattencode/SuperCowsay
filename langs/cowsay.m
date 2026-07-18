#import <Foundation/Foundation.h>
int main(int c,char**v){
    NSAutoreleasePool*p=[NSAutoreleasePool new];
    NSMutableArray*a=[NSMutableArray array];
    for(int i=1;i<c;i++)[a addObject:[NSString stringWithUTF8String:v[i]]];
    NSString*m=[a count]?[a componentsJoinedByString:@" "]:@"Hello, World!";
    NSString*b=[@"" stringByPaddingToLength:[m length]+2 withString:@"_" startingAtIndex:0];
    NSString*d=[@"" stringByPaddingToLength:[m length]+2 withString:@"-" startingAtIndex:0];
    printf(" %s\n< %s >\n %s\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n",[b UTF8String],[m UTF8String],[d UTF8String]);
    [p drain];
    return 0;
}
