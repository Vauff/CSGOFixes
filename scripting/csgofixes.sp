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
	version = "1.2",
	url = "https://github.com/Vauff/CSGOFixes-SP"
};

Handle g_hInputTestActivator;
char g_sPatchNames[][] = {"ThinkAddFlag", "DeactivateWarning", "InputSpeedModFlashlight"};
Address g_aPatchedAddresses[sizeof(g_sPatchNames)];
int g_iPatchedByteCount[sizeof(g_sPatchNames)];
int g_iPatchedBytes[sizeof(g_sPatchNames)][128]; // Increase this if a PatchBytes value in gamedata exceeds 128

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO)
		SetFailState("This plugin only runs on CS:GO!");

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/csgofixes_sp.games.txt");

	if (!FileExists(path))
		SetFailState("Can't find csgofixes_sp.games.txt gamedata.");

	Handle gameData = LoadGameConfigFile("csgofixes_sp.games");
	
	if (gameData == INVALID_HANDLE)
		SetFailState("Can't find csgofixes_sp.games.txt gamedata.");

	// Iterate our patch names (these are dependent on what's in gamedata)
	for (int i = 0; i < sizeof(g_sPatchNames); i++)
	{
		char patchName[64];
		Format(patchName, sizeof(patchName), g_sPatchNames[i]);

		// Get the location of this patches signature
		Address addr = GameConfGetAddress(gameData, patchName);

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

	g_hInputTestActivator = DHookCreateFromConf(gameData, "CBaseFilter::InputTestActivator");
	CloseHandle(gameData);

	if (!g_hInputTestActivator)
	{
		LogError("Failed to setup detour for CBaseFilter::InputTestActivator");
		return;
	}

	if (!DHookEnableDetour(g_hInputTestActivator, false, Detour_InputTestActivator))
		LogError("Failed to detour CBaseFilter::InputTestActivator");
}

public MRESReturn Detour_InputTestActivator(DHookParam hParams)
{
	int pActivator = DHookGetParamObjectPtrVar(hParams, 1, 0, ObjectValueType_CBaseEntityPtr);

	// If null activator, block the real function from executing and crashing the server
	if (pActivator == -1)
		return MRES_Supercede;

	return MRES_Ignored;
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