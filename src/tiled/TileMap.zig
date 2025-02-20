const std = @import("std");
const File = std.fs.File;
const Dir = std.fs.Dir;
const rl = @import("raylib");
const TileMapLayer = @import("./TileMapLayer.zig");
const TileSet = @import("./TileSet.zig");
const fsutil = @import("../fsutil.zig");
const Context = @import("../Context.zig");
const TextureId = @import("../textures.zig").TextureId;

const Self = @This();

pub const MapId: type = enum(u8) {
    Area01,
    Area02,

    pub fn toFile(map_id: MapId) fsutil.OpenError!struct { Dir, File } {
        const area_01 = fsutil.makePathSegmentArray(
            2,
            [2][]const u8{ "assets", "area_01.json" },
        );
        const area_02 = fsutil.makePathSegmentArray(
            2,
            [2][]const u8{ "assets", "area_02.json" },
        );

        return switch (map_id) {
            .Area01 => try fsutil.pathSegmentsToFile(area_01),
            .Area02 => try fsutil.pathSegmentsToFile(area_02),
        };
    }
};

const TileSetSource = struct {
    first_gid: u32,
    source: std.BoundedArray(u8, std.fs.MAX_PATH_BYTES),

    pub fn fromJson(json_value: std.json.Value, context: *Context) !TileSetSource {
        const tile_set_source_obj = try switch (json_value) {
            .object => |obj| obj,
            else => error.InvalidField,
        };

        context.push("firstgid", .{});
        const first_gid_json = try (tile_set_source_obj.get("firstgid") orelse error.MissingField);
        const first_gid = try switch (first_gid_json) {
            .integer => |num| @as(u32, @intCast(num)),
            else => error.InvalidField,
        };
        context.pop();

        context.push("source", .{});
        const source_json = try (tile_set_source_obj.get("source") orelse error.MissingField);
        var source = std.BoundedArray(u8, std.fs.MAX_PATH_BYTES).init(0) catch unreachable;
        try switch (source_json) {
            .string => |str| {
                if (str.len > source.capacity()) return error.InvalidField;
                source.appendSliceAssumeCapacity(str);
            },
            else => error.InvalidField,
        };
        context.pop();

        return TileSetSource{
            .first_gid = first_gid,
            .source = source,
        };
    }
};

height: u32,
width: u32,
tile_height: u32,
tile_width: u32,
layers: std.BoundedArray(TileMapLayer, 10),
tile_set_sources: std.BoundedArray(TileSetSource, 10),
tile_sets: std.BoundedArray(TileSet, 10),

pub const InitError =
    std.fs.Dir.OpenError ||
    std.fs.File.OpenError ||
    std.fs.File.ReadError ||
    FromFileError ||
    FromJsonError;

pub fn init(
    map_id: MapId,
    context: *Context,
    textures: *std.AutoHashMap(TextureId, rl.Texture2D),
) InitError!Self {
    var dir, var file = try MapId.toFile(map_id);
    defer dir.close();
    defer file.close();

    context.push("tile_map", .{});
    var tile_map = try fromFile(&file, context);
    context.pop();

    context.push("tile_sets", .{});
    for (0.., tile_map.tile_set_sources.slice()) |idx, tile_set_source| {
        context.push("tile_sets[{d}]", .{idx});
        var tile_set_file = try dir.openFile(
            tile_set_source.source.slice(),
            .{ .mode = .read_only },
        );
        defer tile_set_file.close();

        const tile_set = try TileSet.fromFile(
            &tile_set_file,
            tile_set_source.first_gid,
            context,
        );
        tile_map.tile_sets.appendAssumeCapacity(tile_set);
        context.pop();

        if (textures.get(tile_set.texture_id) == null) {
            const tile_set_directory = std.fs.path.dirname(tile_set_source.source.slice()) orelse unreachable;
            var image_path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            var image_path_fba = std.heap.FixedBufferAllocator.init(image_path_buffer[0..]);
            const image_path_segments: [3][]const u8 = .{
                "assets",
                tile_set_directory,
                tile_set.image.slice(),
            };
            const image_path = try std.fs.path.joinZ(image_path_fba.allocator(), &image_path_segments);
            const texture2d = rl.loadTexture(image_path);
            try textures.put(tile_set.texture_id, texture2d);
        }
    }
    context.pop();

    return tile_map;
}

pub const FromFileError =
    FromJsonError ||
    std.fs.File.ReadError ||
    std.mem.Allocator.Error ||
    std.json.ParseError(std.json.Scanner);

pub fn fromFile(file: *File, context: *Context) FromFileError!Self {
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

    return fromJson(json, context);
}

pub const FromJsonError =
    error{ InvalidField, UnknownTextureId, MissingField };

pub fn fromJson(json: std.json.Value, context: *Context) FromJsonError!Self {
    const tile_map_obj = try switch (json) {
        .object => |obj| obj,
        else => error.InvalidField,
    };

    context.push("height", .{});
    const height_json = try (tile_map_obj.get("height") orelse error.MissingField);
    const height = try switch (height_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => error.InvalidField,
    };
    context.pop();

    context.push("width", .{});
    const width_json = try (tile_map_obj.get("width") orelse error.MissingField);
    const width = try switch (width_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => error.InvalidField,
    };
    context.pop();

    context.push("tileheight", .{});
    const tile_height_json = try (tile_map_obj.get("tileheight") orelse error.MissingField);
    const tile_height = try switch (tile_height_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => error.InvalidField,
    };
    context.pop();

    context.push("tilewidth", .{});
    const tile_width_json = try (tile_map_obj.get("tilewidth") orelse error.MissingField);
    const tile_width = try switch (tile_width_json) {
        .integer => |num| @as(u32, @intCast(num)),
        else => error.InvalidField,
    };
    context.pop();

    context.push("tilesets", .{});
    const tile_set_sources_json = try (tile_map_obj.get("tilesets") orelse error.MissingField);
    var tile_set_sources = std.BoundedArray(TileSetSource, 10).init(0) catch unreachable;
    try switch (tile_set_sources_json) {
        .array => |arr| {
            if (arr.items.len > tile_set_sources.capacity()) return error.InvalidField;
            for (0.., arr.items) |idx, item| {
                context.push("tilesets[{d}]", .{idx});
                const tile_set_source = try TileSetSource.fromJson(item, context);
                tile_set_sources.appendAssumeCapacity(tile_set_source);
                context.pop();
            }
        },
        else => error.InvalidField,
    };
    context.pop();

    context.push("layers", .{});
    const layers_json = try (tile_map_obj.get("layers") orelse error.MissingField);
    var layers = std.BoundedArray(TileMapLayer, 10).init(0) catch unreachable;
    try switch (layers_json) {
        .array => |arr| {
            if (arr.items.len > layers.capacity()) return error.InvalidField;
            for (0.., arr.items) |idx, item| {
                context.push("layers[{d}]", .{idx});
                const layer = try TileMapLayer.fromJson(item, context);
                layers.appendAssumeCapacity(layer);
                context.pop();
            }
        },
        else => error.InvalidField,
    };
    context.pop();

    return Self{
        .height = height,
        .width = width,
        .tile_height = tile_height,
        .tile_width = tile_width,
        .layers = layers,
        .tile_set_sources = tile_set_sources,
        .tile_sets = std.BoundedArray(TileSet, 10).init(0) catch unreachable,
    };
}
