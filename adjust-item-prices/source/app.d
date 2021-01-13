import std.stdio;
import std.parallelism;
import std.path;
import std.file;
import std.getopt;
import std.math;
import std.string;
import std.typecons;
import std.conv;
import std.exception;

import nwn.twoda;
import nwn.gff;

void main(string[] args)
{

	string twoDAPath;
	bool stats;
	string locVarName = "__required_level__";
	auto res = getopt(args,
		"itemvalue", &twoDAPath,
		"locvar", &locVarName,
		"stats", &stats,
	);
	if(res.helpWanted){
		writefln("Usage: %s [options] uti_path...", args[0].baseName);
		writeln();
		writeln("Adjusts NWN2 item prices based on the required level defined by the local variable float '__required_level__' on the item.");
		writeln();
		writeln("Arguments:");
		writeln("  uti_path  Path to one or more UTI files, or directories containing UTI files");
		writeln();
		writeln("Options:");
		writeln("  --itemvalue=PATH  Path to the itemvalue.2da table. Uses the NWN2 stock table by default.");
		writeln("  --locvar          Name of the local var that sets the item required level. Defaults to '__required_level__'");
		writeln("  --stats           Show statistics");
		return;
	}

	// Load 2da
	TwoDA reqLevel2da;
	if(twoDAPath !is null)
		reqLevel2da = new TwoDA(twoDAPath);
	else
		reqLevel2da = new TwoDA(cast(ubyte[])import("itemvalue.2da"));

	// Adjust function
	size_t statsParsed, statsModified;
	void AdjustUti(in string file){
		auto item = new Gff(file);
		statsParsed++;

		try{
			Nullable!float targetLevel;
			foreach(ref var ; item["VarTable"].get!GffList){
				if(var["Name"].get!GffString == locVarName){
					if(var["Type"].get!GffDWord == 2){
						targetLevel = var["Value"].get!GffFloat;
					}
					else{
						stderr.writeln("ERROR: ", file.baseName, ": ", locVarName, " variable must be a float. Skipping item.");
					}
				}
			}

			if(!targetLevel.isNull){
				const priceMin = reqLevel2da["MAXSINGLEITEMVALUE", cast(int)targetLevel.get - 1].to!int;
				const priceMax = reqLevel2da["MAXSINGLEITEMVALUE", cast(int)targetLevel.get].to!int;

				const targetPrice = (priceMin + (priceMax - priceMin) * (targetLevel.get - cast(int)targetLevel.get)).to!long;
				const currentPrice = item["Cost"].get!GffDWord;
				const modCost = targetPrice - currentPrice;

				if(item["ModifyCost"].get!GffInt == modCost.to!GffInt)
					return;

				try{
					item["ModifyCost"].get!GffInt = modCost.to!GffInt;
					std.file.write(file, item.serialize());
					statsModified++;
					writeln(file.baseName, " => currentPrice=", currentPrice, " targetPrice=", targetPrice, " modCost=", modCost);
				}
				catch(ConvException){
					stderr.writeln("ERROR: ", file.baseName, " => currentPrice=", currentPrice, " targetPrice=", targetPrice, " modCost=", modCost, ": Cannot convert ", modCost, " to GffInt");
				}

			}
		}
		catch(Exception e){
			e.msg = "Exception for item " ~ file ~ ": " ~ e.msg;
			throw e;
		}
	}

	// Process files
	foreach(f ; args[1 .. $]){
		if(f.isDir){
			foreach(file ; parallel(args[1].dirEntries("*.uti", SpanMode.shallow))){
				AdjustUti(file);
			}
		}
		else if(f.isFile)
			AdjustUti(f);
		else
			stderr.writefln("ERROR: '%s' does not exist", f);
	}

	if(stats){
		writefln("%d items were checked, %d were modified.", statsParsed, statsModified);
	}

}
