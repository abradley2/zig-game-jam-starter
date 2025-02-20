const std = @import("std");
const Allocator = std.mem.Allocator;
const component = @import("./component.zig");
const Components = component.Components;

pub const ENTITY_COUNT = 4_096;

pub const EntityRef = struct {
    _id: usize,
    gid: u16,

    pub fn validate(self: EntityRef, pool: *EntityPool) ?usize {
        const expected_gid = pool.lid_to_gid[self.id];

        if (self.gid != expected_gid) {
            return null;
        }
        return self.id;
    }
};

pub const EntityPool: type = struct {
    gid: u16 = 0,
    lid_pool: [ENTITY_COUNT]bool = std.mem.zeroes([ENTITY_COUNT]bool),
    lid_to_gid: [ENTITY_COUNT]u16 = std.mem.zeroes([ENTITY_COUNT]u16),

    sprite_groups: *[ENTITY_COUNT]component.SpriteGroup,
    game_alloc: Allocator,

    pub fn init(game_alloc: Allocator) error{OutOfMemory}!EntityPool {
        var sprite_groups: *[ENTITY_COUNT]component.SpriteGroup = try game_alloc.create([ENTITY_COUNT]component.SpriteGroup);
        for (0..sprite_groups.len) |i| {
            sprite_groups[i] = component.SpriteGroup{
                .sprites = std.ArrayList(component.Sprite).init(game_alloc),
            };
        }

        const self: EntityPool = EntityPool{
            .sprite_groups = sprite_groups,
            .game_alloc = game_alloc,
        };

        return self;
    }

    pub fn deinit(self: *EntityPool) void {
        for (self.sprite_groups) |sprite_group| {
            sprite_group.sprites.deinit();
        }
        self.game_alloc.destroy(self.sprite_groups);
    }

    pub fn acquireSpriteGroup(self: *EntityPool, id: usize) *component.SpriteGroup {
        self.sprite_groups[id].sprites.shrinkAndFree(0);
        return &self.sprite_groups[id];
    }

    pub fn spawnEntity(self: *EntityPool) usize {
        std.debug.assert(self.lid_pool[self.lid_pool.len - 1] == false);

        var id: usize = 0;
        while (true) {
            if (self.lid_pool[id] == false) {
                self.lid_pool[id] = true;
                break;
            }
            id += 1;
        }

        self.gid = self.gid + 1;
        const gid = self.gid;
        self.lid_to_gid[id] = gid;
        return id;
    }

    pub fn idToRef(self: *EntityPool, id: usize) EntityRef {
        return EntityRef{ .id = id, .gid = self.lid_to_gid[id] };
    }

    pub fn freeEntity(self: *EntityPool, components: *Components, id: usize) void {
        self.lid_pool[id] = false;
        self.lid_to_gid[id] = 0;
        components.set(id, component.ComponentSpec.default());
    }
};
