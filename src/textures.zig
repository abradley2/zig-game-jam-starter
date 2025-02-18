const std = @import("std");

pub const TextureId: type = enum(u8) {
    ShipTerrainAndBackWall,
    ShipPlatforms,

    pub fn fromFileName(file_name: std.BoundedArray(u8, std.fs.MAX_NAME_BYTES)) ?TextureId {
        const name = file_name.slice();

        if (std.mem.eql(u8, name, "Terrain and Back Wall (32x32)")) return TextureId.ShipTerrainAndBackWall;

        if (std.mem.eql(u8, name, "Platforms (32x32)")) return TextureId.ShipPlatforms;

        return null;
    }
};
