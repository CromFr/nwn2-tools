# Item price adjuster

This tool sets the items additional cost values in order to require a specific level.

The required level is defined by the local variable `__required_level__` (float) set on the item. Any item that does not have the local variable set is ignored and will not be adjusted.


Required level value examples:
- `5.0`: Require the level 5 or more to be wielded
- `5.2`: A bit more expensive, but still require level 5
- `5.9`: One of the priciest item that still require level 5

## Usage

```bash
./nwn2-adjust-item-prices --help
# Usage: nwn2-adjust-item-prices [options] uti_path...
# 
# Adjusts NWN2 item prices based on the required level defined by the local variable float '__required_level__' on the item.
# 
# Arguments:
#   uti_path  Path to one or more UTI files, or directories containing UTI files
# 
# Options:
#   --itemvalue=PATH  Path to the itemvalue.2da table. Uses the NWN2 stock table by default.

# Adjust all item prices in a module
./nwn2-adjust-item-prices modules/YourMod/

# Adjust all item prices with a custom itemvalue.2da
./nwn2-adjust-item-prices --itemvalue=override/itemvalue.2da modules/YourMod/
```


## Build

```bash
dub build -b release
```