#!/bin/bash

set -euo pipefail
shopt -s nocasematch

SQL="host=localhost;user=root;pwd=123;db=nwnx"
VAULT="/c/Users/Crom/Documents/Neverwinter Nights 2/servervault"
CAMDB="/c/Users/Crom/Documents/Neverwinter Nights 2/database.bak"
# MODULE="/c/Users/Crom/Documents/Neverwinter Nights 2/modules/LcdaDev"
CONSTRAINT='KEY `fk_{{TABLE_NAME}}` (`account_name`, `character_name`), CONSTRAINT `fk_{{TABLE_NAME}}` FOREIGN KEY (`account_name`, `character_name`) REFERENCES `character`(`account_name`, `name`) ON DELETE CASCADE ON UPDATE CASCADE'

# Remove old unused databases
mkdir -p "$CAMDB"/removed

shopt -s nullglob
mv "$CAMDB"/{nwnx,dmfidatabase,secu,qete,a,dmfi_db_mngrtool,grabugetaverneduncan,chasse}.* "$CAMDB"/removed || true
shopt -u nullglob

echo "========================================="

# Migrate PCTools
./nwn2-camtosql.exe \
    --vault "$VAULT" \
    --sql "$SQL" \
    --sql-table-name cam_pctools \
    --sql-constraint "$CONSTRAINT" \
    --sql-register-pc 'INSERT INTO `account` (`name`, `password`) VALUES({{ACCOUNT}}, -1) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)' \
    --sql-register-pc 'INSERT INTO `character` (`account_name`, `name`) VALUES({{ACCOUNT}}, {{CHARNAME}}) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)' \
    --reject-file reject-pctools.json \
    "$CAMDB"/pctools--*.dbf

# echo "-----------------------------------------"
# ./nwn2-camtosql-upgrade-scripts \
#     --sql-table-name cam_pctools \
#     --library-name _cam_sql_db_pctools \
#     --sql-constraint "$CONSTRAINT" \
#     "$MODULE"/{gui_hss_pc_tool,hss_pctools_pc_loaded}.nss \
#     -o "$MODULE"

# Move PCTools databases away
mkdir -p "$CAMDB"/processed
mv "$CAMDB"/pctools--*.dbf "$CAMDB"/processed
trap 'mv "$CAMDB"/processed/* "$CAMDB" && rm -r "$CAMDB"/processed' EXIT

echo "========================================="

# Migrate the rest
./nwn2-camtosql.exe \
    --vault "$VAULT" \
    --sql "$SQL" \
    --sql-constraint "$CONSTRAINT" \
    --reject-file reject.json \
    "$CAMDB"/*.dbf

# echo "-----------------------------------------"
# ./nwn2-camtosql-upgrade-scripts \
#     --sql-constraint "$CONSTRAINT" \
#     "$MODULE" \
#     -o "$MODULE"
