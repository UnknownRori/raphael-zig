# Raphael

<div align="center">
  <img src="./docs/mascot.png" align="center" />
</div>
<div align="center">
  <span>Art drawn by UnknownRori</span>
</div>


> [!WARNING]
> Don't expect much on this project.

Raphael is a search engine focused on local plain text file (Markdown file or .txt) it uses TF-IDF method to measure the importance of word on document in collection.

## Usage

```
USAGE: raphael_zig.exe [OPTIONS]
OPTIONS:
    -index <STRING>
         Index a directory

    -search <STRING>
         Search a term

    -serve
         Start a local server http://localhost:6969

    -help
         Show this help menu
```

## Development

Make sure you have `zig 0.14.1`

```sh
git clone https://github.com/UnknownRori/raphael-zig
cd raphael-zig

zig build run
```

## License

This project is in MIT license.
