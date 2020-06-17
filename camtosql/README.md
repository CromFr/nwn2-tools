# Bioware Campaign database migration tool

Tool for migrating NWN2 campaign database files ([Visual
FoxPro](https://fr.wikipedia.org/wiki/Visual_FoxPro)) to a MySQL database

A complete migration can be performed with these two command-line tools:

- `nwn2-camtosql`: Migrates data from the campaign database to the MySQL
  database.
- `nwn2-camtosql-upgrade-scripts`: Generate a NWScript wrapper for querying
  the MySQL database and modify NSS scripts to use the wrapper instead of
  Get/SetCampaignXxx.

Command-line tools are meant to be executed with a terminal emulator. On
Windows you should use either _cmd_, _powershell_, _git bash_ or _msys2_. It
is also handy to write a script for the migration, like a `.bat` or a `.sh`
file that can be executed by double clicking it on Windows (make sure you have
git bash if you want to execute `.sh` files).

##### nwn2-camtosql
This tool will parse all player characters in the provided vault (with the
`--vault` argument) to generate a list of PC identifier in the same format as
stored in the campaign database (account name + character name, truncated to
32 character if longer, and tabbed with spaces if smaller). Then it will parse
all FoxPro databases provided as argument and, if the character matches a
known PC identifier (or if the identifier is empty), will issue SQL statements
to copy the data into MySQL.

Campaign data that does not match any known PC identifier (it often happens if
the player has deleted some characters) will not be migrated to MySQL. If the
`--reject-file` argument is provided, these variables will be stored in a JSON
format.

The tool does not modify the FoxPro campaign database files in any way.

##### nwn2-camtosql-upgrade-scripts
This tool generates the correct NWScript include file to replace Bioware's
campaign functions with similar functions sending the data to MySQL, and
changes your module scripts to use the new campaign functions (adds a
`#include` atop of the file and changes campaign function calls).

The following function are provided as replacements by adding `SQL` at the end
of the function name:
- `GetCampaignXxx` and `SetCampaignXxx` function for `string`, `float`, `int`,
  `vector`, `location`. The provided `SetCampaignLocationSQL` will store the
  area reference as a tag instead as an object ID, making it more reliable
  than `SetCampaignLocation` as long as the area tag is unique.
- `DeleteCampaignVariable`
- `StoreCampaignObject`, `RetrieveCampaignObject`
- `PackCampaignDatabase`, `DestroyCampaignDatabase`

### Migration workflow

If your module is versioned (using Git, SVN, Perforce, etc.), you may want to
run `nwn2-camtosql-upgrade-scripts` ahead of time on your development
machine, and commit/upload the changes. See step 4. for this.

1. Shut down NWN2 server
2. Make a backup of your MySQL database (`mysqldump -u root -p nwnx >
   backup.sql`).
3. Run the `nwn2-camtosql` tool to copy campaign data to MySQL. This can
   take some time, especially on hard drives. I personally downloaded the
   production data (MySQL, campaign databases and servervault) to my dev
   machine, did the migration on my dev machine and then imported back the
   migrated SQL data to the production server (it took ~15min on my machine,
   while it would probably have lasted 1h30 on the slow hard drives of the
   server).
4. If not already, run `nwn2-camtosql-upgrade-scripts` to upgrade your
   module scripts to use the migrated SQL data. The tool will not compile the
   modified scripts, so you must re-compile all module scripts once the tool
   has finished. You can do this while 3. is running.
5. Once both 3. and 4. are finished, you can restart the NWN2 server.

### Notes
- `GetCampaignXxxSQL` functions will raise a SQL error if the campaign SQL
  table does not exist. Their behavior however still follows `GetCampaignXxx`
  behavior by returning the default type value. The table is automatically
  created when `SetCampaignXxxSQL` is called.
- Don't forget to rebuild scripts after executing
  `nwn2-camtosql-upgrade-scripts`

# Usage

The `--help` flag prints out the documentation for these scripts:

```sh
./nwn2-camtosql --help
# Migrate Bioware Campaign database (foxpro) to a MySQL server
# 
# Usage: nwn2-camtosql [options] dbf_files
#  - options: See below
#  - dbf_files: list of DBF campaign files to migrate
# 
# Note: One SQL table will be created for each database file (i.e. for each 'sCampaignName'), unless --sql-table-name
#  tablename is provided.
# 
# Options with * are required
#  * -v            --vault  Vault containing all known player characters.
#  *                 --sql  MySQL connection string. If set to 'none', no SQL commands will be issued.
#                           Example: host=localhost;port=3306;user=yourname;pwd=pass123;db=nwnx
#       --sql-table-prefix  Prefix to add before the name of each created SQL table
#         --sql-table-name  Set this parameter to migrate every campaign database to a single SQL table with this name.
#                           Incompatible with --sql-table-prefix
#         --sql-constraint  SQL foreign key constraint definition for created tables.
#                           Can be specified multiple times to add several constraints
#                           Any occurence of '{{TABLE_NAME}}' will be replaced with the created table name.
#                           Example: 'KEY `fk_{{TABLE_NAME}}` (`account_name`, `character_name`), CONSTRAINT
#                           fk_{{TABLE_NAME}} FOREIGN KEY (`account_name`, `character_name`) REFERENCES
#                           `character`(`account_name`, `name`) ON DELETE CASCADE ON UPDATE CASCADE'
#        --sql-register-pc  SQL query for registering a player characterif it is not registered
#                           The following tokens will be replaced: {{ACCOUNT}}, {{CHARNAME}}
#            --reject-file  Path to a file that will contains the variables having an unknown player character ID that
#                           have been discarded. The file is in JSON format
#               --imscared  Extra info (like sql queries) and stop update on warnings
#    -h             --help  This help information.

./nwn2-camtosql-upgrade-scripts --help
# Change your module scripts so they use the MySQL database instead of the campaign database
# 
# Usage: nwn2-camtosql-upgrade-scripts [options] [dir|file]
# 
# 
#  -o           --output  Output directory for the script library and unittest files. If not provided, only the library
#                         will be written to stdout.
#         --library-name  Include script name. Defaults to '_cam_sql_db'
#     --sql-table-prefix  See camdb-migrate --help
#       --sql-table-name  See camdb-migrate --help
#       --sql-constraint  See camdb-migrate --help
#  -h             --help  This help information.
```


# Examples

## Migrate each campaign database to a SQL table

```bash
# Set bash to be case insensitive
shopt -s nocasematch

nwn2-camtosql \
    --vault "path_to_servervault" \
    --sql "host=localhost;user=nwnx;pwd=123;db=nwnx" \
    Documents/Neverwinter Nights 2/database/*.dbf

nwn2-camtosql-upgrade-scripts \
    Documents/Neverwinter Nights 2/modules/YourMod/*.nss
```

## Selectively merge multiple campaign databases into one SQL table

On my server I have a lot of PCTools campaign database files, which names are
in the format 'pctools--<Account>_<CharName>', and containing only a handful
of variables.

The preferred behavior for migration is to create one SQL table for each
campaign database file, however in this case it's preferable to merge all
PCTools campaign databases into one single SQL table.

```bash
# Set bash to be case insensitive
shopt -s nocasematch

# Migrate campaign databases to MySQL
# All PC-tools-related databases will be migrated to the SQL table cam_pctools
nwn2-camtosql \
    --vault "path_to_servervault" \
    --sql "host=localhost;user=nwnx;pwd=123;db=nwnx" \
    --sql-table-name cam_pctools \
    pctools--*.dbf

# Modify scripts to use one single table instead
# This will create a new library script '_cam_sql_db_pctools' for making query
# to this table
nwn2-camtosql-upgrade-scripts \
    --sql-table-name cam_pctools \
    --library-name _cam_sql_db_pctools \
    gui_hss_pc_tool.nss hss_pctools_pc_loaded.nss
```

## Bash script

[This script](migrate.sh) was used for migrating my own server database.


# Build

```sh
dub build -b release
dub build -b release :upgrade-scripts
```
