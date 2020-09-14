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
	auto res = getopt(args,
		"itemvalue", &twoDAPath,
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
		return;
	}

	TwoDA reqLevel2da;
	if(twoDAPath !is null)
		reqLevel2da = new TwoDA(twoDAPath);
	else
		reqLevel2da = new TwoDA(cast(ubyte[])import("itemvalue.2da"));

	foreach(file ; parallel(args[1].dirEntries("*.uti", SpanMode.shallow))){
		auto item = new Gff(file);

		try{
			Nullable!float targetLevel;
			foreach(ref var ; item["VarTable"].as!(GffType.List)){
				if(var["Name"].as!(GffType.ExoString) == "__required_level__"){
					targetLevel = var["Value"].as!(GffType.Float);
				}
			}

			if(!targetLevel.isNull){


				const priceMin = reqLevel2da[cast(int)targetLevel.get - 1, "MAXSINGLEITEMVALUE"].to!int;
				const priceMax = reqLevel2da[cast(int)targetLevel.get, "MAXSINGLEITEMVALUE"].to!int;

				const targetPrice = (priceMin + (priceMax - priceMin) * (targetLevel.get - cast(int)targetLevel.get)).to!long;
				const currentPrice = item["Cost"].as!(GffType.DWord);
				const modCost = targetPrice - currentPrice;

				try{
					item["ModifyCost"].as!(GffType.Int) = modCost.to!GffInt;
					std.file.write(file, item.serialize());
					writeln(file.baseName, " => currentPrice=", currentPrice, " targetPrice=", targetPrice, " modCost=", modCost);
				}
				catch(ConvException){

					writeln("ERROR: ", file.baseName, " => currentPrice=", currentPrice, " targetPrice=", targetPrice, " modCost=", modCost, ": Cannot convert ", modCost, " to GffInt");
				}

			}
		}
		catch(Exception e){
			e.msg = "Exception for item " ~ file ~ ": " ~ e.msg;
			throw e;
		}

	}

}
