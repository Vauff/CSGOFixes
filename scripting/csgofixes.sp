#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "CSGOFixes: SourcePawn Edition",
	author = "Vauff",
	description = "Various fixes for CS:GO",
	version = "1.3",
	url = "https://github.com/Vauff/CSGOFixes-SP"
};

#define FSOLID_TRIGGER 0x0008

Handle g_hInputTestActivator;
Handle g_hExplode;
Handle g_hPhysicsTouchTriggers;
Handle g_hUpdateOnRemove;
Handle g_hGameStringPool_Remove;
char g_sPatchNames[][] = {"ThinkAddFlag", "DeactivateWarning", "InputSpeedModFlashlight"};
Address g_aPatchedAddresses[sizeof(g_sPatchNames)];
int g_iPatchedByteCount[sizeof(g_sPatchNames)];
int g_iPatchedBytes[sizeof(g_sPatchNames)][128]; // Increase this if a PatchBytes value in gamedata exceeds 128
int g_iSolidFlags;

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO)
		SetFailState("This plugin only runs on CS:GO!");

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/csgofixes_sp.games.txt");

	if (!FileExists(path))
		SetFailState("Can't find csgofixes_sp.games.txt gamedata.");

	GameData gameData = LoadGameConfigFile("csgofixes_sp.games");
	
	if (gameData == INVALID_HANDLE)
		SetFailState("Can't find csgofixes_sp.games.txt gamedata.");

	// Iterate our patch names (these are dependent on what's in gamedata)
	for (int i = 0; i < sizeof(g_sPatchNames); i++)
	{
		char patchName[64];
		Format(patchName, sizeof(patchName), g_sPatchNames[i]);

		// Get the location of this patches signature
		Address addr = gameData.GetMemSig(patchName);

		if (addr == Address_Null)
		{
			LogError("%s patch failed: Can't find %s address in gamedata.", patchName, patchName);
			continue;
		}

		char cappingOffsetName[64];
		Format(cappingOffsetName, sizeof(cappingOffsetName), "CappingOffset_%s", patchName);

		// Get how many bytes we should move forward from the signature location before starting patching
		int cappingOffset = GameConfGetOffset(gameData, cappingOffsetName);

		if (cappingOffset == -1)
		{
			LogError("%s patch failed: Can't find %s offset in gamedata.", patchName, cappingOffsetName);
			continue;
		}

		// Get patch location
		addr += view_as<Address>(cappingOffset);

		char patchBytesName[64];
		Format(patchBytesName, sizeof(patchBytesName), "PatchBytes_%s", patchName);

		// Find how many bytes after the patch location should be NOP'd
		int patchBytes = GameConfGetOffset(gameData, patchBytesName);

		if (patchBytes == -1)
		{
			LogError("%s patch failed: Can't find %s offset in gamedata.", patchName, patchBytesName);
			continue;
		}

		// Store this patches address and byte count as it's being applied for unpatching on plugin unload
		g_aPatchedAddresses[i] = addr;
		g_iPatchedByteCount[i] = patchBytes;

		// Iterate each byte we need to patch
		for (int j = 0; j < patchBytes; j++)
		{
			// Store the original byte here for unpatching on plugin unload
			g_iPatchedBytes[i][j] = LoadFromAddress(addr, NumberType_Int8);

			// NOP this byte
			StoreToAddress(addr, 0x90, NumberType_Int8);

			// Move on to next byte
			addr++;
		}
	}

	// CBaseGrenade::Explode
	g_hExplode = DHookCreate(GameConfGetOffset(gameData, "Explode"), HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, Hook_Explode);
	DHookAddParam(g_hExplode, HookParamType_ObjectPtr);
	DHookAddParam(g_hExplode, HookParamType_Int);
	if (!g_hExplode)
	{
		CloseHandle(gameData);
		SetFailState("Failed to setup hook for CBaseGrenade::Explode");
	}

	// CBaseFilter::InputTestActivator
	g_hInputTestActivator = DHookCreateFromConf(gameData, "CBaseFilter::InputTestActivator");
	if (!DHookEnableDetour(g_hInputTestActivator, false, Detour_InputTestActivator))
	{
		CloseHandle(gameData);
		SetFailState("Failed to detour CBaseFilter::InputTestActivator");
	}

	if (!g_hInputTestActivator)
	{
		CloseHandle(gameData);
		SetFailState("Failed to setup detour for CBaseFilter::InputTestActivator");
	}

	// CBaseEntity::PhysicsTouchTriggers
	g_hPhysicsTouchTriggers = DHookCreateFromConf(gameData, "CBaseEntity::PhysicsTouchTriggers");
	if(!g_hPhysicsTouchTriggers)
	{
		CloseHandle(gameData);
		SetFailState("Failed to setup detour for CBaseEntity::PhysicsTouchTriggers");
	}

	if(!DHookEnableDetour(g_hPhysicsTouchTriggers, false, Detour_PhysicsTouchTriggers))
	{
		CloseHandle(gameData);
		SetFailState("Failed to detour CBaseEntity::PhysicsTouchTriggers");
	}

	// CBaseEntity::UpdateOnRemove
	g_hUpdateOnRemove = DHookCreateFromConf(gameData, "CBaseEntity::UpdateOnRemove");
	if(!g_hUpdateOnRemove)
	{
		CloseHandle(gameData);
		SetFailState("Failed to setup detour for CBaseEntity::UpdateOnRemove");
	}

	if(!DHookEnableDetour(g_hUpdateOnRemove, false, Detour_UpdateOnRemove))
	{
		CloseHandle(gameData);
		SetFailState("Failed to detour CBaseEntity::UpdateOnRemove");
	}

	// CGameStringPool::Remove
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CGameStringPool::Remove"))
	{
		CloseHandle(gameData);
		SetFailState("Failed to get CGameStringPool::Remove");
	}

	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hGameStringPool_Remove = EndPrepSDKCall();
	if (!g_hGameStringPool_Remove)
	{
		CloseHandle(gameData);
		SetFailState("Unable to prepare SDKCall for CGameStringPool::Remove");
	}

	CloseHandle(gameData);
}

