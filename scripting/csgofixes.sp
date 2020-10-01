#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "CSGOFixes: SourcePawn Edition",
	author = "Vauff",
	description = "Various fixes for CS:GO",
	version = "1.0",
	url = "https://github.com/Vauff/CSGOFixes-SP"
};

public void OnPluginStart()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/csgofixes_sp.games.txt");

	if (!FileExists(path))
		SetFailState("Can't find csgofixes_sp.games.txt gamedata.");

	Handle gameData = LoadGameConfigFile("csgofixes_sp.games");
	
	if (gameData == INVALID_HANDLE)
		SetFailState("Can't find csgofixes_sp.games.txt gamedata.");

	char patchNames[][] = {"ThinkAddFlag", "DeactivateWarning", "InputSpeedModFlashlight"};

	for (int i = 0; i < sizeof(patchNames); i++)
	{
		// Get the patch name
		char patch[64];
		Format(patch, sizeof(patch), patchNames[i]);

		// Get the address near our patch area
		Address iAddr = GameConfGetAddress(gameData, patch);

		if (iAddr == Address_Null)
		{
			CloseHandle(gameData);
			LogError("%s patch failed: Can't find %s address in gamedata.", patch, patch);
			continue;
		}

		// Get the offset from the start of the signature to the start of our patch area.
		char cappingOffset[64];
		Format(cappingOffset, sizeof(cappingOffset), "CappingOffset_%s", patch);
		int iCapOffset = GameConfGetOffset(gameData, cappingOffset);

		if (iCapOffset == -1)
		{
			CloseHandle(gameData);
			LogError("%s patch failed: Can't find %s offset in gamedata.", patch, cappingOffset);
			continue;
		}

		// Move right in front of the instructions we want to NOP.
		iAddr += view_as<Address>(iCapOffset);

		// Get how many bytes we want to NOP.
		char patchBytes[64];
		Format(patchBytes, sizeof(patchBytes), "PatchBytes_%s", patch);
		int iPatchRestoreBytes = GameConfGetOffset(gameData, patchBytes);

		if (iPatchRestoreBytes == -1)
		{
			CloseHandle(gameData);
			LogError("%s patch failed: Can't find %s offset in gamedata.", patch, patchBytes);
			continue;
		}

		for (int j = 0; j < iPatchRestoreBytes; j++)
		{
			//PrintToServer("%x: %x", iAddr, LoadFromAddress(iAddr, NumberType_Int8));

			// NOP
			StoreToAddress(iAddr, 0x90, NumberType_Int8);
			iAddr++;
		}
	}

	CloseHandle(gameData);
}