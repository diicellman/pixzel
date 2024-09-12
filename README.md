# pixzel
image to pixel art convertor in zig.

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
- `-i, --input <file>`: Specify the input image file path (required)
- `-o, --output <file>`: Specify the output image file path (required)
- `-s, --size <number>`: Set the pixel grid size (min_image_size, default: 32)

### Examples:

Basic usage:
```bash
./zig-out/bin/pixzel -i input.png -o output.png
```

With custom pixel size:
```bash
./zig-out/bin/pixzel -i input.png -o output.png -s 64
```

### Notes:

1. The program will generate a pixel art version of your input image and save it as a new image file.
2. Input and output paths are relative to the current working directory, not the location of the executable.
3. The program currently supports PNG input and output files.

## Development

### Running tests

To run the unit tests, use:

```bash
zig build test
```