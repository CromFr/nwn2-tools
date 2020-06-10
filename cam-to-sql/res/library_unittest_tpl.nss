// Unit-test file for checking that the SQL database works as intended.
// You can run this script using the DM console: rs unittest_{{LIB_NAME}}
//
// Generated with https://cromfr.github.io/nwn2-tools/ nwn2-cam-to-sql-upgrade-scripts
//
// Command-line: {{COMMANDLINE}}
//

#include "{{LIB_NAME}}"

const string DB = "_unittest_cam_sql_db";

int CmpVectors(vector vA, vector vB){
	return VectorMagnitude(vA - vB) < 0.001;
}
int CmpLocations(location lA, location lB){
	if(GetAreaFromLocation(lA) != GetAreaFromLocation(lB))
		return FALSE;
	if(GetDistanceBetweenLocations(lA, lB) > 0.001)
		return FALSE;
	float fDiff = GetFacingFromLocation(lA) - GetFacingFromLocation(lB);
	while(fDiff < 0.0)
		fDiff += 360.0;
	while(fDiff >= 360.0)
		fDiff -= 360.0;
	if(fabs(GetFacingFromLocation(lA) - GetFacingFromLocation(lB)) > 0.001)
		return FALSE;
	return TRUE;
}

// Call this function to be sure everything is right with the migration
void main(){
	object o = OBJECT_SELF;

	// Insertion
	SetCampaignStringSQL(DB, "StringExample", "Hello", o);
	if(GetCampaignStringSQL(DB, "StringExample", o) != "Hello") SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	SetCampaignFloatSQL(DB, "FloatExample", 42f, o);
	if(GetCampaignFloatSQL(DB, "FloatExample", o) != 42f) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	SetCampaignIntSQL(DB, "IntExample", 12, o);
	if(GetCampaignIntSQL(DB, "IntExample", o) != 12) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	vector vSelf = GetPosition(o);
	SetCampaignVectorSQL(DB, "VectorExample", vSelf, o);
	if(!CmpVectors(GetCampaignVectorSQL(DB, "VectorExample", o), vSelf)) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	location lSelf = GetLocation(o);
	SetCampaignLocationSQL(DB, "LocationExample", lSelf, o);
	if(!CmpLocations(GetCampaignLocationSQL(DB, "LocationExample", o), lSelf)) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	// Modification
	SetCampaignStringSQL(DB, "StringExample", "World", o);
	if(GetCampaignStringSQL(DB, "StringExample", o) != "World") SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	// Deletion
	DeleteCampaignVariableSQL(DB, "StringExample", o);
	if(GetCampaignStringSQL(DB, "StringExample", o) != "") SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	DeleteCampaignVariableSQL(DB, "FloatExample", o);
	if(GetCampaignFloatSQL(DB, "FloatExample", o) != 0f) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	DeleteCampaignVariableSQL(DB, "IntExample", o);
	if(GetCampaignIntSQL(DB, "IntExample", o) != 0) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	DeleteCampaignVariableSQL(DB, "VectorExample", o);
	if(GetCampaignVectorSQL(DB, "VectorExample", o) != Vector(0f, 0f, 0f)) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	DeleteCampaignVariableSQL(DB, "LocationExample", o);
	if(GetIsLocationValid(GetCampaignLocationSQL(DB, "LocationExample", o))) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	// Packing
	SetCampaignFloatSQL(DB, "FloatExample2", 1337f, o);
	PackCampaignDatabaseSQL(DB);
	if(GetCampaignStringSQL(DB, "StringExample", o) != "") SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));
	if(GetCampaignFloatSQL(DB, "FloatExample2", o) != 1337f) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));

	// SCORCO
	object oItem = CreateItemOnObject("nw_wswss001", o);
	if(!GetIsObjectValid(oItem)) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));
	if(!StoreCampaignObjectSQL(DB, "ObjectExample", oItem, o)) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__) + " (StoreCampaignObjectSQL, check that your xp_mysql plugin supports SCORCO)");

	object oRetrieved = RetrieveCampaignObjectSQL(DB, "ObjectExample", GetLocation(o), o, o);
	if(!GetIsObjectValid(oRetrieved)) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__) + " (RetrieveCampaignObjectSQL, check that your xp_mysql plugin supports SCORCO)");

	DestroyObject(oItem);
	DestroyObject(oRetrieved);

	// Destroy database
	DestroyCampaignDatabaseSQL(DB);
	if(GetCampaignFloatSQL(DB, "FloatExample2", o) != 0f) SpeakString(__FILE__ + ": Error on line " + IntToString(__LINE__));
}