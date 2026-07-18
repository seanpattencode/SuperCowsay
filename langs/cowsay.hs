import System.Environment
main = do
  a <- getArgs
  let m = if null a then "Hello, World!" else unwords a
  let n = replicate (length m + 2)
  putStr $ " " ++ n '_' ++ "\n< " ++ m ++ " >\n " ++ n '-' ++ "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n"
