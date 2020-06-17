# Multi-platform/standalone tools for Neverwinter Nights 2

These tools should work the same on any OS. Please open an issue if you see
any inconsistency.

# Download

Latest version of the tools can be downloaded here:
https://github.com/CromFr/nwn2-tools/releases

# Tools

### [nwn2-stagingtool](stagingtool/)

Generate or update `moduledownloaderresources.xml` and quickly compress client
files (ie `.lzma`), with content taken from a set of directories.

View its [README.md](stagingtool/README.md) for more information

### [nwn2-moduleinstaller](moduleinstaller/)

Strip & install module files to appropriate directories very quickly (by
overwriting only modified files). Your module need to be versioned with git.

View its [README.md](moduleinstaller/README.md) for more information

### [nwn2-itemupdater](itemupdater/)

Update all instances of an item (or many) contained in character files and in
the MySQL database, to the current item blueprint version as configured in
your module. The tool is able to keep or override local variables.

View its [README.md](itemupdater/README.md) for more information

### [nwn2-camtosql](camtosql/)

Migrate the NWN2 campaign database to MySQL, and replace campaign NWScript
function usage in your scripts.

View its [README.md](camtosql/README.md) for more information