# Module staging tool

Generate and update `moduledownloaderresources.xml` and compressed client files
(ie `.lzma`), with content taken from a set of directories.

By default, it only `.hak` `.tlk` `.bmu` `.trx` files will be added to the
client files list (you can set `--extensions` for more file types).

This tool will __only__ scan folders provided as arguments. It will not by
default scan any folders like `Document/Neverwinter Nights 2/override` or
`Document/Neverwinter Nights 2/hak`. This allows much more precise control over
what will be downloaded by clients.

Reading all files and calculating hashes can take a long time. `--since` and
`--incremental` can make this process much faster by skipping files which
modification date is too old.

Colored output on non-windows systems, allowing to quickly see what files have
been added / removed since last use of the tool.

## Usage

```bash
Scan resource directories to find .hak, .tlk, .bmu, .trx files and generate client files to output_folder
./nwn2-stagingtool output_folder resource_folder1 [resource_folder2 ...]
-o     --xml-out Path to moduledownloaderresources.xml. If existing, will read it to only generate modified client files. '-' to print to stdout.
-f       --force Generate all client files even if they have not been modified
    --extensions Set the default file extensions to add to the client files list. Default: [trx, hak, bmu, tlk]
         --since Only check files modified after a given date. Other files will still be listed, but no modification will be detected. Files will still be processed if the LZMA files does not exist. Date must be in YYYY-MM-DDTHH:MM:SS format (ISO ext) or a UNIX timestamp
-i --incremental Store last execution date in moduledownloaderresources.xml, and pass the value to --since. Mutually exclusive with --since.
-j               Number of concurrent threads to use for compressing files
-v     --verbose Print all file operations
-h        --help This help information.

nwn2-stagingtool -o moduledownloaderresources.xml ClientFiles/ $NWN_DOCS/modules/YourMod $NWN_DOCS/hak $NWN_DOCS/tlk $NWN_DOCS/music
# Search for client files inside the module, hak, tlk and music directories, and place compressed files inside ClientFiles/
```



## Build

```bash
# Build LZMA tool
make

# Build staging tool
dub build -b release
```
