WITH m(s) AS (SELECT '__MSG__')
SELECT ' '||replace(hex(zeroblob(length(s)+2)),'00','_')||char(10)
||'< '||s||' >'||char(10)
||' '||replace(hex(zeroblob(length(s)+2)),'00','-')||char(10)
||'        \   ^__^'||char(10)
||'         \  (oo)\_______'||char(10)
||'            (__)\       )\/\'||char(10)
||'                ||----w |'||char(10)
||'                ||     ||' FROM m;
