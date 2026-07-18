object Cowsay{
  def main(a:Array[String]):Unit={
    val m=if(a.isEmpty)"Hello, World!" else a.mkString(" ")
    print(" "+"_"*(m.length+2)+"\n< "+m+" >\n "+"-"*(m.length+2)+"\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n")
  }
}
