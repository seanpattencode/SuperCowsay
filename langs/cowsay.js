// Same contract as cowsay_dynamic, limits included (256 B/arg, 1024 B total): passes the
// 16-case identity matrix on Node and Bun:  ./verify_identity.sh "node langs/cowsay.js"
const a=process.argv.slice(2);let m="",n=0;
for(const s of a){const l=Buffer.byteLength(s);if(l>=256||(n+=l+(n?1:0))>=1024){require("fs").writeSync(2,"Error: Input too long (max 1024 characters)\n");process.exit(1)}if(m)m+=" ";m+=s}
if(!a.length)m="Hello, World!";
const w=Buffer.byteLength(m);
process.stdout.write(` ${"_".repeat(w+2)}\n< ${m} >\n ${"-".repeat(w+2)}\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n`);
