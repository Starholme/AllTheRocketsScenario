-- map_features.lua
-- April 2020
-- Oarc's clone of whistlestop factories maybe?

-- Generic Utility Includes
require("lib/oarc_utils")


COIN_MULTIPLIER = 2

COIN_GENERATION_CHANCES = {
    ["small-biter"] = 0.01,
    ["medium-biter"] = 0.02,
    ["big-biter"] = 0.05,
    ["behemoth-biter"] = 1,

    ["small-spitter"] = 0.01,
    ["medium-spitter"] = 0.02,
    ["big-spitter"] = 0.05,
    ["behemoth-spitter"] = 1,

    ["small-worm-turret"] = 5,
    ["medium-worm-turret"] = 10,
    ["big-worm-turret"] = 15,
    ["behemoth-worm-turret"] = 25,

    ["biter-spawner"] = 20,
    ["spitter-spawner"] = 20,
}

function CoinsFromEnemiesOnPostEntityDied(event)
    if (not event.prototype or not event.prototype.name) then return end

    local coin_chance = nil
    if (COIN_GENERATION_CHANCES[event.prototype.name]) then
        coin_chance = COIN_GENERATION_CHANCES[event.prototype.name]
    end

    if (coin_chance) then
        DropCoins(event.position, coin_chance, event.force)
    end
end

-- Drop coins, force is optional, decon is applied if force is not nil.
function DropCoins(pos, count, force)

    local drop_amount = 0

    -- If count is less than 1, it represents a probability to drop a single coin
    if (count < 1) then
        if (math.random() < count) then
            drop_amount = 1
        end

    -- If count is 1 or more, it represents a probability to drop at least that amount and up to 3x
    elseif (count >= 1) then
        drop_amount = math.random(count,count*COIN_MULTIPLIER)
    end

    if drop_amount == 0 then return end
    game.surfaces[GAME_SURFACE_NAME].spill_item_stack(pos, {name="coin", count=math.floor(drop_amount)}, true, force, false) -- Set nil to force to auto decon.
end
