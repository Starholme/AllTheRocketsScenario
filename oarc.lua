-- To keep the scenario more manageable (for myself) I have done the following:
--      1. Keep all event calls in control.lua (here)
--      2. Put all config options in config.lua and provided an example-config.lua file too.
--      3. Put other stuff into their own files where possible.
--      4. Put all other files into lib folder
--      5. Provided an examples folder for example/recommended map gen settings

-- Generic Utility Includes
require("lib/oarc_utils")

-- Other soft-mod type features.
require("lib/tag")
require("lib/game_opts")
require("lib/player_list")
require("lib/rocket_launch")
require("lib/admin_commands")
require("lib/regrowth_map")
require("lib/notepad")
require("lib/map_features")
require("lib/oarc_buy")
require("lib/auto_decon_miners")
local global_chat = require("lib/global_chat")

-- For Philip. I currently do not use this and need to add proper support for
-- commands like this in the future.
-- require("lib/rgcommand")
-- require("lib/helper_commands")

-- Main Configuration File
require("config")

-- Save all config settings to global table.
require("lib/oarc_global_cfg.lua")

-- Scenario Specific Includes
require("lib/separate_spawns")
require("lib/separate_spawns_guis")
require("lib/oarc_enemies")
require("lib/oarc_gui_tabs")

-- compatibility with mods
require("compat/factoriomaps")

-- Create a new surface so we can modify map settings at the start.
GAME_SURFACE_NAME="oarc"

local function AddCommands()
    commands.add_command("trigger-map-cleanup",
        "Force immediate removal of all expired chunks (unused chunk removal mod)",
        RegrowthForceRemoveChunksCmd)
end



--------------------------------------------------------------------------------
-- ALL EVENT HANLDERS ARE HERE IN ONE PLACE!
--------------------------------------------------------------------------------

----------------------------------------
-- On Init - only runs once the first
--   time the game starts
----------------------------------------
local function OnInit(event)

    -- FIRST
    InitOarcConfig()

    -- Regrowth (always init so we can enable during play.)
    RegrowthInit()

    -- Create new game surface
    CreateGameSurface()

    -- MUST be before other stuff, but after surface creation.
    InitSpawnGlobalsAndForces()

    -- Everyone do the shuffle. Helps avoid always starting at the same location.
    if (global.ocfg.enable_vanilla_spawns) then
        global.vanillaSpawns = FYShuffle(global.vanillaSpawns)
        log("Vanilla spawns:")
        log(serpent.block(global.vanillaSpawns))
    end

    Compat.handle_factoriomaps()

    OarcMapFeatureInitGlobalCounters()
    OarcAutoDeconOnInit()

    -- Display starting point text as a display of dominance.
    RenderPermanentGroundText(game.surfaces[GAME_SURFACE_NAME], {x=-15.5,y=-23}, 30, "ATR", {0.9, 0.7, 0.3, 0.8})
    RenderPermanentGroundText(game.surfaces[GAME_SURFACE_NAME], {x=-17.75,y=4}, 8, "OARC    + Clusterio", {0.9, 0.7, 0.3, 0.8})
end

local function ScriptOnLoad()
    Compat.handle_factoriomaps()
end


----------------------------------------
-- Rocket launch event
-- Used for end game win conditions / unlocking late game stuff
----------------------------------------
local function OnRocketLaunched(event)
    RocketLaunchEvent(event)
end


----------------------------------------
-- Chunk Generation
----------------------------------------
local function OnChunkGenerated(event)

    if (event.surface.name ~= GAME_SURFACE_NAME) then return end

    if global.ocfg.enable_regrowth then
        RegrowthChunkGenerate(event)
    end

    if global.ocfg.enable_undecorator then
        UndecorateOnChunkGenerate(event)
    end

    SeparateSpawnsGenerateChunk(event)

    CreateHoldingPen(event.surface, event.area)
end


----------------------------------------
-- Gui Click
----------------------------------------
local function OnGuiClick(event)

    -- Don't interfere with other mod related stuff.
    if (event.element.get_mod() ~= nil) then return end

    if global.ocfg.enable_tags then
        TagGuiClick(event)
    end

    WelcomeTextGuiClick(event)
    SpawnOptsGuiClick(event)
    SpawnCtrlGuiClick(event)
    SharedSpwnOptsGuiClick(event)
    BuddySpawnOptsGuiClick(event)
    BuddySpawnWaitMenuClick(event)
    BuddySpawnRequestMenuClick(event)
    SharedSpawnJoinWaitMenuClick(event)

    ClickOarcGuiButton(event)

    if global.ocfg.enable_coin_shop then
        ClickOarcStoreButton(event)
    end

    GameOptionsGuiClick(event)
end

local function OnGuiCheckedStateChanged(event)
    SpawnOptsRadioSelect(event)
    SpawnCtrlGuiOptionsSelect(event)
end

local function OnGuiSelectedTabChanged(event)
    TabChangeOarcGui(event)

    if global.ocfg.enable_coin_shop then
        TabChangeOarcStore(event)
    end
end

