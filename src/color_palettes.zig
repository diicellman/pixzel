const std = @import("std");
const zigimg = @import("zigimg");

pub const Palette = struct {
    name: []const u8,
    colors: []const zigimg.color.Rgba32,
};

pub const PaletteError = error{
    PaletteNotFound,
};

pub const presetPalettes = [_]Palette{
    .{
        .name = "retro",
        .colors = &[_]zigimg.color.Rgba32{
            .{ .r = 0, .g = 0, .b = 0, .a = 255 },
            .{ .r = 255, .g = 255, .b = 255, .a = 255 },
            .{ .r = 136, .g = 0, .b = 0, .a = 255 },
            .{ .r = 170, .g = 255, .b = 238, .a = 255 },
            .{ .r = 204, .g = 68, .b = 204, .a = 255 },
            .{ .r = 0, .g = 204, .b = 85, .a = 255 },
            .{ .r = 0, .g = 0, .b = 170, .a = 255 },
            .{ .r = 238, .g = 238, .b = 119, .a = 255 },
            .{ .r = 221, .g = 136, .b = 85, .a = 255 },
            .{ .r = 102, .g = 68, .b = 0, .a = 255 },
            .{ .r = 255, .g = 119, .b = 119, .a = 255 },
            .{ .r = 51, .g = 51, .b = 51, .a = 255 },
            .{ .r = 119, .g = 119, .b = 119, .a = 255 },
            .{ .r = 170, .g = 255, .b = 102, .a = 255 },
            .{ .r = 0, .g = 136, .b = 255, .a = 255 },
            .{ .r = 187, .g = 187, .b = 187, .a = 255 },
        },
    },
    .{
        .name = "grayscale",
        .colors = &[_]zigimg.color.Rgba32{
            .{ .r = 0, .g = 0, .b = 0, .a = 255 },
            .{ .r = 32, .g = 32, .b = 32, .a = 255 },
            .{ .r = 64, .g = 64, .b = 64, .a = 255 },
            .{ .r = 96, .g = 96, .b = 96, .a = 255 },
            .{ .r = 128, .g = 128, .b = 128, .a = 255 },
            .{ .r = 160, .g = 160, .b = 160, .a = 255 },
            .{ .r = 192, .g = 192, .b = 192, .a = 255 },
            .{ .r = 224, .g = 224, .b = 224, .a = 255 },
            .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        },
    },
    .{
        .name = "muted",
        .colors = &[_]zigimg.color.Rgba32{
            .{ .r = 243, .g = 233, .b = 201, .a = 255 },
            .{ .r = 160, .g = 82, .b = 45, .a = 255 },
            .{ .r = 107, .g = 55, .b = 90, .a = 255 },
            .{ .r = 75, .g = 87, .b = 123, .a = 255 },
            .{ .r = 140, .g = 162, .b = 173, .a = 255 },
            .{ .r = 208, .g = 183, .b = 149, .a = 255 },
            .{ .r = 181, .g = 101, .b = 118, .a = 255 },
            .{ .r = 239, .g = 195, .b = 164, .a = 255 },
            .{ .r = 117, .g = 137, .b = 78, .a = 255 },
            .{ .r = 190, .g = 190, .b = 190, .a = 255 },
            .{ .r = 82, .g = 80, .b = 100, .a = 255 },
            .{ .r = 214, .g = 133, .b = 79, .a = 255 },
            .{ .r = 178, .g = 181, .b = 128, .a = 255 },
            .{ .r = 147, .g = 112, .b = 152, .a = 255 },
            .{ .r = 55, .g = 48, .b = 61, .a = 255 },
            .{ .r = 240, .g = 240, .b = 240, .a = 255 },
        },
    },
};

pub fn getPaletteByName(name: []const u8) !Palette {
    for (presetPalettes) |palette| {
        if (std.mem.eql(u8, palette.name, name)) {
            return palette;
        }
    }
    return PaletteError.PaletteNotFound;
}

pub fn loadCustomPalette(allocator: std.mem.Allocator, file_path: []const u8) !Palette {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);
    if (bytes_read != file_size) return error.IncompleteRead;

    var color_count: usize = 0;
    var lines = std.mem.split(u8, buffer, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len > 0) color_count += 1;
    }

    const colors = try allocator.alloc(zigimg.color.Rgba32, color_count);
    errdefer allocator.free(colors);

    var index: usize = 0;
    lines = std.mem.split(u8, buffer, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        var color_parts = std.mem.split(u8, trimmed, ",");
        const r = try std.fmt.parseInt(u8, color_parts.next() orelse return error.InvalidFormat, 10);
        const g = try std.fmt.parseInt(u8, color_parts.next() orelse return error.InvalidFormat, 10);
        const b = try std.fmt.parseInt(u8, color_parts.next() orelse return error.InvalidFormat, 10);

        colors[index] = .{ .r = r, .g = g, .b = b, .a = 255 };
        index += 1;
    }

    return Palette{
        .name = try allocator.dupe(u8, "custom"),
        .colors = colors,
    };
}