public void OnMapStart()
{
	g_iSolidFlags = FindDataMapInfo(0, "m_usSolidFlags");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook all grenade projectiles that implement CBaseGrenade::Explode
	if (StrEqual(classname, "hegrenade_projectile") || StrEqual(classname, "breachcharge_projectile") || StrEqual(classname, "bumpmine_projectile"))
		DHookEntity(g_hExplode, false, entity);
}

public MRESReturn Hook_Explode(int pThis, DHookParam hParams)
{
	int thrower = GetEntPropEnt(pThis, Prop_Send, "m_hThrower");

	// If null thrower (disconnected before explosion), block possible server crash from certain damage filters
	if (thrower == -1)
	{
		RemoveEntity(pThis);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public MRESReturn Detour_InputTestActivator(DHookParam hParams)
{
	int pActivator = DHookGetParamObjectPtrVar(hParams, 1, 0, ObjectValueType_CBaseEntityPtr);

	// If null activator, block the real function from executing and crashing the server
	if (pActivator == -1)
		return MRES_Supercede;

	return MRES_Ignored;
}

public MRESReturn Detour_PhysicsTouchTriggers(int iEntity)
{
	// This function does two things as far as triggers are concerned, invalidate its touchstamp and calls SV_TriggerMoved.
	// SV_TriggerMoved is what checks if the moving trigger (hence the name) is touching anything.
	// But valve for whatever reason ifdef'd out a crucial function that actually performs the ray checks on dedicated servers.
	// As a result, the touchlink never gets updated on the trigger's side, which ends up deleting the touchlink.
	// And so, the player touches the trigger on the very next tick through SV_SolidMoved (which functions properly), and the cycle repeats...
	if (!IsValidEntity(iEntity))
		return MRES_Ignored;

	if (GetEntData(iEntity, g_iSolidFlags) & FSOLID_TRIGGER)
		return MRES_Supercede;

	return MRES_Ignored;
}

public MRESReturn Detour_UpdateOnRemove(int iEntity)
{
	// This function deletes both the entity's targetname and script handle from the game stringtable, but only if it was part of a template with name fixup.
	// The intention was to prevent stringtable leaks from fixed up entity names since they're unique, but script handles are always unique regardless.
	// So there's really no reason not to unconditionally delete script handles when they're no longer needed.
	if (!IsValidEntity(iEntity) || (1 <= iEntity <= MaxClients))
		return MRES_Ignored;

	char szScriptId[64];

	if (GetEntPropString(iEntity, Prop_Data, "m_iszScriptId", szScriptId, sizeof(szScriptId)))
		SDKCall(g_hGameStringPool_Remove, szScriptId);

	return MRES_Handled;
}

public void OnPluginEnd()
{
	// Iterate our currently applied patches and get their location
	for (int i = 0; i < sizeof(g_aPatchedAddresses); i++)
	{
		Address addr = g_aPatchedAddresses[i];

		// Iterate the original bytes in that location and restore them (undo the NOP)
		for (int j = 0; j < g_iPatchedByteCount[i]; j++)
		{
			StoreToAddress(addr, g_iPatchedBytes[i][j], NumberType_Int8);
			addr++;
		}
	}
}