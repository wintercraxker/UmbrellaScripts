-- Timbersaw combo helper for the same Lua game API used by better_techies_combo.lua.
-- Adds a separate entry under Heroes > Hero List > Timbersaw.
-- Hold the configured key: cast Timber Chain toward the farthest suitable tree,
-- then Blink behind the selected enemy (or to the nearest reachable point).

local script = {}
-- Menu widgets must live in a group beneath the hero-specific tab. This mirrors
-- the Heroes > Hero List menu layout used by the Techies script.
-- Place the combo group inside Timbersaw's existing Main Settings page.
local ROOT = { "Heroes", "Hero List", "Timbersaw", "Main Settings", "BOOM COMBO" }
local menu = Menu.Create(table.unpack(ROOT))

local ui = {
    enable = menu:Switch("Enable", false),
    key = menu:Bind("Combo Key", Enum.ButtonCode.KEY_NONE),
}

local COMBO_ITEMS = {
    ["BKB"] = { "item_black_king_bar" },
    ["Hex"] = { "item_sheepstick" },
    ["Bloodthorn"] = { "item_bloodthorn" },
    ["Orchid"] = { "item_orchid" },
    ["Nullifier"] = { "item_nullifier" },
    ["Lotus Orb"] = { "item_lotus_orb" },
    ["Ethereal Blade"] = { "item_ethereal_blade" },
    ["Veil of Discord"] = { "item_veil_of_discord" },
    ["Dagon"] = { "item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon" },
    ["Spirit Vessel"] = { "item_spirit_vessel" },
    ["Urn of Shadows"] = { "item_urn_of_shadows" },
    ["Gleipnir"] = { "item_gungir" },
    ["Rod of Atos"] = { "item_rod_of_atos" },
    ["Heaven's Halberd"] = { "item_heavens_halberd" },
    ["Phase Boots"] = { "item_phase_boots" },
    ["Drums"] = { "item_ancient_janggo", "item_drums" },
    ["Disperser"] = { "item_disperser" },
}

local NO_TARGET_COMBO_ITEMS = {
    ["BKB"] = true, ["Phase Boots"] = true,
    ["Drums"] = true,
}

local POINT_TARGET_COMBO_ITEMS = {
    ["Gleipnir"] = true,
}

ui.items = menu:MultiSelect("Items Usage", {
    { "BKB", "panorama/images/items/black_king_bar_png.vtex_c", false },
    { "Hex", "panorama/images/items/sheepstick_png.vtex_c", false },
    { "Bloodthorn", "panorama/images/items/bloodthorn_png.vtex_c", false },
    { "Orchid", "panorama/images/items/orchid_png.vtex_c", false },
    { "Nullifier", "panorama/images/items/nullifier_png.vtex_c", false },
    { "Lotus Orb", "panorama/images/items/lotus_orb_png.vtex_c", false },
    { "Ethereal Blade", "panorama/images/items/ethereal_blade_png.vtex_c", false },
    { "Veil of Discord", "panorama/images/items/veil_of_discord_png.vtex_c", false },
    { "Dagon", "panorama/images/items/dagon_5_png.vtex_c", false },
    { "Spirit Vessel", "panorama/images/items/spirit_vessel_png.vtex_c", false },
    { "Urn of Shadows", "panorama/images/items/urn_of_shadows_png.vtex_c", false },
    { "Gleipnir", "panorama/images/items/gungir_png.vtex_c", false },
    { "Rod of Atos", "panorama/images/items/rod_of_atos_png.vtex_c", false },
    { "Heaven's Halberd", "panorama/images/items/heavens_halberd_png.vtex_c", false },
    { "Phase Boots", "panorama/images/items/phase_boots_png.vtex_c", false },
    { "Drums", "panorama/images/items/ancient_janggo_png.vtex_c", false },
    { "Disperser", "panorama/images/items/disperser_png.vtex_c", false },
    { "Soul Ring", "panorama/images/items/soul_ring_png.vtex_c", true },
}, false)
ui.items:Icon("\u{e196}")

local BLINK_NAMES = {
    "item_blink", "item_swift_blink", "item_arcane_blink", "item_overwhelming_blink",
}

