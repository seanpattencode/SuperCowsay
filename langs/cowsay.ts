const a: string[] = process.argv.slice(2);
const m: string = a.length ? a.join(" ") : "Hello, World!";
process.stdout.write(` ${"_".repeat(m.length+2)}\n< ${m} >\n ${"-".repeat(m.length+2)}\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n`);
