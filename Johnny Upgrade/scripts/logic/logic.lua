ScriptHost:LoadScript("scripts/logic/generated_requirements.lua")


local DEFAULT_DAMAGE_LOGIC = true
local DEFAULT_RECOIL_LOGIC = false
local DEFAULT_KNOCKBACK_LOGIC = false


local function tracker_count(code)
    return Tracker:ProviderCountForCode(code)
end


local function setting_enabled(code, fallback)
    local obj = Tracker:FindObjectForCode(code)

    if obj == nil then
        return fallback
    end

    return tracker_count(code) > 0
end


local function damage_logic_enabled()
    return setting_enabled("damage_logic", DEFAULT_DAMAGE_LOGIC)
end


local function recoil_logic_enabled()
    return setting_enabled("recoil_logic", DEFAULT_RECOIL_LOGIC)
end


local function knockback_logic_enabled()
    return setting_enabled("knockback_logic", DEFAULT_KNOCKBACK_LOGIC)
end

local function has_required_items(option, extra_ammo)

    if option.speed ~= nil then
        if tracker_count("speed") < option.speed then
            return false
        end
    end

    if option.jump ~= nil then
        if tracker_count("jump_force") < option.jump then
            return false
        end
    end

    if option.double then
        if tracker_count("double_jump") < 1 then
            return false
        end
    end

    if option.energy ~= nil and option.energy > 1 then
        if tracker_count("health") < (option.energy - 1) then
            return false
        end
    end

    local ammo_needed = option.ammo or 0

    if extra_ammo ~= nil and extra_ammo > ammo_needed then
        ammo_needed = extra_ammo
    end

    if ammo_needed > 0 then
        if tracker_count("gun") < 1 then
            return false
        end

        if tracker_count("ammo") < ammo_needed then
            return false
        end
    end

    if option.time ~= nil then
        if tracker_count("time_limit") < option.time then
            return false
        end
    end

    return true
end


local function uses_disabled_logic_setting(option)


    if option.energy ~= nil and option.energy > 1 then
        if not damage_logic_enabled() then
            return true
        end
    end

    if option.tech == "recoil" then
        if not recoil_logic_enabled() then
            return true
        end
    end

    if option.tech == "knockback" then
        if not knockback_logic_enabled() then
            return true
        end
    end

    return false
end


local function option_access(option, extra_ammo)

    if not has_required_items(option, extra_ammo) then
        return AccessibilityLevel.None
    end


    if uses_disabled_logic_setting(option) then
        return AccessibilityLevel.SequenceBreak
    end

    return AccessibilityLevel.Normal
end


local function options_access(options, extra_ammo)

    if options == nil then
        return AccessibilityLevel.None
    end

    local best = AccessibilityLevel.None

    for _, option in ipairs(options) do
        local access = option_access(option, extra_ammo)

        if access == AccessibilityLevel.Normal then
            return AccessibilityLevel.Normal
        end

        if access == AccessibilityLevel.SequenceBreak then
            best = AccessibilityLevel.SequenceBreak
        end
    end

    return best
end


local function requirement_class_access(class_id)

    class_id = tonumber(class_id)

    if class_id == nil then
        return AccessibilityLevel.None
    end

    local options = REQUIREMENT_CLASSES[class_id]

    if options == nil then
        print("Johnny Upgrade logic: missing requirement class " .. tostring(class_id))
        return AccessibilityLevel.None
    end

    return options_access(options)
end




function coin_access(coin_number)

    coin_number = tonumber(coin_number)

    if coin_number == nil then
        return AccessibilityLevel.None
    end

    local class_id = COIN_REQUIREMENT_IDS[coin_number]

    if class_id == nil then
        print("Johnny Upgrade logic: no requirement for Coin " .. tostring(coin_number))
        return AccessibilityLevel.None
    end

    return requirement_class_access(class_id)
end



function enemy_access(enemy_number)

    enemy_number = tonumber(enemy_number)

    if enemy_number == nil then
        return AccessibilityLevel.None
    end

    local class_id = ENEMY_REQUIREMENT_IDS[enemy_number]

    if class_id == nil then
        print("Johnny Upgrade logic: no requirement for Robot " .. tostring(enemy_number))
        return AccessibilityLevel.None
    end

    return requirement_class_access(class_id)
end


function robot_access(robot_number)
    return enemy_access(robot_number)
end



local BOMB_SOURCES = {
    [1] = {
        {coin = 114, ammo = 1},
    },
    [2] = {
        {coin = 110, ammo = 1},
    },
    [3] = {
        {coin = 133, ammo = 2},
        {coin = 85, ammo = 2},
    },
}


function bomb_access(bomb_number)

    bomb_number = tonumber(bomb_number)

    if bomb_number == nil then
        return AccessibilityLevel.None
    end

    local sources = BOMB_SOURCES[bomb_number]

    if sources == nil then
        print("Johnny Upgrade logic: no requirement for Bomb " .. tostring(bomb_number))
        return AccessibilityLevel.None
    end

    local best = AccessibilityLevel.None

    for _, source in ipairs(sources) do

        local class_id = COIN_REQUIREMENT_IDS[source.coin]

        if class_id ~= nil then
            local options = REQUIREMENT_CLASSES[class_id]
            local access = options_access(options, source.ammo)

            if access == AccessibilityLevel.Normal then
                return AccessibilityLevel.Normal
            end

            if access == AccessibilityLevel.SequenceBreak then
                best = AccessibilityLevel.SequenceBreak
            end
        end
    end

    return best
