const std = @import("std");
const zigimg = @import("zigimg");
const Allocator = std.mem.Allocator;

pub const Palette = struct {
    name: []const u8,
    colors: []zigimg.color.Rgba32,
};

pub const PaletteError = error{
    PaletteNotFound,
};

pub const PaletteConfig = struct {
    allocator: Allocator,
    palettes: std.StringHashMap(Palette),

    pub fn init(allocator: Allocator) PaletteConfig {
        return .{
            .allocator = allocator,
            .palettes = std.StringHashMap(Palette).init(allocator),
        };
    }

    pub fn deinit(self: *PaletteConfig) void {
        var it = self.palettes.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.colors);
        }
        self.palettes.deinit();
    }

    pub fn loadFromFile(self: *PaletteConfig, file_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [1024]u8 = undefined;
        var current_section: ?[]u8 = null;
        var current_colors = std.ArrayList(zigimg.color.Rgba32).init(self.allocator);
        defer current_colors.deinit();

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == ';') continue;

            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                // New section
                if (current_section) |name| {
                    try self.addPalette(name, current_colors.items);
                    current_colors.clearRetainingCapacity();
                    self.allocator.free(name);
                }
                current_section = try self.allocator.dupe(u8, trimmed[1 .. trimmed.len - 1]);
            } else if (current_section != null) {
                // Color entry
                var color_parts = std.mem.split(u8, trimmed, ",");
                const r = try std.fmt.parseInt(u8, color_parts.next() orelse return error.InvalidFormat, 10);
                const g = try std.fmt.parseInt(u8, color_parts.next() orelse return error.InvalidFormat, 10);
                const b = try std.fmt.parseInt(u8, color_parts.next() orelse return error.InvalidFormat, 10);
                try current_colors.append(.{ .r = r, .g = g, .b = b, .a = 255 });
            }
        }

        if (current_section) |name| {
            try self.addPalette(name, current_colors.items);
            self.allocator.free(name);
        }
    }

    fn addPalette(self: *PaletteConfig, name: []const u8, colors: []const zigimg.color.Rgba32) !void {
        const palette_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(palette_name);

        const palette_colors = try self.allocator.dupe(zigimg.color.Rgba32, colors);
        errdefer self.allocator.free(palette_colors);

        const result = try self.palettes.getOrPut(palette_name);
        if (result.found_existing) {
            self.allocator.free(result.key_ptr.*);
            self.allocator.free(result.value_ptr.colors);
        }

        result.key_ptr.* = palette_name;
        result.value_ptr.* = .{
            .name = palette_name,
            .colors = palette_colors,
        };
    }

    pub fn getPaletteByName(self: *PaletteConfig, name: []const u8) !Palette {
        if (self.palettes.get(name)) |palette| {
            return palette;
        }
        return PaletteError.PaletteNotFound;
    }

    pub fn listPalettes(self: *PaletteConfig) !void {
        std.debug.print("Available palettes:\n", .{});
        var it = self.palettes.iterator();
        while (it.next()) |entry| {
            std.debug.print("  - {s}\n", .{entry.key_ptr.*});
        }
    }
};
