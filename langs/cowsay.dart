import 'dart:io';
void main(List<String> a){
  final m=a.isEmpty?"Hello, World!":a.join(" ");
  stdout.write(" ${"_"*(m.length+2)}\n< $m >\n ${"-"*(m.length+2)}\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n");
}
