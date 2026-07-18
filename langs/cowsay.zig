// C-ABI main + raw syscall write: immune to std API churn across Zig versions (x86-64 Linux only, like the repo)
const std = @import("std");
var buf: [8192]u8 = undefined;
var mb: [4096]u8 = undefined;
fn ap(p: *usize, s: []const u8) void {
    @memcpy(buf[p.* .. p.* + s.len], s);
    p.* += s.len;
}
pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    var m: []const u8 = "Hello, World!";
    const n: usize = @intCast(argc);
    if (n > 1) {
        var o: usize = 0;
        for (1..n) |i| {
            const s = std.mem.span(argv[i]);
            if (i > 1) { mb[o] = ' '; o += 1; }
            @memcpy(mb[o .. o + s.len], s);
            o += s.len;
        }
        m = mb[0..o];
    }
    var o: usize = 0;
    ap(&o, " ");
    @memset(buf[o .. o + m.len + 2], '_');
    o += m.len + 2;
    ap(&o, "\n< ");
    ap(&o, m);
    ap(&o, " >\n ");
    @memset(buf[o .. o + m.len + 2], '-');
    o += m.len + 2;
    ap(&o, "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n");
    _ = std.os.linux.write(1, &buf, o);
    return 0;
}
