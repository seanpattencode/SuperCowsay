import sys
m=" ".join(sys.argv[1:]) or "Hello, World!"
sys.stdout.write(f" {'_'*(len(m)+2)}\n< {m} >\n {'-'*(len(m)+2)}\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n")
