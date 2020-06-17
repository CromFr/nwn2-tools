// Library to replace Campaign database operations with SQL queries
//
// Generated with https://cromfr.github.io/nwn2-tools/ nwn2-camtosql-upgrade-scripts
//
// Command-line: {{COMMANDLINE}}
//

#include "nwnx_sql"


// PRIVATE FUNCTIONS

// Private function, do not use
string _CampaignDB_VectorToString(vector vVec){
	return FloatToString(vVec.x, 0) + ";"+FloatToString(vVec.y, 0) + ";"+FloatToString(vVec.z, 0);
}

// Private function, do not use
string _CampaignDB_LocationToString(location lLoc){
	return GetTag(GetAreaFromLocation(lLoc))
		+ "#" + _CampaignDB_VectorToString(GetPositionFromLocation(lLoc))
		+ "#" + FloatToString(GetFacingFromLocation(lLoc), 0);
}

// Private function, do not use
vector _CampaignDB_StringToVector(string sVec){
	int nY = FindSubString(sVec, ";", 0) + 1;
	int nZ = FindSubString(sVec, ";", nY) + 1;

	return Vector(
		StringToFloat(GetSubString(sVec, 0, nY - 1)),
		StringToFloat(GetSubString(sVec, nY, nZ - 1 - nY)),
		StringToFloat(GetSubString(sVec, nZ, -1))
	);
}

// Private function, do not use
location _CampaignDB_StringToLocation(string sLoc){
	int nPos = FindSubString(sLoc, "#", 0) + 1;
	int nRot = FindSubString(sLoc, "#", nPos) + 1;

	return Location(
		GetObjectByTag(GetSubString(sLoc, 0, nPos - 1)),
		_CampaignDB_StringToVector(GetSubString(sLoc, nPos, nRot - 1 - nPos)),
		StringToFloat(GetSubString(sLoc, nRot, -1))
	);
}

// Private function, do not use
string _CampaignDB_EncodeTableName(string sName){
	string ret;

	sName = GetStringLowerCase(sName);
	int nLen = GetStringLength(sName);

	int i;
	for(i = 0 ; i < nLen ; i++)
	{
		string s = GetSubString(sName, i, 1);
		int c = CharToASCII(s);
		if(c == 0x27 // '
		|| c == 0x2D // -
		|| (c >= 0x30 && c <= 0x39) // 0-9
		|| c == 0x5F // _
		|| (c >= 0x61 && c <= 0x7A) // a-z
		)
			ret += s;
	}
	return ret;
}

// Private function, do not use
void _CampaignDB_CreateTable(string sCampaignName){
	SQLExecDirect(
		"CREATE TABLE IF NOT EXISTS `{{TABLE_NAME}}` ("
			{{COLUMN_CAMNAME_CREATE}}
			+ "`account_name` VARCHAR(64) NOT NULL,"
			+ "`character_name` VARCHAR(64) NOT NULL,"
			+ "`type` ENUM('float', 'int', 'vector', 'location', 'string', 'object') NOT NULL,"
			+ "`name` VARCHAR(64) NOT NULL,"
			+ "`value` TEXT NULL,"
			+ "`value_obj` LONGBLOB NULL,"
			+ "PRIMARY KEY ({{COLUMN_CAMNAME}} `account_name`, `character_name`, `type`, `name`)"
			{{CONSTRAINTS}}
		+ ") ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin"
	);
}

