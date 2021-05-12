import std.stdio;
import std.string;
import std.ascii;
import std.stdint;
import std.conv;
import std.path;
import std.typecons;
import std.variant;
import std.json;
import std.file;
	alias write = std.stdio.write;
	alias writeFile = std.file.write;
import std.exception: assertThrown, assertNotThrown, enforce;
import std.algorithm;
import std.array;
import std.datetime.stopwatch: StopWatch;
import std.parallelism;
import core.thread;
import std.regex;
import std.variant;
import mysql;
import nwn.fastgff;
import nwn.twoda;
import nwn.biowaredb;

import colorize;

import tools.common.getopt;
	alias required = tools.common.getopt.config.required;


int main(string[] args){
	version(Windows) stdout.setvbuf(1024, _IONBF);

	string vaultPath;

	string sqlConnectStr;
	string sqlTablePrefix = null;
	string[] sqlConstraints = null;
	string sqlSingleTable = null;
	string rejectFilePath = null;
	string[] registerPCStmt = null;

	bool imscared = false;

	string[] camFiles;

	//Parse cmd line
	try{

		auto res = getopt(args,
			required, "vault|v", "Vault containing all known player characters.", &vaultPath,
			required, "sql", "MySQL connection string. If set to 'none', no SQL commands will be issued.\nExample: host=localhost;port=3306;user=yourname;pwd=pass123;db=nwnx", &sqlConnectStr,
			"sql-table-prefix", "Prefix to add before the name of each created SQL table", &sqlTablePrefix,
			"sql-table-name", "Set this parameter to migrate every campaign database to a single SQL table with this name. Incompatible with --sql-table-prefix", &sqlSingleTable,
			"sql-constraint", "SQL foreign key constraint definition for created tables.\n"
				~ "Can be specified multiple times to add several constraints\n"
				~ "Any occurence of '{{TABLE_NAME}}' will be replaced with the created table name.\n"
				~ "Example: 'KEY `fk_{{TABLE_NAME}}` (`account_name`, `character_name`), CONSTRAINT fk_{{TABLE_NAME}} FOREIGN KEY (`account_name`, `character_name`) REFERENCES `character`(`account_name`, `name`) ON DELETE CASCADE ON UPDATE CASCADE'", &sqlConstraints,
			"sql-register-pc", "SQL query for registering a player characterif it is not registered\n"
				~ "The following tokens will be replaced: {{ACCOUNT}}, {{CHARNAME}}\n", &registerPCStmt,
			"reject-file", "Path to a file that will contains the variables having an unknown player character ID that have been discarded. The file is in JSON format", &rejectFilePath,
			"imscared", "Extra info (like sql queries) and stop update on warnings", &imscared,
		);

		if(res.helpWanted){
			improvedGetoptPrinter(
				"Migrate Bioware Campaign database (foxpro) to a MySQL server\n"
				~"\n"
				~"Usage: " ~ args[0].baseName ~ " [options] dbf_files\n"
				~" - options: See below\n"
				~" - dbf_files: list of DBF campaign files to migrate\n"
				~"\n"
				~"Note: One SQL table will be created for each database file (i.e. for each 'sCampaignName'), unless --sql-table-name tablename is provided.",
				res.options);
			return 0;
		}
		enforce(args.length > 1, "Missing dbf_files");

		if(sqlTablePrefix is null && sqlSingleTable is null)
			sqlTablePrefix = "cam_";
		enforce((sqlTablePrefix is null) ^ (sqlSingleTable is null), "You cannot use both --sql-table-prefix and --sql-table-name");

		camFiles = args[1 .. $];
		camFiles.each!(a => {
			enforce(a.extension.toLower == ".dbf", "File " ~ a ~ " is not a .dbf file");
			enforce(a.exists, "File " ~ a ~ " does not exist");
		});
	}
	catch(Exception e){
		stderr.writeln(e.msg);
		stderr.writeln("Use --help for more information");
		return 1;
	}


	//paths
	enforce(vaultPath.exists && vaultPath.isDir, "Vault is not a directory/does not exist");

	if(rejectFilePath !is null)
		rejectFilePath.writeFile("[]");
	JSONValue rejectJSON;
	rejectJSON.array = [];

	MySQLPool connPool;
	if(sqlConnectStr != "none"){
		connPool = new MySQLPool(sqlConnectStr);
		// Test SQL connection
		connPool.lockConnection();
	}
	scope(exit){
		if(connPool !is null)
			connPool.removeUnusedConnections();
	}
	void sqlExec(T...)(in string query, T args){
		try connPool.lockConnection().exec(query, args);
		catch(Exception e){
			stderr.writeln("Error for SQL query: ", query);
			static if(args.length == 1 && is(args[0]: Variant[])){
				stderr.write("               Args: ", args.map!(a => a.peek!(const(ubyte)[]) !is null ? "[BLOB]" : a.toString));
			}
			else{
				stderr.write("               Args: [");
				static foreach(i, arg ; args){
					stderr.writef("%s'%s'",
						i == 0 ? "" : ", ",
						is(typeof(arg) == Nullable!(const(ubyte)[])) ? "[BLOB]" : format!"%s"(arg),
					);
				}
				stderr.writeln("]");
			}
			throw e;
		}
	}
	void sqlCustomExec(in string query, in string[string] tokens){
		enum rgx = ctRegex!`\{\{(\w+)\}\}`;

		Variant[] params;
		const prepQuery = query.replaceAll!((m){
			enforce(m[1] in tokens, format!"Unknown token %s. Available tokens: %s"(m[1], tokens.keys()));
			params ~= Variant(tokens[m[1]]);
			return "?";
		})(rgx);

		sqlExec(prepQuery, params);
	}

	alias FullID = Tuple!(string, "account", string, "charname");
	FullID[PCID] knownIDs;

	writeln("Gathering all known account and character names...");
	StopWatch bench;
	bench.start;
	foreach(charFile ; vaultPath.dirEntries(SpanMode.depth)){
		if(charFile.extension.toLower == ".bic"){
			auto accName = charFile.dirName.baseName;

			auto c = new FastGff(charFile);
			auto fname = c["FirstName"].to!string;
			auto lname = c["LastName"].to!string;
			auto charName = fname ~ (lname.length > 0 ? " " : "") ~ lname;

			auto pcid = PCID(accName, charName);
			auto fullid = FullID(accName, charName);
			if(auto f = pcid in knownIDs){
				if(*f != fullid){
					stderr.cwrite(
						format!"Warning: Owner ID '%s' is already taken by '%s/%s'. '%s/%s' will take the ownership of the campaign variables"(
							pcid, f.account, f.charname, fullid.account, fullid.charname,
						).color(fg.yellow), "\n"
					);
				}
			}
			knownIDs[pcid] = fullid;


			// insert character
			foreach(ref stmt ; registerPCStmt)
				sqlCustomExec(stmt, ["ACCOUNT": accName, "CHARNAME": charName]);
		}
	}
	// add fake character for module vars
	foreach(ref stmt ; registerPCStmt)
		sqlCustomExec(stmt, ["ACCOUNT": "", "CHARNAME": ""]);

	bench.stop;
	writefln(">>> %d indexed characters, %f seconds", knownIDs.length, bench.peek.total!"msecs"/1000.0);


	writeln("Migrating campaign databases");
	bench.reset;
	bench.start;
	if(sqlSingleTable && connPool !is null){
		sqlExec(
			"CREATE TABLE IF NOT EXISTS `" ~ sqlSingleTable ~ "` (
				`campaign_name` VARCHAR(128) NOT NULL,
				`account_name` VARCHAR(64) NOT NULL,
				`character_name` VARCHAR(64) NOT NULL,
				`type` ENUM('float', 'int', 'vector', 'location', 'string', 'object') NOT NULL,
				`name` VARCHAR(64) NOT NULL,
				`value` TEXT NULL,
				`value_obj` LONGBLOB NULL,
				PRIMARY KEY (`campaign_name`, `account_name`, `character_name`, `name`)" ~ (sqlConstraints.length > 0? "," : null) ~ "
				" ~ sqlConstraints.join(",").replace("{{TABLE_NAME}}", sqlSingleTable) ~ "
			) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin"
		);
	}

	bool[FullID] insertedChars;

	foreach(camFile ; camFiles){
		auto camDBName = camFile.baseName.stripExtension;
		writeln("DATABASE ", camDBName);

		StopWatch camFileBench;
		camFileBench.start;

		auto camDB = new BiowareDB(camFile, null, buildPathCI(camFile.dirName, camFile.baseName.stripExtension ~ ".fpt"), false);
		writefln("         %d variables to migrate", camDB.length);


		string tableName;
		if(sqlSingleTable){
			tableName = encodeDBTableName(sqlSingleTable);
		}
		else{
			tableName = encodeDBTableName(sqlTablePrefix ~ camDBName);
			if(connPool !is null){
				sqlExec(
					"CREATE TABLE IF NOT EXISTS `" ~ tableName ~ "` (
						`account_name` VARCHAR(64) NOT NULL,
						`character_name` VARCHAR(64) NOT NULL,
						`type` ENUM('float', 'int', 'vector', 'location', 'string', 'object') NOT NULL,
						`name` VARCHAR(64) NOT NULL,
						`value` TEXT NULL,
						`value_obj` LONGBLOB NULL,
						PRIMARY KEY (`account_name`, `character_name`, `name`)" ~ (sqlConstraints.length > 0? "," : null) ~ "
						" ~ sqlConstraints.join(",").replace("{{TABLE_NAME}}", tableName) ~ "
					) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin"
				);
			}
		}

		foreach(i, var ; camDB){
			if(i > 0 && i % 10_000 == 0)
				writefln("         %dK / %dK", i / 1000, camDB.length / 1000);

			auto rejected = false;
			Nullable!string valueStr;
			Nullable!(const(ubyte)[]) valueBlob;

			if(!var.deleted){
				final switch(var.type) with(BiowareDB.VarType){
					case Int:
						valueStr = camDB.getVariableValue!NWInt(var.index).to!string;
						break;
					case Float:
						valueStr = camDB.getVariableValue!NWFloat(var.index).to!string;
						break;
					case String:
						valueStr = camDB.getVariableValue!NWString(var.index);
						break;
					case Vector:
						auto v = camDB.getVariableValue!NWVector(var.index);
						valueStr = format!"%f;%f;%f"(v[0], v[1], v[2]);
						break;
					case Location:
						auto l = camDB.getVariableValue!NWLocation(var.index);
						valueStr = format!"#%f;%f;%f#%f"(l.position[0], l.position[1], l.position[2], l.facing);
						break;
					case Object:
						valueBlob = camDB.getVariableValue!BinaryObject(var.index);
						break;
				}
			}

			string varType;
			final switch(var.type) with(BiowareDB.VarType){
				case Int:      varType = "int";      break;
				case Float:    varType = "float";    break;
				case String:   varType = "string";   break;
				case Vector:   varType = "vector";   break;
				case Location: varType = "location"; break;
				case Object:   varType = "object";   break;
			}

			// Retrieve player character ID
			FullID fullID;
			if(var.playerid[].any!"a != ' '"){
				if(auto _fullID = var.playerid in knownIDs){
					fullID = *_fullID;
				}
				else{
					// No matching character found :/

					if(rejectFilePath is null)
						stderr.cwrite(format!"Warning: Unknown player id '%s'. Ignored variable name '%s'"(var.playerid, var.name).color(fg.yellow), "\n");
					rejected = true;

					if(rejectFilePath !is null){
						rejectJSON.array ~= JSONValue([
							"campaign_name": JSONValue(camDBName),
							"pc_id": JSONValue(var.playerid.pcid.idup),
							"type": JSONValue(varType),
							"name": JSONValue(var.name),
							"value": camDB.getVariableValueJSON(var.index),
						]);
					}
					else
						stderr.cwrite(format!"Warning: Unknown player id '%s'. Ignored variable name '%s'"(var.playerid, var.name).color(fg.yellow), "\n");

					// Do not insert in MySQL
					continue;
				}
			}

			// Insert into MySQL
			if(sqlSingleTable){
				if(imscared) writefln("-> %s cam='%s' acct='%s' SET char='%s': %s %s = '%s'", tableName, camDBName, fullID.account, fullID.charname, varType, var.name, !valueStr.isNull ? valueStr.get : "[OBJ]");
				if(connPool !is null){
					sqlExec(
						"INSERT INTO `" ~ tableName ~ "`
							(`campaign_name`, `account_name`, `character_name`, `type`, `name`, `value`, `value_obj`)
							VALUES(?, ?, ?, ?, ?, ?, ?)
							ON DUPLICATE KEY UPDATE `type`=VALUES(`type`), `value`=VALUES(`value`), `value_obj`=VALUES(`value_obj`)",
						camDBName, fullID.account, fullID.charname, varType, var.name, valueStr, valueBlob
					);
				}
			}
			else{
				if(imscared) writefln("-> %s acct='%s' char='%s' SET %s %s = '%s'", tableName, fullID.account, fullID.charname, varType, var.name, !valueStr.isNull ? valueStr.get : "[OBJ]");
				if(connPool !is null){
					sqlExec(
						"INSERT INTO `" ~ tableName ~ "`
							(`account_name`, `character_name`, `type`, `name`, `value`, `value_obj`)
							VALUES(?, ?, ?, ?, ?, ?)
							ON DUPLICATE KEY UPDATE `type`=VALUES(`type`), `value`=VALUES(`value`), `value_obj`=VALUES(`value_obj`)",
						fullID.account, fullID.charname, varType, var.name, valueStr, valueBlob
					);
				}
			}
		}
		camFileBench.stop;
		writefln("         >>> took %f seconds", camFileBench.peek.total!"msecs"/1000.0);
	}
	bench.stop;

	if(rejectFilePath !is null)
		rejectFilePath.writeFile(rejectJSON.toPrettyString);


	writeln("Migration ended !");
	writeln(">>> ", bench.peek.total!"msecs"/1000.0, " seconds");

	return 0;
}



string encodeDBTableName(in string name){
	return name.filter!(c =>
			c == 0x27 // '
			|| c == 0x2D // -
			|| (c >= 0x30 && c <= 0x39) // 0-9
			|| c == 0x5F // _
			|| (c >= 0x61 && c <= 0x7A) // a-z)
		)
		.array
		.to!string;
}


/// Builds a path like a case insensitive filesystem.
/// basePath is assumed to have the correct case.
/// If a subfile exists, fixes the case. If does not exist, append the name as is.
string buildPathCI(T...)(in string basePath, T subFiles){
	import std.file;
	import std.path;
	import std.string: toUpper;

	assert(basePath.exists, "basePath " ~ basePath ~ " does not exist");
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