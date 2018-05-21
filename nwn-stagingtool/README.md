# Module staging tool

Generate and update `moduledownloaderresources.xml` and compressed client files
(ie `.lzma`), with content taken from a set of directories.

By default, it only `.hak` `.tlk` `.bmu` `.trx` files will be added to the
client files list (you can set `--extensions` for more file types).

This tool will __only__ scan folders provided as arguments. It will not by
default scan any folders like `Document/Neverwinter Nights 2/override` or
`Document/Neverwinter Nights 2/hak`. This allows much more precise control over
what will be downloaded by clients.

Colored output on non-windows systems, allowing to quickly see what files have
been added / removed since last use of the tool.

## Usage

```bash
nwn-stagingtool --help
# Scan resource directories to find .hak, .tlk, .bmu, .trx files and generate client files to output_folder
# nwn-stagingtool output_folder resource_folder1 [resource_folder2 ...]
# -o    --xml-out Path to moduledownloaderresources.xml. If existing, will read it to only generate modified client files. '-' to print to stdout.
# -f      --force Generate all client files even if they have not been modified
#    --extensions Set the default file extensions to add to the client files list. Default: [trx, hak, bmu, tlk]
# -v    --verbose Print all file operations
# -h       --help This help information.

nwn-stagingtool -o moduledownloaderresources.xml ClientFiles/ $NWN_DOCS/modules/YourMod $NWN_DOCS/hak $NWN_DOCS/tlk $NWN_DOCS/music
# Search for client files inside the module, hak, tlk and music directories, and place compressed files inside ClientFiles/
```



## Build

```bash
# Build LZMA tool
make

# Build staging tool
dub build -b release
```