

all: dub

dub:
	dub build
	dub build :upgrade-scripts


migrate:
	dub build
	./nwn2-camtosql.exe --help


multi-db: dub
	./nwn2-camtosql-upgrade-scripts.exe "C:/Users/Crom/Documents/Neverwinter Nights 2/modules/LcdaDev" -o "C:/Users/Crom/Documents/Neverwinter Nights 2/modules/LcdaDev"

single-db: dub
	./nwn2-camtosql-upgrade-scripts.exe \
		"C:/Users/Crom/Documents/Neverwinter Nights 2/modules/LcdaDev" \
		-o "C:/Users/Crom/Documents/Neverwinter Nights 2/modules/LcdaDev" \
		--sql-table-name "cam_to_sql" \
		--sql-constraint  'CONSTRAINT `fk_character` FOREIGN KEY (`account_name`, `character_name`) REFERENCES `character` (`account_name`, `name`) ON DELETE CASCADE ON UPDATE CASCADE'


single-db-migrate: dub
	./nwn2-camtosql.exe \
		--vault "C:/Users/Crom/Documents/Neverwinter Nights 2/servervault/" \
		--sql none \
		--sql-table-name "cam_to_sql" \
		--sql-constraint  'CONSTRAINT `fk_character` FOREIGN KEY (`account_name`, `character_name`) REFERENCES `character` (`account_name`, `name`) ON DELETE CASCADE ON UPDATE CASCADE'