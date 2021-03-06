import std;

import nwn.gff;

void main(string[] args)
{
	string areasDir;
	auto res = getopt(args,
		"areas-dir", &areasDir,
	);
	if(res.helpWanted){
		writefln("Usage: %s [options] module.ifo", args[0].baseName);
		writeln();
		writeln("Updates the module area list stored inside the module.ifo file");
		writeln();
		writeln("Options:");
		writeln("  --areas-dir=PATH  Directory where the areas are located. Defaults to the same directory where the module.ifo file is");
		return;
	}


	enforce(args.length == 2, format!"Bad number of arguments. See %s --help"(args[0].baseName));

	auto ifoFile = args[1];
	auto ifo = new Gff(ifoFile);

	if(areasDir is null)
		areasDir = ifoFile.dirName;

	string[] resrefList;

	foreach(file ; areasDir.dirEntries(SpanMode.shallow)){
		if(file.extension.toLower == ".are"){
			resrefList ~= file.baseName.stripExtension.toLower;
		}
	}
	resrefList.sort;
	writefln("%s areas found: %s", resrefList.length, resrefList);

	ifo["Mod_Area_list"] = GffList(resrefList.map!(a => GffStruct(["Area_Name": GffValue(GffResRef(a))], 6)).array);

	std.file.write(ifoFile, ifo.serialize());
}
