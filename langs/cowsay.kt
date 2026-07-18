fun main(a:Array<String>){
    val m=if(a.isEmpty())"Hello, World!" else a.joinToString(" ")
    print(" "+"_".repeat(m.length+2)+"\n< $m >\n "+"-".repeat(m.length+2)+"\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n")
}
