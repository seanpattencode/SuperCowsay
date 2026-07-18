fn main(){
    let a:Vec<String>=std::env::args().skip(1).collect();
    let m=if a.is_empty(){"Hello, World!".to_string()}else{a.join(" ")};
    print!(" {}\n< {} >\n {}\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n","_".repeat(m.len()+2),m,"-".repeat(m.len()+2));
}