local run = nil
local hold_consumed = false
local damage_state = { next_update = 0, last_target = nil, messages = nil, until_at = 0 }

local function log(_) end

local function valid_unit(unit)
    return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end

local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

local function normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length < 0.001 then return 0, 0 end
    return x / length, y / length
end

local function pick_target(me)
    local target = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
    if valid_unit(target) and NPC.IsVisible(target) then return target end
    return nil
end

local function tree_position(tree)
    if not tree then return nil end
    if Tree and Tree.GetPosition then
        local ok, pos = pcall(Tree.GetPosition, tree)
        if ok and pos then return pos end
    end
    if Entity and Entity.GetAbsOrigin then
        local ok, pos = pcall(Entity.GetAbsOrigin, tree)
        if ok and pos then return pos end
    end
    if type(tree) == "table" and tree.x and tree.y then return tree end
    return nil
end

local function farthest_reachable_tree(me, chain)
    if not Trees or not Trees.InRadius then return nil end
    local origin = Entity.GetAbsOrigin(me)
    local cast_range = Ability.GetCastRange(chain)
    if not cast_range or cast_range <= 0 then cast_range = 1200 end
    local tree_search_radius = 90
    local ok, trees = pcall(Trees.InRadius, origin, cast_range + tree_search_radius, true)
    if not ok or type(trees) ~= "table" then return nil end

    local candidates = {}
    for _, tree in pairs(trees) do
        local pos = tree_position(tree)
        if pos then
            local distance_sq = dist2(origin, pos)
            if (not Tree or not Tree.IsActive or Tree.IsActive(tree))
                and distance_sq <= cast_range * cast_range then
                candidates[#candidates + 1] = { pos = pos, distance_sq = distance_sq }
            end
        end
    end

    table.sort(candidates, function(a, b) return a.distance_sq > b.distance_sq end)
    local fallback = candidates[1] and candidates[1].pos or nil
    for _, candidate in ipairs(candidates) do
        local dx = candidate.pos.x - origin.x
        local dy = candidate.pos.y - origin.y
        local length = math.sqrt(dx * dx + dy * dy)
        local blocked = false
        if length > 1 then
            local ux, uy = dx / length, dy / length
            for _, other in pairs(trees) do
                local other_pos = tree_position(other)
                if other_pos and (not Tree or not Tree.IsActive or Tree.IsActive(other)) then
                    local ox, oy = other_pos.x - origin.x, other_pos.y - origin.y
                    local along = ox * ux + oy * uy
                    if along > 40 and along < length - 40 then
                        local px, py = ox - ux * along, oy - uy * along
                        if px * px + py * py <= tree_search_radius * tree_search_radius then
                            blocked = true
                            break
                        end
                    end
                end
            end
        end
        if not blocked then return candidate.pos end
    end
    -- If every long path is crossed by a closer tree, aim at the farthest tree;
    -- the game will latch to the first tree the chain actually intersects.
    return fallback
end

local function get_blink(me)
    for _, name in ipairs(BLINK_NAMES) do
        local item = NPC.GetItem(me, name)
        if item and Item.IsItemEnabled(item) and Ability.IsCastable(item, NPC.GetMana(me)) then
            return item
        end
    end
    return nil
end

local function ready_combo_item(me, names)
    for _, name in ipairs(names) do
        local item = NPC.GetItem(me, name)
        if item and Item.IsItemEnabled(item) and Ability.IsCastable(item, NPC.GetMana(me)) then
            return item
        end
    end
    return nil
end

local function use_selected_combo_item(me, state)
    if not ui.items then return false end
    state.items_done = state.items_done or {}
    local used_any = false
    for _, id in ipairs(ui.items:ListEnabled()) do
        if id ~= "Soul Ring" and not state.items_done[id] then
            local names = COMBO_ITEMS[id]
            local item = names and ready_combo_item(me, names) or nil
            if item then
                local target_valid = valid_unit(state.target)
                local cast_sent = false
                if NO_TARGET_COMBO_ITEMS[id] then
                    Ability.CastNoTarget(item, false, true, false, "timber_item_" .. id)
                    cast_sent = true
                elseif POINT_TARGET_COMBO_ITEMS[id] then
                    local target_pos = target_valid and Entity.GetAbsOrigin(state.target) or nil
                    if target_pos then
                        Ability.CastPosition(item, target_pos, false, true, false, "timber_item_" .. id)
                        cast_sent = true
                    end
                elseif target_valid then
                    Ability.CastTarget(item, state.target, false, true, false, "timber_item_" .. id)
                    cast_sent = true
                end
                if cast_sent then
                    state.items_done[id] = true
                    used_any = true
                    log("Combo item order sent: " .. id)
                end
            elseif names then
                -- Keep owned items that are temporarily unavailable eligible
                -- for the post-return pass; absent items need no retry.
                local owned = false
                for _, name in ipairs(names) do
                    if NPC.GetItem(me, name) then owned = true; break end
                end
                if not owned then state.items_done[id] = true end
            else
                state.items_done[id] = true
            end
        end
    end
    return used_any
end

local function get_ready_ability(me, name)
    local ability = NPC.GetAbility(me, name)
    if not ability or not Entity.IsEntity(ability) or not Entity.IsAbility(ability)
        or Ability.IsHidden(ability) or not Ability.IsActivated(ability)
        or not Ability.IsCastable(ability, NPC.GetMana(me)) then
        return nil
    end
    return ability
end

local function try_cast_chakram(me, state, now)
    local chakram = NPC.GetAbility(me, "shredder_chakram")
    if not chakram or not Entity.IsEntity(chakram) or not Entity.IsAbility(chakram)
        or not Ability.IsCastable(chakram, NPC.GetMana(me)) then
        return false
    end
    local target_pos = valid_unit(state.target) and Entity.GetAbsOrigin(state.target) or nil
    if not target_pos then return false end

    state.chakram = chakram
    state.phase = "chakram"
    state.last_chakram_attempt = now
    state.return_not_before = now + 0.02
    Ability.CastPosition(chakram, target_pos, false, true, false, "timber_chakram")
    log("Chakram cast order sent")
    return true
end

local function blink_point(me, target, blink)
    local origin = Entity.GetAbsOrigin(me)
    local enemy = Entity.GetAbsOrigin(target)
    -- Aim just beyond the enemy on the line from Timbersaw through the target.
    local dx, dy = normalize(enemy.x - origin.x, enemy.y - origin.y)
    if dx == 0 and dy == 0 then return nil end
    local desired = Vector(enemy.x + dx * 150, enemy.y + dy * 150, enemy.z)
    local range = Ability.GetCastRange(blink)
    if not range or range <= 0 then range = 1200 end
    local d2 = dist2(origin, desired)
    if d2 <= (range - 32) * (range - 32) then return desired end

    -- If the point behind the target is out of range, blink as close as possible
    -- along the same direction, with a small margin from the maximum range.
    local step = math.max(0, range - 48)
    return Vector(origin.x + dx * step, origin.y + dy * step, enemy.z)
end

local function safe_special(ability, keys, fallback)
    if ability and Entity.IsEntity(ability) and Entity.IsAbility(ability) then
        for _, key in ipairs(keys) do
            local ok, value = pcall(Ability.GetLevelSpecialValueFor, ability, key)
            if ok and type(value) == "number" and value > 0 then return value end
        end
    end
    return fallback or 0
end

local function ability_level(ability)
    if not ability then return 0 end
    local ok, level = pcall(Ability.GetLevel, ability)
    return ok and type(level) == "number" and level or 0
end

local function has_real_item(me, name)
    local item = NPC.GetItem(me, name)
    return item and Item.IsItemEnabled(item) or false
end

local function kaya_item_amp(me)
    if has_real_item(me, "item_yasha_and_kaya") or has_real_item(me, "item_kaya_and_sange") then
        return 0.12
    end
    if has_real_item(me, "item_kaya") then return 0.10 end
    return 0
end

local function spell_amp(me)
    if NPC.GetSpellAmplification then
        local ok, value = pcall(NPC.GetSpellAmplification, me)
        if ok and type(value) == "number" then
            if math.abs(value) > 1.5 then value = value / 100 end
            return value
        end
    end
    local base = 0
    if NPC.GetBaseSpellAmp then
        local ok, value = pcall(NPC.GetBaseSpellAmp, me)
        if ok and type(value) == "number" then
            base = math.abs(value) > 1.5 and value / 100 or value
        end
    end
    return base + kaya_item_amp(me)
end

local function is_strength_primary(hero)
    if not Hero or not Hero.GetPrimaryAttribute or not Enum.Attributes then return false end
    local ok, primary = pcall(Hero.GetPrimaryAttribute, hero)
    if not ok then return false end
    for name, value in pairs(Enum.Attributes) do
        if value == primary and tostring(name):find("STRENGTH") then return true end
    end
    return false
end

local function count_trees_near(point, radius)
    if not Trees or not Trees.InRadius then return 0 end
    local ok, trees = pcall(Trees.InRadius, point, radius, true)
    if not ok or type(trees) ~= "table" then return 0 end
    local count = 0
    for _, tree in pairs(trees) do
        if (not Tree or not Tree.IsActive or Tree.IsActive(tree)) then
            local pos = tree_position(tree)
            if pos and dist2(point, pos) <= radius * radius then count = count + 1 end
        end
    end
    return count
end

local function magic_damage_multiplier(target)
    if NPC.GetMagicalArmorDamageMultiplier then
        local ok, value = pcall(NPC.GetMagicalArmorDamageMultiplier, target)
        if ok and type(value) == "number" and value >= 0 then
            if value > 1.5 then value = value / 100 end
            return value
        end
    end
    if NPC.GetMagicalArmorValue then
        local ok, resist = pcall(NPC.GetMagicalArmorValue, target)
        if ok and type(resist) == "number" then
            if math.abs(resist) > 1.5 then resist = resist / 100 end
            return math.max(0, 1 - resist)
        end
    end
    return 0.75
end

local function combo_item_in_range(me, target, point, item)
    local origin = point or Entity.GetAbsOrigin(me)
    local target_pos = Entity.GetAbsOrigin(target)
    local range = Ability.GetCastRange(item)
    if not range or range <= 0 then range = 700 end
    if NPC.GetCastRangeBonus then
        local ok, bonus = pcall(NPC.GetCastRangeBonus, me)
        if ok and type(bonus) == "number" then range = range + bonus end
    end
    return dist2(origin, target_pos) <= (range + 80) * (range + 80)
end

local function combo_item_damage(me, target, combo_point, spell_amp, chakram_damage, spell_damage)
    if not ui.items then return 0 end
    local magic_mult = magic_damage_multiplier(target)
    local target_hp = Entity.GetHealth(target)
    local damage = 0
    local incoming_magic_amp = 1
    local first_item_id = nil
    local soul_burn_ratio = nil
    local soul_burn_damage = 0
    local vessel_item, urn_item = nil, nil

    for _, id in ipairs(ui.items:ListEnabled()) do
        if id ~= "Soul Ring" and COMBO_ITEMS[id] then
            local item = ready_combo_item(me, COMBO_ITEMS[id])
            if item and combo_item_in_range(me, target, combo_point, item) then
                if not first_item_id then first_item_id = id end

                if id == "Dagon" then
                    local dagon_levels = {400, 500, 600, 700, 800}
                    local level = 1
                    if Ability.GetName then
                        local ok, name = pcall(Ability.GetName, item)
                        local suffix = ok and type(name) == "string" and name:match("item_dagon_(%d+)")
                        if suffix then level = math.max(1, math.min(5, tonumber(suffix) or 1)) end
                    end
                    local raw = safe_special(item, {"damage", "blast_damage"}, dagon_levels[level])
                    local dealt = raw * (1 + spell_amp) * magic_mult * incoming_magic_amp
                    damage = damage + dealt
                    if soul_burn_ratio then soul_burn_damage = soul_burn_damage + dealt end
                elseif id == "Ethereal Blade" then
                    local stats = 0
                    for _, getter in ipairs({"GetStrengthTotal", "GetAgilityTotal", "GetIntellectTotal"}) do
                        if Hero and Hero[getter] then
                            local ok, value = pcall(Hero[getter], me)
                            if ok and type(value) == "number" then stats = stats + value end
                        end
                    end
                    local raw = safe_special(item, {"blast_damage", "damage"}, 50 + stats)
                    local dealt = raw * 1.30 * (1 + spell_amp) * magic_mult * incoming_magic_amp
                    damage = damage + dealt
                    if soul_burn_ratio then soul_burn_damage = soul_burn_damage + dealt end
                    incoming_magic_amp = incoming_magic_amp * 1.30
                elseif id == "Veil of Discord" then
                    -- Veil's current spell-damage amplification affects later
                    -- spell damage and magical item hits.
                    incoming_magic_amp = incoming_magic_amp * 1.10
                elseif id == "Bloodthorn" or id == "Orchid" then
                    if not soul_burn_ratio then
                        soul_burn_ratio = id == "Bloodthorn" and 0.60 or 0.30
                    end
                elseif id == "Spirit Vessel" then
                    vessel_item = item
                elseif id == "Urn of Shadows" then
                    urn_item = item
                end
            end
        end
    end

    if first_item_id == "Bloodthorn" or first_item_id == "Orchid" then
        soul_burn_damage = soul_burn_damage + chakram_damage
    end
    if soul_burn_ratio and soul_burn_damage > 0 then
        damage = damage + soul_burn_damage * soul_burn_ratio * magic_mult
    end

    -- Urn and Vessel share the same Soul Release effect; Vessel supersedes Urn.
    local dot_item = vessel_item or urn_item
    if dot_item then
        local vessel = vessel_item ~= nil
        local current_hp = math.max(0, target_hp - spell_damage - damage)
        for _ = 1, 8 do
            local raw_tick = 25
            if vessel then raw_tick = raw_tick + current_hp * 0.04 end
            local tick = math.min(current_hp, raw_tick * (1 + spell_amp) * magic_mult)
            damage = damage + tick
            current_hp = math.max(0, current_hp - tick)
        end
    end

    return damage
end

local function calculate_combo_damage(me, target)
    if not target then return nil end

    local whirling = NPC.GetAbility(me, "shredder_whirling_death")
    local chain = NPC.GetAbility(me, "shredder_timber_chain")
    local chakram = NPC.GetAbility(me, "shredder_chakram")
    local q_level = ability_level(whirling)
    local w_level = ability_level(chain)
    local r_level = ability_level(chakram)
    if q_level < 1 or w_level < 1 or r_level < 1 then return nil end

    local levels_q = {60, 120, 180, 240}
    local levels_w = {45, 105, 165, 225}
    local levels_r = {75, 150, 225}
    local q_base = safe_special(whirling, {"whirling_damage", "damage"}, levels_q[q_level] or 0)
    local q_tree_bonus = safe_special(whirling, {"tree_damage_scale", "tree_bonus_damage"}, ({9,16,23,30})[q_level] or 0)
    local q_radius = safe_special(whirling, {"whirling_radius", "radius"}, 325)
    local q_center = Entity.GetAbsOrigin(target)
    local blink = get_blink(me)
    local combo_point = q_center
    if blink then
        local predicted = blink_point(me, target, blink)
        if predicted then q_center = predicted; combo_point = predicted end
    end
    local nearby_trees = count_trees_near(q_center, q_radius)
    local q_pure = q_base + q_tree_bonus * nearby_trees

    local w_damage = safe_special(chain, {"damage"}, levels_w[w_level] or 0)
    local r_pass = safe_special(chakram, {"pass_damage"}, levels_r[r_level] or 0)
    local stat_loss_pct = safe_special(whirling, {"stat_loss_pct"}, 0.13)
    if stat_loss_pct > 1 then stat_loss_pct = stat_loss_pct / 100 end
    local strength_hp_loss = 0
    if is_strength_primary(target) and Hero and Hero.GetStrengthTotal then
        local ok, strength = pcall(Hero.GetStrengthTotal, target)
        if ok and type(strength) == "number" then
            strength_hp_loss = strength * stat_loss_pct * 22
        end
    end

    -- These Timbersaw spells deal pure damage. Kaya-family spell amp applies;
    -- magic resistance does not. Chakram is counted once outward and once back.
    local amp = spell_amp(me)
    local q_final = q_pure * (1 + amp)
    local w_final = w_damage * (1 + amp)
    local r_final = r_pass * 2 * (1 + amp)
    local spell_damage = q_final + w_final + r_final + strength_hp_loss
    local item_damage = combo_item_damage(me, target, combo_point, amp, r_final, spell_damage)
    if ui.items:Get("Veil of Discord") then
        local first_item_id
        for _, id in ipairs(ui.items:ListEnabled()) do
            if id ~= "Soul Ring" and COMBO_ITEMS[id] then
                local item = ready_combo_item(me, COMBO_ITEMS[id])
                if item and combo_item_in_range(me, target, combo_point, item) then
                    first_item_id = id
                    break
                end
            end
        end
        if first_item_id == "Veil of Discord" then
            item_damage = item_damage + r_final * 0.10
        end
    end
    return spell_damage + item_damage
end

local function hero_display_name(hero)
    local name = NPC.GetUnitName(hero) or "Герой"
    name = name:gsub("^npc_dota_hero_", ""):gsub("_", " ")
    return name:gsub("(%S)(%S*)", function(first, rest)
        return first:upper() .. rest
    end)
end

local hero_icons = {}
local function get_hero_icon(unit)
    if not Render or not Render.LoadImage then return nil end
    local unit_name = NPC.GetUnitName(unit)
    if not unit_name or unit_name == "" then return nil end
    if hero_icons[unit_name] ~= nil then return hero_icons[unit_name] or nil end

    -- Dota hero icon assets use the unit name with the Panorama _png suffix.
    local path = "panorama/images/heroes/icons/" .. unit_name .. "_png.vtex_c"
    local ok, image = pcall(Render.LoadImage, path)
    if not ok or not image then
        -- Some builds expose the same asset without the compiled-texture suffix.
        ok, image = pcall(Render.LoadImage, "panorama/images/heroes/icons/" .. unit_name .. ".png")
    end
    hero_icons[unit_name] = ok and image or false
    return hero_icons[unit_name] or nil
end

local function update_lethal_message(me, now)
    if now < damage_state.next_update then return end
    damage_state.next_update = now + 0.15
    local entries, ids = {}, {}
    local my_team = Entity.GetTeamNum(me)
    for _, enemy in pairs(Heroes.GetAll()) do
        if valid_unit(enemy) and Entity.GetTeamNum(enemy) ~= my_team and NPC.IsVisible(enemy) then
            local estimate = calculate_combo_damage(me, enemy)
            if estimate and estimate >= Entity.GetHealth(enemy) then
                local id = tostring(Entity.GetIndex(enemy))
                entries[#entries + 1] = { id = id, name = hero_display_name(enemy), icon = get_hero_icon(enemy) }
                ids[#ids + 1] = id
            end
        end
    end
    if #entries > 0 then
        table.sort(entries, function(a, b) return a.name < b.name end)
        table.sort(ids)
        local key = table.concat(ids, ",")
        if damage_state.last_target ~= key then
            damage_state.messages = entries
            damage_state.until_at = now + 2.0
        end
        damage_state.last_target = key
    else
        damage_state.last_target = nil
    end
end

local function start(me)
    local target = pick_target(me)
    if not target then log("no visible enemy under cursor"); return false end
    local chain = NPC.GetAbility(me, "shredder_timber_chain")
    local blink = get_blink(me)
    if not chain or not Entity.IsEntity(chain) or not Entity.IsAbility(chain) then
        log("Timber Chain is unavailable"); return false
    end
    if not blink then log("Blink is unavailable"); return false end

    local tree = farthest_reachable_tree(me, chain)
    if not tree then log("no active tree within Timber Chain range"); return false end

    local point = blink_point(me, target, blink)
    if not point then return false end
    local now = GameRules.GetGameTime()
    local cooldown = Ability.GetCooldown(chain)
    if ui.items:Get("Soul Ring") then
        local soul_ring = ready_combo_item(me, { "item_soul_ring" })
        if soul_ring then
            Ability.CastNoTarget(soul_ring, false, true, false, "timber_soul_ring")
            run = {
                target = target, chain = chain, chain_cooldown = cooldown,
                tree = tree, blink_point = point, sent_at = now,
                deadline = now + 0.5, retries = 0, phase = "soul_ring",
            }
            return true
        end
    end
    if not Ability.IsCastable(chain, NPC.GetMana(me)) then
        log("Timber Chain is unavailable"); return false
    end
    Ability.CastPosition(chain, tree, false, true, false, "timber_chain_combo")
    run = {
        target = target, chain = chain, chain_cooldown = cooldown,
        tree = tree, blink_point = point, sent_at = now,
        deadline = now + 1.25 + NetChannel.GetAvgLatency() * 2,
        retries = 0,
    }
    log("Timber Chain order sent; waiting for cast confirmation")
    return true
end

local function cast_blink_after_chain(me, state)
    local blink = get_blink(me)
    if not blink then log("Blink became unavailable after Timber Chain"); run = nil; return end
    local point = blink_point(me, state.target, blink)
    if not point then run = nil; return end
    state.phase = "after_blink"
    state.blink_sent_at = GameRules.GetGameTime()
    state.deadline = state.blink_sent_at + 2.0
    Ability.CastPosition(blink, point, false, true, false, "timber_chain_blink")
    log("Timber Chain confirmed; Blink order sent")
end

function script.OnUpdate()
    local me = Heroes.GetLocal()
    if valid_unit(me) and NPC.GetUnitName(me) == "npc_dota_hero_shredder" then
        if ui.enable:Get() then
            update_lethal_message(me, GameRules.GetGameTime())
        else
            damage_state.messages = nil
            damage_state.last_target = nil
        end
    end
    if not ui.enable:Get() or not valid_unit(me)
        or NPC.GetUnitName(me) ~= "npc_dota_hero_shredder" then
        run = nil
        hold_consumed = false
        return
    end
    if GameRules.IsPaused() then return end

    local first, second = ui.key:Get(), ui.key:Get(1)
    local down = first ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(first, true)
        and (second == Enum.ButtonCode.KEY_NONE or Input.IsKeyDown(second, true))
    if down and not run and not hold_consumed then
        hold_consumed = start(me)
    end
    -- The bind starts one combo. Once Timber Chain has been issued, let the
    -- sequence finish even if the key is released; release only rearms the bind.
    if not down then hold_consumed = false end

    if not run then return end
    if not valid_unit(run.target) then
        if run.phase == "wait_chakram" then
            run.phase = "post_return_items"
        elseif run.phase ~= "chakram" and run.phase ~= "post_return_items" then
            run = nil
            log("target lost")
            return
        end
    end
    local now = GameRules.GetGameTime()

    if run.phase == "soul_ring" then
        if now <= run.sent_at then return end
        if run.chain and Entity.IsEntity(run.chain) and Entity.IsAbility(run.chain)
            and Ability.IsCastable(run.chain, NPC.GetMana(me)) then
            run.phase = nil
            run.chain_cooldown = Ability.GetCooldown(run.chain)
            run.sent_at = now
            run.deadline = now + 1.25 + NetChannel.GetAvgLatency() * 2
            Ability.CastPosition(run.chain, run.tree, false, true, false, "timber_chain_combo")
        elseif now >= run.deadline then
            run = nil
        end
        return
    end

    if run.phase == "after_blink" then
        -- Give Blink one tick, cast Q, then process every selected item before R.
        if now <= (run.blink_sent_at or now) then return end
        local whirling = get_ready_ability(me, "shredder_whirling_death")
        if whirling then
            Ability.CastNoTarget(whirling, false, true, false, "timber_whirling_death")
        end
        run.items_done = {}
        -- Keep the requested order in one update: Q, every selected ready
        -- item, and then Chakram.
        use_selected_combo_item(me, run)
        run.phase = "wait_chakram"
        run.deadline = now + 3.0
        run.last_chakram_attempt = 0
        try_cast_chakram(me, run, now)
        return
    end

    if run.phase == "wait_chakram" then
        if now - (run.last_chakram_attempt or 0) >= 0.15 then
            run.last_chakram_attempt = now
            try_cast_chakram(me, run, now)
        end
        if now >= run.deadline then
            run.phase = "post_return_items"
        end
        return
    end

    if run.phase == "chakram" then
        if now < (run.return_not_before or now) then return end
        if run.chakram and Ability.IsInAbilityPhase(run.chakram) then return end
        local return_ability = NPC.GetAbility(me, "shredder_return_chakram")
        if return_ability and Entity.IsEntity(return_ability)
            and Entity.IsAbility(return_ability) and not Ability.IsHidden(return_ability)
            and Ability.IsActivated(return_ability)
            and Ability.IsCastable(return_ability, NPC.GetMana(me)) then
            Ability.CastNoTarget(return_ability, false, true, false, "timber_return_chakram")
            run.phase = "post_return_items"
            return
        end
        -- If the order was rejected, the main Chakram remains castable. Retry
        -- until the return sub-ability appears or the bounded attempt window ends.
        if now - (run.last_chakram_attempt or 0) >= 0.20
            and now < run.deadline
            and not Ability.IsInAbilityPhase(run.chakram) then
            try_cast_chakram(me, run, now)
        end
        if now >= run.deadline then run.phase = "post_return_items" end
        return
    end

    if run.phase == "post_return_items" then
        if use_selected_combo_item(me, run) then return end
        run = nil
        return
    end

    local chain_valid = run.chain and Entity.IsEntity(run.chain) and Entity.IsAbility(run.chain)
    if chain_valid and Ability.IsInAbilityPhase(run.chain) then return end

    local confirmed = chain_valid and Ability.GetCooldown(run.chain) > run.chain_cooldown + 0.01
    if not confirmed and NPC.HasModifier(me, "modifier_shredder_timber_chain") then confirmed = true end
    if confirmed then
        -- Keep the state machine alive after Blink so the Q/R/return stages run.
        cast_blink_after_chain(me, run)
        return
    end

    if now >= run.deadline then
        if run.retries < 1 and chain_valid and Ability.IsCastable(run.chain, NPC.GetMana(me)) then
            run.retries = run.retries + 1
            run.chain_cooldown = Ability.GetCooldown(run.chain)
            run.sent_at = now
            run.deadline = now + 1.25 + NetChannel.GetAvgLatency() * 2
            Ability.CastPosition(run.chain, run.tree, false, true, false, "timber_chain_combo_retry")
            log("Timber Chain was not confirmed; retrying")
        else
            run = nil
            log("Timber Chain was not confirmed; Blink cancelled")
        end
    end
end

local lethal_font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS)

function script.OnDraw()
    if not ui.enable:Get() or not damage_state.messages then return end
    local now = GameRules.GetGameTime()
    if now >= damage_state.until_at then
        damage_state.messages = nil
        damage_state.last_target = nil
        return
    end
    local screen = Render.ScreenSize()
    local blink_on = math.floor(now * 8) % 2 == 0
    if not blink_on then return end

    -- Match the compact top toast in the reference image, below the HUD.
    local y = 92
    local line_height, icon_size, gap = 34, 28, 10
    for _, entry in ipairs(damage_state.messages) do
        local prefix_size = Render.TextSize(lethal_font, 24, entry.name)
        local suffix = "Убивается BOOM COMBO"
        local suffix_size = Render.TextSize(lethal_font, 24, suffix)
        local total_width = icon_size + gap + prefix_size.x + gap + suffix_size.x
        local x = (screen.x - total_width) / 2
        local pos = Vec2(x, y)
        if entry.icon and Render.Image then
            pcall(Render.Image, entry.icon, Vec2(x, y + 2), Vec2(icon_size, icon_size))
        end
        local name_pos = Vec2(x + icon_size + gap, y)
        local suffix_pos = Vec2(name_pos.x + prefix_size.x + gap, y)
        Render.Text(lethal_font, 24, entry.name, Vec2(name_pos.x + 1, name_pos.y + 1), Color(0, 0, 0, 230))
        Render.Text(lethal_font, 24, entry.name, name_pos, Color(245, 245, 245, 255))
        Render.Text(lethal_font, 24, suffix, Vec2(suffix_pos.x + 1, suffix_pos.y + 1), Color(0, 0, 0, 230))
        Render.Text(lethal_font, 24, suffix, suffix_pos, Color(255, 70, 70, 255))
        y = y + line_height
    end
end

return script
