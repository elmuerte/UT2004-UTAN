/*******************************************************************************
	UpdateAP																	<br />
	UpdateAP downloads the updated access policy list every set interval when
	the	game starts.															<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2004 Michiel "El Muerte" Hendriks									<br />
	...UTAN License ...
	<!-- $Id: UpdateAP.uc,v 1.2 2004/04/18 20:24:50 elmuerte Exp $ -->
*******************************************************************************/

class UpdateAP extends Info config;

/** weblocation of the AP list to use */
var(Config) config string 	APLocation;
/** last time the list was accessed */
var(Config) config int 		LastUpdate;
/** minimal minutes between updates */
var(Config) config int		UpdateInterval;
/** purge the AP list on every update */
var(Config) config bool 	PurgeOnUpdate;
/** only add new AP entries, never remove */
var(Config) config bool 	OnlyAdd;

var protected HttpSock htsock;

/** prefix for additions */
const AP_ADD = "+";
/** prefix for APs to remove */
const AP_DEL = "-";

var localized string PILabel[4], PIDesc[4];

event PreBeginPlay()
{
	super.PreBeginPlay();
	if (Level.Game.AccessControl == none)
	{
		Error("Level.Game.AccessControl == none");
		return;
	}
	if ((APLocation != "") && (now()-LastUpdate > (UpdateInterval*60))) UpdateAPList();
}

/** request the page */
function UpdateAPList()
{
	log("Retrieving access policy...", name);
	htsock = spawn(class'HttpSock');
	htsock.OnComplete = APListDownloaded;
	htsock.OnError = APListError;
	htsock.HttpRequest(APLocation);
}

/** HttpSock returned an error */
function APListError(string ErrorMessage, optional string Param1, optional string Param2)
{
	log("Error retrieving access policy list, message:"@ErrorMessage@Param1@Param2, name);
}

/** Download complete, process the data */
function APListDownloaded()
{
	local int i, j;
	local string tmp;

	if (htsock.LastStatus != 200)
	{
		Log("Last HTTP result != 200 Ok", name);
		return;
	}
	if (PurgeOnUpdate)
	{
		log("Purging old access policy", name);
		Level.Game.AccessControl.IPPolicies.length = 0;
		Level.Game.AccessControl.BannedIDs.length = 0;
	}
	for (i = 0; i < htsock.ReturnData.length; i++)
	{
		tmp = htsock.ReturnData[i];
		if (Left(tmp, 1) ~= AP_ADD)
		{
			tmp = Mid(tmp, 1);
			if (IsIDBan(tmp))
			{
				for (j = 0; j < Level.Game.AccessControl.BannedIDs.length; j++)
				{
					if (Level.Game.AccessControl.BannedIDs[j] ~= tmp) break;
				}
				if (j == Level.Game.AccessControl.BannedIDs.length)
				{
					log("Added BannedID:"@tmp, name);
					Level.Game.AccessControl.BannedIDs[j] = tmp;
				}
			}
			else {
				for (j = 0; j < Level.Game.AccessControl.IPPolicies.length; j++)
				{
					if (Level.Game.AccessControl.IPPolicies[j] == tmp) break;
				}
				if (j == Level.Game.AccessControl.IPPolicies.length)
				{
					log("Added IPPolicies:"@tmp, name);
					Level.Game.AccessControl.IPPolicies[j] = tmp;
				}
			}
		}
		else if (Left(tmp, 1) ~= AP_DEL)
		{
			if (OnlyAdd) continue;
			tmp = Mid(tmp, 1);
			if (IsIDBan(tmp))
			{
				for (j = 0; j < Level.Game.AccessControl.BannedIDs.length; j++)
				{
					if (Level.Game.AccessControl.BannedIDs[j] ~= tmp) break;
				}
				if (j < Level.Game.AccessControl.BannedIDs.length)
				{
					log("Removed BannedID:"@tmp, name);
					Level.Game.AccessControl.BannedIDs.Remove(j, 1);
				}
			}
			else {
				for (j = 0; j < Level.Game.AccessControl.IPPolicies.length; j++)
				{
					if (Level.Game.AccessControl.IPPolicies[j] == tmp) break;
				}
				if (j < Level.Game.AccessControl.IPPolicies.length)
				{
					log("Removed IPPolicies:"@tmp, name);
					Level.Game.AccessControl.IPPolicies.Remove(j, 1);
				}
			}
		}
	}
	LastUpdate = now();
	SaveConfig();
	Level.Game.AccessControl.SaveConfig();
}



/** Returns the current timestamp */
function int now()
{
	return class'HttpUtil'.static.timestamp(Level.Year, Level.Month, Level.Day, Level.Hour, Level.Minute, Level.Second);
}

/** returns true when the ban is a ID ban */
function bool IsIDBan(string AP)
{
	AP = Left(AP, InStr(AP, ";"));
	return !((AP ~= "ACCEPT") || (AP ~= "DENY"));
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
	super.FillPlayInfo(PlayInfo);
	PlayInfo.AddSetting("UTAN", "APLocation", 		default.PILabel[0], 255, 1, "Text"	,,"",,true);
	PlayInfo.AddSetting("UTAN", "UpdateInterval", 	default.PILabel[1], 255, 2, "Text"	,"5;1-99999","",,true);
	PlayInfo.AddSetting("UTAN", "PurgeOnUpdate", 	default.PILabel[2], 255, 3, "Check"	,,"",,true);
	PlayInfo.AddSetting("UTAN", "OnlyAdd", 			default.PILabel[3], 255, 4, "Check"	,,"",,true);
}

static event string GetDescriptionText(string PropName)
{
	switch (PropName)
	{
		case "APLocation":		return default.PIDesc[0];
		case "UpdateInterval":	return default.PIDesc[1];
		case "PurgeOnUpdate":	return default.PIDesc[2];
		case "OnlyAdd":			return default.PIDesc[3];
	}
	return "";
}

defaultproperties
{
	PurgeOnUpdate=false
	UpdateInterval=30
	OnlyAdd=false

	PILabel[0]="Location"
	PILabel[1]="Update Interval"
	PILabel[2]="Purge on update"
	PILabel[3]="Only add"

	PIDesc[0]="Weblocation of the Access Policy list"
	PIDesc[1]="Minuted between updates"
	PIDesc[2]="Purge all old access policies when updating"
	PIDesc[3]="Only add policies, don't remove any"
}
