const std = @import("std");

const Self = @This();

const ContextSegment = std.BoundedArray(u8, 256);

context: std.BoundedArray(ContextSegment, 12),

pub fn init() Self {
    return Self{
        .context = std.BoundedArray(ContextSegment, 12).init(0) catch unreachable,
    };
}

pub fn push(self: *Self, comptime fmt_str: []const u8, args: anytype) void {
    const context_segment: *ContextSegment = self.context.addOne() catch return;

    var buffer: [256]u8 = undefined;
    const output_buff = std.fmt.bufPrint(&buffer, fmt_str, args) catch buffer[0..];

    context_segment.resize(output_buff.len) catch unreachable;
    @memcpy(context_segment.slice(), output_buff);
}

pub fn pop(self: *Self) void {
    _ = self.context.pop();
}

pub fn print(self: *Self) std.BoundedArray(u8, 4096) {
    var output = std.BoundedArray(u8, 4096).init(0) catch unreachable;
    for (0..self.context.len) |i| {
        const idx = self.context.len - i - 1;
        const context_segment: ContextSegment = self.context.slice()[idx];

        const prev_len = output.len;
        const next_len = output.len + context_segment.len;

        output.resize(next_len) catch {};
        const output_slice = output.slice()[prev_len..next_len];
        @memcpy(output_slice, context_segment.slice());

        if (idx != 0) output.appendSlice(" <- ") catch {};
    }
    return output;
}
