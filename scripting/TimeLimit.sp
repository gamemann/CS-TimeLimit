#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <nextmap>
#undef REQUIRE_EXTENSIONS
#include <cstrike>
#define REQUIRE_EXTENSIONS

#define PL_VERSION "1.0.2"

public Plugin myinfo = 
{
	name = "[CS]Time Limit Enforcer",
	author = "Roy (Christian Deacon) & Ariistuujj",
	description = "Time limit enforcer using option two.",
	version = PL_VERSION,
	url = "GFLClan.com"
};

/* ConVars */
ConVar g_cvEnabled = null;
ConVar g_cvWarnings = null;
ConVar g_cvConfig = null;
ConVar g_cvTimeLimitSet = null;
ConVar g_cvMaxRoundsSet = null;
ConVar g_cvChangeType = null;

ConVar g_cvIgnoreCond = null;
ConVar g_cvRestartDelay = null;
ConVar g_cvTimeLimit = null;
ConVar g_cvMaxRounds = null;

/* ConVar values */
bool g_bEnabled;
bool g_bWarnings;
char g_sConfig[PLATFORM_MAX_PATH];
int g_iTimeLimitSet;
int g_iMaxRoundsSet;
int g_iChangeType;

/* Other Variables. */
Handle g_hCountDown = null;
Handle g_hWarningTimer = null;
KeyValues g_kvWarnings = null;

public void OnPluginStart() 
{
	// ConVars.
	g_cvEnabled = CreateConVar("sm_tl_enabled", "1", "Enable \"Time Limit Enforcer\"?");
	HookConVarChange(g_cvEnabled, ConVarChanged);	
	
	g_cvWarnings = CreateConVar("sm_tl_warning", "1", "If 1, a timer will spawn (executes every second) and will warn players with time left (configured in configs/TimeLimit-Warnings.cfg).");
	HookConVarChange(g_cvWarnings, ConVarChanged);	
	
	g_cvConfig = CreateConVar("sm_tl_config", "configs/TimeLimit-Warnings.cfg", "Path to the Warnings configuration file.");
	HookConVarChange(g_cvConfig, ConVarChanged);
	
	g_cvTimeLimitSet = CreateConVar("sm_tl_timelimit_set", "0", "Set the 'mp_timelimit' ConVar to this when the round ends.");
	HookConVarChange(g_cvTimeLimitSet, ConVarChanged);	

	g_cvMaxRoundsSet = CreateConVar("sm_tl_maxrounds_set", "0", "Set the 'mp_maxrounds' ConVar to this when the round ends.");
	HookConVarChange(g_cvMaxRoundsSet, ConVarChanged);	
	
	g_cvChangeType = CreateConVar("sm_tl_change_type", "0", "0 = Use 'CS_TerminateRound' to end the map (requires cstrike). 1 = Uses 'ForceChangeLevel' within 'nextmap'.");
	HookConVarChange(g_cvChangeType, ConVarChanged);
	
	g_cvIgnoreCond = FindConVar("mp_ignore_round_win_conditions");
	g_cvRestartDelay = FindConVar("mp_round_restart_delay");
	g_cvTimeLimit = FindConVar("mp_timelimit");
	g_cvMaxRounds = FindConVar("mp_maxrounds");
	
	// Translations.
	LoadTranslations("TimeLimit.phrases.txt");
	LoadTranslations("TimeLimit-Warnings.phrases.txt");
	
	// Commands.
	RegAdminCmd("sm_endround", Command_EndRound, ADMFLAG_ROOT);
	
	// Config.
	AutoExecConfig(true, "sm_timelimit");
}

public void ConVarChanged(Handle hCvar, const char[] oldV, const char[] newV)
{
	OnConfigsExecuted();
}

public void OnMapTimeLeftChanged()
{
	// Recreate the timer, etc.

	delete g_hCountDown;

	ResetTimeLeft();
}

