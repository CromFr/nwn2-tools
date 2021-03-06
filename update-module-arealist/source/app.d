import std;

import nwn.gff;

void main(string[] args)
{
	string areasDir;
	string outFile;
	string[] includeList;
	string[] excludeList;
	auto res = getopt(args,
		"areas-dir", &areasDir,
		"o|output", &outFile,
		"i|include", &includeList,
		"e|exclude", &excludeList,
	);
	if(res.helpWanted){
		writefln("Usage: %s [options] module.ifo", args[0].baseName);
		writeln();
		writeln("Updates the module area list stored inside the module.ifo file");
		writeln();
		writeln("Options:");
		writeln("  --areas-dir=PATH    Directory where the areas are located. Defaults to the same directory where the module.ifo file is");
		writeln("  -i, --include=PATH  Only include areas listed by this flag");
		writeln("  -e, --exclude=PATH  Do not include areas listed by this flag");
		writeln("  -o, --output=PATH   Output IFO file. By default overwrites the given file.");
		return;
	}


	enforce(args.length == 2, format!"Bad number of arguments. See %s --help"(args[0].baseName));
	if(includeList.length > 0)
		enforce(excludeList.length == 0, "Cannot combine --include with --exclude");

	auto ifoFile = args[1];
	auto ifo = new Gff(ifoFile);

	if(areasDir is null)
		areasDir = ifoFile.dirName;

	string[] resrefList;

	if(includeList.length > 0){
		foreach(file ; includeList){
			auto f = file;
			if(!f.exists)
				f = f ~ ".are";
			enforce(f.exists, format!"Area '%s' not found"(f));

			resrefList ~= file.baseName.stripExtension.toLower;
		}
	}
	else{
		bool[string] excludeSet;
		foreach(e ; excludeList)
			excludeSet[e.baseName.stripExtension.toLower] = true;

		foreach(file ; areasDir.dirEntries(SpanMode.shallow)){
			if(file.extension.toLower == ".are"){
				auto resref = file.baseName.stripExtension.toLower;
				if(resref !in excludeSet)
					resrefList ~= resref;
			}
		}
	}

	resrefList.sort;
	writefln("%s areas found: %s", resrefList.length, resrefList);

	ifo["Mod_Area_list"] = GffList(resrefList.map!(a => GffStruct(["Area_Name": GffValue(GffResRef(a))], 6)).array);

	if(outFile is null)
		outFile = ifoFile;

	std.file.write(outFile, ifo.serialize());
}
