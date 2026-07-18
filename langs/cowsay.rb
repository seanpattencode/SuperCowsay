m=ARGV.empty? ? "Hello, World!" : ARGV.join(" ")
print " #{"_"*(m.size+2)}\n< #{m} >\n #{"-"*(m.size+2)}\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n"
