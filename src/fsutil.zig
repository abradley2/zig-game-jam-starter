const std = @import("std");
const Dir = std.fs.Dir;
const File = std.fs.File;

pub const OpenError = std.fs.File.OpenError || std.fs.Dir.OpenError;

const PathSegmentArray = std.BoundedArray([]const u8, 32);

pub fn makePathSegmentArray(
    comptime Len: usize,
    comptime Items: [Len][]const u8,
) PathSegmentArray {
    var bounded_array = comptime PathSegmentArray.init(0) catch unreachable;

    if (Len > 32) {
        @compileError("Length exceeds capacity");
    }

    for (0..Len) |i| {
        bounded_array.appendAssumeCapacity(Items[i]);
    }
    return bounded_array;
}

pub fn pathSegmentsToFile(segments_arr: PathSegmentArray) OpenError!struct { Dir, File } {
    var f: File = undefined;
    var d: Dir = std.fs.cwd();

    var dirs_to_close = std.BoundedArray(std.fs.Dir, 32).init(0) catch unreachable;

    const segments = segments_arr.slice();
    const segments_len = segments.len;
    for (0..segments_len) |i| {
        const segment = segments[i];
        if (i == segments_len - 1) {
            _ = dirs_to_close.pop();
            f = try d.openFile(segment, .{ .mode = .read_only });
            break;
        }

        d = try d.openDir(segment, .{});
        dirs_to_close.appendAssumeCapacity(d);
    }

    for (dirs_to_close.slice()) |*dir| {
        _ = dir.close();
    }

    return .{ d, f };
}
