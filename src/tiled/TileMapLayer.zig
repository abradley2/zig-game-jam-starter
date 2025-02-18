const std = @import("std");
const Context = @import("../Context.zig");

const Self = @This();

pub const MAX_LAYER_SIZE = 2_500;

data: std.BoundedArray(u32, MAX_LAYER_SIZE),

pub fn fromJson(
    json: std.json.Value,
    context: *Context,
) !Self {
    context.push("tile_map_layer", .{});
    const json_obj = switch (json) {
        .object => |obj| obj,
        else => return error.InvalidField,
    };
    context.pop();

    context.push("data", .{});
    const data_json = json_obj.get("data") orelse return error.MissingField;
    var data = std.BoundedArray(u32, MAX_LAYER_SIZE).init(0) catch unreachable;
    switch (data_json) {
        .array => |arr| {
            if (arr.items.len > data.capacity()) return error.InvalidField;

            for (0.., arr.items) |idx, item_json| {
                context.push("data[{d}]", .{idx});
                switch (item_json) {
                    .integer => |num| {
                        data.appendAssumeCapacity(@as(u32, @intCast(num)));
                    },
                    else => return error.InvalidField,
                }
                context.pop();
            }
        },
        else => return error.InvalidField,
    }
    context.pop();

    return Self{
        .data = data,
    };
}
