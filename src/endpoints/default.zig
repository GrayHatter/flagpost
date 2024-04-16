const std = @import("std");

const Allocator = std.mem.Allocator;

const Endpoint = @import("../endpoint.zig");
const Context = @import("../context.zig");
const UserData = @import("../request_data.zig").UserData;
const Template = Endpoint.Template;
const Error = Endpoint.Error;

const Flag = struct {
    flag: []const u8,
};

pub fn defaultPost(ctx: *Context) Error!void {
    if (ctx.req_data.post_data) |post| {
        const flags = try Flags.loadFlags(ctx.alloc);
        const udata = UserData(Flag).init(post) catch return error.BadData;
        std.debug.print("udata {}\n", .{udata});
        var writeable = false;
        for (flags) |*flag| {
            if (eql(u8, udata.flag, flag.flag_text)) {
                std.debug.print("win!\n", .{});
                writeable = true;
                flag.found = true;
                break;
            }
        }
        if (writeable) {
            Flags.writeFlags(flags) catch unreachable;
        }
    }

    ctx.response.redirect("/", true) catch unreachable;
}

const eql = std.mem.eql;

const Flags = struct {
    name: []const u8,
    flag_text: []const u8,
    found: bool,

    var buffer: [0xFFFF]u8 = undefined;
    pub fn loadFlags(a: Allocator) ![]Flags {
        var fd = std.fs.cwd().openFile("flagdata.txt", .{}) catch unreachable;
        defer fd.close();
        const amount = fd.readAll(&buffer) catch unreachable;

        var flags = std.ArrayList(Flags).init(a);
        var lines = split(u8, buffer[0..amount], "\n");
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var pairs = split(u8, line, ":");
            try flags.append(.{
                .name = pairs.first(),
                .flag_text = pairs.next() orelse "",
                .found = eql(u8, "found", pairs.rest()),
            });
        }
        return try flags.toOwnedSlice();
    }

    var line_buffer: [0xFFFF]u8 = undefined;
    pub fn writeFlags(list: []const Flags) !void {
        var fd = std.fs.cwd().openFile("flagdata.txt", .{ .mode = .read_write }) catch unreachable;
        defer fd.close();

        for (list) |line| {
            const text = try std.fmt.bufPrint(&line_buffer, "{s}:{s}:{s}\n", .{
                line.name,
                line.flag_text,
                if (line.found) "found" else "none",
            });
            try fd.writeAll(text);
        }
    }
};

const split = std.mem.split;

const stars = "***************************************************";

pub fn default(ctx: *Context) Error!void {
    const flags = try Flags.loadFlags(ctx.alloc);

    //for (flags) |itm| {
    //    std.debug.print("flags {}\n", .{itm});
    //}
    var tmpl = Template.find("index.html");
    tmpl.init(ctx.alloc);

    var flags_ctx = try ctx.alloc.alloc(Template.Context, flags.len);
    var end: usize = 0;
    var found: usize = 0;
    for (flags) |flag| {
        const lctx = &flags_ctx[end];
        lctx.* = Template.Context.init(ctx.alloc);
        if (flag.found) {
            try lctx.put("Name", flag.name);
            try lctx.put("FlagText", flag.flag_text);
            try lctx.put("Found", "<span style=\"color: red\">&nbsp;FOUND!</span>");
            found += 1;
        } else {
            try lctx.put("Name", "Undiscovered Account");
            try lctx.put("FlagText", stars[0..flag.flag_text.len]);
            try lctx.put("Found", "Unknown");
        }
        end += 1;
    }

    try tmpl.ctx.?.putBlock("Flags", flags_ctx);
    try tmpl.ctx.?.put("Count", try std.fmt.allocPrint(ctx.alloc, "{}", .{found}));
    try ctx.sendTemplate(&tmpl);
}
