const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const component = @import("./component.zig");
const Components = component.Components;
const entity = @import("./entity.zig");
const EntityPool = entity.EntityPool;
const system = @import("./system.zig");
const Collisions = @import("./Collisions.zig");
const Logger = @import("./Logger.zig");
const TileMap = @import("./tiled/TileMap.zig");
const MapId = TileMap.MapId;
const TextureId = @import("./textures.zig").TextureId;
const Context = @import("./Context.zig");

test {
    std.testing.refAllDecls(@This());
}

pub fn main() !void {
    var components_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer components_alloc.deinit();

    var components = try component.initComponents(
        components_alloc.allocator(),
        entity.ENTITY_COUNT,
    );

    var game_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!game_alloc.detectLeaks());

    var entity_pool = try EntityPool.init(game_alloc.allocator());
    defer entity_pool.deinit();

    var collisions = try Collisions.init(game_alloc.allocator());
    defer collisions.deinit();

    var textures = std.AutoHashMap(TextureId, rl.Texture2D).init(game_alloc.allocator());
    defer {
        var texture_map_iter = textures.iterator();
        while (texture_map_iter.next()) |entry| {
            rl.unloadTexture(entry.value_ptr.*);
        }
        textures.deinit();
    }

    const l = try Logger.create();

    try runGame(
        &l,
        &entity_pool,
        &components,
        &collisions,
        &textures,
    );
}

fn loadMap(
    l: *const Logger,
    map_id: MapId,
    entity_pool: *EntityPool,
    components: *Components,
    textures: *std.AutoHashMap(TextureId, rl.Texture2D),
) !void {
    var context = Context.init();
    errdefer |err| {
        l.write("{}: {s}\n", .{ err, context.print().slice() });
    }

    const tile_map = try TileMap.init(map_id, &context, textures);

    for (0.., tile_map.layers.slice()) |layer_idx, layer| {
        const layer_entity = entity_pool.spawnEntity();
        var layer_sprite_group = entity_pool.acquireSpriteGroup(layer_entity);

        _ = layer_idx;
        for (0.., layer.data.slice()) |tile_idx, tile| {
            _ = tile;
            const row = tile_idx / tile_map.width;
            const col = tile_idx % tile_map.height;

            const x_offset = col * tile_map.tile_width;
            const y_offset = row * tile_map.tile_height;

            const sprite = component.Sprite{
                .dst_offset_x = @floatFromInt(x_offset),
                .dst_offset_y = @floatFromInt(y_offset),
                .dst_height = @floatFromInt(tile_map.tile_height),
                .dst_width = @floatFromInt(tile_map.tile_width),
                .src_rect = rl.Rectangle{
                    .x = 32,
                    .y = 32,
                    .width = 32,
                    .height = 32,
                },
            };

            try layer_sprite_group.sprites.append(sprite);
        }
    }

    _ = components;
}

fn runGame(
    l: *const Logger,
    entity_pool: *EntityPool,
    components: *Components,
    collisions: *Collisions,
    textures: *std.AutoHashMap(TextureId, rl.Texture2D),
) !void {
    const demo_entity_id = entity_pool.spawnEntity();

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Unnamed Game");
    defer rl.closeWindow();

    try loadMap(l, MapId.Area01, entity_pool, components, textures);

    rl.setTargetFPS(60);

    var frame_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    while (!rl.windowShouldClose()) {
        defer _ = frame_alloc.reset(.{ .retain_with_limit = 1_024 });

        system.runPhysicsSystem(components.slice());
        try collisions.advanceCollisions();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
    }

    entity_pool.freeEntity(components, demo_entity_id);
    entity_pool.freeEntity(components, demo_entity_id);
}
