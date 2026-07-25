// C-ABI main + raw write (Linux syscall / kernel32 WriteFile): immune to std API churn across Zig versions
const std = @import("std");
const builtin = @import("builtin");
extern "kernel32" fn GetStdHandle(h: u32) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn WriteFile(f: ?*anyopaque, b: [*]const u8, n: u32, w: *u32, ov: ?*anyopaque) callconv(.winapi) i32;
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
    if (builtin.os.tag == .windows) {
        var wr: u32 = 0;
        _ = WriteFile(GetStdHandle(4294967285), &buf, @intCast(o), &wr, null); // STD_OUTPUT_HANDLE = -11
    } else _ = std.os.linux.write(1, &buf, o);
    return 0;
}