// Private function, do not use
void _CampaignDB_Upsert(string sCampaignName, object oPlayer, string sVarType, string sVarName, string sValue){
	sCampaignName = _CampaignDB_EncodeTableName(sCampaignName);

	if(!GetLocalInt(GetModule(), {{TABLE_INIT_VAR}})){
		SetLocalInt(GetModule(), {{TABLE_INIT_VAR}}, TRUE);
		_CampaignDB_CreateTable(sCampaignName);
	}

	string sAccount;
	string sCharName;
	if(GetIsObjectValid(oPlayer) && GetIsPC(oPlayer)){
		sAccount = SQLEncodeSpecialChars(GetPCPlayerName(oPlayer));
		sCharName = SQLEncodeSpecialChars(GetName(oPlayer));
	}
	SQLExecDirect(
		"INSERT INTO `{{TABLE_NAME}}` ({{INSERT_CAMNAME_COLUMN}}`account_name`,`character_name`,`type`,`name`,`value`,`value_obj`) VALUES("
			{{INSERT_CAMNAME_VALUE}}
			+ "'" + sAccount + "',"
			+ "'" + sCharName + "',"
			+ "'" + sVarType + "',"
			+ "'" + SQLEncodeSpecialChars(sVarName) + "',"
			+ "'" + SQLEncodeSpecialChars(sValue) + "', NULL)"
		+ "ON DUPLICATE KEY UPDATE `type`=VALUES(`type`), `value`=VALUES(`value`), `value_obj`=VALUES(`value_obj`)"
	);
}

// Private function, do not use
string _CampaignDB_Select(string sCampaignName, object oPlayer, string sVarType, string sVarName){
	sCampaignName = _CampaignDB_EncodeTableName(sCampaignName);

	string sAccount;
	string sCharName;
	if(GetIsObjectValid(oPlayer) && GetIsPC(oPlayer)){
		sAccount = SQLEncodeSpecialChars(GetPCPlayerName(oPlayer));
		sCharName = SQLEncodeSpecialChars(GetName(oPlayer));
	}
	SQLExecDirect(
		"SELECT `value` FROM `{{TABLE_NAME}}`"
		+ "WHERE `account_name`='" + sAccount + "'"
		+ " AND `character_name`='" + sCharName + "'"
		{{WHERE_CAMNAME}}
		+ " AND `type` = '" + sVarType + "'"
		+ " AND `name` = '" + SQLEncodeSpecialChars(sVarName) + "'"
	);
	if(SQLFetch())
		return SQLGetData(1);
	return "";
}

// PUBLIC FUNCTIONS

// Retrieve the value of a variable stored in the campaign SQL database. This
// function emulates GetCampaignString behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// Return: the stored string value.
string GetCampaignStringSQL(string sCampaignName, string sVarName, object oPlayer=OBJECT_INVALID){
	return _CampaignDB_Select(sCampaignName, oPlayer, "string", sVarName);
}

// Retrieve the value of a variable stored in the campaign SQL database. This
// function emulates GetCampaignFloat behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// Return: the stored float value.
float GetCampaignFloatSQL(string sCampaignName, string sVarName, object oPlayer=OBJECT_INVALID){
	return StringToFloat(_CampaignDB_Select(sCampaignName, oPlayer, "float", sVarName));
}

// Retrieve the value of a variable stored in the campaign SQL database. This
// function emulates GetCampaignInt behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// Return: the stored int value.
int GetCampaignIntSQL(string sCampaignName, string sVarName, object oPlayer=OBJECT_INVALID){
	return StringToInt(_CampaignDB_Select(sCampaignName, oPlayer, "int", sVarName));
}

// Retrieve the value of a variable stored in the campaign SQL database. This
// function emulates GetCampaignVector behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// Return: the stored vector value.
vector GetCampaignVectorSQL(string sCampaignName, string sVarName, object oPlayer=OBJECT_INVALID){
	return _CampaignDB_StringToVector(_CampaignDB_Select(sCampaignName, oPlayer, "vector", sVarName));
}

// Retrieve the value of a variable stored in the campaign SQL database. This
// function emulates GetCampaignLocation behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// Return: the stored location value.
location GetCampaignLocationSQL(string sCampaignName, string sVarName, object oPlayer=OBJECT_INVALID){
	return _CampaignDB_StringToLocation(_CampaignDB_Select(sCampaignName, oPlayer, "location", sVarName));
}



