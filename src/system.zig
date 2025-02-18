const std = @import("std");
const component = @import("./component.zig");
const Components = component.Components;
const Slot = component.Slot;

test runPhysicsSystem {
    const entity = @import("./entity.zig");

    var components = try component.initComponents(std.testing.allocator, 100);
    defer components.deinit(std.testing.allocator);

    var entity_pool = try entity.EntityPool.init(std.testing.allocator);
    defer entity_pool.deinit();

    const test_entity_id = entity_pool.spawnEntity();

    components.set(test_entity_id, component.ComponentSpec.default());

    components.items(.position)[test_entity_id] = Slot(component.Position){
        .has = component.Position{ .x = 0, .y = 0, .z = 0 },
    };
    components.items(.velocity)[test_entity_id] = Slot(component.Velocity){
        .has = component.Velocity{ .dx = 1, .dy = 1 },
    };

    runPhysicsSystem(components.slice());
    runPhysicsSystem(components.slice());

    const updated_position: component.Position = component.toOpt(
        component.Position,
        components.items(.position)[test_entity_id],
    ) orelse @panic("Expected position to be set");

    try std.testing.expectEqual(updated_position.x, 2);
    try std.testing.expectEqual(updated_position.y, 2);
}

pub fn runPhysicsSystem(components: Components.Slice) void {
    for (
        0..,
        components.items(.position),
        components.items(.velocity),
    ) |
        id,
        *has_position,
        has_velocity,
    | {
        _ = id;

        var position = component.toOptPtr(component.Position, has_position) orelse continue;
        const velocity = component.toOpt(component.Velocity, has_velocity) orelse continue;

        position.x += velocity.dx;
        position.y += velocity.dy;
    }
}
