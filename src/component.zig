const std = @import("std");
const rl = @import("raylib");

pub fn Slot(comptime T: type) type {
    return union(enum(u2)) {
        empty: void,
        has: T,
    };
}

pub inline fn toOpt(comptime T: type, component: Slot(T)) ?T {
    return switch (component) {
        .has => |v| return v,
        .empty => return null,
    };
}

pub inline fn toOptPtr(comptime T: type, component: *Slot(T)) ?*T {
    return switch (component.*) {
        .has => |*v| return v,
        .empty => return null,
    };
}

pub const ComponentSpec = struct {
    position: Slot(Position),
    velocity: Slot(Velocity),
    health: Slot(Health),
    pub fn default() ComponentSpec {
        return ComponentSpec{
            .position = .empty,
            .velocity = .empty,
            .health = .empty,
        };
    }
};

pub const Components = std.MultiArrayList(ComponentSpec);

pub fn initComponents(alloc: std.mem.Allocator, capacity: usize) error{OutOfMemory}!Components {
    var scene = Components{};
    try scene.ensureTotalCapacity(alloc, capacity);

    for (0..scene.capacity) |_| scene.appendAssumeCapacity(ComponentSpec.default());
    return scene;
}

pub const Position = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Velocity = struct {
    dx: f32,
    dy: f32,
};

pub const Health = struct {
    points: i32,
};

pub const Texture = struct {
    texture_ptr: *rl.Texture2D,
};

pub const Sprite = struct {
    src_rect: rl.Rectangle,
    dst_width: f32,
    dst_height: f32,
    dst_offset_x: f32,
    dst_offset_y: f32,
};

pub const SpriteGroup = struct {
    sprites: std.ArrayList(Sprite),
};
