-- use this file to map the AP item ids to your items
-- first value is the code of the target item and the second is the item type (currently only "toggle", "progressive" and "consumable" but feel free to expand for your needs!)
-- here are the SM items as an example: https://github.com/Cyb3RGER/sm_ap_tracker/blob/main/scripts/autotracking/item_mapping.lua
ITEM_MAPPING = {
    [9990000] = {"speed", "consumable"},
    [9990001] = {"jump_force", "consumable"},
    [9990002] = {"double_jump", "toggle"},
    [9990003] = {"time_limit", "consumable"},
    [9990004] = {"health", "consumable"},
    [9990005] = {"ammo", "consumable"},
    [9990006] = {"gun_power", "consumable"},
    [9990007] = {"coin_multiplier", "consumable"},
    [9990013] = {"gun", "toggle"},
}