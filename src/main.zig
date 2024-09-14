const std = @import("std");
const zigimg = @import("zigimg");
const color_palettes = @import("color_palettes.zig");
const expect = std.testing.expect;

const PixelArtOptions = struct {
    min_pixel_size: u32 = 2,
    max_pixel_size: u32 = 8,
    min_image_size: u32 = 32,
    num_colors: u32 = 16,
    palette: ?color_palettes.Palette = null,
};

const CliOptions = struct {
    input_path: []const u8,
    output_path: []const u8,
    pixel_size: u32,
    palette_name: ?[]const u8,
    custom_palette_path: ?[]const u8,
    help: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cli_options = try parseCliArguments(allocator);
    defer {
        allocator.free(cli_options.input_path);
        allocator.free(cli_options.output_path);
        if (cli_options.palette_name) |name| allocator.free(name);
        if (cli_options.custom_palette_path) |path| allocator.free(path);
    }

    if (cli_options.help) {
        printUsage();
        return;
    }

    // Load the image
    var image = try zigimg.Image.fromFilePath(allocator, cli_options.input_path);
    defer image.deinit();

    // Get the palette
    var palette: ?color_palettes.Palette = null;
    defer {
        if (palette) |p| {
            if (cli_options.custom_palette_path != null) {
                allocator.free(p.colors);
                allocator.free(p.name);
            }
        }
    }

    if (cli_options.custom_palette_path) |path| {
        palette = try color_palettes.loadCustomPalette(allocator, path);
        std.debug.print("Custom palette loaded successfully\n", .{});
    } else if (cli_options.palette_name) |name| {
        palette = try color_palettes.getPaletteByName(name);
    }

    // Convert to pixel art
    std.debug.print("Converting to pixel art\n", .{});
    var pixel_art = try convertToPixelArt(allocator, image, .{
        .min_pixel_size = 6,
        .max_pixel_size = 10,
        .min_image_size = cli_options.pixel_size,
        .num_colors = if (palette) |p| @intCast(p.colors.len) else 64,
        .palette = palette,
    });
    defer pixel_art.deinit();

    // Save the result
    try pixel_art.writeToFilePath(cli_options.output_path, .{ .png = .{} });

    std.debug.print("Pixel art image saved as '{s}'\n", .{cli_options.output_path});
}

fn parseCliArguments(allocator: std.mem.Allocator) !CliOptions {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip the program name
    _ = args.skip();

    var options = CliOptions{
        .input_path = try allocator.dupe(u8, "images/input.png"),
        .output_path = try allocator.dupe(u8, "images/output.png"),
        .pixel_size = 32,
        .help = false,
        .palette_name = null,
        .custom_palette_path = null,
    };

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            options.help = true;
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--input")) {
            if (args.next()) |input_path| {
                allocator.free(options.input_path);
                options.input_path = try allocator.dupe(u8, input_path);
            } else {
                return error.MissingInputPath;
            }
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            if (args.next()) |output_path| {
                allocator.free(options.output_path);
                options.output_path = try allocator.dupe(u8, output_path);
            } else {
                return error.MissingOutputPath;
            }
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--size")) {
            if (args.next()) |size_str| {
                options.pixel_size = try std.fmt.parseInt(u32, size_str, 10);
            } else {
                return error.MissingPixelSize;
            }
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--palette")) {
            if (args.next()) |palette_name| {
                if (options.palette_name) |name| allocator.free(name);
                options.palette_name = try allocator.dupe(u8, palette_name);
            } else {
                return error.MissingPaletteName;
            }
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--custom-palette")) {
            if (args.next()) |custom_palette_path| {
                options.custom_palette_path = try allocator.dupe(u8, custom_palette_path);
            } else {
                return error.MissingCustomPalettePath;
            }
        }
    }

    return options;
}

fn printUsage() void {
    const usage =
        \\Usage: pixel_art_converter [options]
        \\
        \\Options:
        \\  -h, --help              Show this help message
        \\  -i, --input <path>      Path to input image (default: images/input.png)
        \\  -o, --output <path>     Path to output image (default: images/output.png)
        \\  -s, --size <number>     Pixel grid size (min_image_size, default: 32)
        \\  -p, --palette <name>    Use a preset palette (e.g., "retro", "grayscale")
        \\  -c, --custom-palette <path>  Path to a custom palette file
        \\
    ;
    std.debug.print("{s}", .{usage});
}

