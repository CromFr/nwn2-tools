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



void info(T...)(T args){
	stderr.writeln("\x1b[32;1m", args, "\x1b[m");
}
void warning(T...)(T args){
	stderr.writeln("\x1b[33;1mWarning: ", args, "\x1b[m");
}
void error(T...)(T args){
	stderr.writeln("\x1b[31;40;1mError: ", args, "\x1b[m");
}

bool verbose = false;

int main(string[] args)
{

	import std.getopt;
	string xmlPath = null;
	bool force = false;
	string[] extensions = ["trx", "hak", "bmu", "tlk"];
	uint threads = 0;

	auto res = getopt(args, config.passThrough,
		"o|xml-out", "Path to moduledownloaderresources.xml. If existing, will read it to only generate modified client files. '-' to print to stdout.", &xmlPath,
		"f|force", "Generate all client files even if they have not been modified", &force,
		"extensions", "Set the default file extensions to add to the client files list. Default: [trx, hak, bmu, tlk]", &extensions,
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
		xmlPath = buildPath(outPath, "moduledownloaderresources.xml");
	}

	// Load servers.xml files
	int[] serversList;
	foreach(ref path ; resPaths){
		auto serversFile = buildPath(path, "servers.xml");
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

	//Load existing xml hashes
	string[string] resourceHashes;
	if(xmlPath != "-" && xmlPath.exists){
		auto parser = new DocumentParser(xmlPath.readText);
		parser.onStartTag["resource"] = (ElementParser xml){
			resourceHashes[xml.tag.attr["name"].toLower] = xml.tag.attr["hash"];
		};
		parser.parse();
	}

	// Generate resource list
	Tuple!(DirEntry, string)[] resourceEntries;
	foreach(resPath ; resPaths){
		foreach(file ; resPath.dirEntries(SpanMode.shallow)){
			if(file.name.extension.toLower in extMap){
				auto expectedHash = file.baseName.toLower in resourceHashes;
				resourceEntries ~= Tuple!(DirEntry, string)(file, expectedHash is null? null : *expectedHash);
			}
		}
	}

	// Compress files asap
	if(threads > 0)
		defaultPoolThreads = threads;

	Resource[] resources;
	resources.length = resourceEntries.length;
	foreach(i, resEntry ; resourceEntries.parallel){
		resources[i] = Resource(resEntry[0], resEntry[1], outPath, force);
	}

	// Mark existing files
	foreach(ref resource ; resources) {
		immutable name = resource.file.baseName.toLower;

		auto expectedHash = name in resourceHashes;
		if(expectedHash !is null)
			resourceHashes.remove(name);
	}

	// Warn for removed files
	foreach(name, hash ; resourceHashes){
		warning("Removed file: ", name);
		//TODO: remove lzma files from output dir
	}

	//Sort resource list
	import std.algorithm.sorting: multiSort;
	resources.multiSort!("a.type < b.type", "a.name < b.name");


	//Generate XML
	string xml = `<?xml version="1.0" encoding="utf-8"?>`~"\n";
	xml ~= `<content xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">` ~ "\n";
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
		file = resFile;
		name = file.name.baseName;
		switch(name.extension.toLower){
			case ".trx": type = ResType.DirectoryEntry; break;
			case ".hak": type = ResType.Hak; break;
			case ".bmu": type = ResType.Music; break;
			case ".tlk": type = ResType.Tlk; break;
			default: assert(0, "Unknown resource extension");
		}

		bool genDlFile = false;

		import std.digest.sha;
		immutable data = cast(immutable ubyte[])readFile(file);
		resSize = data.length;
		resHash = data.sha1Of.toHexString.idup;


		auto dlFilePath = buildPath(outputDir, name~".lzma");


		if(expectedResHash is null){
			genDlFile = true;
			info("New file: '", name, "' ('", file.name, "')");
		}
		else if(resHash != expectedResHash){
			genDlFile = true;
			info("Modified file: ", name, "' ('", file.name, "')");
		}
		else if(!dlFilePath.exists){
			genDlFile = true;
		}

		if(genDlFile){
			if(verbose) writeln("Compressing ", name);

			auto res = Lzma(["lzma", "e", file.name, dlFilePath]);
			enforce(res.status == 0, "lzma command failed:\n"~res.output);
		}

		ubyte[] dlData = cast(ubyte[])readFile(dlFilePath);
		dlSize = dlData.length;
		dlHash = dlData.sha1Of.toHexString.idup;
	}

	DirEntry file;

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