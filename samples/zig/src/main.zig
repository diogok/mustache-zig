const std = @import("std");
const Io = std.Io;
const Writer = std.Io.Writer;
const mustache = @import("mustache");

// Mustache template
const template_text =
    \\{{! This is a spec-compliant mustache template }}
    \\Hello {{name}} from Zig
    \\This template was generated with
    \\{{#env}}
    \\Zig: {{zig_version}}
    \\Mustache: {{mustache_version}}
    \\{{/env}}
    \\Supported features:
    \\{{#features}}
    \\  - {{name}} {{condition}}
    \\{{/features}}
;

const Feature = struct {
    name: []const u8,
    condition: []const u8,
};

// Context, can be any Zig struct, supporting optionals, slices, tuples, recursive types, pointers, etc.
var ctx = .{
    .name = "friends",
    .env = .{
        .zig_version = "master",
        .mustache_version = "alpha",
    },
    .features = &[_]Feature{
        .{ .name = "interpolation", .condition = "✅ done" },
        .{ .name = "sections", .condition = "✅ done" },
        .{ .name = "comments", .condition = "✅ done" },
        .{ .name = "delimiters", .condition = "✅ done" },
        .{ .name = "partials", .condition = "✅ done" },
        .{ .name = "lambdas", .condition = "✅ done" },
        .{ .name = "inheritance", .condition = "⏳ comming soon" },
    },
};

pub fn main(init: std.process.Init) anyerror!void {
    const gpa = init.gpa;
    const io = init.io;

    try renderFromString(gpa, io);
    try renderFromJson(gpa, io);
    //try renderComptimeTemplate(io);
    try renderFromCachedTemplate(gpa, io);
    try renderFromFile(io);
    //try renderComptimePartialTemplate(io);
}

fn stdoutWriter(io: Io, buffer: []u8) Io.File.Writer {
    return Io.File.stdout().writer(io, buffer);
}

/// Render a template from a string
pub fn renderFromString(allocator: std.mem.Allocator, io: Io) anyerror!void {
    var buf: [4096]u8 = undefined;
    var fw = stdoutWriter(io, &buf);
    defer fw.interface.flush() catch {};

    // Direct render to save memory
    try mustache.renderText(allocator, template_text, ctx, &fw.interface);
}

/// Render a template from a Json object
pub fn renderFromJson(allocator: std.mem.Allocator, io: Io) anyerror!void {
    var buf: [4096]u8 = undefined;
    var fw = stdoutWriter(io, &buf);
    defer fw.interface.flush() catch {};

    // Serializing the context as a json string
    const json_text = try std.json.Stringify.valueAlloc(allocator, ctx, .{});
    defer allocator.free(json_text);

    var tree = try std.json.parseFromSlice(std.json.Value, allocator, json_text, .{});
    defer tree.deinit();

    // Rendering from a Json object
    try mustache.renderText(allocator, template_text, tree.value, &fw.interface);
}

/// Parses a template at comptime to render many times at runtime, no allocations needed
pub fn renderComptimeTemplate(io: Io) anyerror!void {
    var buf: [4096]u8 = undefined;
    var fw = stdoutWriter(io, &buf);
    defer fw.interface.flush() catch {};

    // Comptime-parsed template
    const comptime_template = comptime mustache.parseComptime(template_text, .{}, .{});

    var repeat: u32 = 0;
    while (repeat < 10) : (repeat += 1) {
        try mustache.render(comptime_template, ctx, &fw.interface);
    }
}

/// Caches a template to render many times
pub fn renderFromCachedTemplate(allocator: std.mem.Allocator, io: Io) anyerror!void {
    // Store this template and render many times from it
    const cached_template = switch (try mustache.parseText(allocator, template_text, .{}, .{ .copy_strings = false })) {
        .success => |ret| ret,
        .parse_error => |detail| {
            std.log.err("Parse error {s} at lin {}, col {}", .{ @errorName(detail.parse_error), detail.lin, detail.col });
            return;
        },
    };
    defer cached_template.deinit(allocator);

    var buf: [4096]u8 = undefined;
    var fw = stdoutWriter(io, &buf);
    defer fw.interface.flush() catch {};

    var repeat: u32 = 0;
    while (repeat < 10) : (repeat += 1) {
        const result = try mustache.allocRender(allocator, cached_template, ctx);
        defer allocator.free(result);

        try fw.interface.writeAll(result);
    }
}

/// Render a template from a file path
pub fn renderFromFile(io: Io) anyerror!void {

    // 16KB should be enough memory for this job
    var plenty_of_memory: std.heap.DebugAllocator(.{ .enable_memory_limit = true }) = .init;
    plenty_of_memory.requested_memory_limit = 16 * 1024;
    defer _ = plenty_of_memory.deinit();

    const allocator = plenty_of_memory.allocator();

    var tmp_dir = try Io.Dir.cwd().createDirPathOpen(io, "zig-out/samples-tmp", .{});
    defer tmp_dir.close(io);

    const file_name = "template.mustache";
    defer tmp_dir.deleteFile(io, file_name) catch {};

    {
        var file = try tmp_dir.createFile(io, file_name, .{ .truncate = true });
        defer file.close(io);

        var w_buf: [4096]u8 = undefined;
        var fw = file.writer(io, &w_buf);
        defer fw.interface.flush() catch {};

        // Writing the same template 10K times on a file
        var repeat: u32 = 0;
        while (repeat < 10_000) : (repeat += 1) {
            try fw.interface.writeAll(template_text);
        }
    }

    const path_to_template = try tmp_dir.realPathFileAlloc(io, file_name, allocator);
    defer allocator.free(path_to_template);

    var out_buf: [4096]u8 = undefined;
    var out_fw = stdoutWriter(io, &out_buf);
    defer out_fw.interface.flush() catch {};

    // Rendering this large template with only 16KB of RAM
    try mustache.renderFile(allocator, io, path_to_template, ctx, &out_fw.interface);
}

/// Parses a template at comptime to render many times at runtime, no allocations needed
pub fn renderComptimePartialTemplate(io: Io) anyerror!void {
    var buf: [4096]u8 = undefined;
    var fw = stdoutWriter(io, &buf);
    defer fw.interface.flush() catch {};

    // Comptime-parsed template
    const comptime_template = comptime mustache.parseComptime(
        \\{{=[ ]=}}
        \\📜 hello [>partial], your lucky number is [sub_value.value]
        \\--------------------------------------
        \\
    , .{}, .{});

    // Comptime tuple with a comptime partial template
    const comptime_partials = .{ "partial", comptime mustache.parseComptime("from {{name}}", .{}, .{}) };

    const Data = struct {
        name: []const u8,
        sub_value: struct {
            value: u32,
        },
    };

    // Runtime value
    const data: Data = .{ .name = "mustache", .sub_value = .{ .value = 42 } };

    var repeat: u32 = 0;
    while (repeat < 10) : (repeat += 1) {
        try mustache.renderPartials(comptime_template, comptime_partials, data, &fw.interface);
    }
}
