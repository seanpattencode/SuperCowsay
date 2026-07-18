#!/usr/bin/env python3
# SuperCowsay polyglot bench — full PYPL language index (all implementable ranks 1-30) + APL + AWK
# + DB index representatives (SQLite, MySQL, PostgreSQL, Redis) + Perl original.
# Not implementable: VBA (needs Office host; VB.NET covers Visual Basic) · ABAP (SAP-proprietary)
# · Oracle/SQL Server/Db2 (proprietary servers) · MongoDB (not in Ubuntu archives)
# · PYPL IDE/Online-IDE indices (editors, not runtimes — nothing to execute cowsay in).
#   python3 langs/bench.py setup [--yes]   check toolchains; print (--yes: run) install + DB provisioning
#   python3 langs/bench.py                 build + verify byte-identical vs ./cowsay_dynamic + hyperfine
#   python3 langs/bench.py android         push Kotlin DEX + Zig arm64 to adb device, verify + time on ART vs native
import json,os,shlex,shutil,subprocess,sys
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
for p in ("~/.local/share/swiftly/bin","~/.local/dart-sdk/bin"):os.environ["PATH"]+=os.pathsep+os.path.expanduser(p)
B="langs/build";SQ=f"{B}/cowsay_gen.sql";MSG="The quick brown fox jumps over the lazy dog"
SWIFT="no apt pkg — swift.org/install: curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz && tar xf swiftly-*.tar.gz && ./swiftly init --assume-yes  # too-new Ubuntu: add --platform ubuntu24.04"
DART="no apt/snap — dart.dev: curl -LO https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip && unzip -q dartsdk-*.zip -d ~/.local"
APLH="GNU APL left Debian/Ubuntu archives — build from source: curl -sO https://ftp.gnu.org/gnu/apl/apl-2.0.tar.gz && tar xf apl-2.0.tar.gz && cd apl-2.0 && ./configure --prefix=$HOME/.local && make -j$(nproc) && make install"
def sh(c,**k):return subprocess.run(c,shell=isinstance(c,str),text=True,**k)
L=[ # name, pypl rank, required tools, install hint (apt pkgs unless snap/URL), build, run argv (MSG appended unless DB special)
("Assembly","-",["as","ld"],"binutils","make cowsay_dynamic",["./cowsay_dynamic"]),
("Python","1",["python3"],"python3",None,["python3","langs/cowsay.py"]),
("Java","2",["javac","java"],"default-jdk",f"javac -d {B}/java langs/Cowsay.java",["java","-cp",f"{B}/java","Cowsay"]),
("C","3",["gcc"],"gcc",f"gcc -O3 -o {B}/cowsay_c langs/cowsay.c",[f"{B}/cowsay_c"]),
("C++","3",["g++"],"g++",f"g++ -O3 -o {B}/cowsay_cpp langs/cowsay.cpp",[f"{B}/cowsay_cpp"]),
("R","4",["Rscript"],"r-base-core",None,["Rscript","langs/cowsay.R"]),
("JavaScript","5",["node"],"nodejs",None,["node","langs/cowsay.js"]),
("Objective-C","6",["gnustep-config","gcc"],"gobjc gnustep-devel",  # -B/usr/bin: conda ld shadows system ld
 f"/usr/bin/gcc -B/usr/bin $(gnustep-config --objc-flags) -std=gnu99 -O2 -o {B}/cowsay_objc langs/cowsay.m $(gnustep-config --base-libs)",
 [f"{B}/cowsay_objc"]),
("PHP","7",["php"],"php-cli",None,["php","langs/cowsay.php"]),
("C#","8",["mcs","mono"],"mono-devel",f"mcs -out:{B}/Cowsay.exe langs/Cowsay.cs",["mono",f"{B}/Cowsay.exe"]),
("Rust","9",["rustc"],"rustc",f"rustc -O -o {B}/cowsay_rs langs/cowsay.rs",[f"{B}/cowsay_rs"]),
("Swift","10",["swiftc"],SWIFT,  # clean PATH: conda ld breaks the link
 f"PATH=$HOME/.local/share/swiftly/bin:/usr/bin:/bin swiftc -O -o {B}/cowsay_swift langs/cowsay.swift",[f"{B}/cowsay_swift"]),
("Ada","11",["gnatmake"],"gnat",  # own obj dir: fpc also emits a cowsay.o
 f"mkdir -p {B}/ada && PATH=/usr/bin:/bin gnatmake -f -q -O2 -D {B}/ada -o {B}/cowsay_ada langs/cowsay.adb",[f"{B}/cowsay_ada"]),
("TypeScript","12",["node"],"nodejs",None,["node","--experimental-strip-types","langs/cowsay.ts"]),
("Matlab","13",["octave"],"octave  # Matlab language via GNU Octave",None,["octave","-qf","langs/cowsay_oct.m"]),
("PowerShell","14",["pwsh"],"snap install powershell --classic",None,["pwsh","-NoProfile","-File","langs/cowsay.ps1"]),
("Ruby","15",["ruby"],"ruby",None,["ruby","langs/cowsay.rb"]),
("Kotlin","17",["kotlinc","java"],"snap install kotlin --classic",f"kotlinc langs/cowsay.kt -include-runtime -d {B}/cowsay_kt.jar",
 ["java","-jar",f"{B}/cowsay_kt.jar"]),
("Dart","18",["dart"],DART,f"dart compile exe -o {B}/cowsay_dart langs/cowsay.dart",[f"{B}/cowsay_dart"]),
("Lua","19",["lua5.4"],"lua5.4",None,["lua5.4","langs/cowsay.lua"]),
("Go","20",["go"],"golang-go",f"go build -o {B}/cowsay_go langs/cowsay.go",[f"{B}/cowsay_go"]),
("Julia","21",["julia"],"snap install julia --classic",None,["julia","langs/cowsay.jl"]),
("Scala","22",["scalac","java"],"scala",  # own class dir: object Cowsay collides with Java's class
 f"mkdir -p {B}/scala && scalac -d {B}/scala langs/cowsay.scala",
 ["java","-cp",f"{B}/scala:/usr/share/java/scala-library.jar","Cowsay"]),
("Pascal","23",["fpc"],"fpc  # Delphi/Pascal via Free Pascal",
 f"mkdir -p {B}/fpc && fpc -O2 -v0 -FE{B} -FU{B}/fpc -ocowsay_pas langs/cowsay.pas",[f"{B}/cowsay_pas"]),
("VB.NET","25",["dotnet"],"dotnet-sdk-10.0",  # mono-vbnc left the archives; VB via dotnet
 f"dotnet build langs/CowsayVb.vbproj -c Release -v q -o {B}/vb --artifacts-path {B}/vbart",["dotnet",f"{B}/vb/CowsayVb.dll"]),
("Zig","26",["zig"],"snap install zig --classic --beta",  # direct binary: the /snap/bin shim can fail under snapd quirks
 f"z=/snap/zig/current/zig; [ -x $z ] || z=zig; $z build-exe -lc -O ReleaseFast -femit-bin={B}/cowsay_zig langs/cowsay.zig",
 [f"{B}/cowsay_zig"]),
("Perl","27",["perl"],"perl",None,["env","COWPATH=./cows","./cowsay_original_perl.pl","-W","100"]),
("Haskell","28",["ghc"],"ghc",f"ghc -v0 -O2 -outputdir {B} -o {B}/cowsay_hs langs/cowsay.hs",[f"{B}/cowsay_hs"]),
("Groovy","29",["groovy"],"groovy",None,["groovy","langs/cowsay.groovy"]),
("Cobol","30",["cobc"],"gnucobol",f"PATH=/usr/bin:/bin cobc -x -free -O2 -o {B}/cowsay_cob langs/cowsay.cob",[f"{B}/cowsay_cob"]),
("APL","+",["apl"],APLH,None,["apl","--script","-f","langs/cowsay.apl","--"]),
("AWK","+",["gawk"],"gawk",None,["gawk","-f","langs/cowsay.awk"]),
("SQLite","DB",["sqlite3"],"sqlite3",None,["sqlite3",":memory:",f".read {SQ}"]),
("MySQL","DB",["mysql"],"mysql-server",None,None),
("PostgreSQL","DB",["psql"],"postgresql",None,None),
("Redis","DB",["redis-cli"],"redis-server",None,None),
]
def runargs(l):
    n=l[0]
    if n=="SQLite":return l[5]
    if n=="Redis":return ["redis-cli","--raw","EVAL",open("langs/cowsay.redis.lua").read(),"0",MSG]
    if n=="MySQL":return ["mysql","-NBr","-e",f"SET @m='{MSG}';"+open("langs/cowsay.mysql.sql").read()]
    if n=="PostgreSQL":return ["psql","-qtAX","-v",f"m={MSG}","-f","langs/cowsay.pg.sql"]
    return l[5]+[MSG]
