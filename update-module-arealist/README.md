# Item price adjuster

Updates the module area list stored inside the module.ifo file. Useful if you
want add or delete areas and don't want to open the module in the toolset to
update the area list.

## Usage

On Windows, you can drag and drop the module.ifo file on the executable, or use the command line.

```bash
./nwn2-update-module-arealist --help
# Usage: nwn2-update-module-arealist [options] module.ifo
# 
# Update the module area list stored inside the module.ifo file
# 
# Options:
#   --areas-dir=PATH  Directory where the areas are located. Defaults to the same directory where the module.ifo file is

# Example:
./nwn2-update-module-arealist modules/YourMod/module.ifo
```


## Build

```bash
dub build -b release
```