end



function gun_access()
    return requirement_class_access(GUN_REQUIREMENT_ID)
end



function find_the_gun_access()
    return gun_access()
end




function boss_arena_access()
    return requirement_class_access(BOSS_ARENA_REQUIREMENT_ID)
end


function goal_access()

    if tracker_count("gun") < 1 then
        return AccessibilityLevel.None
    end

    if tracker_count("gun_power") < 5 then
        return AccessibilityLevel.None
    end

    if tracker_count("ammo") < 5 then
        return AccessibilityLevel.None
    end

    if tracker_count("time_limit") < 18 then
        return AccessibilityLevel.None
    end

    return boss_arena_access()
end




local SHOP_MAX_TIERS = {
    speed = 10,
    jump_force = 10,
    double_jump = 1,
    time_limit = 24,
    health = 5,
    ammo = 10,
    gun_power = 5,
    coin_multiplier = 10,
}

local SHOP_MULTIPLIER_GATES = {
    speed = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 1,
        [6] = 2,
        [7] = 3,
        [8] = 6,
        [9] = 8,
        [10] = 9,
    },

    jump_force = {
        [1] = 0,
        [2] = 0,
        [3] = 1,
        [4] = 2,
        [5] = 2,
        [6] = 3,
        [7] = 4,
        [8] = 5,
        [9] = 6,
        [10] = 7,
    },

    time_limit = {
        [1] = 0,
        [2] = 1,
        [3] = 1,
        [4] = 2,
        [5] = 3,
        [6] = 3,
        [7] = 4,
        [8] = 4,
        [9] = 5,
        [10] = 5,
        [11] = 5,
        [12] = 6,
        [13] = 6,
        [14] = 7,
        [15] = 7,
        [16] = 7,
        [17] = 8,
        [18] = 8,
        [19] = 8,
        [20] = 9,
        [21] = 9,
        [22] = 9,
        [23] = 9,
        [24] = 9,
    },

    health = {
        [1] = 1,
        [2] = 2,
        [3] = 4,
        [4] = 5,
        [5] = 7,
    },

    ammo = {
        [1] = 0,
        [2] = 2,
        [3] = 3,
        [4] = 4,
        [5] = 5,
        [6] = 6,
        [7] = 7,
        [8] = 8,
        [9] = 8,
        [10] = 9,
    },

    gun_power = {
        [1] = 1,
        [2] = 2,
        [3] = 4,
        [4] = 5,
        [5] = 6,
    },

    coin_multiplier = {
        [1] = 1,
        [2] = 2,
        [3] = 3,
        [4] = 3,
        [5] = 4,
        [6] = 5,
        [7] = 6,
        [8] = 7,
        [9] = 7,
        [10] = 8,
    },
}



local function shop_tier_in_logic(track, tier)

    tier = tonumber(tier)

    if tier == nil then
        return false
    end

    local max_tier = SHOP_MAX_TIERS[track]

    if max_tier == nil or tier < 1 or tier > max_tier then
        return false
    end

    if tier > 1 then
        if not shop_tier_in_logic(track, tier - 1) then
            return false
        end
    end


    if track == "double_jump" then
        return boss_arena_access() == AccessibilityLevel.Normal
    end


    local track_gates = SHOP_MULTIPLIER_GATES[track]

    if track_gates == nil then
        return false
    end

    local gate = track_gates[tier]

    if gate == nil then
        return false
    end

    if tracker_count("coin_multiplier") < gate then
        return false
    end

    return true
end

function ammo_shop_access(tier)

   
    if tracker_count("gun") < 1 then
        return AccessibilityLevel.None
    end

    return shop_tier_access("ammo", tier)
end


function gun_power_shop_access(tier)

  
    if tracker_count("gun") < 1 then
        return AccessibilityLevel.None
    end


    return shop_tier_access("gun_power", tier)
end


function shop_tier_access(track, tier)

    if shop_tier_in_logic(track, tier) then
        return AccessibilityLevel.Normal
    end

    return AccessibilityLevel.SequenceBreak
end



function speed_shop_access(tier)
    return shop_tier_access("speed", tier)
end


function jump_shop_access(tier)
    return shop_tier_access("jump_force", tier)
end


function double_jump_shop_access()
    return shop_tier_access("double_jump", 1)
end


function time_shop_access(tier)
    return shop_tier_access("time_limit", tier)
end


function health_shop_access(tier)
    return shop_tier_access("health", tier)
end


function energy_shop_access(tier)
    return health_shop_access(tier)
end




function coin_multiplier_shop_access(tier)
    return shop_tier_access("coin_multiplier", tier)
end


function shop_access()

    local tracks = {
        "speed",
        "jump_force",
        "double_jump",
        "time_limit",
        "health",
        "ammo",
        "gun_power",
        "coin_multiplier",
    }

    for _, track in ipairs(tracks) do
        local max_tier = SHOP_MAX_TIERS[track]

        for tier = 1, max_tier do
            if shop_tier_in_logic(track, tier) then
                return AccessibilityLevel.Normal
            end
        end
    end

    return AccessibilityLevel.SequenceBreak
end



function requirement_access(class_id)
    return requirement_class_access(class_id)
end

print("Johnny Upgrade logic loaded")
