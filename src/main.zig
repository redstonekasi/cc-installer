const std = @import("std");
const builtin = @import("builtin");

const log = std.log;
const process = std.process;
const fs = std.fs;
const path = std.fs.path;
const mem = std.mem;

const OpenError = fs.File.OpenError;

const usage = "usage: cumcord {install|uninstall} [stable|ptb|canary|development]";

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try process.argsAlloc(arena);

    if (args.len < 2) {
        log.info("{s}", .{usage});
        log.err("expected command argument", .{});
        process.exit(1);
    }

    const resources_path: []const u8 = switch (builtin.os.tag) {
        .windows => brk: {
            const local_app_data = try process.getEnvVarOwned(arena, "localappdata");
            const discord_name: []const u8 = if (args.len < 3) "Discord" else switch (args[2][0]) {
                's' => "Discord",
                'p' => "DiscordPtb",
                'c' => "DiscordCanary",
                'd' => "DiscordDevelopment",
                else => {
                    log.info("{s}", .{usage});
                    log.err("invalid branch", .{});
                    process.exit(1);
                },
            };

            const discord_path = try path.join(arena, &[_][]const u8{ local_app_data, discord_name });

            var discord_dir = fs.openIterableDirAbsolute(discord_path, .{}) catch |err| {
                switch (err) {
                    OpenError.FileNotFound => log.err("could not find discord installation ({s})", .{discord_name}),
                    OpenError.AccessDenied => log.err("could not access discord, insufficient permissions", .{}),
                    else => log.err("an unknown error occured trying to access discord installation", .{}),
                }
                process.exit(1);
            };
            defer discord_dir.close();
            var walker = try discord_dir.walk(arena);
            defer walker.deinit();

            while (try walker.next()) |entry| {
                if (entry.kind != .Directory) continue;
                if (std.mem.startsWith(u8, entry.basename, "app-")) {
                    break :brk try path.join(arena, &[_][]const u8{ discord_path, entry.path, "resources" });
                }
            }

            log.err("unable to find app directory", .{});
            process.exit(1);
        },
        .linux, .freebsd => brk: {
            const possible_paths = [_][]const u8{ "/opt", "/usr/share" };
            const discord_name: []const u8 = if (args.len < 3) "discord" else switch (args[2][0]) {
                's' => "discord",
                'p' => "discord-ptb",
                'c' => "discord-canary",
                'd' => "discord-development",
                else => {
                    log.info("{s}", .{usage});
                    log.err("invalid branch", .{});
                    process.exit(1);
                },
            };

            for (possible_paths) |p| {
                const possible_path = try path.join(arena, &[_][]const u8{ p, discord_name });
                fs.accessAbsolute(possible_path, .{}) catch continue;
                break :brk try path.join(arena, &[_][]const u8{ possible_path, "resources" });
            }

            log.err("unable to find app directory", .{});
            process.exit(1);
        },
        .macos => brk: {
            const discord_name: []const u8 = if (args.len < 3) "Discord" else switch (args[2][0]) {
                's' => "Discord",
                'p' => "Discord Ptb",
                'c' => "Discord Canary",
                'd' => "Discord Development",
                else => {
                    log.info("{s}", .{usage});
                    log.err("invalid branch", .{});
                    process.exit(1);
                },
            };

            const discord_folder = try mem.join(arena, "", &[_][]const u8{ discord_name, ".app" });

            break :brk try path.join(arena, &[_][]const u8{ "/Applications", discord_folder, "Contents", "Resources" });
        },
        else => @compileError("unsupported operating system"), // todo: add macos suppport
    };

    switch (args[1][0]) {
        'i' => install(arena, resources_path) catch |err| {
            switch (err) {
                OpenError.PathAlreadyExists => log.err("cumcord (or another client mod) is already installed", .{}),
                OpenError.AccessDenied => log.err("couldn't install cumcord, access denied", .{}),
                else => log.err("an unknown error occured during installation", .{}),
            }
            process.exit(1);
        },
        'u' => uninstall(resources_path) catch |err| {
            switch (err) {
                // OpenError.FileNotFound => log.err("cumcord isn't installed", .{}),
                OpenError.AccessDenied => log.err("couldn't uninstall cumcord, access denied", .{}),
                else => log.err("an unknown error occured during uninstallation", .{}),
            }
            process.exit(1);
        },
        else => {
            log.info("{s}", .{usage});
            log.err("invalid command", .{});
            process.exit(1);
        },
    }
}

fn install(arena: std.mem.Allocator, resources_path: []const u8) !void {
    const app_folder_path = try path.join(arena, &[_][]const u8{ resources_path, "app" });
    const app_index_path = try path.join(arena, &[_][]const u8{ app_folder_path, "index.js" });
    const app_package_path = try path.join(arena, &[_][]const u8{ app_folder_path, "package.json" });

    log.info("installing to {s}", .{resources_path});

    try fs.makeDirAbsolute(app_folder_path);

    const index = try fs.createFileAbsolute(app_index_path, .{});
    defer index.close();
    const package = try fs.createFileAbsolute(app_package_path, .{});
    defer package.close();

    try index.writeAll(@embedFile("app/index.js"));
    try package.writeAll(@embedFile("app/package.json"));

    log.info("installed, please restart discord", .{});
}

fn uninstall(resources_path: []const u8) !void {
    log.info("uninstalling from {s}", .{resources_path});

    var resources_dir = try fs.openDirAbsolute(resources_path, .{});
    try resources_dir.deleteTree("app");

    log.info("uninstalled, please restart discord", .{});
}
