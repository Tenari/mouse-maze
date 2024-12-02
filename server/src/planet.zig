const std = @import("std");

const Self = @This();
// 1 solar radius = 0.0386767568 light minutes
const EARTH_RADIUS_KM: f64 = 6371.0;
// 1 light minute = 17,987,547,480 m
const KM_PER_LIGHT_MINUTE: f64 = 17_987_547.480;
const EARTH_RADIUS: f64 = EARTH_RADIUS_KM / KM_PER_LIGHT_MINUTE;
const GAS_GIANT_RADIUS: f64 = EARTH_RADIUS * 10.9;
const ICE_GIANT_RADIUS: f64 = 24_622.0 / KM_PER_LIGHT_MINUTE;
const LAVA_RADIUS: f64 = EARTH_RADIUS * 1.528;

pub const Printable = struct {
    x: f64, y: f64, z: f64,
    kind: Kind,
    radius: f64,
};

const Kind = enum {
    earth, gas, ice, water, desert, lava,

    pub fn radius(self: Kind, seed: f64) f64 {
        return switch (self) {
            .earth, .desert, .water => (0.5*EARTH_RADIUS) + @rem(seed, EARTH_RADIUS),
            .gas => (GAS_GIANT_RADIUS*0.5) + @rem(seed, GAS_GIANT_RADIUS),
            .ice => (0.5*ICE_GIANT_RADIUS) + @rem(seed, ICE_GIANT_RADIUS),
            .lava => (0.5*LAVA_RADIUS) + @rem(seed, LAVA_RADIUS),
        };
    }

    pub fn fromSeed(seed: f64) Kind {
        const modded: u8 = @intFromFloat(@mod(seed, 6));
        return switch (modded) {
            0 => .earth,
            1 => .gas,
            2 => .ice,
            3 => .water,
            4 => .desert,
            else => .lava,
        };
    }
};

// fields
id: u64,
kind: Kind,
radius: f64,
x: f64 = 0.0,
y: f64 = 0.0,
z: f64 = 0.0,

// fns
// seed should be from 1000 to 0
pub fn init(seed: f64) Self {
    const orbitRadius = 3.5 + (seed / 1000.0) * 245.0;
    const orbitTheta = (seed / 1000.0) * (std.math.pi * 2.0); //in radians
    // const zAngle = (seed % 50) / 10;
    const kind = Kind.fromSeed(seed);
    return .{
        .id = 0,
        .kind = kind,
        .radius = kind.radius(seed),
        .x = @cos(orbitTheta) * orbitRadius,
        .y = @sin(orbitTheta) * orbitRadius,
    };
}


