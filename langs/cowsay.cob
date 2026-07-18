identification division.
program-id. cowsay.
data division.
working-storage section.
01 n pic 9(4) comp.
01 i pic 9(4) comp.
01 a pic x(256).
01 al pic 9(4) comp.
01 m pic x(1024).
01 ml pic 9(4) comp value 0.
01 b pic x(1026).
procedure division.
accept n from argument-number
perform varying i from 1 by 1 until i > n
    display i upon argument-number
    move spaces to a
    accept a from argument-value
    compute al = function stored-char-length(a)
    if i > 1
        move " " to m(ml + 1:1)
        add 1 to ml
    end-if
    if al > 0
        move a(1:al) to m(ml + 1:al)
        add al to ml
    end-if
end-perform
if ml = 0
    move "Hello, World!" to m
    move 13 to ml
end-if
move all "_" to b(1:ml + 2)
display " " b(1:ml + 2)
display "< " m(1:ml) " >"
move all "-" to b(1:ml + 2)
display " " b(1:ml + 2)
display "        \   ^__^"
display "         \  (oo)\_______"
display "            (__)\       )\/\"
display "                ||----w |"
display "                ||     ||"
stop run.
