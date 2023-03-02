# CSGOFixes
A collection of various fixes for CS:GO, originally based on the [CSSFixes](https://git.botox.bz/CSSZombieEscape/sm-ext-CSSFixes) extension. These fixes are largely targeted at custom gamemodes/maps where these problems will actually appear unlike the base game, but still technically apply to any CS:GO server.

This plugin contains the following fixes:

- Re-enables movement lag compensation inside of game_ui's to fix "laggy movement"
- Fixes the game_ui Deactivate input crashing the server with a null activator
- Stops the player_speedmod ModifySpeed input from disabling players flashlights
- Fixes filter TestActivator inputs crashing the server with a null activator
- Fixes grenade explosions where the thrower left before explosion crashing the server if tested against numerous possible damage filters that lack null attacker checks
- Fixes parented triggers firing OnStartTouch every tick while touched, this also fixes the well-known "stack damage" bug
- Forces all entities (not just templated ones) to delete their script handle if it exists, thus mitigating a game stringtable leak
- Fixes chat/command processing lag when map physics create a lot of friction dust particles

### Additional Credits
- BotoX: Creating the original [CSSFixes](https://git.botox.bz/CSSZombieEscape/sm-ext-CSSFixes), where some of these fixes were originally made
- Snowy: General help
- Peace-Maker: Creating [Movement Unlocker](https://forums.alliedmods.net/showthread.php?t=255298), which I based the patching code off of