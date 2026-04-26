const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const assert = std.debug.assert;
const testing = std.testing;

const Io = std.Io;

const mustache = @import("../mustache.zig");
const TemplateOptions = mustache.options.TemplateOptions;

const ref_counter = @import("ref_counter.zig");

const File = Io.File;

pub fn FileReaderType(comptime options: TemplateOptions) type {
    const read_buffer_size = switch (options.source) {
        .file => |file| file.read_buffer_size,
        .string => return void,
    };

    const RefCounter = ref_counter.RefCounterType(options);
    const RefCountedSlice = ref_counter.RefCountedSliceType(options);

    return struct {
        const FileReader = @This();

        pub const OpenError = File.OpenError;
        pub const Error = Allocator.Error || File.ReadStreamingError;

        io: Io,
        file: File,
        eof: bool = false,

        pub fn init(io: Io, absolute_path: []const u8) OpenError!FileReader {
            const file = try Io.Dir.openFileAbsolute(io, absolute_path, .{});
            return FileReader{
                .io = io,
                .file = file,
            };
        }

        pub fn read(self: *FileReader, allocator: Allocator, prepend: []const u8) Error!RefCountedSlice {
            var buffer = try allocator.alloc(u8, read_buffer_size + prepend.len);
            errdefer allocator.free(buffer);

            if (prepend.len > 0) {
                std.mem.copyForwards(u8, buffer, prepend);
            }

            const size = self.file.readStreaming(self.io, &.{buffer[prepend.len..]}) catch |err| switch (err) {
                error.EndOfStream => 0,
                else => |e| return e,
            };

            if (size < read_buffer_size) {
                const full_size = prepend.len + size;

                assert(full_size < buffer.len);
                buffer = try allocator.realloc(buffer, full_size);
                self.eof = true;
            } else {
                self.eof = false;
            }

            return RefCountedSlice{
                .slice = buffer,
                .ref_counter = try RefCounter.create(allocator, buffer),
            };
        }

        pub fn deinit(self: *FileReader) void {
            self.file.close(self.io);
        }
    };
}

test "FileReader.Slices" {
    const allocator = testing.allocator;
    const io = testing.io;

    // Test the FileReader slicing mechanism
    // In a real use case, the read_buffer_len is much larger than the amount needed to produce a token
    // So we can parse many tokens on a single read, and read a new slice containing only the last unparsed bytes
    //
    // Just 5 chars in our test
    const SlicedReader = FileReaderType(.{ .source = .{ .file = .{ .read_buffer_size = 5 } }, .output = .cache });

    //
    //                           Block index
    //              First slice  | Second slice
    //           Block index  |  | |    Third slice
    //                     ↓  ↓  ↓ ↓    ↓
    const content_text = "{{name}}Just static";

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const file_name = "file_reader_slices.tmp";
    {
        var file = try tmp.dir.createFile(io, file_name, .{ .truncate = true });
        defer file.close(io);
        var w_buf: [256]u8 = undefined;
        var fw = file.writer(io, &w_buf);
        try fw.interface.writeAll(content_text);
        try fw.interface.flush();
    }

    const absolute_file_path = try tmp.dir.realPathFileAlloc(io, file_name, allocator);
    defer allocator.free(absolute_file_path);

    var reader = try SlicedReader.init(io, absolute_file_path);
    defer reader.deinit();

    var slice: []const u8 = &.{};
    try testing.expectEqualStrings("", slice);

    // First read
    // We got a slice with "read_buffer_len" size to parse
    var result_1 = try reader.read(allocator, slice);
    defer result_1.ref_counter.unRef(allocator);
    slice = result_1.slice;

    try testing.expectEqual(false, reader.eof);
    try testing.expectEqual(@as(usize, 5), slice.len);
    try testing.expectEqualStrings("{{nam", slice);

    // Second read,
    // The parser produces the first token "{{" and reaches the EOF of this slice
    // We need more data, the previous slice was parsed until the block_index = 2,
    // so we expect the next read to return the remaining bytes plus new 5 bytes read
    var result_2 = try reader.read(allocator, slice[2..]);
    defer result_2.ref_counter.unRef(allocator);
    slice = result_2.slice;

    try testing.expectEqual(false, reader.eof);
    try testing.expectEqualStrings("name}}Ju", slice);

    // Third read,
    // We parsed a next token '}}' at block_index = 6,
    // so we need another slice
    var result_3 = try reader.read(allocator, slice[6..]);
    defer result_3.ref_counter.unRef(allocator);
    slice = result_3.slice;

    try testing.expectEqual(false, reader.eof);
    try testing.expectEqualStrings("Just st", slice);

    // Last read,
    // Nothing was parsed,
    var result_4 = try reader.read(allocator, slice);
    defer result_4.ref_counter.unRef(allocator);
    slice = result_4.slice;

    try testing.expectEqual(true, reader.eof);
    try testing.expectEqualStrings("Just static", slice);

    // After that, EOF
    var result_5 = try reader.read(allocator, slice);
    defer result_5.ref_counter.unRef(allocator);
    slice = result_5.slice;

    try testing.expectEqual(true, reader.eof);
    try testing.expectEqualStrings("Just static", slice);
}