public void OnConfigsExecuted()
{
	g_bEnabled = GetConVarBool(g_cvEnabled);
	g_bWarnings = GetConVarBool(g_cvWarnings);
	GetConVarString(g_cvConfig, g_sConfig, sizeof(g_sConfig));
	g_iTimeLimitSet = GetConVarInt(g_cvTimeLimitSet);
	g_iMaxRoundsSet = GetConVarInt(g_cvMaxRoundsSet);
	g_iChangeType = GetConVarInt(g_cvChangeType);
	
	// Start/Stop warnings timer.
	if (g_bWarnings)
	{
		// Configure warnings.
		if (g_kvWarnings == null)
		{
			char sFile[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sFile, sizeof(sFile), "%s", g_sConfig);
			
			g_kvWarnings = CreateKeyValues("Warnings");
			FileToKeyValues(g_kvWarnings, sFile);
		}
		
		// Start the timer if it isn't started already.
		g_hWarningTimer = CreateTimer(1.0, Timer_Warning, _, TIMER_REPEAT);
	}
	else
	{
		// Stop the timer.
		delete g_hWarningTimer;
		
		// Close key values.
		delete g_kvWarnings;
	}
}

public Action Command_EndRound(int iClient, int iArgs) 
{
	EndGame();
	CReplyToCommand(iClient, "%t%t", "Tag", "EndRoundCmd")
	
	return Plugin_Handled;
}

stock void EndGame() 
{
	if (!g_bEnabled)
	{
		return;
	}
	
	// Get the next map.
	char sNextMap[MAX_NAME_LENGTH];
	GetNextMap(sNextMap, sizeof(sNextMap));
	
	// Set "mp_ignore_round_win_conditions" to 0.
	if (g_cvIgnoreCond != null)
	{
		SetConVarInt(g_cvIgnoreCond, 0, false, false);
	}
	
	// Set "mp_timelimit" to CVar value.
	if (g_cvTimeLimit != null)
	{
		SetConVarInt(g_cvTimeLimit, g_iTimeLimitSet, false, false);
	}

	// Set "mp_maxrounds" to CVar value.
	if (g_cvMaxRounds != null)
	{
		SetConVarInt(g_cvMaxRounds, g_iMaxRoundsSet, false, false);
	}
	
	// Now terminate the round!
	if (g_iChangeType == 0)
	{
		CS_TerminateRound((g_cvRestartDelay != null && g_cvRestartDelay.FloatValue > 0) ? g_cvRestartDelay.FloatValue : 1.0, CSRoundEnd_Draw, false);
	}
	else
	{
		ForceChangeLevel(sNextMap, "Time limit is up");
	}
	
	CPrintToChatAll("%t%t", "Tag", "NextMapMsg", sNextMap);
}

stock void ResetTimeLeft()
{
	if (!g_bEnabled)
	{
		return;
	}
	
	// Get new time left.
	int iTimeLeft;
	GetMapTimeLeft(iTimeLeft);
	
	// Check the value.
	if (iTimeLeft < 1)
	{
		return;
	}
	
	// Recreate the timer.
	g_hCountDown = CreateTimer(float(iTimeLeft), Timer_CountDown, _);
}

public Action Timer_CountDown(Handle hTimer)
{
	// Check timer handle to ensure it matches global handle.
	if (hTimer != g_hCountDown)
	{
		return Plugin_Stop;
	}

	g_hCountDown = null;
	EndGame();

	return Plugin_Continue;
}

public Action Timer_Warning(Handle hTimer)
{
	// Check timer handle to ensure it matches global handle.
	if (hTimer != g_hWarningTimer)
	{
		return Plugin_Stop;
	}

	// First, get the time left.
	int iTimeLeft;
	GetMapTimeLeft(iTimeLeft);
	
	
	// Check if the Key Values handle is valid and if there is enough time left.
	if (g_kvWarnings != null && iTimeLeft > 0)
	{
		char sTimeLeft[11];

		IntToString(iTimeLeft, sTimeLeft, sizeof(sTimeLeft));
		
		// Now, search for x in the key values.
		if (KvJumpToKey(g_kvWarnings, sTimeLeft, false))
		{	
			// Get the translation name to use.
			char sTranslation[MAX_NAME_LENGTH];
			KvGetString(g_kvWarnings, "translation", sTranslation, sizeof(sTranslation), "SecondsRemaining");
			
			// Now, rewind the KV.
			KvRewind(g_kvWarnings);
			
			// Now, print it to the entire server.
			CPrintToChatAll("%t%t", "Tag", sTranslation, iTimeLeft, (iTimeLeft / 60));
		}
	}

	return Plugin_Continue;
}