# Vault / MySQL item updater

This tools can update items possessed by players or stored in a MySQL-compatible database.

- The items are either matched by their resref (`--update`) or their tags (`--update-tag`). I recommend using resref when possible.
- Item local variables are kept across updates by default. See `policy` for overwriting variables.
- Item `Plot` and `Cursed` flags are overwritten by default. See `policy` for keeping flags.
- __Nothing is effective until you confirm__ applying changes at the end of the execution, and __automatically creates backups__ to prevent any mistake:
    + Current characters (that will be modified) are backed up inside `$TEMP_DIR/backup_vault/$account_name/`
    + Current SQL stored items (that will be modified) are backed up inside `$TEMP_DIR/updated_vault/$account_name/`
    + Updated characters are stored inside `$TEMP_DIR/sql/$table.$column/$primary_key.item.gff`
- The players need to be disconnected for servervault updates, otherwise the updated BIC file will be overwritten by the server's version.
- Unequip updated items to prevent forbidden character due to too powerful equipped items. Writes a warning if the inventory is full and item can't be unequipped.


# Usage

```sh
nwn2-itemupdater --help
# Update items in bic files & sql db
# 
# Tokens:
# - identifier: String used to detect is the item needs to be updated. Can be a resref or a tag (see below)
# - blueprint: Path of an UTI file, or resource name in LcdaDev
# - policy: associative array of properties to keep/override
#     Ex: ("Cursed":Keep, "Var.bIntelligent":Override)
# 
# Options with * are required
#  * -m     --module  Module directory, containing all blueprints
#    -v      --vault  Vault containing all character bic files to update.
#              --sql  MySQL connection string (ie:
#                     host=localhost;port=3306;user=yourname;pwd=pass123;db=mysqln_testdb)
#        --sql-table  MySQL tables and columns to update. Can be provided multiple
#                     times. ex: 'player_chest.item_data'
#             --temp  Temp folder for storing modified files installing them, and
#                     also backup files.
#                     Default: ./itemupdater_tmp
#           --update  Update an item using its TemplateResRef property as
#                     identifier.
#                     The format is: identifier=blueprint(policy)
#                     identifier & policy are optional
#                     Can be specified multiple times, separated by the character
#                     '+'
#                     Ex: --update myresref=myblueprint
#                     --update myblueprint("Cursed":Keep)
#       --update-tag  Similar to --update, but using the Tag property as
#                     identifier.
#          --dry-run  Do not write any file
#    -y        --yes  Do not prompt and accept everything
#    -j          --j  Number of parallel jobs
#                     Default: 1
#         --imscared  Extra info (like sql queries) and stop update on warnings
#    -h       --help  This help information.

# Example
nwn2-itemupdater \
    --vault path_to_servervault/ --module path_to_your_module_folder/ \
    --sql "host=localhost;port=3306;user=nwnx;pwd=123;db=nwnx" --sql-tables "player_chest.item_data" \
    --update 'new_blueprint+exrtaodrinary_itme=extraordinary_item+new_cursed_item("Cursed":Keep)'
# Update items contained in the servervault and the item_data column of 
#   player_chest SQL table.
#
# Items with resref=new_blueprint will be updated to latest module version of
#   new_blueprint.uti.
# Items with resref=exrtaodrinary_itme will be updated to latest module version
#   of extraordinary_item.uti. The resref will be set to match 
#   extraordinary_item.uti resref
# Items with resref=new_cursed_item will be updated to latest module version of
#   new_cursed_item.uti, but the Cursed flag will be kept (useful if players can
#   un-curse the item).
```


# Build

```sh
dub build -b release
```
