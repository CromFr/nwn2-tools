# Module installer tool

If your module is versioned using Git, this tool can help you:

- Update your git repository
- Copy/remove changed files to the installed module copy
- Get faster loading times by using the override folder when possible (files
  inside module folder get duplicated during module load)
- __Cons__: you will need to commit compiled scripts inside the repository


The following folders will be populated:

- `.are .git .trx .ult .upe .utc .utd .ute .uti .utm .utp .utr .utt .utw .ncs .dlg .fac .jrl .xml .2da`
    + into: `$nwn2home/Override/ModuleName`
- `.ifo .gff`
    + into: `$nwn2home/Modules/ModuleName`
- `.trn .gic .pfb .dat .nss .ndb`
    + are removed / ignored
- Other files are pun into `$nwn2home/Override/ModuleName-unknown` for the sake of safety


This tool is only suited for server setup, as it will populate the override
folder with module files.


## Usage

```bash
nwn2-moduleinstaller --help
# ./nwn2-moduleinstaller module_git_repo nwn2home
#           --name Override module name
#         --branch Module git branch to install. Default: origin/master
# -f       --force Delete and reinstall all module files
#    --nogitupdate Do not fetch/checkout git repo. Use as is. May need -f in some cases.
# -v     --verbose Print all file operations
# -h        --help This help information.
```



## Build

```bash
dub build -b release
```