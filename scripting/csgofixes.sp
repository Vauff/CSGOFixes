#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "CSGOFixes: SourcePawn Edition",
	author = "Vauff",
	description = "Various fixes for CS:GO",
	version = "1.1.1",
	url = "https://github.com/Vauff/CSGOFixes-SP"
};

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

	for (int i = 0; i < sizeof(g_sPatchNames); i++)
	{
		char patchName[64];
		Format(patchName, sizeof(patchName), g_sPatchNames[i]);
		Address addr = GameConfGetAddress(gameData, patchName);

		if (addr == Address_Null)
		{
			LogError("%s patch failed: Can't find %s address in gamedata.", patchName, patchName);
			continue;
		}

		char cappingOffsetName[64];
		Format(cappingOffsetName, sizeof(cappingOffsetName), "CappingOffset_%s", patchName);
		int cappingOffset = GameConfGetOffset(gameData, cappingOffsetName);

		if (cappingOffset == -1)
		{
			LogError("%s patch failed: Can't find %s offset in gamedata.", patchName, cappingOffsetName);
			continue;
		}

		addr += view_as<Address>(cappingOffset);

		char patchBytesName[64];
		Format(patchBytesName, sizeof(patchBytesName), "PatchBytes_%s", patchName);
		int patchBytes = GameConfGetOffset(gameData, patchBytesName);

		if (patchBytes == -1)
		{
			LogError("%s patch failed: Can't find %s offset in gamedata.", patchName, patchBytesName);
			continue;
		}

		g_aPatchedAddresses[i] = addr;
		g_iPatchedByteCount[i] = patchBytes;

		for (int j = 0; j < patchBytes; j++)
		{
			g_iPatchedBytes[i][j] = LoadFromAddress(addr, NumberType_Int8);
			StoreToAddress(addr, 0x90, NumberType_Int8);
			addr++;
		}
	}

	CloseHandle(gameData);
}

public void OnPluginEnd()
{
	for (int i = 0; i < sizeof(g_aPatchedAddresses); i++)
	{
		Address addr = g_aPatchedAddresses[i];

		for (int j = 0; j < g_iPatchedByteCount[i]; j++)
		{
			StoreToAddress(addr, g_iPatchedBytes[i][j], NumberType_Int8);
			addr++;
		}
	}
}