miss=lambda l:[t for t in l[2] if not shutil.which(t)]
PROV=[ # idempotent local-DB provisioning (unix-socket auth for current user), run on setup --yes
("mysql","sudo mysql -e \"CREATE USER IF NOT EXISTS '$USER'@'localhost' IDENTIFIED WITH auth_socket\" 2>/dev/null"
 " || sudo mysql -e \"CREATE USER IF NOT EXISTS '$USER'@'localhost' IDENTIFIED VIA unix_socket\" || true"),
("psql","sudo -u postgres createuser $USER 2>/dev/null; sudo -u postgres createdb -O $USER $USER 2>/dev/null; true"),
]
if sys.argv[1:2]==["setup"]:
    apt,man=[],[]
    for l in L:
        m=miss(l)
        print(f"{'MISSING' if m else 'ok':8}{l[0]:13}"+(f" {' '.join(m)}  ({l[3]})" if m else ""))
        if m:(man if l[3].startswith("snap ") or l[3] in(SWIFT,DART,APLH) else apt).append(l[3])
    print("\nnot implementable: VBA (Office host) · ABAP (SAP) · Oracle/SQLServer/Db2 (proprietary) · MongoDB (not in archives) · IDE/Online-IDE indices (editors, not runtimes)")
    if apt:
        c="sudo apt-get install -y "+" ".join(dict.fromkeys(" ".join(a.split("#")[0] for a in apt).split()))
        print(c)
        if "--yes" in sys.argv:sh(c)
    if "--yes" in sys.argv:
        for h in man:
            if h.startswith("snap "):sh("sudo "+h)
        for t,c in PROV:
            if shutil.which(t):sh(c)
    sys.exit(0)
