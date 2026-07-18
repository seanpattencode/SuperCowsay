class Cowsay{
    static void Main(string[] a){
        string m=a.Length>0?string.Join(" ",a):"Hello, World!";
        System.Console.Write(" "+new string('_',m.Length+2)+"\n< "+m+" >\n "+new string('-',m.Length+2)+"\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n");
    }
}
