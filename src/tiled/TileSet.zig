const std = @import("std");
const File = std.fs.File;
const Context = @import("../Context.zig");
const TextureId = @import("../textures.zig").TextureId;

const Self = @This();

columns: u32,
image: std.BoundedArray(u8, std.fs.MAX_PATH_BYTES),
name: std.BoundedArray(u8, std.fs.MAX_NAME_BYTES),
texture_id: TextureId,
tile_height: u32,
tile_width: u32,
spacing: u32,
margin: u32,
tile_count: u32,
first_gid: u32,

pub fn fromFile(
    file: *File,
    first_gid: u32,
    context: *Context,
) !Self {
    var buffer: [1024 * 64]u8 = undefined;
    const read_size = try file.readAll(&buffer);
    const file_data = buffer[0..read_size];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const json = try std.json.parseFromSliceLeaky(
        std.json.Value,
        arena.allocator(),
        file_data,
        .{},
    );

    return try fromJson(json, first_gid, context);
}

pub fn fromJson(
    json: std.json.Value,
    first_gid: u32,
    context: *Context,
) error{ InvalidField, UnknownTextureId, MissingField }!Self {
    const tile_set_obj = switch (json) {
        .object => |obj| obj,
        else => return error.InvalidField,
    };

    context.push("columns", .{});
    const columns_json = try (tile_set_obj.get("columns") orelse error.MissingField);
    const columns = switch (columns_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => return error.InvalidField,
    };
    context.pop();

    context.push("tilecount", .{});
    const tile_count_json = try (tile_set_obj.get("tilecount") orelse error.MissingField);
    const tile_count = switch (tile_count_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => return error.InvalidField,
    };
    context.pop();

    context.push("image", .{});
    const image_json = try (tile_set_obj.get("image") orelse error.MissingField);
    var image = std.BoundedArray(u8, std.fs.MAX_PATH_BYTES).init(0) catch unreachable;
    switch (image_json) {
        .string => |str| image.appendSliceAssumeCapacity(str),
        else => return error.InvalidField,
    }
    context.pop();

    context.push("name", .{});
    const name_json = try (tile_set_obj.get("name") orelse error.MissingField);
    var name = std.BoundedArray(u8, std.fs.MAX_NAME_BYTES).init(0) catch unreachable;
    switch (name_json) {
        .string => |str| name.appendSliceAssumeCapacity(str),
        else => return error.InvalidField,
    }

    const texture_id = try (TextureId.fromFileName(name) orelse error.UnknownTextureId);
    context.pop();

    context.push("tileheight", .{});
    const tile_height_json = try (tile_set_obj.get("tileheight") orelse error.MissingField);
    const tile_height = switch (tile_height_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => return error.InvalidField,
    };
    context.pop();

    context.push("tilewidth", .{});
    const tile_width_json = try (tile_set_obj.get("tilewidth") orelse error.MissingField);
    const tile_width = switch (tile_width_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => return error.InvalidField,
    };
    context.pop();

    context.push("spacing", .{});
    const spacing_json = try (tile_set_obj.get("spacing") orelse error.MissingField);
    const spacing = switch (spacing_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => return error.InvalidField,
    };
    context.pop();

    context.push("margin", .{});
    const margin_json = try (tile_set_obj.get("margin") orelse error.MissingField);
    const margin = switch (margin_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => return error.InvalidField,
    };
    context.pop();

    return Self{
        .columns = columns,
        .image = image,
        .name = name,
        .texture_id = texture_id,
        .tile_height = tile_height,
        .tile_width = tile_width,
        .spacing = spacing,
        .margin = margin,
        .tile_count = tile_count,
        .first_gid = first_gid,
    };
}
