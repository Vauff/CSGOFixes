# CSGOFixes-SP
A partial SourcePawn implementation of CSGOFixes, contains the following CS:GO fixes:

- Re-enables lag compensation inside of a game_ui by stopping the FL_ONTRAIN flag from being added ([Reference code](https://github.com/perilouswithadollarsign/cstrike15_src/blob/29e4c1fda9698d5cebcdaf1a0de4b829fa149bf8/game/server/game_ui.cpp#L292))
- Fixes the game_ui Deactivate input crashing with a null activator by removing an incorrectly implemented warning message ([Reference code](https://github.com/perilouswithadollarsign/cstrike15_src/blob/29e4c1fda9698d5cebcdaf1a0de4b829fa149bf8/game/server/game_ui.cpp#L173))
- Fixes player_speedmod from disabling players flashlights by removing the FlashlightTurnOff() call ([Reference code](https://github.com/perilouswithadollarsign/cstrike15_src/blob/29e4c1fda9698d5cebcdaf1a0de4b829fa149bf8/game/server/player.cpp#L8165))

## Credits
- BotoX: Creating the original [CSSFixes](https://git.botox.bz/CSSZombieEscape/sm-ext-CSSFixes), where most of these fixes were originally made
- Snowy: General help
- Peace-Maker: Creating [Movement Unlocker](https://forums.alliedmods.net/showthread.php?t=255298), which I based the patching code off of