----------------------------------------
-- Player Events
----------------------------------------
local function OnPlayerJoinedGame(event)
    PlayerJoinedMessages(event)
    ServerWriteFile("player_events", game.players[event.player_index].name .. " joined the game." .. "\n")
end

local function OnPlayerCreated(event)
    local player = game.players[event.player_index]

    -- Move the player to the game surface immediately.
    player.teleport({x=0,y=0}, GAME_SURFACE_NAME)

    if global.ocfg.enable_long_reach then
        GivePlayerLongReach(player)
    end

    SeparateSpawnsPlayerCreated(event.player_index, true)

    InitOarcGuiTabs(player)

    if global.ocfg.enable_coin_shop then
        InitOarcStoreGuiTabs(player)
    end
end

local function OnPlayerRespawned(event)
    SeparateSpawnsPlayerRespawned(event)

    PlayerRespawnItems(event)

    if global.ocfg.enable_long_reach then
        GivePlayerLongReach(game.players[event.player_index])
    end
end

local function OnPlayerLeftGame(event)
    ServerWriteFile("player_events", game.players[event.player_index].name .. " left the game." .. "\n")
    local player = game.players[event.player_index]

    -- If players leave early, say goodbye.
    if (player and (player.online_time < (global.ocfg.minimum_online_time * TICKS_PER_MINUTE))) then
        log("Player left early: " .. player.name)
        SendBroadcastMsg(player.name .. "'s base was marked for immediate clean up because they left within "..global.ocfg.minimum_online_time.." minutes of joining.")
        RemoveOrResetPlayer(player, true, true, true, true)
    end
end


----------------------------------------
-- On tick events. Stuff that needs to happen at regular intervals.
-- Delayed events, delayed spawns, ...
----------------------------------------
local function OnTick(event)
    if global.ocfg.enable_regrowth then
        RegrowthOnTick()
        RegrowthForceRemovalOnTick()
    end

    DelayedSpawnOnTick()

    TimeoutSpeechBubblesOnTick()
    FadeoutRenderOnTick()

    if global.ocfg.enable_miner_decon then
        OarcAutoDeconOnTick()
    end
end


local function OnSectorScanned(event)
    if global.ocfg.enable_regrowth then
        RegrowthSectorScan(event)
    end
end

----------------------------------------
-- Various on "built" events
----------------------------------------
local function OnBuiltEntity(event)
    if global.ocfg.enable_autofill then
        Autofill(event)
    end

    if global.ocfg.enable_regrowth then
        if (event.created_entity.surface.name ~= GAME_SURFACE_NAME) then return end
        RegrowthMarkAreaSafeGivenTilePos(event.created_entity.position, 2, false)
    end

    if global.ocfg.enable_anti_grief then
        SetItemBlueprintTimeToLive(event)
    end

end

local function OnGuiClosed(event)
    OarcGuiOnGuiClosedEvent(event)
    OarcStoreOnGuiClosedEvent(event)
end

return {
    events = {
        [defines.events.on_resource_depleted] = OarcAutoDeconOnResourceDepleted,
        [defines.events.on_post_entity_died] = CoinsFromEnemiesOnPostEntityDied,
        [defines.events.on_gui_closed] = OnGuiClosed,
        [defines.events.on_gui_text_changed] = NotepadOnGuiTextChange,
        [defines.events.on_character_corpse_expired] = DropGravestoneChestFromCorpse,
        [defines.events.on_unit_group_finished_gathering] = OarcModifyEnemyGroup,
        [defines.events.on_biter_base_built] = ModifyEnemySpawnsNearPlayerStartingAreas,
        [defines.events.on_entity_spawned] = ModifyEnemySpawnsNearPlayerStartingAreas,
        [defines.events.on_research_finished] = LockGoodiesUntilRocketLaunch,
        [defines.events.on_console_chat] = global_chat.ChatEvent,
        [defines.events.script_raised_built] = RegrowthScriptRaisedBuilt,
        [defines.events.on_player_built_tile] = RegrowthOnPlayerBuiltTile,
        [defines.events.on_robot_built_entity] = RegrowthOnRobotBuiltEntity,
        [defines.events.on_built_entity] = OnBuiltEntity,
        [defines.events.on_sector_scanned] = OnSectorScanned,
        [defines.events.on_tick] = OnTick,
        [defines.events.on_player_left_game] = OnPlayerLeftGame,
        [defines.events.on_player_respawned] = OnPlayerRespawned,
        [defines.events.on_player_created] = OnPlayerCreated,
        [defines.events.on_player_joined_game] = OnPlayerJoinedGame,
        [defines.events.on_gui_selected_tab_changed] = OnGuiSelectedTabChanged,
        [defines.events.on_gui_checked_state_changed] = OnGuiCheckedStateChanged,
        [defines.events.on_gui_click] = OnGuiClick,
        [defines.events.on_chunk_generated] = OnChunkGenerated,
        [defines.events.on_rocket_launched] = OnRocketLaunched
    },
    on_load = ScriptOnLoad,
    on_init = OnInit,
    add_commands = AddCommands
}
