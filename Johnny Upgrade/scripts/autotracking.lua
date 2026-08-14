-- Johnny Upgrade Archipelago autotracking
-- Tracks received AP progression items and completed AP locations.

ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")

local function debug_log(...)
    if ENABLE_DEBUG_LOG then
        print("[Johnny Upgrade AP]", ...)
    end
end

local function reset_item(code, item_type)
    local obj = Tracker:FindObjectForCode(code)
    if obj == nil then
        debug_log("Missing tracker item:", code)
        return
    end
    if item_type == "toggle" then
        obj.Active = false
    elseif item_type == "consumable" then
        obj.AcquiredCount = 0
    elseif item_type == "progressive" or item_type == "progressive_toggle" then
        obj.CurrentStage = 0
        if item_type == "progressive_toggle" then obj.Active = false end
    end
end

local function reset_location(code)
    local obj = Tracker:FindObjectForCode(code)
    if obj == nil then
        debug_log("Missing tracker location:", code)
        return
    end
    obj.AvailableChestCount = obj.ChestCount
    obj.Highlight = Highlight.None
end


local HINT_KEY = nil
HINTED_LOCATIONS = HINTED_LOCATIONS or {}

local function force_hint_logic_refresh()

    local obj = Tracker:FindObjectForCode("hint_refresh")

    if obj == nil then
        debug_log("Missing hint_refresh item")
        return
    end

    obj.Active = not obj.Active

    debug_log(
        "Hint logic refresh:",
        tostring(obj.Active)
    )
end

local function onClear(slot_data)
    debug_log("Connected; resetting tracked state")

    local function set_toggle(code, value)
        local obj = Tracker:FindObjectForCode(code)

        if obj ~= nil then
            obj.Active = value == true
        end
    end



    local reset_codes = {}
    for _, mapping in pairs(ITEM_MAPPING) do
        local code = mapping[1]
        if not reset_codes[code] then
            reset_item(code, mapping[2])
            reset_codes[code] = true
        end
    end

    local reset_locations = {}
    for _, codes in pairs(LOCATION_MAPPING) do
        for _, code in ipairs(codes) do
            if not reset_locations[code] then
                reset_location(code)
                reset_locations[code] = true
            end
        end
    end

    for location_id, _ in pairs(HINTED_LOCATIONS) do
        HINTED_LOCATIONS[location_id] = nil
    end

    local team = Archipelago.TeamNumber
    local player = Archipelago.PlayerNumber

    if team == nil or team < 0 then
        team = 0
    end

    if player ~= nil and player > 0 then

        HINT_KEY =
            "_read_hints_"
            .. tostring(team)
            .. "_"
            .. tostring(player)

        debug_log("Watching hints:", HINT_KEY)

        Archipelago:SetNotify({HINT_KEY})
        Archipelago:Get({HINT_KEY})
    end
end

local function onItem(index, item_id, item_name, player_number)
    local mapping = ITEM_MAPPING[item_id]
    if mapping == nil then
        return -- filler/useful/trap item not represented on the tracker
    end

    local code = mapping[1]
    local item_type = mapping[2]
    local obj = Tracker:FindObjectForCode(code)
    if obj == nil then
        debug_log("Could not find item for", item_id, item_name, code)
        return
    end

    if item_type == "toggle" then
        obj.Active = true
    elseif item_type == "consumable" then
        obj.AcquiredCount = obj.AcquiredCount + 1
    elseif item_type == "progressive" or item_type == "progressive_toggle" then
        obj.CurrentStage = obj.CurrentStage + 1
        if item_type == "progressive_toggle" then obj.Active = true end
    end

    debug_log("Item", index, item_id, item_name, "->", code)
end

local function onLocation(location_id, location_name)
    local codes = LOCATION_MAPPING[location_id]
    if codes == nil then
        debug_log("Unmapped location", location_id, location_name)
        return
    end

    for _, code in ipairs(codes) do
        local obj = Tracker:FindObjectForCode(code)
        if obj ~= nil then
            obj.AvailableChestCount = 0
        else
            debug_log("Could not find location section", code, location_name)
        end
    end

    HINTED_LOCATIONS[location_id] = nil

    debug_log("Location", location_id, location_name, "checked")
end



local function clear_hints()

    for location_id, _ in pairs(HINTED_LOCATIONS) do
        HINTED_LOCATIONS[location_id] = nil
    end
end


local function apply_hints(hints)

    clear_hints()

    if type(hints) ~= "table" then
        debug_log("Hint data was not a table")
        return
    end

    local my_player = Archipelago.PlayerNumber

    for _, hint in pairs(hints) do

        if type(hint) == "table" then

            local location_id = tonumber(hint.location)
            local finding_player = tonumber(hint.finding_player)
            local status = tonumber(hint.status) or 0

            local found =
                hint.found == true
                or status == 40

            if location_id ~= nil
                and finding_player == my_player
                and not found
                and LOCATION_MAPPING[location_id] ~= nil
            then

                HINTED_LOCATIONS[location_id] = true

                debug_log("Hinted location:", location_id)
            end
        end
    end
    force_hint_logic_refresh()
end


local function onHintsRetrieved(key, value)

    if key ~= HINT_KEY then
        return
    end

    debug_log("Received current hint list")
    apply_hints(value)
end


local function onHintsChanged(key, value, old_value)

    if key ~= HINT_KEY then
        return
    end

    debug_log("Hint list changed")
    apply_hints(value)
end

Archipelago:AddClearHandler("JohnnyUpgrade_Clear", onClear)
Archipelago:AddItemHandler("JohnnyUpgrade_Items", onItem)
Archipelago:AddLocationHandler("JohnnyUpgrade_Locations", onLocation)
Archipelago:AddRetrievedHandler("JohnnyUpgrade_HintsGet", onHintsRetrieved)

Archipelago:AddSetReplyHandler("JohnnyUpgrade_HintsChanged", onHintsChanged)

debug_log("Archipelago autotracking loaded")
