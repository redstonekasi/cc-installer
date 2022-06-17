const std = @import("std");

const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;
const Mode = std.builtin.Mode;

const BuildTarget = struct {
    name: []const u8,
    cross_target: CrossTarget,
    mode: Mode,
};

const targets = [_]BuildTarget{
    .{
        .name = "cumcord-x86_64-windows",
        .cross_target = CrossTarget{
            .cpu_arch = Target.Cpu.Arch.x86_64,
            .os_tag = Target.Os.Tag.windows,
        },
        .mode = Mode.ReleaseSafe,
    },
    .{
        .name = "cumcord-x86_64-linux",
        .cross_target = CrossTarget{
            .cpu_arch = Target.Cpu.Arch.x86_64,
            .os_tag = Target.Os.Tag.linux,
        },
        .mode = Mode.ReleaseSafe,
    },
};

pub fn build(b: *std.build.Builder) void {
    for (targets) |target| {
        const exe = b.addExecutable(target.name, "src/main.zig");
        exe.strip = true;
        exe.setTarget(target.cross_target);
        exe.setBuildMode(target.mode);
        exe.install();
    }
}
