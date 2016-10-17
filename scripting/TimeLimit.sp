#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <nextmap>

#define PL_VERSION "1.0.0"

public Plugin myinfo = 
{
	name = "[CS]Time Limit Enforcer",
	author = "Roy (Christian Deacon)",
	description = "Time limit enforcer using option two.",
	version = PL_VERSION,
	url = "GFLClan.com"
};

// ConVars
ConVar g_cvEnabled = null;

ConVar g_cvIgnoreCond = null;

// ConVar values
bool g_bEnabled;

// Other Variables.
Handle g_hCountDown;

public void OnPluginStart() 
{
	// ConVars.
	g_cvEnabled = CreateConVar("sm_tl_enabled", "1", "Enable \"Time Limit Enforcer\"?");
	HookConVarChange(g_cvEnabled, ConVarChanged);
	
	g_cvIgnoreCond = FindConVar("mp_ignore_round_win_conditions");
	
	// Make sure the game is CS:GO or CS:S.
	if(GetEngineVersion() != Engine_CSGO && GetEngineVersion() != Engine_CSS) 
	{
		SetFailState("This plugin only supports CS:GO and CS:S.");
	}
	
	// Translations.
	LoadTranslations("TimeLimit.phrases.txt");
	
	// Commands.
	RegAdminCmd("sm_endround", Command_EndRound, ADMFLAG_ROOT);
	
	// Config.
	AutoExecConfig(true, "sm_tle");
}

public void ConVarChanged(Handle hCvar, const char[] oldV, const char[] newV)
{
	OnConfigsExecuted();
}

public void OnMapTimeLeftChanged()
{
	/* Recreate the timer, etc. */
	PrintToServer("[TL] TimeLimitChange :: Resetting timer");
	ResetTimeLeft();
}

public void OnConfigsExecuted()
{
	g_bEnabled = GetConVarBool(g_cvEnabled);
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
	
	// Set "mp_ignore_round_win_conditions" to 0.
	if (g_cvIgnoreCond != null)
	{
		SetConVarInt(g_cvIgnoreCond, 0, false, false);
	}
	
	// Now terminate the round!
	CS_TerminateRound(1.0, CSRoundEnd_Draw, true);
	
	// Now print a message!
	char sNextMap[MAX_NAME_LENGTH];
	GetNextMap(sNextMap, sizeof(sNextMap));
	
	PrintToChatAll("%t%t", "Tag", "NextMapMsg", sNextMap);
}

stock void ResetTimeLeft()
{
	if (!g_bEnabled)
	{
		return;
	}
	
	/* Get new time left. */
	int iTimeLeft;
	GetMapTimeLeft(iTimeLeft);
	
	/* Check the value. */
	if (iTimeLeft < 1)
	{
		return;
	}
	
	/* Kill the previous timer. */
	if (g_hCountDown != null)
	{
		delete g_hCountDown;
	}
	
	PrintToServer("[TL] Starting reset timer with %f (%i)", float(iTimeLeft), iTimeLeft);
	
	/* Recreate the timer. */
	g_hCountDown = CreateTimer(float(iTimeLeft), Timer_CountDown, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CountDown(Handle hTimer)
{
	PrintToServer("[TL] Ending theeeeeeeee gameeeeeeeee");
	EndGame();
}