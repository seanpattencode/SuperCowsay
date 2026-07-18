package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	m := "Hello, World!"
	if len(os.Args) > 1 {
		m = strings.Join(os.Args[1:], " ")
	}
	fmt.Printf(" %s\n< %s >\n %s\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n",
		strings.Repeat("_", len(m)+2), m, strings.Repeat("-", len(m)+2))
}
