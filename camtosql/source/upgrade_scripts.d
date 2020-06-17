import std.stdio;
import std.regex;
import std.string;
import std.conv;
import std.path;
import std.file;
	alias write = std.stdio.write;
	alias writeFile = std.file.write;
import std.parallelism;
import std.algorithm;
import std.array;
import std.exception;

import colorize;

import tools.common.getopt;
	alias required = tools.common.getopt.config.required;


int main(string[] args)
{
	version(Windows) stdout.setvbuf(1024, _IONBF);

	string sqlTablePrefix = "cam_";
	string[] sqlConstraints = null;
	string sqlSingleTable = null;
	string libName = "_cam_sql_db";
	string outDir = null;

	bool imscared = false;

	string[] originalCommandLine = args.dup;


	try{
		auto res = getopt(args,
			"o|output", "Output directory for the script library and unittest files. If not provided, only the library will be written to stdout.", &outDir,
			"library-name", "Include script name. Defaults to '_cam_sql_db'", &libName,
			"sql-table-prefix", "See camdb-migrate --help", &sqlTablePrefix,
			"sql-table-name", "See camdb-migrate --help", &sqlSingleTable,
			"sql-constraint", "See camdb-migrate --help", &sqlConstraints,
		);

		if(res.helpWanted){
			improvedGetoptPrinter(
				"Change your module scripts so they use the MySQL database instead of the campaign database\n"
				~"\n"
				~"Usage: " ~ args[0].baseName ~ " [options] [dir|file]\n"
				~"\n"
				~"",
				res.options);
			return 0;
		}

		enforce(args.length > 1, "Missing dir or file argument");
	}
	catch(Exception e){
		stderr.writeln(e.msg);
		stderr.writeln("Use --help for more information");
		return 1;
	}

	args[1 .. $].each!(a => enforce(a.exists, "Target " ~ a ~ " does not exist"));

	const files = args[1 .. $]
		.map!(a =>
			a.isDir ?
			a.dirEntries(SpanMode.depth).filter!(f => f.extension.toLower == ".nss").array()
			: [DirEntry(a)]
		)
		.join;


	// Create library file
	auto libData = cast(string)import("library_tpl.nss");

	const constraintsStr = sqlConstraints.length > 0 ? format!q{+ ", %s"}(sqlConstraints.join(",")) : "";

	libData = libData
		.replace("{{CONSTRAINTS}}", sqlConstraints.length > 0 ? format!q{+ ", %s"}(sqlConstraints.join(",")) : "")
		.replace("{{COMMANDLINE}}", originalCommandLine.to!string);

	if(sqlSingleTable !is null){
		// Single table
		libData = libData
			.replace("{{COLUMN_CAMNAME}}", q{`campaign_name`,})
			.replace("{{COLUMN_CAMNAME_CREATE}}", q{+ "`campaign_name` VARCHAR(128) NOT NULL,"})
			.replace("{{TABLE_NAME}}", sqlSingleTable)
			.replace("{{TABLE_INIT_VAR}}", q{"__cam_db_init"})
			.replace("{{INSERT_CAMNAME_COLUMN}}", q{`campaign_name`,})
			.replace("{{INSERT_CAMNAME_VALUE}}", q{+ "'" + sCampaignName + "',"})
			.replace("{{WHERE_CAMNAME}}", q{+ " AND `campaign_name`='" + sCampaignName + "'"})
			.replace("{{DESTROY_CODE}}",
				format!q{SQLExecDirect("DELETE FROM `%s` WHERE `campaign_name`='" + sCampaignName + "'");}(sqlSingleTable)
				.detab.entab(8 * 4)
			)
			.replace("{{CONSTRAINTS}}", constraintsStr.replace("{{TABLE_NAME}}", sqlSingleTable));
	}
	else{
		// One table per database
		libData = libData
			.replace("{{COLUMN_CAMNAME}}", "")
			.replace("{{COLUMN_CAMNAME_CREATE}}", "")
			.replace("{{TABLE_NAME}}", format!q{%s" + sCampaignName + "}(sqlTablePrefix))
			.replace("{{TABLE_INIT_VAR}}", q{"__cam_db_init_" + sCampaignName})
			.replace("{{INSERT_CAMNAME_COLUMN}}", "")
			.replace("{{INSERT_CAMNAME_VALUE}}", "")
			.replace("{{WHERE_CAMNAME}}", "")
			.replace("{{DESTROY_CODE}}",
				format!q{DeleteLocalInt(GetModule(), "__cam_db_init_" + sCampaignName);
				SQLExecDirect("DROP TABLE IF EXISTS `%s" + sCampaignName + "`");}(sqlTablePrefix)
				.detab.entab(8 * 4)
			)
			.replace("{{CONSTRAINTS}}", constraintsStr.replace("{{TABLE_NAME}}", format!q{%s" + sCampaignName + "}(sqlTablePrefix)));
	}

	if(outDir is null)
		writeln(libData);
	else{
		enforce(outDir.isDir, outDir ~ " is not a directory / does not exist !");

		const libFile = buildPath(outDir, libName ~ ".nss");
		libFile.writeFile(libData);
		stderr.writefln("Written library: %s", libFile);

		auto unittestData = cast(string)import("library_unittest_tpl.nss")
			.replace("{{LIB_NAME}}", libName);
		const unitFile = buildPath(outDir, "unittest_" ~ libName ~ ".nss");
		unitFile.writeFile(unittestData);
		stderr.writefln("Written unit-test file: %s", unitFile);
	}


	// Modify scripts
	stderr.writefln("%d files will be parsed for code migration", files.length);
	size_t statz = 0;
	enum includeRgx = ctRegex!(`^(?![ \t]*//)[ \t]*#include\s+"([^"]+?)"`, "mg");
	enum replaceFunRgx = ctRegex!(`\b([GS]etCampaign(?:String|Float|Int|Vector|Location)|DeleteCampaignVariable|(?:Destroy|Pack)CampaignDatabase|(?:Store|Retrieve)CampaignObject)(\s*\()`, "g");
	const libIncludeLine = "#include \"" ~ libName ~ "\"";
	foreach(scriptFile ; parallel(files)){
		const scriptName = scriptFile.baseName.stripExtension;
		if(scriptName == "nwnx_sql"){
			stderr.writefln("Skipped %s", scriptFile);
			continue;
		}

		auto data = cast(string)scriptFile.read();

		bool modified = false;
		data = data.replaceAll!((m){
				modified = true;
				return m[1] ~ "SQL" ~ m[2];
			})(replaceFunRgx);

		if(modified){
			string lineEndings = "\n";
			if(data.indexOf("\r\n") >= 0)
				lineEndings = "\r\n";

			bool hasAnyIncludes = false;
			bool hasLibInclude = false;
			foreach(m ; data.matchAll(includeRgx)){
				hasAnyIncludes = true;
				if(m[1] == libName){
					hasLibInclude = true;
					break;
				}
			}

			if(!hasLibInclude){
				if(hasAnyIncludes){
					// Add before the first include
					data = data.replaceFirst!(m => libIncludeLine ~ "\n" ~ m[0])(includeRgx);
				}
				else{
					// Add after the first comment block

					const lines = data.splitLines();

					size_t insertPos = 0;
					bool isStarBlock = false;
					foreach(i, ref line ; lines){
						auto l = line.strip;

						if(isStarBlock){
							if(l.indexOf("*/") >= 0){
								isStarBlock = false;
							}
							continue;
						}
						if(l.length >= 2){
							if(l[0 .. 2] == "//")
								continue;
							if(l[0 .. 2] == "/*"){
								isStarBlock = true;
								continue;
							}
						}

						insertPos = i;
						break;
					}

					data = (lines[0 .. insertPos] ~ libIncludeLine ~ lines[insertPos .. $]).join(lineEndings);
				}
			}
			scriptFile.writeFile(data);
			statz++;
		}

	}
	stderr.writefln("Parsing finished, %d updated scripts", statz);
	return 0;
}
