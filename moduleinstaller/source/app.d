import std.stdio;
import std.path;
import std.file;
import std.getopt;
import std.string: toLower, splitLines;
import std.exception: enforce;
import std.array: split;
import std.process;

void info(T...)(T args){
	stderr.writeln("\x1b[32;1m", args, "\x1b[m");
}
void warning(T...)(T args){
	stderr.writeln("\x1b[33;1mWarning:\x1b[m ", args);
}
void error(T...)(T args){
	stderr.writeln("\x1b[31;40;1mError:\x1b[m ", args);
}


// Find a file in a folder case insensitively.
// If file is not found, will use the subFile value.
string subFileCI(in string path, in string subFile){
	if(!path.exists)
		return buildPath(path, subFile);
	foreach(file ; path.dirEntries(SpanMode.shallow)){
		if(filenameCmp!(CaseSensitive.no)(file.baseName, subFile) == 0)
			return file.name;
	}
	return buildPath(path, subFile);
}

int main(string[] args)
{



	string name = null;
	string branch = "origin/master";
	bool force = false;
	bool verbose = false;
	bool nogitupdate = false;

	auto res = getopt(args, config.passThrough,
		"name","Override module name", &name,
		"branch","Module git branch to install. Default: origin/master", &branch,
		"force|f","Delete and reinstall all module files", &force,
		"nogitupdate","Do not fetch/checkout git repo. Use as is. May need -f in some cases.", &nogitupdate,
		"verbose|v","Print all file operations", &verbose,
		);
	if(res.helpWanted || args.length != 3){
		defaultGetoptPrinter(
			args[0]~" module_git_repo nwn2home",
			res.options);
		return 0;
	}

	auto modulePath = args[1];
	auto nwnHomePath = args[2];

	enforce(modulePath.isDir, "module_git_repo does not exist");
	enforce(nwnHomePath.isDir, "nwn2home does not exist");

	auto moduleName = name is null? DirEntry(modulePath).baseName : name;

	auto outModuleDir = nwnHomePath.subFileCI("modules").subFileCI(moduleName);
	auto outOverrideDir = nwnHomePath.subFileCI("override").subFileCI(moduleName);
	auto outUnknownDir = nwnHomePath.subFileCI("override").subFileCI(moduleName~"-unknown");
	auto versionFile = nwnHomePath.subFileCI("modules").subFileCI(moduleName~"-version.txt");


	if(verbose){
		writeln("File destinations:");
		writeln("  NWN2 Home: ", nwnHomePath);
		writeln("  Module directory: ", outModuleDir);
		writeln("  Override directory: ", outOverrideDir);
		writeln("  Unknown files: ", outUnknownDir);
		writeln("  Version file: ", versionFile);
	}

	string fileDestination(in string file)
	{
		auto name = file.baseName.toLower();
		auto ext = name.extension;

		if(name[0] == '.')
			return null;

		switch(ext)
		{
			case ".are",".git",".trx",
				 ".ult",".upe",".utc",".utd",".ute",".uti",".utm",".utp",".utr",".utt",".utw",
				 ".ncs",
				 ".dlg",
				 ".fac",".jrl",
				 ".xml",".2da":
				return buildPath(outOverrideDir, name);

			case ".ifo",".gff":
				return buildPath(outModuleDir, name);

			case ".trn",".gic",".pfb",".dat",".nss",".ndb",
				".sublime-project":
				return null;

			default:
				warning("unknown extension ", ext);
				return buildPath(outUnknownDir, name);
		}
	}



	auto moduleGit = new GitRepo(modulePath, "git");

	if(nogitupdate == false){
		info("Fetching last commits...");
		enforce(moduleGit.fetch(), "Could not fetch latest commits");

		info("Clearing current repository state...");
		moduleGit.clear();

		info("Checking out branch ", branch,"...");
		moduleGit.upgrade(branch);
	}


	string installedVersion = null;
	if(versionFile.exists && versionFile.isFile)
		installedVersion = versionFile.readText;

	if(installedVersion == null || installedVersion.length == 0)
		force = true;

	if(force){
		//Wipe and reinstall everything
		info("No installed version found for module ", moduleName);

		info("Wiping existing installed files...");
		if(outModuleDir.exists){
			writeln(" rm ", outModuleDir);
			outModuleDir.rmdirRecurse;
		}
		outModuleDir.mkdirRecurse;
		if(outOverrideDir.exists){
			writeln(" rm ", outOverrideDir);
			outOverrideDir.rmdirRecurse;
		}
		outOverrideDir.mkdirRecurse;
		if(outUnknownDir.exists){
			writeln(" rm ", outUnknownDir);
			outUnknownDir.rmdirRecurse;
		}
		outUnknownDir.mkdirRecurse;
		if(versionFile.exists){
			writeln(" rm ", versionFile);
			versionFile.remove;
		}

		info("Installing module files...");
		foreach(file ; modulePath.dirEntries(SpanMode.shallow)){
			auto dest = fileDestination(file.name);
			if(dest is null){
				if(verbose) writeln(" STRIP ",file.baseName);
			}
			else{
				if(verbose) writeln(" COPY  ",file.baseName, " -> ", dest);
				copy(file, dest);
			}
		}
	}
	else{
		//Install only modified files
		info("Installed version found: ", installedVersion);

		auto diffs = moduleGit.getDiffs(installedVersion, moduleGit.getLocalCommitHash);

		foreach(ref diff ; diffs){
			auto dest = fileDestination(diff.file);

			if(dest is null){
				if(verbose) writeln(" STRIP ",diff.file);
			}
			else{
				switch(diff.type){
					case 'M'://Modified
						if(dest.exists)
						{
							if(verbose) writeln(" UPDAT ", diff.file.baseName, " -> ", dest);
							diff.file.copy(dest);
						}
						else
							error("Target file ", dest, " does not exist. Previous installation may have gone wrong. Try running with --force");
						break;

					case 'A'://Added
						if(!dest.exists)
						{
							if(verbose) writeln(" ADDED ", diff.file.baseName, " -> ", dest);
							diff.file.copy(dest);
						}
						else
							error("Target file ", dest, " already exist. Previous installation may have gone wrong. Try running with --force");
						break;
					case 'D':
						if(dest.exists)
						{
							if(verbose) writeln(" REMOV ", dest);
							dest.remove;
						}
						else
							error("Target file ", dest, " does not exist. Previous installation may have gone wrong. Try running with --force");
						break;
					default:
						assert(0, "Git diff type "~diff.type~" not handled");
				}
			}


		}
	}


	std.file.write(versionFile, moduleGit.getLocalCommitHash);
	info("Done !");
	return 0;
}






