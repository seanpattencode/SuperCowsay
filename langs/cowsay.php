<?php
$m=implode(" ",array_slice($argv,1))?:"Hello, World!";
$l=strlen($m)+2;
echo " ".str_repeat("_",$l)."\n< $m >\n ".str_repeat("-",$l)."\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
