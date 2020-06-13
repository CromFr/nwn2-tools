import std.stdio;
import std.getopt;
	alias required = std.getopt.config.required;
import std.string;
import std.stdint;
import std.conv;
import std.path;
import std.typecons;
import std.variant;
import std.file;
	alias write = std.stdio.write;
	alias writeFile = std.file.write;
import std.exception: assertThrown, assertNotThrown, enforce;
import std.algorithm;
import std.datetime.stopwatch: StopWatch;
import std.parallelism;
import core.thread;
import mysql;
import nwn.gff;
import nwn.twoda;



enum UpdatePolicy{
	Override = 0,
	Keep = 1,
}
alias ItemPolicy = UpdatePolicy[string];

int main(string[] args){
	string vaultPath;
	string modulePath;
	string tempPath = "itemupdater_tmp";
	bool alwaysAccept = false;
	uint parallelJobs = 1;
	bool skipVault = false;
	bool skipSql = false;
	bool dryRun = false;
	bool imscared = false;
	string sqlConnectStr;
	string[] sqlTables;

	alias BlueprintUpdateDef = Tuple!(string,"from", string,"blueprint", UpdatePolicy[string],"policy");
	BlueprintUpdateDef[] resrefupdateDef;
	BlueprintUpdateDef[] tagupdateDef;


	//Parse cmd line
	try{
		void parseUpdateArg(string param, string arg){
			import std.regex: ctRegex, matchFirst;
			enum rgx = ctRegex!`^(?:(.+)=)?(.+?)(?:\(([^\(]*)\))?$`;

			foreach(ref s ; arg.split("+")){
				auto cap = s.matchFirst(rgx);
				enforce(!cap.empty, "Wrong --update format for: '"~s~"'");

				string from = cap[1];
				string blueprint = cap[2];
				auto policy = ("["~cap[3]~"]").to!(ItemPolicy);

				if(param=="update"){
					resrefupdateDef ~= BlueprintUpdateDef(from, blueprint, policy);
				}
				else if(param=="update-tag"){
					tagupdateDef ~= BlueprintUpdateDef(from, blueprint, policy);
				}
				else assert(0);
			}
		}

		enum prgHelp =
			 "Update items in bic files & sql db\n"
			~"\n"
			~"Tokens:\n"
			~"- identifier: String used to detect is the item needs to be updated. Can be a resref or a tag (see below)\n"
			~"- blueprint: Path of an UTI file, or resource name in LcdaDev\n"
			~"- policy: associative array of properties to keep/override\n"
			~"    Ex: (\"Cursed\":Keep, \"Var.bIntelligent\":Override)";
		enum updateHelp =
			 "Update an item using its TemplateResRef property as identifier.\n"
			~"The format is: identifier=blueprint(policy)\n"
			~"identifier & policy are optional\n"
			~"Can be specified multiple times, separated by the character '+'\n"
			~"Ex: --update myresref=myblueprint\n"
			~"    --update myblueprint(\"Cursed\":Keep)";

		auto res = getopt(args,
			required,"module|m", "Module directory, containing all blueprints", &modulePath,
			"vault|v", "Vault containing all character bic files to update.", &vaultPath,
			"sql", "MySQL connection string (ie: host=localhost;port=3306;user=yourname;pwd=pass123;db=mysqln_testdb)", &sqlConnectStr,
			"sql-table", "MySQL tables and columns to update. Can be provided multiple times. ex: 'player_chest.item_data'", &sqlTables,
			"temp", "Temp folder for storing modified files installing them, and also backup files.\nDefault: ./itemupdater_tmp", &tempPath,
			"update", updateHelp, &parseUpdateArg,
			"update-tag", "Similar to --update, but using the Tag property as identifier.", &parseUpdateArg,
			"dry-run", "Do not write any file", &dryRun,
			"yes|y", "Do not prompt and accept everything", &alwaysAccept,
			"j|j", "Number of parallel jobs\nDefault: 1", &parallelJobs,
			"imscared", "Extra info (like sql queries) and stop update on warnings", &imscared,
			);

		if(res.helpWanted){
			improvedGetoptPrinter(
				prgHelp,
				res.options);
			return 0;
		}

		enforce(parallelJobs>0, "-j option must be >= 1");
	}
	catch(Exception e){
		stderr.writeln(e.msg);
		stderr.writeln("Use --help for more information");
		return 1;
	}

	//paths
	immutable vault = vaultPath;
	enforce(vault is null || (vault.exists && vault.isDir), "Vault is not a directory/does not exist");
	immutable temp = tempPath;


	enforce(vaultPath !is null || sqlTables !is null, "Nothing to do. Please provide --vault or --sql-table");

	MySQLPool connPool;
	string[2][] sqlTargets;
	if(sqlTables !is null){
		enforce(sqlConnectStr !is null, "Cannot connect to SQL. Please provide --sql");

		foreach(tablecol ; sqlTables){
			const tablecolSplit = tablecol.split(".");
			enforce(tablecolSplit.length == 2, "--sql-table must be in the format table_name.column_name");

			sqlTargets ~= tablecolSplit[0..2];
		}

		connPool = new MySQLPool(sqlConnectStr);
		connPool.lockConnection();
	}


	alias UpdateTarget = Tuple!(Gff,"gff", ItemPolicy,"policy");
	UpdateTarget[string] updateResref;
	UpdateTarget[string] updateTag;

	foreach(ref bpu ; resrefupdateDef){
		auto bpPath = bpu.blueprint.extension is null?
			buildPathCI(modulePath, bpu.blueprint~".uti") : bpu.blueprint;
		auto gff = new Gff(bpPath);

		if(bpu.from !is null && bpu.from.length>0){
			enforce(bpu.from !in updateResref,
				"Template resref '"~bpu.from~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateResref[bpu.from] = UpdateTarget(gff, bpu.policy);
		}
		else{
			immutable tplResref = gff["TemplateResRef"].as!(GffType.ResRef);
			enforce(tplResref !in updateResref,
				"Template resref '"~tplResref~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateResref[tplResref] = UpdateTarget(gff, bpu.policy);
		}
	}
	foreach(ref bpu ; tagupdateDef){
		auto bpPath = bpu.blueprint.extension is null?
			buildPathCI(modulePath, bpu.blueprint~".uti") : bpu.blueprint;
		auto gff = new Gff(bpPath);

		if(bpu.from !is null && bpu.from.length>0){
			enforce(bpu.from !in updateTag,
				"Tag '"~bpu.from~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateTag[bpu.from] = UpdateTarget(gff, bpu.policy);
		}
		else{
			immutable tag = gff["Tag"].as!(GffType.ResRef);
			enforce(tag !in updateTag,
				"Tag '"~tag~"' already registered. Cannot add blueprint '"~bpu.blueprint~"'");
			updateTag[tag] = UpdateTarget(gff, bpu.policy);
		}
	}

	enforce(updateResref.length>0 || updateTag.length>0,
		"Nothing to update. Use --update or --update-tag");


	StopWatch bench;
	auto taskPool = new TaskPool(parallelJobs-1);
	scope(exit) taskPool.finish;




	if(dryRun == false){
		if(temp.exists){
			if(alwaysAccept == false && !temp.dirEntries(SpanMode.shallow).empty){
				stderr.writeln("\x1b[1;31mWARNING: '", temp, "' is not empty and may contain backups from previous item updates\x1b[m");
				writeln();
				write("'d' to delete content and continue: ");
				stdout.flush();
				if(readln()[0] != 'd')
					return 1;
			}
			temp.rmdirRecurse;
			writeln("Deleted '",temp,"'");
		}
		temp.mkdirRecurse;
	}


	//Servervault update
	if(vaultPath !is null){
		writeln();
		writeln("".center(80, '='));
		writeln("  Servervault update  ".center(80, '|'));
		writeln(("  "~vaultPath~"  ").center(80, '|'));
		writeln("".center(80, '='));
		writeln();
		stdout.flush();

		bench.start;
		foreach(charFile ; taskPool.parallel(vault.dirEntries("*.bic", SpanMode.depth))){
			immutable charPathRelative = charFile.relativePath(vault);

			bool charUpdated = false;
			int[string] updatedItemStats;

			void updateSingleItem(string UpdateMethod)(ref GffNode item, in UpdateTarget target){
				static if(UpdateMethod=="tag")
					auto identifier = item["Tag"].to!string;
				else static if(UpdateMethod=="resref")
					auto identifier = item["TemplateResRef"].to!string;
				else static assert(0);


				if(auto cnt = identifier in updatedItemStats)
					(*cnt)++;
				else
					updatedItemStats[identifier] = 1;

				charUpdated = true;
				item = item.updateItem(target.gff, target.policy);
			}

			void updateInventory(ref GffNode container){
				assert("ItemList" in container.as!(GffType.Struct));

				foreach(ref item ; container["ItemList"].as!(GffType.List)){
					if(auto target = item["TemplateResRef"].to!string in updateResref){
						updateSingleItem!"resref"(item, *target);
					}
					else if(auto target = item["Tag"].to!string in updateTag){
						updateSingleItem!"tag"(item, *target);
					}

					if("ItemList" in item.as!(GffType.Struct)){
						updateInventory(item);
					}
				}

				if("Equip_ItemList" in container.as!(GffType.Struct)){
					bool[size_t] itemsToRemove;
					foreach(ref item ; container["Equip_ItemList"].as!(GffType.List)){

						bool u = false;
						if(auto target = item["TemplateResRef"].to!string in updateResref){
							updateSingleItem!"resref"(item, *target);
							u=true;
						}
						else if(auto target = item["Tag"].to!string in updateTag){
							updateSingleItem!"tag"(item, *target);
							u=true;
						}

						if(u){
							if(container["ItemList"].as!(GffType.List).length < 128){
								itemsToRemove[item.structType] = true;
								container["ItemList"].as!(GffType.List) ~= item.dup;
							}
							else{
								stderr.writeln(
									"\x1b[1;31mWARNING: ",charPathRelative," has '",item["Tag"].to!string,"' equipped and no room in inventory to unequip it.",
									" The character may be refused on login for having an item too powerful for his level.\x1b[m");
								if(imscared) pressEnter();
							}
						}
					}

					foreach_reverse(i, ref item ; container["Equip_ItemList"].as!(GffType.List)){
						if(item.structType in itemsToRemove){
							immutable l = container["Equip_ItemList"].as!(GffType.List).length;
							container["Equip_ItemList"].as!(GffType.List) =
								container["Equip_ItemList"].as!(GffType.List)[0..i]
								~ (i+1<l? container["Equip_ItemList"].as!(GffType.List)[i+1..$] : null);
						}
					}
				}
			}

			auto character = new Gff(cast(ubyte[])charFile.read);
			updateInventory(character);

			if(charUpdated){
				//copy backup
				auto backupFile = buildPath(temp, "backup_vault", charPathRelative);
				if(!buildNormalizedPath(backupFile, "..").exists)
					buildNormalizedPath(backupFile, "..").mkdirRecurse;
				charFile.copy(backupFile);

				//serialize current
				auto serializedChar = character.serialize;
				if(dryRun == false){
					auto tmpFile = buildPath(temp, "updated_vault", charPathRelative);
					if(!buildNormalizedPath(tmpFile, "..").exists)
						buildNormalizedPath(tmpFile, "..").mkdirRecurse;
					tmpFile.writeFile(serializedChar);
				}

				//message
				write(charPathRelative.leftJustify(35));
				foreach(k,v ; updatedItemStats)
					write(" ",k,"(x",v,")");

				writeln();
				stdout.flush();
			}

		}
		bench.stop;
		writeln(">>> ", bench.peek.total!"msecs"/1000.0, " seconds");
	}


	//SQL db update
	if(connPool !is null){


		connPool.lockConnection().exec("SET autocommit=0");

		foreach(target ; sqlTargets){
			writeln();
			writeln("".center(80, '='));
			writeln("  MySQL update  ".center(80, '|'));
			writeln(("  table: "~target[0]~" column: "~target[1]~"  ").center(80, '|'));
			writeln("".center(80, '='));
			writeln();
			stdout.flush();

			immutable backup = buildPath(temp, "sql", target[0]~"."~target[1]);
			backup.mkdirRecurse;


			bench.reset;
			bench.start;

			auto conn = connPool.lockConnection();

			string[] primaryKeys;
			{
				auto res = conn.query("SHOW KEYS FROM `"~target[0]~"` WHERE Key_name = 'PRIMARY'");
				immutable colIndex = res.colNameIndicies["Column_name"];
				foreach(row ; res)
					primaryKeys ~= "`" ~ row[colIndex].get!string ~ "`";
			}


			immutable selectQuery = "SELECT `"~target[1]~"`, "~primaryKeys.join(", ")~" FROM `"~target[0]~"`";
			immutable updateQuery = "UPDATE `"~target[0]~"` SET `"~target[1]~"`=? WHERE "~primaryKeys.map!(a => a~"=?").join(" AND ");

			if(imscared){
				writeln("SQL selection query: ", selectQuery);
				writeln("SQL update query: ", updateQuery);
				pressEnter();
			}

			foreach(ref row ; conn.query(selectQuery)){
				auto itemData = row[0].get!(ubyte[]);
				Variant[] keys;
				foreach(i, _ ; primaryKeys)
					keys ~= row[i + 1];

				auto item = new Gff(itemData);

				auto targetUpdate = item["TemplateResRef"].to!string in updateResref;
				if(!targetUpdate) targetUpdate = item["Tag"].to!string in updateTag;

				if(targetUpdate){
					item.root = item.root.updateItem(targetUpdate.gff, targetUpdate.policy);
					ubyte[] updatedData = item.serialize();

					if(itemData == updatedData){
						writeln("\x1b[1;31mWARNING: Item "~target[0]~"["~keys.map!(to!string).join(",")~"]: resref=", targetUpdate.gff["TemplateResRef"].to!string, " did not change after update\x1b[m");
						if(imscared){
							writeln("This is happen because the item is already at the latest version found in the module folder");
							pressEnter();
						}
					}
					else if(dryRun == false){
						// Write backup file
						buildPath(backup, keys.map!(to!string).join(".")~".item.gff").writeFile(itemData);

						// Update SQL
						Variant[] updateArgs;
						updateArgs ~= Variant(updatedData);
						foreach(i, key ; keys)
							updateArgs ~= Variant(updatedData);

						auto affectedRows = connPool.lockConnection().exec(updateQuery, updateArgs);

						enforce(affectedRows==1, "Wrong number of rows affected by SQL query: "~affectedRows.to!string~" rows affected for item "~target[0]~"["~keys.map!(to!string).join(",")~"]");
					}

					writeln(target[0]~"[",keys.map!(to!string).join(","),"] ",item["Tag"].to!string);
					stdout.flush();
				}
			}

			bench.stop;

			writeln(">>> ", bench.peek.total!"msecs"/1000.0, " seconds");
		}
	}


	writeln();
	writeln("".center(80, '='));
	writeln("  APPLY CHANGES ?  ".center(80, '|'));
	writeln("".center(80, '='));
	writeln("All items have been updated");
	writeln("- new character files have been put in ", buildPath(temp, "updated_vault"));
	writeln("- new items in database are pending for SQL commit");
	writeln();


	char ans;
	if(alwaysAccept==false){
		do{
			write("'y' to apply changes, 'n' to leave them in temp dir: ");
			stdout.flush();
			ans = readln()[0];
		} while(ans!='y' && ans !='n');
	}
	else
		ans = 'y';

	if(ans=='y' && dryRun == false){
		//Copy char to new vault
		size_t count;
		void copyRecurse(string from, string to){
			if(isDir(from)){
				if(!to.exists){
					mkdir(to);
				}

				if(to.isDir){
					foreach(child ; from.dirEntries(SpanMode.shallow))
						copyRecurse(child.name, buildPathCI(to, child.baseName));
				}
				else
					throw new Exception("Cannot copy '"~from~"': '"~to~"' already exists and is not a directory");
			}
			else{
				//writeln("> ",to); stdout.flush();
				copy(from, to);
				count++;
			}
		}


		if(vaultPath !is null){
			copyRecurse(buildPath(temp, "updated_vault"), vault);
			writeln(count," files copied");
			stdout.flush();
		}

		//SQL commit
		if(connPool !is null){
			connPool.lockConnection().exec("COMMIT");
			writeln("SQL work commited");
			stdout.flush();
		}

		writeln("  DONE !  ".center(80, '_'));

		return 0;
	}


	//SQL rollback
	if(connPool !is null && dryRun == false)
		connPool.lockConnection().exec("ROLLBACK");


	return 0;
}


///
GffNode updateItem(in GffNode oldItem, in GffNode blueprint, in ItemPolicy itemPolicy){

	GffNode updatedItem = blueprint.dup;
	updatedItem.structType = 0;

	//Remove blueprint props
	updatedItem.as!(GffType.Struct).remove("Comment");
	updatedItem.as!(GffType.Struct).remove("Classification");
	updatedItem.as!(GffType.Struct).remove("ItemCastsShadow");
	updatedItem.as!(GffType.Struct).remove("ItemRcvShadow");
	updatedItem.as!(GffType.Struct).remove("UVScroll");

	void copyPropertyIfPresent(in GffNode oldItem, ref GffNode updatedItem, string property){
		if(auto node = property in oldItem.as!(GffType.Struct))
			updatedItem.appendField(node.dup);
	}

	//Add instance & inventory props

	copyPropertyIfPresent(oldItem, updatedItem, "ObjectId");
	copyPropertyIfPresent(oldItem, updatedItem, "Repos_Index");
	copyPropertyIfPresent(oldItem, updatedItem, "ActionList");
	copyPropertyIfPresent(oldItem, updatedItem, "DisplayName");//TODO: see if value is copied from name
	copyPropertyIfPresent(oldItem, updatedItem, "EffectList");
	if("LastName" in oldItem.as!(GffType.Struct)){
		if("LastName" !in updatedItem.as!(GffType.Struct))
			updatedItem.appendField(GffNode(GffType.ExoLocString, "LastName", GffExoLocString(0, [0:""])));
	}
	copyPropertyIfPresent(oldItem, updatedItem, "XOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "XPosition");
	copyPropertyIfPresent(oldItem, updatedItem, "YOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "YPosition");
	copyPropertyIfPresent(oldItem, updatedItem, "ZOrientation");
	copyPropertyIfPresent(oldItem, updatedItem, "ZPosition");

	//Set instance properties that must persist through updates
	//updatedItem["Dropable"] = oldItem["Dropable"].dup;
	updatedItem["StackSize"] = oldItem["StackSize"].dup;
	if("ItemList" in oldItem.as!(GffType.Struct)){
		enforce(blueprint["BaseItem"].to!int == 66,
			"Updating an container (bag) by removing its container ability would remove all its content"
			~" ("~oldItem["Tag"].to!string~" => "~blueprint["TemplateResRef"].to!string~")");
		//The item is a container (bag)
		updatedItem["ItemList"] = oldItem["ItemList"].dup;
	}
	updatedItem.structType = oldItem.structType;

	//Fix nwn2 oddities
	updatedItem["ArmorRulesType"] = GffNode(GffType.Int, "ArmorRulesType", blueprint["ArmorRulesType"].as!(GffType.Byte));
	updatedItem["Cost"].as!(GffType.DWord) = 0;
	foreach(ref prop ; updatedItem["PropertiesList"].as!(GffType.List)){
		prop.as!(GffType.Struct).remove("Param2");
		prop.as!(GffType.Struct).remove("Param2Value");
		prop["UsesPerDay"] = GffNode(GffType.Byte, "UsesPerDay", 255);
		prop["Useable"] = GffNode(GffType.Byte, "Useable", 1);
	}


	//Copy local variables
	size_t[string] varsInUpdatedItem;
	foreach(i, ref var ; updatedItem["VarTable"].as!(GffType.List))
		varsInUpdatedItem[var["Name"].as!(GffType.ExoString)] = i;

	foreach(ref oldItemVar ; oldItem["VarTable"].as!(GffType.List)){
		immutable name = oldItemVar["Name"].to!string;

		auto policy = UpdatePolicy.Keep;
		if(auto p = ("Var."~name) in itemPolicy)
			policy = *p;

		if(auto idx = name in varsInUpdatedItem){
			//Var is in updatedItem (inherited from blueprint)
			//Set var using policy
			if(policy == UpdatePolicy.Keep){
				//Copy old item var to updated item
				updatedItem["VarTable"][*idx] = oldItemVar.dup;
			}
			else{
				//keep the var inherited from blueprint
			}
		}
		else{
			//Var not found in blueprint
			//Append var
			if(policy == UpdatePolicy.Keep){
				//Add oldvar to updated item
				varsInUpdatedItem[name] = updatedItem["VarTable"].as!(GffType.List).length;
				updatedItem["VarTable"].as!(GffType.List) ~= oldItemVar.dup;
			}
			else{
				//Do not add oldvar to updated item
			}
		}
	}

	//Property policy
	foreach(propName, policy ; itemPolicy){
		if(propName.length<4 || propName[0..4]!="Var."){
			//policy is for a property
			auto propOld = propName in oldItem.as!(GffType.Struct);
			auto propUpd = propName in updatedItem.as!(GffType.Struct);
			enforce(propOld && propUpd, "Property '"~propName~"' does not exist in both instance and blueprint, impossible to enforce policy.");
			if(policy == UpdatePolicy.Keep){
				*propUpd = propOld.dup;
			}
		}
	}

	return updatedItem;
}





























void pressEnter(){
	write("Press [Enter] to continue");
	stdout.flush();
	readln();
}







/// Builds a path like a case insensitive filesystem.
/// basePath is assumed to have the correct case.
/// If a subfile exists, fixes the case. If does not exist, append the name as is.
string buildPathCI(T...)(in string basePath, T subFiles){
	import std.file;
	import std.path;
	import std.string: toUpper;

	assert(basePath.exists, "basePath does not exist");
	string path = basePath;

	foreach(subFile ; subFiles){
		//Case is correct, cool !
		if(buildPath(path, subFile).exists){
			path = buildPath(path, subFile);
		}
		//Most likely only the extension is fucked up
		else if(buildPath(path, subFile.stripExtension ~ subFile.extension.toUpper).exists){
			path = buildPath(path, subFile.stripExtension ~ subFile.extension.toUpper);
		}
		//Perform full scan of the directory
		else{
			bool bFound = false;
			foreach(file ; path.dirEntries(SpanMode.shallow)){
				if(filenameCmp!(CaseSensitive.no)(file.baseName, subFile) == 0){
					bFound = true;
					path = file.name;
					break;
				}
			}
			if(!bFound)
				path = buildPath(path, subFile);
		}
	}
	return path;
}
void improvedGetoptPrinter(string text, Option[] opt, int width=80){
	import std.stdio: writef, writeln;
	import std.algorithm: map, reduce;

	size_t widthOptLong;
	bool hasRequiredOpt = false;
	size_t widthHelpIndentation;
	foreach(ref o ; opt){
		if(o.optLong.length > widthOptLong)
			widthOptLong = o.optLong.length;
		if(o.required)
			hasRequiredOpt = true;
	}
	widthHelpIndentation = widthOptLong + 8;
	auto helpIndent = "".leftJustify(widthHelpIndentation);

	writeln(text);
	writeln();
	if(helpIndent) writeln("Options with * are required");

	foreach(ref o ; opt){
		writef(" %s %s %*s  ",
			o.required? "*" : " ",
			o.optShort !is null? o.optShort : "  ",
			widthOptLong, o.optLong );

		auto wrappedText = o.help
			.splitLines
			.map!(a=>a.wrap(width-widthHelpIndentation).splitLines)
			.reduce!(delegate(a, b){return a~b;});

		bool first = true;
		foreach(l ; wrappedText){
			writeln(first? "" : helpIndent, l);
			first = false;
		}
	}
}