fn convertToPixelArt(allocator: std.mem.Allocator, image: zigimg.Image, options: PixelArtOptions) !zigimg.Image {
    const width = @as(u32, @intCast(image.width));
    const height = @as(u32, @intCast(image.height));

    const min_dimension = @min(width, height);
    const pixel_size = @max(options.min_pixel_size, @min(options.max_pixel_size, min_dimension / options.min_image_size));

    const new_width = @max(options.min_image_size, width / pixel_size);
    const new_height = @max(options.min_image_size, height / pixel_size);

    // 1. Downscale the image
    var downscaled = try downscaleImage(allocator, image, new_width, new_height);
    defer downscaled.deinit();

    // 2. Apply color quantization or use provided palette
    std.debug.print("Applying color quantization or using provided palette\n", .{});
    const palette = if (options.palette) |p| p.colors else try createPalette(allocator, downscaled, options.num_colors);
    defer if (options.palette == null) allocator.free(palette);

    // 3. Apply dithering
    var dithered = try applyDithering(allocator, downscaled, palette);
    defer dithered.deinit();

    // 4. Upscale the image back to original size
    return upscaleImage(allocator, dithered, width, height);
}

fn getPixelRgba32(image: zigimg.Image, index: usize) zigimg.color.Rgba32 {
    return switch (image.pixels) {
        .rgba32 => |pixels| pixels[index],
        .rgb24 => |pixels| zigimg.color.Rgba32{
            .r = pixels[index].r,
            .g = pixels[index].g,
            .b = pixels[index].b,
            .a = 255,
        },
        else => zigimg.color.Rgba32{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
}

fn downscaleImage(allocator: std.mem.Allocator, image: zigimg.Image, new_width: u32, new_height: u32) !zigimg.Image {
    var downscaled = try zigimg.Image.create(allocator, new_width, new_height, .rgba32);
    errdefer downscaled.deinit();

    const x_ratio = @as(f32, @floatFromInt(image.width)) / @as(f32, @floatFromInt(new_width));
    const y_ratio = @as(f32, @floatFromInt(image.height)) / @as(f32, @floatFromInt(new_height));

    var y: u32 = 0;
    while (y < new_height) : (y += 1) {
        var x: u32 = 0;
        while (x < new_width) : (x += 1) {
            const src_x = @as(u32, @intFromFloat(x_ratio * @as(f32, @floatFromInt(x))));
            const src_y = @as(u32, @intFromFloat(y_ratio * @as(f32, @floatFromInt(y))));

            var r_sum: u32 = 0;
            var g_sum: u32 = 0;
            var b_sum: u32 = 0;
            var a_sum: u32 = 0;
            var weight_sum: f32 = 0;

            const kernel_size: u32 = 3;
            var ky: u32 = 0;
            while (ky < kernel_size) : (ky += 1) {
                var kx: u32 = 0;
                while (kx < kernel_size) : (kx += 1) {
                    const sample_x = @min(image.width - 1, src_x + kx);
                    const sample_y = @min(image.height - 1, src_y + ky);
                    const sample_index = sample_y * image.width + sample_x;
                    const sample = getPixelRgba32(image, sample_index);

                    const weight = 1.0 / @as(f32, @floatFromInt((kx + 1) * (ky + 1)));
                    r_sum += @as(u32, @intFromFloat(@as(f32, @floatFromInt(sample.r)) * weight));
                    g_sum += @as(u32, @intFromFloat(@as(f32, @floatFromInt(sample.g)) * weight));
                    b_sum += @as(u32, @intFromFloat(@as(f32, @floatFromInt(sample.b)) * weight));
                    a_sum += @as(u32, @intFromFloat(@as(f32, @floatFromInt(sample.a)) * weight));
                    weight_sum += weight;
                }
            }

            const dst_index = y * new_width + x;
            downscaled.pixels.rgba32[dst_index] = zigimg.color.Rgba32{
                .r = @intCast(@min(255, r_sum / @as(u32, @intFromFloat(weight_sum)))),
                .g = @intCast(@min(255, g_sum / @as(u32, @intFromFloat(weight_sum)))),
                .b = @intCast(@min(255, b_sum / @as(u32, @intFromFloat(weight_sum)))),
                .a = @intCast(@min(255, a_sum / @as(u32, @intFromFloat(weight_sum)))),
            };
        }
    }

    return downscaled;
}

fn upscaleImage(allocator: std.mem.Allocator, image: zigimg.Image, new_width: u32, new_height: u32) !zigimg.Image {
    var upscaled = try zigimg.Image.create(allocator, new_width, new_height, .rgba32);
    errdefer upscaled.deinit();

    const x_ratio = @as(f32, @floatFromInt(image.width)) / @as(f32, @floatFromInt(new_width));
    const y_ratio = @as(f32, @floatFromInt(image.height)) / @as(f32, @floatFromInt(new_height));

    var y: u32 = 0;
    while (y < new_height) : (y += 1) {
        var x: u32 = 0;
        while (x < new_width) : (x += 1) {
            const src_x = @as(u32, @intFromFloat(x_ratio * @as(f32, @floatFromInt(x))));
            const src_y = @as(u32, @intFromFloat(y_ratio * @as(f32, @floatFromInt(y))));
            const src_index = src_y * image.width + src_x;
            const dst_index = y * new_width + x;

            upscaled.pixels.rgba32[dst_index] = switch (image.pixels) {
                .rgba32 => |pixels| pixels[src_index],
                .rgb24 => |pixels| .{
                    .r = pixels[src_index].r,
                    .g = pixels[src_index].g,
                    .b = pixels[src_index].b,
                    .a = 255,
                },
                else => return error.UnsupportedPixelFormat,
            };
        }
    }

    return upscaled;
}

fn createPalette(allocator: std.mem.Allocator, image: zigimg.Image, num_colors: u32) ![]zigimg.color.Rgba32 {
    var quantizer = zigimg.OctTreeQuantizer.init(allocator);
    defer quantizer.deinit();

    const total_pixels = image.width * image.height;
    var y: u32 = 0;
    while (y < image.height) : (y += 1) {
        var x: u32 = 0;
        while (x < image.width) : (x += 1) {
            if (total_pixels <= 1_000_000 or (y % 4 == 0 and x % 4 == 0)) {
                const pixel = getPixelRgba32(image, y * image.width + x);
                try quantizer.addColor(pixel);
            }
        }
    }

    const temp_palette = try allocator.alloc(zigimg.color.Rgba32, num_colors);
    defer allocator.free(temp_palette);

    const actual_palette = quantizer.makePalette(num_colors, temp_palette);

    // Allocate only the space needed for the actual palette
    const final_palette = try allocator.alloc(zigimg.color.Rgba32, actual_palette.len);
    @memcpy(final_palette, actual_palette);

    return final_palette;
}

fn applyDithering(allocator: std.mem.Allocator, image: zigimg.Image, palette: []const zigimg.color.Rgba32) !zigimg.Image {
    var dithered = try zigimg.Image.create(allocator, image.width, image.height, .rgba32);
    errdefer dithered.deinit();

    var y: u32 = 0;
    while (y < image.height) : (y += 1) {
        var x: u32 = 0;
        while (x < image.width) : (x += 1) {
            const index = y * image.width + x;
            const old_pixel = image.pixels.rgba32[index];
            const new_pixel = findClosestColor(old_pixel, palette);
            dithered.pixels.rgba32[index] = new_pixel;

            const color_error = subtractColors(old_pixel, new_pixel);

            if (x + 1 < image.width) {
                dithered.pixels.rgba32[index + 1] = addWeightedError(image.pixels.rgba32[index + 1], color_error, 7.0 / 16.0);
            }
            if (y + 1 < image.height) {
                if (x > 0) {
                    dithered.pixels.rgba32[index + image.width - 1] = addWeightedError(image.pixels.rgba32[index + image.width - 1], color_error, 3.0 / 16.0);
                }
                dithered.pixels.rgba32[index + image.width] = addWeightedError(image.pixels.rgba32[index + image.width], color_error, 5.0 / 16.0);
                if (x + 1 < image.width) {
                    dithered.pixels.rgba32[index + image.width + 1] = addWeightedError(image.pixels.rgba32[index + image.width + 1], color_error, 1.0 / 16.0);
                }
            }
        }
    }

    return dithered;
}

fn subtractColors(c1: zigimg.color.Rgba32, c2: zigimg.color.Rgba32) zigimg.color.Rgba32 {
    return .{
        .r = @intCast(@max(0, @as(i16, c1.r) - @as(i16, c2.r))),
        .g = @intCast(@max(0, @as(i16, c1.g) - @as(i16, c2.g))),
        .b = @intCast(@max(0, @as(i16, c1.b) - @as(i16, c2.b))),
        .a = c1.a,
    };
}

fn findClosestColor(color: zigimg.color.Rgba32, palette: []const zigimg.color.Rgba32) zigimg.color.Rgba32 {
    var closest = palette[0];
    var min_distance: u32 = std.math.maxInt(u32);

    for (palette) |palette_color| {
        const distance = colorDistance(color, palette_color);
        if (distance < min_distance) {
            min_distance = distance;
            closest = palette_color;
        }
    }

    return closest;
}

fn colorDistance(c1: zigimg.color.Rgba32, c2: zigimg.color.Rgba32) u32 {
    const dr = @as(i32, c1.r) - @as(i32, c2.r);
    const dg = @as(i32, c1.g) - @as(i32, c2.g);
    const db = @as(i32, c1.b) - @as(i32, c2.b);
    return @as(u32, @intCast(dr * dr + dg * dg + db * db));
}

fn addWeightedError(color: zigimg.color.Rgba32, color_error: zigimg.color.Rgba32, weight: f32) zigimg.color.Rgba32 {
    return .{
        .r = @as(u8, @intCast(@min(255, @max(0, @as(i32, color.r) + @as(i32, @intFromFloat(@as(f32, @floatFromInt(color_error.r)) * weight)))))),
        .g = @as(u8, @intCast(@min(255, @max(0, @as(i32, color.g) + @as(i32, @intFromFloat(@as(f32, @floatFromInt(color_error.g)) * weight)))))),
        .b = @as(u8, @intCast(@min(255, @max(0, @as(i32, color.b) + @as(i32, @intFromFloat(@as(f32, @floatFromInt(color_error.b)) * weight)))))),
        .a = color.a,
    };
}

test "pixel art conversion with project image" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load the test image from the project's images folder
    const test_image_path = "images/test_image.png";
    var original_image = try zigimg.Image.fromFilePath(allocator, test_image_path);
    defer original_image.deinit();

    std.debug.print("Original image dimensions: {}x{}\n", .{ original_image.width, original_image.height });

    // Convert to pixel art
    const options = PixelArtOptions{
        .min_pixel_size = 4,
        .max_pixel_size = 8,
        .min_image_size = 64,
        .num_colors = 64,
    };
    var pixel_art = try convertToPixelArt(allocator, original_image, options);
    defer pixel_art.deinit();

    std.debug.print("Pixel art dimensions: {}x{}\n", .{ pixel_art.width, pixel_art.height });

    // Check dimensions
    try expect(pixel_art.width >= options.min_image_size);
    try expect(pixel_art.height >= options.min_image_size);

    // Check color palette
    var color_set = std.AutoHashMap(zigimg.color.Rgba32, void).init(allocator);
    defer color_set.deinit();

    for (pixel_art.pixels.rgba32) |pixel| {
        try color_set.put(pixel, {});
    }

    std.debug.print("Number of unique colors: {}\n", .{color_set.count()});
    try expect(color_set.count() <= options.num_colors);

    // Optionally, save the converted image for visual inspection
    try pixel_art.writeToFilePath("images/test_output.png", .{ .png = .{} });

    std.debug.print("Pixel art conversion test passed! Check images/test_output.png for the result.\n", .{});
}