// Store a persistent variable in the campaign SQL database. This function
// emulates SetCampaignString behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// - sString: String value to store
void SetCampaignStringSQL(string sCampaignName, string sVarName, string sString, object oPlayer=OBJECT_INVALID){
	_CampaignDB_Upsert(sCampaignName, oPlayer, "string", sVarName, sString);
}

// Store a persistent variable in the campaign SQL database. This function
// emulates SetCampaignFloat behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// - fFloat: Float value to store
void SetCampaignFloatSQL(string sCampaignName, string sVarName, float fFloat, object oPlayer=OBJECT_INVALID){
	_CampaignDB_Upsert(sCampaignName, oPlayer, "float", sVarName, FloatToString(fFloat, 0));
}

// Store a persistent variable in the campaign SQL database. This function
// emulates SetCampaignInt behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// - nInt: Int value to store
void SetCampaignIntSQL(string sCampaignName, string sVarName, int nInt, object oPlayer=OBJECT_INVALID){
	_CampaignDB_Upsert(sCampaignName, oPlayer, "int", sVarName, IntToString(nInt));
}

// Store a persistent variable in the campaign SQL database. This function
// emulates SetCampaignVector behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// - vVector: Vector value to store
void SetCampaignVectorSQL(string sCampaignName, string sVarName, vector vVector, object oPlayer=OBJECT_INVALID){
	_CampaignDB_Upsert(sCampaignName, oPlayer, "vector", sVarName, _CampaignDB_VectorToString(vVector));
}

// Store a persistent variable in the campaign SQL database. This function
// emulates SetCampaignLocation behavior.
//
// <u>Compatibility notes</u>: The built-in SetCampaignLocation stores the
// area information as an object ID, however this is very unreliable as the ID
// often change when the module is modified. This function stores the area tag
// instead, making it more reliable <b>as long as the tag is unique</b>.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// - lLocation: Location value to store
void SetCampaignLocationSQL(string sCampaignName, string sVarName, location lLocation, object oPlayer=OBJECT_INVALID){
	_CampaignDB_Upsert(sCampaignName, oPlayer, "location", sVarName, _CampaignDB_LocationToString(lLocation));
}


// Remove a specific variable from a campaign SQL database. This function
// emulates DeleteCampaignVariable behavior.
//
// <u>Compatibility notes</u>: Like DeleteCampaignVariable, the variable is
// not effectively removed from the SQL database, instead its value is set to
// NULL. Use PackCampaignDatabaseSQL to definitively remove any previously
// deleted variables.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
void DeleteCampaignVariableSQL(string sCampaignName, string sVarName, object oPlayer=OBJECT_INVALID){
	sCampaignName = _CampaignDB_EncodeTableName(sCampaignName);

	string sAccount;
	string sCharName;
	if(GetIsObjectValid(oPlayer) && GetIsPC(oPlayer)){
		sAccount = SQLEncodeSpecialChars(GetPCPlayerName(oPlayer));
		sCharName = SQLEncodeSpecialChars(GetName(oPlayer));
	}
	SQLExecDirect(
		"UPDATE `{{TABLE_NAME}}`"
		+ " SET `value`=NULL, `value_obj`=NULL"
		+ " WHERE `account_name`='" + sAccount + "'"
		+ " AND `character_name`='" + sCharName + "'"
		{{WHERE_CAMNAME}}
		+ " AND `name` = '" + SQLEncodeSpecialChars(sVarName) + "'"
	);
}

// Destroy all variables stored in the campaign SQL database. All data stored
// in sCampaignName campaign SQL database will be lost forever. This function
// emulates DestroyCampaignDatabase behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
void DestroyCampaignDatabaseSQL(string sCampaignName){
	sCampaignName = _CampaignDB_EncodeTableName(sCampaignName);
	{{DESTROY_CODE}}
}




