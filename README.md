# pixzel

Image to pixel art converter in Zig.

## Installation

### Prerequisites

Make sure you have Zig installed on your system. You can download it from the [official Zig website](https://ziglang.org/download/).

### Build from source

To build the project, run:

```bash
zig build -Drelease
```

This command builds an executable which can be found at `./zig-out/bin/pixzel`.

If you want to directly run the executable, use:

```bash
zig build run -Drelease -- [options]
```

See below for explanations of available options.

## Usage

Run the program with the following options:

```
./zig-out/bin/pixzel [options]
```

### Options:

- `-h, --help`: Print the help message and exit
- `-i, --input <file>`: Specify the input image file path (default: images/input.png)
- `-o, --output <file>`: Specify the output image file path (default: images/output.png)
- `-s, --size <number>`: Set the pixel grid size (min_image_size, default: 32)
- `-p, --palette <name>`: Use a preset palette (e.g., "muted", "retro", "grayscale")
- `-l, --list-palettes`: List all available palettes

### Examples:

Basic usage:
```bash
./zig-out/bin/pixzel -i input.png -o output.png
```

With custom pixel size:
```bash
./zig-out/bin/pixzel -i input.png -o output.png -s 64
```

With color palette:
```bash
./zig-out/bin/pixzel -i input.png -o output.png -s 64 -p muted
```

List available palettes:
```bash
./zig-out/bin/pixzel -l
```

### Notes:

1. The program will generate a pixel art version of your input image and save it as a new image file.
2. Input and output paths are relative to the current working directory, not the location of the executable.
3. The program currently supports PNG input and output files.
4. Color palettes are defined in an INI file. You can add your own palettes to this file.

## Custom Palettes

Palettes are defined in an INI file. Each section represents a palette, with the section name being the palette name. Colors are defined as comma-separated RGB values.

Example palette definition:

```ini
[muted]
243,233,201
160,82,45
107,55,90
75,87,123
140,162,173
208,183,149
181,101,118
239,195,164
117,137,78
190,190,190
82,80,100
214,133,79
178,181,128
147,112,152
55,48,61
240,240,240
```

To use a custom palette, add it to the INI file and use the `-p` option with the palette name.

## Development

### Running tests

To run the unit tests, use:

```bash
zig build test
```
