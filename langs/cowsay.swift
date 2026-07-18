let a=CommandLine.arguments.dropFirst()
let m=a.isEmpty ? "Hello, World!" : a.joined(separator:" ")
print(" "+String(repeating:"_",count:m.count+2)+"\n< "+m+" >\n "+String(repeating:"-",count:m.count+2)+"\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||",terminator:"\n")