class GitRepo
{
public:
	this(string repositoryPath, string gitPath)
	{
		dir = repositoryPath;
		this.gitPath = gitPath;
	}

	string getLatestOriginCommitHash()
	{
		return executeGitCommand("rev-parse origin/"~getCurrentBranchName(), true).output;
	}
	string getLocalCommitHash()
	{
		return executeGitCommand("rev-parse "~getCurrentBranchName(), true).output;
	}

	string getCurrentBranchName()
	{
		return executeGitCommand("rev-parse --abbrev-ref HEAD", true).output;
	}

	string getBranchList()
	{
		return executeGitCommand("branch -a", true).output;
	}


	struct Diff
	{
		this(char _type, string _file){type=_type; file=_file;}
		char type;
		string file;
	}
	Diff[] getDiffs(string sFromCommitHash, string sToCommitHash)
	{
		import std.regex;
		static auto rgxDiff = regex(`^([MADRCU])\s+(.+)$`);
		Diff[] ret;

		string cmdOut = executeGitCommand("diff --name-status --no-renames "~sFromCommitHash~" "~sToCommitHash).output;
		foreach(string line ; cmdOut.splitLines)
		{
			auto results = match(line, rgxDiff);
			if(results)
				ret ~= Diff(results.captures[1][0],dir~"/"~results.captures[2]);
			else
				writeln("La ligne ",line," ne correspond pas à la regex de diff");

		}
		return ret;
	}


	bool fetch()
	{
		return executeGitCommand("fetch origin -a", false).status==0;
	}

	void clear()
	{
		executeGitCommand("reset --hard HEAD", true);
		executeGitCommand("clean -f", true);
	}

	bool upgrade(string sBranchName)
	{
		return executeGitCommand("checkout "~sBranchName).status==0;
	}



private:
	string gitPath;
	string dir;

	auto executeGitCommand(string cmd, bool silent=false)
	{
		string sDir = getcwd();
		chdir(dir);

		writeln("\x1b[2m>", gitPath, " ", cmd, "\x1b[m");
		string[] command = split(cmd);
		command = gitPath~command;
		auto cmdout = execute(command);

		chdir(sDir);

		if(!silent || cmdout.status>0)
			writeln("\x1b[2m", cmdout.output, "\x1b[m");

		return cmdout;
	}
}
