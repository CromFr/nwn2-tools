import std.stdio;
import std.array: join;
import std.string;
import std.conv;
import std.path;
import std.file;
import std.file: readFile = read, writeFile = write;
import std.exception;
import std.xml;
import std.algorithm;
import std.parallelism;
import std.typecons;
import std.datetime;

import nwnlibd.path;



extern(C) int main2(int numArgs, const char** args, char *rs);
auto Lzma(string[] args){

	char[800] rs;
	rs[] = 0;

	char*[] cargs;
	foreach(arg ; args)
		cargs ~= (arg ~ "\0").dup.ptr;

	auto ret = main2(args.length.to!int, cargs.ptr, rs.ptr);

	return Tuple!(int,"status", string,"output")(ret, rs.ptr.fromStringz.dup);
}

version(Windows) version(X86_64)
extern(C) void* __enclave_config;

__gshared bool verbose = false;
void logDebug(T...)(T args){
	if(verbose){
		version(Windows) stderr.writeln(args);
		else stderr.writeln("\x1b[2m", args, "\x1b[m");
	}
}
void info(T...)(T args){
	version(Windows) stderr.writeln(args);
	else stderr.writeln("\x1b[32;1m", args, "\x1b[m");
}
void warning(T...)(T args){
	version(Windows) stderr.writeln("Warning: ", args);
	else stderr.writeln("\x1b[33;1mWarning: ", args, "\x1b[m");
}
void error(T...)(T args){
	version(Windows) stderr.writeln("Error: ", args);
	else stderr.writeln("\x1b[31;40;1mError: ", args, "\x1b[m");
}


int main(string[] args)
{

	import std.getopt;
	string xmlPath = null;
	bool force = false;
	string[] extensions = ["trx", "hak", "bmu", "tlk"];
	uint threads = 0;
	string sinceStr = null;
	bool incremental = false;

	auto res = getopt(args, config.passThrough,
		"o|xml-out", "Path to moduledownloaderresources.xml. If existing, will read it to only generate modified client files. '-' to print to stdout.", &xmlPath,
		"f|force", "Generate all client files even if they have not been modified", &force,
		"extensions", "Set the default file extensions to add to the client files list. Default: [trx, hak, bmu, tlk]", &extensions,
		"since", "Only check files modified after a given date. Other files will still be listed, but no modification will be detected."
			~" Files will still be processed if the LZMA files does not exist."
			~" Date must be in YYYY-MM-DDTHH:MM:SS format (ISO ext) or a UNIX timestamp", &sinceStr,
		"i|incremental", "Store last execution date in moduledownloaderresources.xml, and pass the value to --since. Mutually exclusive with --since.", &incremental,
		"j","Number of concurrent threads to use for compressing files", &threads,
		"verbose|v","Print all file operations", &verbose,
		);
	if(res.helpWanted || args.length < 3){
		defaultGetoptPrinter(
			"Scan resource directories to find .hak, .tlk, .bmu, .trx files and generate client files to output_folder\n"
			~args[0]~" output_folder resource_folder1 [resource_folder2 ...]",
			res.options);
		return 0;
	}


	//Process args
	auto outPath = DirEntry(args[1]);
	auto resPaths = args[2 .. $];

	foreach(ref path ; resPaths)
		enforce(path.exists && path.isDir, "Path '"~path~"' does not exist / is not a directory.");

	bool[string] extMap;
	foreach(e ; extensions) extMap["." ~ e.toLower] = true;


	if(xmlPath is null){
		xmlPath = buildPathCI(outPath, "moduledownloaderresources.xml");
	}

	if(incremental){
		assert(sinceStr is null, "Cannot provide both --since and --incremental");
	}

	Nullable!SysTime since;
	if(sinceStr !is null){

		try since = SysTime.fromUnixTime(sinceStr.to!long);
		catch(ConvException){
			since = SysTime(DateTime.fromISOExtString(sinceStr));
		}
	}

	// Load servers.xml files
	int[] serversList;
	foreach(ref path ; resPaths){
		auto serversFile = buildPathCI(path, "servers.xml");
		if(serversFile.exists && serversFile.isFile){
			auto parser = new DocumentParser(serversFile.readText);
			parser.onStartTag["server"] = (ElementParser xml){
				serversList ~= xml.tag.attr["id"].to!int;
			};
			parser.parse();

			enforce(serversList.length > 0, "Cound not find any server in "~serversFile);
			break;
		}
	}
	enforce(serversList.length > 0, "Could not find servers.xml file");
	auto serversListXml = `<server-ref>` ~ serversList.map!(a => `<string>` ~ a.to!string ~ `</string>`).join ~ `</server-ref>`;

	//Load existing xml resources
	Resource[string] previousResources;
	if(xmlPath != "-" && xmlPath.exists){
		auto parser = new DocumentParser(xmlPath.readText);
		if(incremental && "gen-date" in parser.tag.attr){
			try{
				since = cast(SysTime)DateTime.fromISOExtString(parser.tag.attr["gen-date"]);
				logDebug("Previous generation date: ", cast(DateTime)since.get);
			}
			catch(DateTimeException e){
				warning("Previous generation date ignored because malformed: ", e.msg);
			}
		}
		parser.onStartTag["resource"] = (ElementParser xml){
			const name = xml.tag.attr["name"].toLower;
			const type = xml.tag.attr["type"].to!(Resource.ResType);
			const resHash = xml.tag.attr["hash"];
			const resSize = xml.tag.attr["size"].to!size_t;
			const dlHash = xml.tag.attr["downloadHash"];
			const dlSize = xml.tag.attr["dlsize"].to!size_t;
			previousResources[name] = Resource(
				name,
				type,
				resHash,
				resSize,
				dlHash,
				dlSize,
			);
		};
		parser.parse();
	}

	// Generate new resource list
	DirEntry[] resourceFiles;
	foreach(resPath ; resPaths){
		foreach(file ; resPath.dirEntries(SpanMode.shallow)){
			if(file.extension.toLower in extMap){
				resourceFiles ~= file;
			}
		}
	}

	// Compress files asap
	if(threads > 0)
		defaultPoolThreads = threads;

	Resource[] resources;
	resources.length = resourceFiles.length;
	foreach(i, resDirEntry ; resourceFiles.parallel){
		const resName = resDirEntry.baseName.toLower;

		if(!since.isNull && resDirEntry.timeLastModified < since.get && resName in previousResources && buildPathCI(outPath, resName~".lzma").exists){
			// Insert previous entry
			logDebug("Skipped ", resDirEntry, " (mtime too old)");
			resources[i] = previousResources[resName];
		}
		else{
			// Process resource file
			logDebug("Processing ", resDirEntry);
			string prevHash = resName in previousResources ? previousResources[resName].resHash : null;
			resources[i] = Resource(resDirEntry, prevHash, outPath, force);
			string newHash = resources[i].resHash;

			if(prevHash is null)
				info("New file: '", resName, "' ('", resDirEntry, "')");
			else if(prevHash != newHash)
				info("Modified file: ", resName, "' ('", resDirEntry, "')");
			else
				logDebug("Unmodified file: ", resName, "' ('", resDirEntry, "')");
		}
	}

	// Remove kept files from previousResources
	foreach(ref resource ; resources) {

		auto expectedRes = resource.name in previousResources;
		if(expectedRes !is null)
			previousResources.remove(resource.name);
	}

	// Warn for removed files
	foreach(ref res ; previousResources){
		warning("Removed file: ", res.name);
		const lzma = buildPathCI(outPath, res.name ~ ".lzma");
		if(lzma.exists)
			logDebug("Delete file: ", lzma);
			lzma.remove();
	}

	//Sort resource list
	import std.algorithm.sorting: multiSort;
	resources.multiSort!("a.type < b.type", "a.name < b.name");


	//Generate XML
	string xml = `<?xml version="1.0" encoding="utf-8"?>`~"\n";
	string genDateAttr;
	if(incremental)
		genDateAttr = ` gen-date="` ~ (cast(DateTime)Clock.currTime()).toISOExtString() ~ `"`;
	xml ~= `<content xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"` ~ genDateAttr ~ `>` ~ "\n";
	foreach(const ref resource ; resources){
		xml ~= "  " ~ resource.toXml(serversListXml) ~ "\n";
	}
	xml ~= `</content>` ~ "\n";

	//Write XML
	if(xmlPath == "-")
		writeln(xml);
	else
		xmlPath.writeFile(xml);
	return 0;

}


