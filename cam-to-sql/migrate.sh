#!/bin/bash
#
# Example bash script for migrating NWN2 campaign database and the related
# nwscript code to a MySQL database. This script was used for migrating my own
# server, and is provided here as an example. If you want to reuse this
# script, you'd need to adapt some parts.
#
#
# - The following database won't be migrated: nwnx, dmfidatabase, secu, qete,
#   a, dmfi_db_mngrtool, grabugetaverneduncan, chasse
# - Campaign DBs starting with "pctools--" will be merged into a single SQL
#   table named cam_pctools
# - Other campaign DBs will each have their own SQL Table, with the cam_
#   prefix
#
# On Windows, you can run this using git shell, msys2 or WSL.
#

set -euo pipefail
shopt -s nocasematch

SQL="host=localhost;user=root;pwd=password;db=nwnx"
VAULT="/c/Users/Crom/Documents/Neverwinter Nights 2/servervault"
CAMDB="/c/Users/Crom/Documents/Neverwinter Nights 2/database"
MODULE="/c/Users/Crom/Documents/Neverwinter Nights 2/modules/LcdaDev"

# There is an existing tables containing all characters info and their
# respective accounts. The created campaign SQL tables will be linked to these
# columns.
CONSTRAINT='KEY `fk_{{TABLE_NAME}}` (`account_name`, `character_name`), CONSTRAINT `fk_{{TABLE_NAME}}` FOREIGN KEY (`account_name`, `character_name`) REFERENCES `character`(`account_name`, `name`) ON DELETE CASCADE ON UPDATE CASCADE'

# Move databases elsewhere so they aren't migrated
mkdir -p "$CAMDB"/removed
shopt -s nullglob
mv "$CAMDB"/{nwnx,dmfidatabase,secu,qete,a,dmfi_db_mngrtool,grabugetaverneduncan,chasse}.* "$CAMDB"/removed || true
shopt -u nullglob

echo "========================================="

# Migrate PCTools databases
./nwn2-cam-to-sql \
    --vault "$VAULT" \
    --sql "$SQL" \
    --sql-table-name cam_pctools \
    --sql-constraint "$CONSTRAINT" \
    --sql-register-pc 'INSERT INTO `account` (`name`, `password`) VALUES({{ACCOUNT}}, -1) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)' \
    --sql-register-pc 'INSERT INTO `character` (`account_name`, `name`) VALUES({{ACCOUNT}}, {{CHARNAME}}) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)' \
    --reject-file reject-pctools.json \
    "$CAMDB"/pctools--*.dbf

echo "-----------------------------------------"
./nwn2-cam-to-sql-upgrade-scripts \
    --sql-table-name cam_pctools \
    --library-name _cam_sql_db_pctools \
    --sql-constraint "$CONSTRAINT" \
    "$MODULE"/{gui_hss_pc_tool,hss_pctools_pc_loaded}.nss \
    -o "$MODULE"

# Move PCTools databases away, so they aren't migrated twice with nwn2-cam-to-sql
mkdir -p "$CAMDB"/processed
mv "$CAMDB"/pctools--*.dbf "$CAMDB"/processed
trap 'mv "$CAMDB"/processed/* "$CAMDB" && rm -r "$CAMDB"/processed' EXIT

echo "========================================="

# Migrate the rest
./nwn2-cam-to-sql \
    --vault "$VAULT" \
    --sql "$SQL" \
    --sql-constraint "$CONSTRAINT" \
    --sql-register-pc 'INSERT INTO `account` (`name`, `password`) VALUES({{ACCOUNT}}, -1) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)' \
    --sql-register-pc 'INSERT INTO `character` (`account_name`, `name`) VALUES({{ACCOUNT}}, {{CHARNAME}}) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)' \
    --reject-file reject.json \
    "$CAMDB"/*.dbf

echo "-----------------------------------------"
./nwn2-cam-to-sql-upgrade-scripts \
    --sql-constraint "$CONSTRAINT" \
    "$MODULE" \
    -o "$MODULE"
