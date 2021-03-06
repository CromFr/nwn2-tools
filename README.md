# Multi-platform/standalone tools for Neverwinter Nights 2

These tools are aimed toward server administrators, to help them perform and
automate various tasks related to their Neverwinter Nights 2 server.

They do not assume the existence of any game file or folder and do not require
the game to be installed. Any game-related file needed by the tool has to be
provided as command line arguments.

These tools can be executed on either Windows and Linux (just make sure you
download the correct version).

[See below](#tools) for the list of tools, and their documentation.

# Download

Latest version of the tools can be downloaded here:
https://github.com/CromFr/nwn2-tools/releases

# Tools

### [nwn2-stagingtool](stagingtool/)

Generate or update `moduledownloaderresources.xml` and quickly compress client
files (ie `.lzma`), with content taken from a set of directories.

Take a look at its [README.md](stagingtool/README.md) for more information

### [nwn2-moduleinstaller](moduleinstaller/)

Strip & install module files to appropriate directories very quickly (by
overwriting only modified files). Your module need to be versioned with git.

Take a look at its [README.md](moduleinstaller/README.md) for more information

### [nwn2-itemupdater](itemupdater/)

Update all instances of an item (or many) contained in character files and in
the MySQL database, to the current item blueprint version as configured in
your module. The tool is able to keep or override local variables.

Take a look at its [README.md](itemupdater/README.md) for more information

### [nwn2-camtosql](camtosql/)

Migrate the NWN2 campaign database to MySQL, and replace campaign NWScript
function usage in your scripts.

Take a look at its [README.md](camtosql/README.md) for more information


### [nwn2-adjust-item-prices](adjust-item-prices/)

Set the items additional cost values in order to require a specific level.

Take a look at its [README.md](adjust-item-prices/README.md) for more information


### [nwn2-update-module-arealist](update-module-arealist/)

Updates the module area list stored inside the module.ifo file.

Take a look at its [README.md](adjust-item-prices/README.md) for more information