if sys.argv[1:2]==["android"]:
    import glob
    if sh("adb get-state",capture_output=True).returncode:sys.exit("no adb device (plug in + USB debugging; check `adb devices`)")
    d8=(sorted(glob.glob(os.path.expanduser("~/Android/Sdk/build-tools/*/d8")))or[shutil.which("d8")])[-1]
    if not d8:sys.exit("d8 missing: sdkmanager 'build-tools;36.1.0'")
    A=f"{B}/android";os.makedirs(A,exist_ok=True)
    os.path.exists(f"{B}/cowsay_kt.jar")or sh(f"kotlinc langs/cowsay.kt -include-runtime -d {B}/cowsay_kt.jar",check=True)
    sh(f"{d8} --release --output {A} {B}/cowsay_kt.jar",capture_output=True,check=True)
    sh(f"z=/snap/zig/current/zig; [ -x $z ] || z=zig; $z build-exe -lc -O ReleaseFast -target aarch64-linux-musl -femit-bin={A}/cowsay_zig_arm64 langs/cowsay.zig",check=True)
    sh(f"adb push {A}/classes.dex /data/local/tmp/cowsay_kt.dex && adb push {A}/cowsay_zig_arm64 /data/local/tmp/ && adb shell chmod 755 /data/local/tmp/cowsay_zig_arm64",capture_output=True,check=True)
    ref=sh(["./cowsay_dynamic",MSG],capture_output=True).stdout
    print("device: "+sh("adb shell getprop ro.product.model",capture_output=True).stdout.strip())
    ROWS=[("exec floor (toybox true)","/system/bin/true",200,None),  # dynamic-link exec cost every row pays
     ("Zig arm64 static",f"/data/local/tmp/cowsay_zig_arm64 '{MSG}'",200,["adb","exec-out","/data/local/tmp/cowsay_zig_arm64",MSG]),
     ("Kotlin ART (dalvikvm64)",f"dalvikvm64 -cp /data/local/tmp/cowsay_kt.dex CowsayKt '{MSG}'",5,
      ["adb","exec-out","dalvikvm64","-cp","/data/local/tmp/cowsay_kt.dex","CowsayKt",MSG])]
    res=[]
    for n,c,it,ver in ROWS:
        if ver:
            v=sh(ver,capture_output=True)
            print(("ok   " if v.stdout==ref else "FAIL ")+n+": output "+("byte-identical" if v.stdout==ref else "DIFFERS"))
            if v.stdout!=ref:continue
        o=sh(f"adb shell \"date +%s%N; i=0; while [ \\$i -lt {it} ]; do {c} >/dev/null 2>&1; i=\\$((i+1)); done; date +%s%N\"",capture_output=True)
        a,b=[int(x)for x in o.stdout.split()]  # host math: device mksh arithmetic is 32-bit, ns stamps wrap
        res.append((n,(b-a)/it/1000))
    base=next((u for n,u in res if n.startswith("Zig")),res[0][1])
    print(f"\n{'on-device':26}{'mean':>12}{'vs zig':>9}")
    for n,us in res:print(f"{n:26}{us:>10.1f}µs{us/base:>8.1f}x")
    print("desktop rows for comparison: python3 langs/bench.py")
    sys.exit(0)