// Store a creature or item object in the campaign SQL database. The object is
// serialized to GFF (quite similar to how items are stored in a BIC file) and
// stored as a binary blob. This function emulates StoreCampaignObject
// behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// - oObject: Item or creature to store
// Return: TRUE if the object has been stored, FALSE otherwise
int StoreCampaignObjectSQL(string sCampaignName, string sVarName, object oObject, object oPlayer=OBJECT_INVALID){
	sCampaignName = _CampaignDB_EncodeTableName(sCampaignName);

	if(!GetLocalInt(GetModule(), {{TABLE_INIT_VAR}})){
		SetLocalInt(GetModule(), {{TABLE_INIT_VAR}}, TRUE);
		_CampaignDB_CreateTable(sCampaignName);
	}

	string sAccount;
	string sCharName;
	if(GetIsObjectValid(oPlayer) && GetIsPC(oPlayer)){
		sAccount = SQLEncodeSpecialChars(GetPCPlayerName(oPlayer));
		sCharName = SQLEncodeSpecialChars(GetName(oPlayer));
	}
	SQLSCORCOExec(
		"INSERT INTO `{{TABLE_NAME}}` ({{INSERT_CAMNAME_COLUMN}}`account_name`,`character_name`,`type`,`name`,`value`,`value_obj`) VALUES("
			{{INSERT_CAMNAME_VALUE}}
			+ "'" + sAccount + "',"
			+ "'" + sCharName + "',"
			+ "'object',"
			+ "'" + SQLEncodeSpecialChars(sVarName) + "',"
			+ "NULL,"
			+ "%s) ON DUPLICATE KEY UPDATE `type`=VALUES(`type`), `value`=VALUES(`value`), `value_obj`=VALUES(`value_obj`)"
	);
	SQLStoreObject(oObject);
	return SQLGetAffectedRows() == 1;
}


// Retrieve and create a creature or item object that is stored in the campaign SQL
// database. This function emulates RetrieveCampaignObject behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
// - sVarName: Variable name
// - lLocation: Location where the object will be created, if the object is a
//   creature, or if oOwner is invalid.
// - oOwner: If the stored object is an item, it will be created in oOwner's
//   inventory.
// - oPlayer: Variable owner. Set to a player object to tie the variable to a
//   player's account and character name.
// Return: the retrieved and created item or creature object
object RetrieveCampaignObjectSQL(string sCampaignName, string sVarName, location lLocation, object oOwner=OBJECT_INVALID, object oPlayer=OBJECT_INVALID){
	sCampaignName = _CampaignDB_EncodeTableName(sCampaignName);

	string sAccount;
	string sCharName;
	if(GetIsObjectValid(oPlayer) && GetIsPC(oPlayer)){
		sAccount = SQLEncodeSpecialChars(GetPCPlayerName(oPlayer));
		sCharName = SQLEncodeSpecialChars(GetName(oPlayer));
	}

	SQLSCORCOExec(
		"SELECT `value_obj` FROM `{{TABLE_NAME}}`"
		+ " WHERE `account_name`='" + sAccount + "'"
		+ " AND `character_name`='" + sCharName + "'"
		+ " AND `type` = 'object'"
		+ " AND `name` = '" + SQLEncodeSpecialChars(sVarName) + "'"
	);
	return SQLRetrieveObject(lLocation, oOwner);
}


// Effectively remove SQL rows that have been deleted using
// DeleteCampaignVariableSQL. This function emulates PackCampaignDatabase
// behavior.
//
// Args:
// - sCampaignName: Campaign name (case sensitive)
void PackCampaignDatabaseSQL(string sCampaignName){
	sCampaignName = _CampaignDB_EncodeTableName(sCampaignName);

	SQLExecDirect(
		"DELETE FROM `{{TABLE_NAME}}` WHERE `value` IS NULL AND `value_obj` IS NULL"
		{{WHERE_CAMNAME}}
	);
}


