const std = @import("std");
const Allocator = std.mem.Allocator;
const entity = @import("entity.zig");
const EntityRef = entity.EntityRef;
const testing = std.testing;

test "memory is cleaned up when we advance collisions" {
    var buffer: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
    var collisions = try Self.init(fba.allocator());

    for (0..1_000) |i| {
        const entity_a = entity.EntityRef{ ._id = i, .gid = 0 };
        const entity_b = entity.EntityRef{ ._id = i + 1, .gid = 0 };
        try collisions.addCollision(entity_a, entity_b);
        try collisions.advanceCollisions();
    }

    try testing.expect(true);
}

const Self = @This();

pub const Collision = struct {
    entity_a: EntityRef,
    entity_b: EntityRef,
};

game_allocator: Allocator,
prev_frame_collisions: std.AutoHashMap(Collision, bool),
current_frame_collisions: std.AutoHashMap(Collision, bool),

pub fn advanceCollisions(
    self: *Self,
) error{OutOfMemory}!void {
    var prev_iter = self.prev_frame_collisions.iterator();
    while (prev_iter.next()) |entry| {
        std.debug.assert(self.prev_frame_collisions.remove(entry.key_ptr.*));
    }

    var current_iter = self.current_frame_collisions.iterator();
    while (current_iter.next()) |entry| {
        std.debug.assert(self.current_frame_collisions.remove(entry.key_ptr.*));
    }
}

pub fn addCollision(
    self: *Self,
    entity_a: EntityRef,
    entity_b: EntityRef,
) error{OutOfMemory}!void {
    const collision = Collision{ .entity_a = entity_a, .entity_b = entity_b };
    try self.current_frame_collisions.put(collision, true);
}

pub fn init(game_allocator: Allocator) error{OutOfMemory}!Self {
    var self: Self = undefined;
    self.game_allocator = game_allocator;
    self.prev_frame_collisions = std.AutoHashMap(Collision, bool).init(game_allocator);
    self.current_frame_collisions = std.AutoHashMap(Collision, bool).init(game_allocator);
    return self;
}

pub fn deinit(self: *Self) void {
    self.prev_frame_collisions.deinit();
    self.current_frame_collisions.deinit();
}