os.makedirs(B,exist_ok=True)
open(SQ,"w").write(open("langs/cowsay.sql").read().replace("__MSG__",MSG.replace("'","''")))
good,ref=[],None
for l in L:
    m=miss(l)
    if m:print(f"SKIP {l[0]}: missing {' '.join(m)}");continue
    if l[4]:
        r=sh(l[4],capture_output=True)
        if r.returncode:print(f"SKIP {l[0]}: build failed: {(r.stderr or r.stdout).strip()[-300:]}");continue
    try:r=sh(runargs(l),capture_output=True,timeout=60)
    except Exception as e:print(f"SKIP {l[0]}: run failed: {e}");continue
    if ref is None:ref=r.stdout  # Assembly runs first = reference
    if r.stdout==ref:print(f"ok   {l[0]}: output byte-identical");good.append(l)
    else:print(f"FAIL {l[0]}: output differs from assembly reference ({(r.stderr or '').strip()[-120:]})")
if not shutil.which("hyperfine"):sys.exit("hyperfine missing: sudo apt-get install -y hyperfine")
cmd=["hyperfine","-N","--warmup","3","--min-runs","10","--export-json",f"{B}/results.json"]
for l in good:cmd+=["-n",l[0],shlex.join(runargs(l))]
sh(cmd,check=True)
res=json.load(open(f"{B}/results.json"))["results"]
for l,r in zip(good,res):r["n"],r["rank"]=l[0],l[1]
base=res[0]["mean"]
print(f"\n{'lang':13}{'pypl':>4}{'mean':>12}{'σ':>10}{'vs asm':>9}")
for r in sorted(res,key=lambda r:r["mean"]):
    print(f"{r['n']:13}{r['rank']:>4}{r['mean']*1e6:>10.1f}µs{(r['stddev'] or 0)*1e6:>8.1f}µs{r['mean']/base:>8.1f}x")
