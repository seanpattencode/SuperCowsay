public class Cowsay{
    public static void main(String[] a){
        String m=a.length>0?String.join(" ",a):"Hello, World!";
        System.out.print(" "+"_".repeat(m.length()+2)+"\n< "+m+" >\n "+"-".repeat(m.length()+2)+"\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n");
    }
}
