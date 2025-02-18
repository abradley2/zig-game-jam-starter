const std = @import("std");

log_file: std.fs.File,

const Self = @This();

pub fn write(self: *const Self, comptime fmt: []const u8, args: anytype) void {
    var buf: [1024 * 4]u8 = undefined;
    const printed = std.fmt.bufPrintZ(&buf, fmt, args) catch "LogError";

    _ = self.log_file.write(printed) catch 0;
    _ = self.log_file.write("\n") catch 0;
}

pub const InitLogFileError = std.fs.Dir.RealPathError || std.fs.File.OpenError;

pub fn initLogFile() InitLogFileError!std.fs.File {
    const log_file_name = "log.txt";

    // create and close just to make sure we have a blank log file
    const f = try std.fs.cwd().createFile(log_file_name, .{});
    f.close();

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const log_path = try std.fs.cwd().realpath(log_file_name, &path_buffer);

    return try std.fs.cwd().openFile(log_path, .{
        .mode = std.fs.File.OpenMode.write_only,
    });
}

pub fn create() !Self {
    _ = try initLogFile();
    return Self{
        .log_file = try initLogFile(),
    };
}

pub fn destroy(self: Self) void {
    self.log_file.close();
}
