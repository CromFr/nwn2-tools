import std.stdio;
import std.getopt;
import std.path;
import std.array;
import std.exception;
import nwn.gff;

import std.getopt;

int main(string[] args)
{
	bool keepInv = false;
	bool rmEquip = false;
	GffWord factionId = 2;
	string[] scripts;
	string classification;
	auto res = getopt(args,
		"inventory|i", "Keep character inventory", &keepInv,
		"no-equip|e", "Remove equipment", &rmEquip,
		"faction|f", "Set faction ID (defaults to 2 = Commoner)", &factionId,
		"script|s", "Override the default creature scripts. Syntax is <event>:<script_name>."
		~ " Events can be: Attacked, Damaged, Death, Dialogue, Disturbed, EndRound, Heartbeat, OnBlocked, OnNotice, Rested, Spawn, SpellAt, UserDefine."
		~ " Example: --script=Attacked:custom_script", &factionId,
		"classification|c", "Set blueprint classification (so it's easier to find in the toolset)", &classification,
	);
	if(res.helpWanted){
		defaultGetoptPrinter(
			"Convert BIC character files to UTC blueprints\nUsage: " ~ args[0].baseName ~ " [options] infile.bic [outfile.utc]",
			res.options);
		return 0;
	}

	if(args.length != 2 && args.length != 3){
		writeln("Usage: ", args[0].baseName, " [options] infile.bic [outfile.utc]");
		return 1;
	}

	string[string] scriptsOverride;
	foreach(s ; scripts){
		auto spl = s.split(":");
		enforce(spl.length == 2, "Error: syntax for script overrides is: <event>:<script_name>");
		scriptsOverride[spl[0]] = spl[1];
	}

	auto targetFile = args.length == 3? args[2] : args[1].setExtension("utc");

	auto gff = new Gff(args[1]);


	immutable resref = args[1].baseName.stripExtension;

	gff.fileType = "UTC";

	if(rmEquip){
		// Remove equipped items
		gff["Equip_ItemList"].get!GffList.length = 0;
	}
	else{
		//Set item list resrefs
		foreach(ref item ; gff["Equip_ItemList"].get!GffList){

			auto newItem = GffStruct();
			newItem.id = item.id;
			newItem["Repos_PosX"] = GffWord(0);
			newItem["Repos_PosY"] = GffWord(0);
			newItem["Pickpocketable"] = GffByte(0);
			newItem["Dropable"] = GffByte(0);
			newItem["EquippedRes"] = GffResRef(item["TemplateResRef"].to!string);

			item = newItem;
		}
	}

	if(keepInv){
		//Set item list resrefs
		foreach(ref item ; gff["ItemList"].get!GffList){

			auto newItem = GffStruct();
			newItem.id = item.id;
			newItem["Repos_PosX"] = GffWord(0);
			newItem["Repos_PosY"] = GffWord(0);
			newItem["Pickpocketable"] = GffByte(0);
			newItem["Dropable"] = GffByte(0);
			newItem["EquippedRes"] = GffResRef(item["TemplateResRef"].to!string);

			item = newItem;
		}
	}
	else{
		//Remove inventory items
		gff["ItemList"].get!GffList.length = 0;
	}

	//Set misc
	gff["TemplateResRef"].get!GffResRef = resref;
	gff["Tag"].get!GffString = resref;
	gff["FactionID"].get!GffWord = factionId;
	gff["Classification"] = classification;
	gff["IsPC"].get!GffByte = 0;

	foreach(key ; [
		"LvlStatList",
		"CombatInfo",
		"SkillPoints",
		"Experience",
		"PregameCurrent",
		"Gold",
		"oidTarget",
		"MasterID",
		"OnHandAttacks",
		"OffHandAttacks",
		"AttackResult",
		"DamageMin",
		"DamageMax",
		"BlockBroadcast",
		"BlockRespond",
		"IgnoreTarget",
		"BlockCombat",
		"UnrestrictLU",
		"DetectMode",
		"StealthMode",
		"TrackingMode",
		"EnhVisionMode",
		"HlfrBlstMode",
		"HlfrShldMode",
		"DefCastMode",
		"CombatMode",
		"RosterTag",
		"RosterMember",
		"CustomHeartbeat",
		"PossBlocked",
		"BodyBagId",
		"OriginAttacked",
		"OriginDamaged",
		"OriginDeath",
		"OriginDialogue",
		"OriginDisturbed",
		"OriginEndRound",
		"OriginHeartbeat",
		"OriginOnBlocked",
		"OriginOnNotice",
		"OriginRested",
		"OriginSpawn",
		"OriginSpellAt",
		"OriginUserDefine",
		"ScriptsBckdUp",
		"PerceptionList",
		"CombatRoundData",
		"AreaId",
		"SitObject",
		"AmbientAnimState",
		"PM_IsPolymorphed",
		"Listening",
		"XPosition",
		"YPosition",
		"ZPosition",
		"XOrientation",
		"YOrientation",
		"ZOrientation",
		"AnimationDay",
		"AnimationTime",
		"HotbarList",
		"CreatnScrptFird",
		]){
		if(key in gff)
			gff.root.remove(key);
	}


	//Set scripts
	gff["ScriptAttacked"].get!GffResRef = scriptsOverride.get("Attacked", "nw_c2_default5");
	gff["ScriptDamaged"].get!GffResRef = scriptsOverride.get("Damaged", "nw_c2_default6");
	gff["ScriptDeath"].get!GffResRef = scriptsOverride.get("Death", "nw_c2_default7");
	gff["ScriptDialogue"].get!GffResRef = scriptsOverride.get("Dialogue", "nw_c2_default4");
	gff["ScriptDisturbed"].get!GffResRef = scriptsOverride.get("Disturbed", "nw_c2_default8");
	gff["ScriptEndRound"].get!GffResRef = scriptsOverride.get("EndRound", "nw_c2_default3");
	gff["ScriptHeartbeat"].get!GffResRef = scriptsOverride.get("Heartbeat", "nw_c2_default1");
	gff["ScriptOnBlocked"].get!GffResRef = scriptsOverride.get("OnBlocked", "nw_c2_defaulte");
	gff["ScriptOnNotice"].get!GffResRef = scriptsOverride.get("OnNotice", "nw_c2_default2");
	gff["ScriptRested"].get!GffResRef = scriptsOverride.get("Rested", "nw_c2_defaulta");
	gff["ScriptSpawn"].get!GffResRef = scriptsOverride.get("Spawn", "nw_c2_default9");
	gff["ScriptSpellAt"].get!GffResRef = scriptsOverride.get("SpellAt", "nw_c2_defaultb");
	gff["ScriptUserDefine"].get!GffResRef = scriptsOverride.get("UserDefine", "nw_c2_defaultd");



	//Write file
	import std.file: writeFile = write;
	writeFile(targetFile, gff.serialize());

	return 0;
}