struct Resource{
	this(in DirEntry resFile, in string expectedResHash, in DirEntry outputDir, bool force){
		name = resFile.baseName.toLower;
		switch(name.extension.toLower){
			case ".trx": type = ResType.DirectoryEntry; break;
			case ".hak": type = ResType.Hak; break;
			case ".bmu": type = ResType.Music; break;
			case ".tlk": type = ResType.Tlk; break;
			default: assert(0, "Unknown resource extension");
		}


		import std.digest.sha;
		immutable data = cast(immutable ubyte[])readFile(resFile);
		resSize = data.length;
		resHash = data.sha1Of.toHexString.idup;

		auto dlFilePath = buildPathCI(outputDir, name~".lzma");

		if(expectedResHash is null || resHash != expectedResHash || !dlFilePath.exists){
			logDebug("Compressing ", name);

			auto res = Lzma(["lzma", "e", resFile.name, dlFilePath]);
			enforce(res.status == 0, "lzma command failed:\n" ~ res.output);
		}

		ubyte[] dlData = cast(ubyte[])readFile(dlFilePath);
		dlSize = dlData.length;
		dlHash = dlData.sha1Of.toHexString.idup;
	}

	this(in string name, in ResType type, in string resHash, in size_t resSize, in string dlHash, in size_t dlSize){
		this.name = name.toLower;
		this.type = type;
		this.resHash = resHash;
		this.resSize = resSize;
		this.dlHash = dlHash;
		this.dlSize = dlSize;
	}

	string name;
	ResType type;
	string resHash;
	size_t resSize;
	string dlHash;
	size_t dlSize;

	string toXml(in string serverList) const{
		return "<resource "
				~" name="~("\""~name~"\"").leftJustify(32+6) // with extension
				~" type="~("\""~type.to!string~"\"").leftJustify(14+2)
				~" hash=\""~resHash~"\""
				~" size="~("\""~resSize.to!string~"\"").leftJustify(9+2)
				~" downloadHash=\""~dlHash~"\""
				~" dlsize="~("\""~dlSize.to!string~"\"").leftJustify(9+2)
				~" critical=\"false\""
				~" exclude=\"false\""
				~" urlOverride=\"\""
				~">"~serverList~"</resource>";
	}


	enum ResType{
		Hak,
		Tlk,
		Music,
		DirectoryEntry,
	}
}