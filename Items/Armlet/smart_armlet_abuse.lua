--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  Smart Armlet Abuse — Script for the UMBRELLA Client (Dota 2, Lua)     ║
    ╚══════════════════════════════════════════════════════════════════════╝

    Features:
      • Does NOT toggle Armlet directly: Umbrella's built-in Armlet Abuse
        handles the toggling, while this script dynamically adjusts its
        HP threshold slider (path defined in CFG.builtin.paths).
      • The HP threshold is calculated adaptively based on nearby enemy
        damage, damage types, critical hits, ping/FPS (prediction),
        and available nukes/ultimate abilities.
      • GetSurvivalChance() — estimates the probability of surviving
        the next 1–2 seconds.
      • "Who Can Kill You" — displays the most dangerous enemy
        (icon, name, and estimated damage).
      • Top-screen notifications inspired by the reference design
        (threshold changes / safe / danger / Armlet Abuse won't
        activate in time / compact mode).
      • Draggable panel that can be minimized into a compact indicator.
      • World-space ping rings (danger zones, ON/OFF timing),
        with a 0.5-second cooldown.

    IMPORTANT (Execution Environment):
      This script is designed for Umbrella's Lua API (Menu / Render /
      Input / Entity / NPC / NPCs / Heroes / Ability / NetChannel /
      GameRules).

      All API calls are centralized in the `A` table (Section 3).
      If your Umbrella version uses different function names,
      modify only the corresponding functions in that table.

      Ability and item values in the tables below are approximate
      and should be adjusted according to the current Dota 2 patch.

    About the HP Threshold:
      The threshold represents the HP level BELOW which Armlet Abuse
      is triggered.

      The HIGHER the threshold, the earlier and more aggressively
      Armlet Abuse activates.

      Therefore, when critical hits or ultimate abilities are detected,
      the threshold INCREASES to provide a greater safety margin.
]]


local script = {}

---------------------------------------------------------------------------
-- 1. CONFIGURATION (everything that needs tuning is here)
---------------------------------------------------------------------------
local CFG = {
    debug        = false,   -- console log (duplicated by the menu switch)
    scanRadius   = 1000,    -- enemy analysis radius (800–1200)
    scanInterval = 0.03,    -- recalculation interval (sec)

    threshold = {
        base        = 250,  -- lower threshold limit (= built-in abuse slider minimum)
        min         = 250,
        max         = 500,  -- built-in abuse slider maximum
        safetyMargin= 0.15, -- extra margin above "required HP" (15%)
        decayPerSec = 150,  -- threshold return speed
        landingScale= 1.0,  -- "in-flight" damage multiplier in the threshold
        -- Armlet power is applied with a delay of ~0.6 sec (patch 7.41f), so the threshold must
        -- cover the damage during that time: required HP = DPS * (0.6 + ping/reaction).
        extraHorizon= 0.6,
        notifyDelta = 50,   -- threshold change required for a notification
    },

    window         = 1.5,   -- survival estimation window (1–2 sec)
    reactionTime   = 0.10,  -- base reaction time (sec)

    net = {
        highPing      = 150,  -- ms; above this, enable prediction
        extraLookahead= 0.20, -- extra prediction for high ping (sec)
        lowFps        = 45,   -- below this, add prediction
        lowFpsExtra   = 0.10,
    },

    crit = {
        pessimism      = 2.5, -- how much to inflate crit chance (1 = unbiased expected value)
        thresholdBonus = 120, -- +HP to the threshold for each +1.0 crit factor
    },

    ultSensitivity = 1.25,    -- sensitivity multiplier when a nuke/ultimate is ready
    abilityRangePad= 250,     -- extra enemy cast range (the enemy may approach)

    surv = { steepness = 4.0 },   -- survival chance sigmoid steepness

    allies = { radius = 900, perAlly = 0.04, maxBonus = 0.16, perHealModifier = 150 },

    weights = { hero = 1.0, tower = 0.7, summon = 0.6, creep = 0.35 },  -- threat priority
    illusionDamage = 0.35,    -- approximate damage dealt by an illusion
    towerDamagePad = 0.6,     -- towers do not always hit us: damage fraction

    armlet = {
        bonusHP        = 475,   -- HP bonus when enabled (25 STR; patch-dependent)
        drainPerSec    = 45,    -- HP drain per second (7.41f: 45; previously 40)
        reToggleDelay  = 0.03,  -- pause between off and on (sec)
        cycleCooldown  = 0.35,  -- minimum time between abuse cycles
        minToggleGap   = 0.04,
        autoOff        = true,  -- turn off when safe
        autoOffDelay   = 2.0,
        softDebuffPenalty = 0.10, -- Break/Silence — reduce expected benefit by 10%
    },

    states = { calm = 70, caution = 40, danger = 5 },  -- survival chance boundaries (%)

    colors = {
        green  = {110, 210, 110, 255},
        yellow = {235, 190, 80, 255},
        red    = {235, 85, 75, 255},
        white  = {245, 245, 245, 255},
        gray   = {150, 155, 150, 255},
        pill   = {18, 18, 18, 215},
        panel  = {14, 16, 14, 200},
        accent = {225, 50, 50, 255},
        ringOn = {110, 210, 110, 255},
        ringOff= {170, 170, 170, 255},
    },

    toasts = {
        enabled  = true,
        y        = 70,      -- top offset
        life     = 2.6,
        cooldown = 0.5,     -- no more than once every 0.5 sec per key
        chanceDelta = 10,   -- show a notification when survival chance changes by ±N%
                            -- (configured in the script menu)
        max      = 4,
        compact  = false,   -- true = compact banners (heart + HP + chance)
    },

    pings = {
        enabled  = true,
        cooldown = 0.5,     -- per threat
        life     = 0.9,
        toggleLife = 0.8,
    },

    panel = { x = 60, y = 300, w = 250, compact = false },

    -- Where the script tab is created in the Umbrella menu if the built-in
    -- abuse page cannot be found (otherwise, use the page containing its slider).
    menu = { page = { "Miscellaneous", "In Game", "Armlet Abuse" } },

    -- Umbrella's built-in Armlet abuse: we do NOT toggle the item, only
    -- write the threshold to its slider.
    builtin = {
        enabled     = true,
        percent     = false,  -- true if the built-in abuse slider is a percentage of max HP
        minChange   = 10,     -- do not move the slider for smaller changes
        minInterval = 0.1,    -- and not more often than once every N sec
        -- Path to the built-in abuse threshold slider (tab/group/item names
        -- as shown in the Umbrella menu). The script tries paths in order. SET YOUR OWN.
        -- In-game menu: Miscellaneous > In Game > Armlet Abuse > [Main] > "Health Threshold".
        -- Explicit paths are tried first; the script then cycles through name variants.
        paths = {
            { "Miscellaneous", "In Game", "Armlet Abuse", "Main", "Armlet Abuse", "Health Threshold" },
        },
        guess = {
            top    = { "Miscellaneous", "Misc", "Other", "Прочее" },
            second = { "In Game", "В игре" },
            third  = { "Armlet Abuse", "Abuse Armlet", "Абуз Армлета" },
            tab    = { "Main", "Основной" },
            group  = { "Armlet Abuse", "Абуз Армлета" },
            name   = { "Health Threshold", "HP Threshold", "Threshold", "Порог Здоровья" },
        },
    },
}

---------------------------------------------------------------------------
-- 2. DATA (approximate values — adjust for the current patch)
---------------------------------------------------------------------------
-- Crit sources: chance (%), mult (% damage). The maximum is used (crits do not stack).
local CRIT_ITEMS = {
    item_greater_crit = { chance = 30, mult = 235 },
    item_lesser_crit  = { chance = 20, mult = 175 },
}
local CRIT_ABILITIES = {
    phantom_assassin_coup_de_grace = { chance = {15, 15, 15}, mult = {230, 350, 450} },
    juggernaut_blade_dance         = { chance = {20, 25, 30, 35}, mult = {180, 180, 180, 180} },
    skeleton_king_mortal_strike    = { chance = {15, 15, 15, 15}, mult = {250, 250, 250, 250} },
    chaos_knight_chaos_strike      = { chance = {12, 12, 12, 12}, mult = {150, 175, 200, 225} },
}

-- Nukes: dmg by level; kind = magic|pure; perMissing — damage based on the target's missing HP;
-- execute — instant-kill threshold by level.
local NUKES = {
    lina_laguna_blade        = { dmg = {450, 675, 925},  kind = "magic", range = 600,   ult = true },
    lion_finger_of_death     = { dmg = {600, 725, 850},  kind = "magic", range = 900,   ult = true },
    zuus_thundergods_wrath   = { dmg = {225, 325, 425},  kind = "magic", range = 99999, ult = true },
    queenofpain_sonic_wave   = { dmg = {325, 475, 625},  kind = "pure",  range = 1350,  ult = true,
                                 talentLevel = 20, talentDamage = 250 },
    jakiro_macropyre         = { dps = {100, 150, 200}, dur = 10, kind = "magic", range = 1400,
                                 ult = true, scepterPure = true, scepterDuration = 15,
                                 talentLevel = 20, talentDps = 25 },
    sniper_assassinate       = { dmg = {320, 445, 570},  kind = "magic", range = 3000,  ult = true },
    axe_culling_blade        = { dmg = {250, 350, 450},  kind = "pure",  range = 150,   ult = true,
                                 execute = {300, 450, 625} },
    necrolyte_reapers_scythe = { perMissing = {0.6, 0.9, 1.2}, kind = "magic", range = 600, ult = true },

    -- DoT abilities: dps by level, dur — duration (sec). Values are approximate.
    viper_viper_strike       = { dps = {70, 100, 150},  dur = 5,  kind = "magic", range = 700, ult = true },
    viper_nethertoxin        = { dps = {20, 30, 40, 50},dur = 8,  kind = "magic", range = 900 },
    venomancer_noxious_plague= { dmg = {150, 200, 250}, maxHpPct = {0.02, 0.03, 0.04},
                                 dur = 4, kind = "magic", range = 800, ult = true },
    venomancer_snakebite     = { dmg = {40, 70, 100, 130}, dps = {10, 20, 30, 40},
                                 dur = 6, kind = "magic", range = 600 },
    venomancer_venomous_gale = { dmg = {25, 50, 75, 100}, dps = {3.33, 13.33, 23.33, 33.33},
                                 dur = 15, kind = "magic", range = 800 },
}
local DAGON_DMG = { 400, 500, 600, 700, 800 }

-- States in which Armlet CANNOT be enabled (items are blocked).
local HARD_BLOCK = { "MODIFIER_STATE_STUNNED", "MODIFIER_STATE_MUTED", "MODIFIER_STATE_HEXED" }
-- "Soft" debuffs: Armlet works, but chance is reduced and the reason is shown.
local SOFT_DEBUFF = { "MODIFIER_STATE_SILENCED", "MODIFIER_STATE_PASSIVES_DISABLED" }

local HEAL_MODIFIERS = {
    "modifier_flask_healing", "modifier_bottle_regeneration", "modifier_tango_heal",
    "modifier_item_urn_heal", "modifier_item_spirit_vessel_heal", "modifier_clarity_potion",
}

---------------------------------------------------------------------------
-- 3. API ADAPTER (the only version-dependent part of Umbrella)
---------------------------------------------------------------------------
local UI = {}      -- menu elements (populated below)
local State = {}   -- shared script state

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

local function uiGet(el, default)
    if el and el.Get then
        local v = try(el.Get, el)
        if v ~= nil then return v end
    end
    return default
end

local function dbg() return CFG.debug or uiGet(UI.debug, false) end
local function log(...) if dbg() then print("[SmartArmlet]", ...) end end

local A = {}

function A.time() return try(GameRules.GetGameTime) or os.clock() end
function A.me() return try(Heroes.GetLocal) end
function A.alive(e) return e ~= nil and try(Entity.IsAlive, e) == true end
function A.dormant(e) return try(Entity.IsDormant, e) == true end
function A.pos(e) return try(Entity.GetAbsOrigin, e) end
function A.hp(e) return try(Entity.GetHealth, e) or 0 end
function A.maxHp(e) return try(Entity.GetMaxHealth, e) or 1 end
function A.mana(e) return try(NPC.GetMana, e) or 0 end
function A.unitName(e) return try(NPC.GetUnitName, e) or "unknown" end
function A.index(e) return try(Entity.GetIndex, e) or 0 end
function A.isIllusion(e) return try(NPC.IsIllusion, e) == true end
function A.sameTeam(a, b) return try(Entity.IsSameTeam, a, b) == true end

function A.dist(p1, p2)
    if not p1 or not p2 then return 99999 end
    local dx, dy = p1.x - p2.x, p1.y - p2.y
    return math.sqrt(dx * dx + dy * dy)
end

function A.classify(e)
    if not A.alive(e) or A.dormant(e) then return nil end
    if try(Entity.IsHero, e) or try(NPC.IsHero, e) then return "hero" end
    local cls = try(Entity.GetClassName, e) or ""
    if cls:find("Tower") then return "tower" end
    if try(NPC.IsStructure, e) then return nil end   -- other structures do not attack
    if try(NPC.IsCreep, e) or try(NPC.IsLaneCreep, e) then return "creep" end
    -- wards, summons, neutrals, etc.: any unit that deals damage
    if A.attackDamage(e) > 0 then return "summon" end
    return nil
end

function A.enemiesNear(me, radius)
    local pos = A.pos(me)
    local out, seen = {}, {}
    if not pos then return out end
    local r = try(NPCs.InRadius, pos, radius, try(Entity.GetTeamNum, me), Enum.TeamType.TEAM_ENEMY)
    if type(r) == "table" then
        for _, e in ipairs(r) do
            local id = A.index(e); if not seen[id] then seen[id] = true; out[#out + 1] = e end
        end
    end
    local heroes = try(Heroes.GetAll)
    if type(heroes) == "table" then
        for _, h in ipairs(heroes) do
            local id = A.index(h)
            if not seen[id] and h ~= me and not A.sameTeam(h, me)
               and A.dist(pos, A.pos(h)) <= radius then
                seen[id] = true; out[#out + 1] = h
            end
        end
    end
    return out
end

function A.alliesNear(me, radius)
    local n, pos = 0, A.pos(me)
    local heroes = try(Heroes.GetAll)
    if type(heroes) ~= "table" or not pos then return 0 end
    for _, h in ipairs(heroes) do
        if h ~= me and A.alive(h) and A.sameTeam(h, me) and not A.isIllusion(h)
           and A.dist(pos, A.pos(h)) <= radius then n = n + 1 end
    end
    return n
end

function A.armlet(me) return try(NPC.GetItem, me, "item_armlet", true) end
function A.toggleState(item) return try(Ability.GetToggleState, item) == true end

function A.hasState(e, name)
    local v = Enum and Enum.ModifierState and Enum.ModifierState[name]
    if v == nil then return false end
    return try(NPC.HasState, e, v) == true
end

function A.armorMult(me)
    local m = try(NPC.GetArmorDamageMultiplier, me)
    if m then return m end
    local armor = try(NPC.GetPhysicalArmorValue, me) or 0
    return 1 - 0.06 * armor / (1 + 0.06 * math.abs(armor))
end
function A.magicMult(me) return try(NPC.GetMagicalArmorDamageMultiplier, me) or 0.75 end

function A.modifierStacksRemaining(e, modifierName)
    if not Modifier then return 0, 0 end
    local modifiers = try(NPC.GetModifiers, e)
    if type(modifiers) ~= "table" then return 0, 0 end
    local now = A.time()
    for _, mod in pairs(modifiers) do
        if try(Modifier.GetName, mod) == modifierName then
            local stacks = try(Modifier.GetStackCount, mod) or 0
            local dieTime = try(Modifier.GetDieTime, mod) or now
            return math.max(0, stacks), math.max(0, dieTime - now)
        end
    end
    return 0, 0
end

function A.attackDamage(e)
    local d = try(NPC.GetTrueDamage, e)
    if d then return d end
    local mn, mx = try(NPC.GetMinDamage, e), try(NPC.GetMaxDamage, e)
    if mn and mx then return (mn + mx) / 2 + (try(NPC.GetBonusDamage, e) or 0) end
    return 0
end
function A.secondsPerAttack(e) return try(NPC.GetSecondsPerAttack, e) or 1.7 end
function A.attackRange(e) return try(NPC.GetAttackRange, e) or 150 end
function A.moveSpeed(e) return try(NPC.GetMoveSpeed, e) or 300 end
function A.projectileSpeed(e, kind, range)
    local s = try(NPC.GetProjectileSpeed, e)
    if s and s > 0 then return s end
    if kind == "tower" then return 750 end
    if range > 300 then return 900 end
    return 99999 -- melee range
end

-- Ping (ms) and FPS
function A.pingMs()
    local v = try(NetChannel.GetAvgLatency, Enum.Flow.FLOW_OUTGOING)
    if not v then return 0 end
    if v < 5 then v = v * 1000 end -- the API may return seconds
    return v
end

-- Rendering
local fonts, images = {}, {}
local function col(t, aMul)
    local a = t[4] * (aMul or 1)
    return Color(t[1], t[2], t[3], math.floor(clamp(a, 0, 255)))
end
local function font(bold)
    local k = bold and "b" or "n"
    if not fonts[k] then fonts[k] = try(Render.LoadFont, "Arial", 0, bold and 700 or 500) end
    return fonts[k]
end
function A.screen()
    local a, b = try(Render.ScreenSize)
    if type(a) == "number" then return a, b end
    if a then return a.x, a.y end
    return 1920, 1080
end
function A.textSize(bold, size, s)
    local v, h = try(Render.TextSize, font(bold), size, s)
    if type(v) == "number" then return v, h end
    if v then return v.x, v.y end
    return #s * size * 0.55, size
end
function A.text(bold, size, s, x, y, c, aMul)
    try(Render.Text, font(bold), size, s, Vec2(x, y), col(c, aMul))
end
function A.rect(x, y, w, h, c, aMul, round)
    try(Render.FilledRect, Vec2(x, y), Vec2(x + w, y + h), col(c, aMul), round or 0)
end
function A.circle(x, y, r, c, aMul) try(Render.FilledCircle, Vec2(x, y), r, col(c, aMul)) end
function A.line(x1, y1, x2, y2, c, aMul, th)
    try(Render.Line, Vec2(x1, y1), Vec2(x2, y2), col(c, aMul), th or 1)
end
function A.heroImage(unitName)
    if images[unitName] == nil then
        images[unitName] = try(Render.LoadImage,
            "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c") or false
    end
    return images[unitName]
end
function A.image(img, x, y, s, aMul, round)
    try(Render.Image, img, Vec2(x, y), Vec2(s, s), col({255, 255, 255, 255}, aMul), round or 0)
end
function A.worldToScreen(v)
    local p, vis = try(Render.WorldToScreen, v)
    if p and vis ~= false then return p.x, p.y end
    return nil
end
function A.cursor()
    local a, b = try(Input.GetCursorPos)
    if type(a) == "number" then return a, b end
    if a then return a.x, a.y end
    return 0, 0
end
function A.mouseDown() return try(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1) == true end

---------------------------------------------------------------------------
-- 4. MENU
---------------------------------------------------------------------------
-- The menu is created at the end of the file (after searching for built-in abuse) so our
-- script settings can be placed on the Miscellaneous > In Game > Armlet Abuse page.
function UI.create(pagePath)
    local ok, where = pcall(function()
        local grp, where
        if pagePath then
            local okp, g = pcall(function()
                local unpack_ = table.unpack or unpack
                local page = Menu.Create(unpack_(pagePath))
                return page:Create("Main"):Create("Smart Armlet Abuse")
            end)
            if okp and g then grp, where = g, table.concat(pagePath, " > ") end
        end
        if not grp then error("could not create requested menu page") end
        UI.enable     = grp:Switch("Enable", true)
        UI.radius     = grp:Slider("Analysis Radius", 600, 1500, CFG.scanRadius)
        UI.base       = grp:Slider("Base HP Threshold", 250, 500, CFG.threshold.base)
        UI.panel      = grp:Switch("Panel", true)
        UI.toasts     = grp:Switch("Top Notifications", true)
        UI.compactToast = grp:Switch("Compact Notifications", CFG.toasts.compact)
        UI.pings      = grp:Switch("World Rings", true)
        UI.compactKey = grp:Bind("Compact Panel Mode", Enum.ButtonCode.KEY_NONE)
        UI.debug      = grp:Switch("Debug Log", false)
        UI.chanceDelta   = grp:Slider("Survival Chance Notification Step (%)", 1, 50, CFG.toasts.chanceDelta)
        UI.notifyOnState = grp:Switch("Notify on State Change", false)
        return where
    end)
    if not ok then print("[SmartArmlet] Menu API unavailable — using CFG")
    else print("[SmartArmlet] menu: " .. tostring(where)) end
end

---------------------------------------------------------------------------
-- 5. NETWORK / FPS (prediction)
---------------------------------------------------------------------------
local Net = { pingMs = 0, fps = 144, frameDt = 0.007, lastPing = 0, lastClock = os.clock() }

function Net.frame()
    local c = os.clock()
    local dt = clamp(c - Net.lastClock, 0.0005, 0.5)
    Net.lastClock = c
    Net.frameDt = Net.frameDt * 0.9 + dt * 0.1
    Net.fps = 1 / Net.frameDt
end

function Net.lookahead()
    local t = A.time()
    if t - Net.lastPing > 0.25 then Net.pingMs = A.pingMs(); Net.lastPing = t end
    local lat = CFG.reactionTime + Net.pingMs / 1000
    if Net.pingMs > CFG.net.highPing then lat = lat + CFG.net.extraLookahead end
    if Net.fps < CFG.net.lowFps then lat = lat + CFG.net.lowFpsExtra + Net.frameDt * 2 end
    return lat
end

---------------------------------------------------------------------------
-- 6. DAMAGE CALCULATION
---------------------------------------------------------------------------
local Dmg = { critCache = {} }

function Dmg.viperPoisonForecast(perStackDps, currentStacks, remaining, window, expectedHits, maxStacks)
    maxStacks = maxStacks or 6
    local stacks = clamp(currentStacks or 0, 0, maxStacks)
    local activeTime = clamp(remaining or 0, 0, window)
    local futureStacks = math.min(maxStacks - stacks, math.max(0, expectedHits or 0))
    -- Applied stacks use their actual modifier count. Future hits add a smooth,
    -- half-window average; once at max stacks, hit-count noise adds no damage.
    return perStackDps * (stacks * activeTime + futureStacks * window * 0.5)
end
local Recent = { list = {} }   -- recent damage dealt to us by specific sources

function Recent.add(attackerIdx, dmg, t)
    Recent.list[#Recent.list + 1] = { id = attackerIdx, d = dmg, t = t }
    if #Recent.list > 64 then table.remove(Recent.list, 1) end
end
function Recent.get(e, t)
    local id, sum = A.index(e), 0
    for _, r in ipairs(Recent.list) do
        if r.id == id and t - r.t <= 2.0 then sum = sum + r.d end
    end
    return sum
end

function Dmg.invalidate() Dmg.critCache = {} end

local function lvlValue(tbl, lvl) return tbl[clamp(lvl, 1, #tbl)] end

function Dmg.critFactor(e)
    local id, t = A.index(e), A.time()
    local c = Dmg.critCache[id]
    if c and t - c.t < 1.0 then return c.v end
    local best = 1
    local function consider(chance, mult)
        local p = clamp(chance / 100 * CFG.crit.pessimism, 0, 1)
        local f = 1 + (mult / 100 - 1) * p
        if f > best then best = f end
    end
    for name, d in pairs(CRIT_ITEMS) do
        if try(NPC.GetItem, e, name, true) then consider(d.chance, d.mult) end
    end
    for name, d in pairs(CRIT_ABILITIES) do
        local ab = try(NPC.GetAbility, e, name)
        if ab then
            local lvl = try(Ability.GetLevel, ab) or 0
            if lvl > 0 then consider(lvlValue(d.chance, lvl), lvlValue(d.mult, lvl)) end
        end
    end
    Dmg.critCache[id] = { v = best, t = t }
    return best
end

-- Auto-attack damage over the `window` (sec)
local function attackInWindow(e, me, kind, dist, window, critF, illusion)
    local dmg = A.attackDamage(e)
    if dmg <= 0 then return 0, 0 end
    local range = A.attackRange(e) + 50
    local aps = 1 / math.max(A.secondsPerAttack(e), 0.2)
    local reach = math.max(0, dist - range) / math.max(A.moveSpeed(e), 100)
    local left = window - reach
    if left <= 0 then return 0, 0 end
    local flight = math.min(dist, range) / A.projectileSpeed(e, kind, range)
    local eff = math.max(0, left - flight)
    local hits = eff * aps + ((dist <= range) and 0.5 or 0) -- 0.5 = a hit is already winding up
    local total = dmg * A.armorMult(me) * critF * hits
    if illusion then total = total * CFG.illusionDamage end
    if kind == "tower" then total = total * CFG.towerDamagePad end
    return total, hits
end

-- Poison Attack / Poison Sting are applied by attacks, not cast as free nukes.
-- Estimate only the poison that can tick inside this forecast window.
local function attackPoisonInWindow(e, me, window, hits, illusion)
    if hits <= 0 or window <= 0 then return 0 end
    local name = A.unitName(e)
    if name == "npc_dota_hero_viper" then
        local ab = try(NPC.GetAbility, e, "viper_poison_attack")
        local lvl = ab and (try(Ability.GetLevel, ab) or 0) or 0
        if lvl > 0 then
            local hasShard = try(NPC.HasShard, e) == true
            local perStack = hasShard
                and ({4.6, 9.2, 13.8, 18.4})[clamp(lvl, 1, 4)]
                or ({4, 8, 12, 16})[clamp(lvl, 1, 4)]
            local stacks, remaining = A.modifierStacksRemaining(me, "modifier_viper_poison_attack_slow")
            local maxStacks = hasShard and 8 or 6
            local damage = Dmg.viperPoisonForecast(perStack, stacks, remaining, window, hits, maxStacks)
            return damage * A.magicMult(me) * (illusion and CFG.illusionDamage or 1)
        end
    elseif name == "npc_dota_hero_venomancer" then
        local heroLevel = try(NPC.GetCurrentLevel, e) or 1
        local damage = (9 + heroLevel) * window
        return damage * A.magicMult(me) * (illusion and CFG.illusionDamage or 1)
    end
    return 0
end

-- List of the enemy's ready nukes that can reach us
function Dmg.nukes(e, me, dist, myHp, myMaxHp)
    local out = {}
    local mana = A.mana(e)
    local function ready(ab)
        if not ab then return false end
        if (try(Ability.GetLevel, ab) or 0) <= 0 then return false end
        local r = try(Ability.IsCastable, ab, mana)
        if r == nil then r = try(Ability.IsReady, ab) end
        return r == true
    end
    for name, d in pairs(NUKES) do
        local ab = try(NPC.GetAbility, e, name)
        if ready(ab) and dist <= d.range + CFG.abilityRangePad then
            local lvl = try(Ability.GetLevel, ab) or 1
            local heroLevel = try(NPC.GetCurrentLevel, e) or 1
            local hasScepter = try(NPC.HasScepter, e) == true
            local duration = (d.scepterDuration and hasScepter) and d.scepterDuration or (d.dur or CFG.window)
            local dmgKind = (d.scepterPure and hasScepter) and "pure" or d.kind
            local raw, instant, dps = 0, 0, nil
            if d.dmg then
                instant = lvlValue(d.dmg, lvl)
                if d.talentDamage and heroLevel >= d.talentLevel then instant = instant + d.talentDamage end
                raw = instant
            end
            if d.maxHpPct then
                dps = myMaxHp * lvlValue(d.maxHpPct, lvl) / math.max(duration, 0.1)
                raw = raw + dps * math.min(duration, CFG.window)
            end
            if d.dps then
                local currentDps = lvlValue(d.dps, lvl)
                if d.talentDps and heroLevel >= d.talentLevel then currentDps = currentDps + d.talentDps end
                dps = (dps or 0) + currentDps
                raw = raw + currentDps * math.min(duration, CFG.window)
            elseif d.perMissing then
                raw = raw + (myMaxHp - myHp) * lvlValue(d.perMissing, lvl)
            end
            local lethal = d.execute and myHp <= lvlValue(d.execute, lvl) or false
            out[#out + 1] = { dmg = raw, instant = instant, dps = dps, kind = dmgKind,
                              ult = d.ult, execute = lethal }
        end
    end
    for i = 1, 5 do
        local nm = (i == 1) and "item_dagon" or ("item_dagon_" .. i)
        local it = try(NPC.GetItem, e, nm, true)
        if it and dist <= 600 + CFG.abilityRangePad and try(Ability.IsReady, it) == true then
            out[#out + 1] = { dmg = DAGON_DMG[i], kind = "magic", ult = false }
            break
        end
    end
    return out
end

-- Full assessment of one threat. Returns a table or nil.
function Dmg.threat(e, me, myPos, win, lat, hp, maxHp)
    local kind = A.classify(e)
    if not kind then return nil end
    local dist = A.dist(myPos, A.pos(e))
    local illusion = A.isIllusion(e)
    local critF = (kind == "hero") and Dmg.critFactor(e) or 1

    local physBurst, hitsBurst = attackInWindow(e, me, kind, dist, win, critF, illusion)
    local physLand, hitsLand = attackInWindow(e, me, kind, dist, lat, critF, illusion)
    physBurst = physBurst + attackPoisonInWindow(e, me, win, hitsBurst, illusion)
    physLand = physLand + attackPoisonInWindow(e, me, lat, hitsLand, illusion)

    local magic, pure, hasUlt, execute = 0, 0, false, false
    local spellLand = 0   -- ability damage arriving within the prediction horizon
    if kind == "hero" and not illusion then
        local mm = A.magicMult(me)
        for _, n in ipairs(Dmg.nukes(e, me, dist, hp, maxHp)) do
            local k = (n.kind == "magic") and mm or 1
            magic = magic + ((n.kind == "magic") and n.dmg * mm or 0)
            pure  = pure  + ((n.kind ~= "magic") and n.dmg or 0)
            -- an instant nuke lands in full; DoT uses only dps * horizon
            spellLand = spellLand + ((n.instant or (n.dps and 0 or n.dmg)) * k)
                           + (n.dps and n.dps * lat * k or 0)
            if n.ult then hasUlt = true end
            if n.execute then execute = true end
        end
    end

    local burst   = physBurst + magic + pure
    local landing = physLand + spellLand
    if burst <= 0 then return nil end

    local t = A.time()
    local score = burst * (CFG.weights[kind] or 0.3) + (hasUlt and 50 or 0)
                  + Recent.get(e, t) * 0.5
    return {
        ent = e, kind = kind, name = A.unitName(e), dist = dist,
        burst = burst, landing = landing, critF = critF, hasUlt = hasUlt,
        execute = execute, score = score,
        range = A.attackRange(e),
    }
end

function Dmg.scan(me)
    local myPos = A.pos(me)
    if not myPos then return nil end
    local radius = uiGet(UI.radius, CFG.scanRadius)
    local win, lat = CFG.window, Net.lookahead()
    local horizon = lat + CFG.threshold.extraHorizon   -- look beyond ping for the threshold
    local hp, maxHp = A.hp(me), A.maxHp(me)
    local snap = { threats = {}, burst = 0, landing = 0, hasUlt = false, critF = 1, lat = lat, horizon = horizon }
    for _, e in ipairs(A.enemiesNear(me, radius)) do
        local t = Dmg.threat(e, me, myPos, win, horizon, hp, maxHp)
        if t then
            snap.threats[#snap.threats + 1] = t
            snap.burst = snap.burst + t.burst
            snap.landing = snap.landing + t.landing
            snap.hasUlt = snap.hasUlt or t.hasUlt
            if t.critF > snap.critF then snap.critF = t.critF end
        end
    end
    table.sort(snap.threats, function(a, b) return a.score > b.score end)
    snap.killer = snap.threats[1]
    return snap
end

---------------------------------------------------------------------------
-- 7. SURVIVAL
---------------------------------------------------------------------------
local Surv = {}

function Surv.armletBlock(me)
    local flags, hard, soft = {}, false, false
    for _, s in ipairs(HARD_BLOCK) do
        if A.hasState(me, s) then hard = true; flags[#flags + 1] = s:gsub("MODIFIER_STATE_", "") end
    end
    for _, s in ipairs(SOFT_DEBUFF) do
        if A.hasState(me, s) then soft = true; flags[#flags + 1] = s:gsub("MODIFIER_STATE_", "") end
    end
    return hard, soft, flags
end

function Surv.healBonus(me)
    local h = 0
    for _, m in ipairs(HEAL_MODIFIERS) do
        if try(NPC.HasModifier, me, m) then h = h + CFG.allies.perHealModifier end
    end
    return h
end

-- Returns an evaluation table; chance is a percentage (0..100)
function Surv.evaluate(me, snap)
    local hp = A.hp(me)
    local hard, soft, flags = Surv.armletBlock(me)
    local item = A.armlet(me)

    local gain = 0
    if item and not hard then
        gain = CFG.armlet.bonusHP * (soft and (1 - CFG.armlet.softDebuffPenalty) or 1)
    end

    local ehp = hp + gain + Surv.healBonus(me)
    local allyBonus = clamp(A.alliesNear(me, CFG.allies.radius) * CFG.allies.perAlly, 0, CFG.allies.maxBonus)
    ehp = ehp * (1 + allyBonus)

    -- use the greater of calculated damage and actual DPS (captures any DoT/unaccounted damage)
    local incoming = snap and math.max(snap.burst, (snap.takenDps or 0) * CFG.window) or 0
    local chance
    if hp <= 0 then chance = 0
    elseif incoming <= 0 then chance = 100
    else
        local ratio = ehp / incoming
        chance = 100 / (1 + math.exp(-(ratio - 1) * CFG.surv.steepness))
    end
    if snap and snap.killer and snap.killer.execute then chance = chance * 0.2 end

    return {
        chance = clamp(chance, 0, 100), ehp = ehp, incoming = incoming,
        blocked = hard, flags = flags, killer = snap and snap.killer or nil,
    }
end

-- Public function per specification: chance of surviving 1–2 sec (percentage)
function GetSurvivalChance()
    return State.chance or 100
end

function Surv.stateOf(chance)
    if chance >= CFG.states.calm then return "calm"
    elseif chance >= CFG.states.caution then return "caution"
    elseif chance >= CFG.states.danger then return "danger"
    end
    return "lethal"
end

function Surv.color(chance)
    if chance >= CFG.states.calm then return CFG.colors.green end
    if chance >= CFG.states.caution then return CFG.colors.yellow end
    return CFG.colors.red
end

---------------------------------------------------------------------------
-- 8. ADAPTIVE THRESHOLD
---------------------------------------------------------------------------
local Threshold = { value = CFG.threshold.base }
local Taken = { dps = 0, lastHp = nil, lastT = nil }   -- actual incoming DPS
-- Calibrate the damage model against reality: if actual damage is higher than calculated
-- (unaccounted DoT/auras/stacks), scale the estimate up (1.0..3.0).
local Calib = { k = 1.0 }

function Taken.update(hp, armletOn, t)
    if Taken.lastHp and Taken.lastT then
        local dt = t - Taken.lastT
        if dt > 0 and dt < 0.5 then
            local drop = Taken.lastHp - hp
            if armletOn then drop = drop - CFG.armlet.drainPerSec * dt end
            -- toggling Armlet changes HP by ~±475: skip this sample,
            -- but do NOT become blind after a toggle (damage is most important during abuse)
            if Taken.lastOn ~= nil and armletOn ~= Taken.lastOn then drop = 0 end
            drop = math.max(0, drop)
            local tau = 0.35
            Taken.dps = Taken.dps * math.exp(-dt / tau) + drop / tau
        else
            Taken.dps = Taken.dps * 0.5
        end
    end
    Taken.lastHp, Taken.lastT, Taken.lastOn = hp, t, armletOn
end

function Threshold.update(snap, dt)
    local base = clamp(uiGet(UI.base, CFG.threshold.base), CFG.threshold.min, CFG.threshold.max)
    local sens = snap.hasUlt and CFG.ultSensitivity or 1
    -- Threshold = HP lost before abuse actually activates (≈ 0.6 sec power delay + ping).
    -- Use the greater of model damage (abilities/attacks in the horizon) and actual DPS from HP delta.
    local horizon = snap.horizon or ((snap.lat or 0.15) + CFG.threshold.extraHorizon)
    local fromModel = snap.landing * sens * CFG.threshold.landingScale
    local fromReal  = Taken.dps * horizon
    local need = (math.max(fromModel, fromReal) + (snap.critF - 1) * CFG.crit.thresholdBonus)
                 * (1 + CFG.threshold.safetyMargin)
    local target = clamp(math.max(base, need), CFG.threshold.min, CFG.threshold.max)
    Threshold.need, Threshold.capped = need, need > CFG.threshold.max   -- reached the slider cap

    if target >= Threshold.value then
        Threshold.value = target                                   -- upward changes are immediate
    else
        Threshold.value = math.max(target, Threshold.value - CFG.threshold.decayPerSec * dt)
    end
    return Threshold.value
end

---------------------------------------------------------------------------
-- 9. ICONS (drawn directly, without textures)
---------------------------------------------------------------------------
local Icon = {}

local function triangleDown(cx, top, w, h, c, aMul)  -- point down
    local n = math.max(2, math.floor(h))
    for i = 0, n - 1 do
        local ww = w * (1 - i / n)
        A.rect(cx - ww / 2, top + i * (h / n), ww, h / n + 0.5, c, aMul)
    end
end
local function triangleUp(cx, top, w, h, c, aMul)    -- point up
    local n = math.max(2, math.floor(h))
    for i = 0, n - 1 do
        local ww = w * (i + 1) / n
        A.rect(cx - ww / 2, top + i * (h / n), ww, h / n + 0.5, c, aMul)
    end
end

function Icon.draw(name, cx, cy, size, c, aMul)
    local s = size / 2
    if name == "heart" then
        A.circle(cx - s * 0.42, cy - s * 0.2, s * 0.55, c, aMul)
        A.circle(cx + s * 0.42, cy - s * 0.2, s * 0.55, c, aMul)
        triangleDown(cx, cy - s * 0.25, s * 1.95, s * 1.25, c, aMul)
        -- small "pulse" overlay
        A.line(cx - s * 0.8, cy + s * 0.05, cx - s * 0.25, cy + s * 0.05, CFG.colors.pill, aMul, 1.5)
        A.line(cx - s * 0.25, cy + s * 0.05, cx, cy - s * 0.4, CFG.colors.pill, aMul, 1.5)
        A.line(cx, cy - s * 0.4, cx + s * 0.3, cy + s * 0.35, CFG.colors.pill, aMul, 1.5)
        A.line(cx + s * 0.3, cy + s * 0.35, cx + s * 0.8, cy + s * 0.05, CFG.colors.pill, aMul, 1.5)
    elseif name == "arrow_up" or name == "arrow_down" then
        if name == "arrow_up" then
            triangleUp(cx, cy - s, s * 1.7, s, c, aMul)
            A.rect(cx - s * 0.2, cy, s * 0.4, s, c, aMul)
        else
            triangleDown(cx, cy, s * 1.7, s, c, aMul)
            A.rect(cx - s * 0.2, cy - s, s * 0.4, s, c, aMul)
        end
    elseif name == "warn" then
        triangleUp(cx, cy - s, s * 2, s * 1.8, c, aMul)
        A.rect(cx - 1, cy - s * 0.1, 2, s * 0.8, CFG.colors.pill, aMul)
        A.rect(cx - 1, cy + s * 0.8, 2, 2, CFG.colors.pill, aMul)
    elseif name == "skull" then
        A.circle(cx, cy - s * 0.15, s * 0.85, c, aMul)
        A.rect(cx - s * 0.45, cy + s * 0.4, s * 0.9, s * 0.55, c, aMul, 1)
        A.circle(cx - s * 0.33, cy - s * 0.15, s * 0.22, CFG.colors.pill, aMul)
        A.circle(cx + s * 0.33, cy - s * 0.15, s * 0.22, CFG.colors.pill, aMul)
    end
end

---------------------------------------------------------------------------
-- 10. TOP NOTIFICATIONS (reference style)
---------------------------------------------------------------------------
local Toast = { list = {}, lastPush = {} }

local HEADERS = {
    threshold = "THRESHOLD CHANGED",
    calm      = "CALM",
    caution   = "CAUTION",
    danger    = "DANGER",
    lethal    = "TOO LATE TO ABUSE",
}

-- Segments: {t="icon"|"text"|"sep"|"hero", ...}
local function seg_text(s, c, bold, gap) return { t = "text", s = s, c = c, b = bold, g = gap } end

function Toast.segsThreshold(value, up)
    return {
        { t = "icon", n = up and "arrow_up" or "arrow_down", c = CFG.colors.red, g = 12 },
        seg_text("HP threshold changed to", CFG.colors.white, false, 6),
        seg_text(tostring(math.floor(value + 0.5)), CFG.colors.white, true),
    }
end

function Toast.segsCap(maxValue)
    return {
        { t = "icon", n = "warn", c = CFG.colors.red, g = 12 },
        seg_text("Threshold set to maximum", CFG.colors.white, false, 6),
        seg_text(tostring(maxValue), CFG.colors.white, true),
    }
end

function Toast.segsState(stateName, thr, chance, killer, compact)
    local cc = Surv.color(chance)
    local pct = math.floor(chance + 0.5) .. "%"
    local segs = { { t = "icon", n = "heart", c = CFG.colors.red, g = compact and 8 or 12 } }
    if compact then
        segs[#segs + 1] = seg_text(tostring(math.floor(thr + 0.5)), CFG.colors.white, true, 10)
        segs[#segs + 1] = { t = "sep" }
        segs[#segs + 1] = seg_text(pct, cc, true, 6)
    else
        segs[#segs + 1] = seg_text("HP threshold", CFG.colors.white, false, 6)
        segs[#segs + 1] = seg_text(tostring(math.floor(thr + 0.5)), CFG.colors.white, true, 10)
        segs[#segs + 1] = { t = "sep" }
        segs[#segs + 1] = seg_text("Survival chance", CFG.colors.gray, false, 6)
        segs[#segs + 1] = seg_text(pct, cc, true, 6)
    end
    if stateName == "danger" then
        segs[#segs + 1] = { t = "icon", n = "warn", c = cc, g = 10 }
    elseif stateName == "lethal" then
        segs[#segs + 1] = { t = "icon", n = "skull", c = cc, g = 10 }
    end
    if not compact and killer and (stateName == "danger" or stateName == "lethal") then
        segs[#segs + 1] = { t = "sep" }
        segs[#segs + 1] = { t = "hero", unit = killer.name, kind = killer.kind, g = 8 }
        segs[#segs + 1] = seg_text("-" .. math.floor(killer.burst + 0.5), CFG.colors.white, true)
    end
    return segs
end

-- key: the same key updates an existing banner instead of creating duplicates
function Toast.push(key, header, segs, accent)
    if not CFG.toasts.enabled or not uiGet(UI.toasts, true) then return end
    local t = A.time()
    for _, it in ipairs(Toast.list) do
        if it.key == key then
            it.header, it.segs, it.accent, it.dieAt = header, segs, accent, t + CFG.toasts.life
            return
        end
    end
    if Toast.lastPush[key] and t - Toast.lastPush[key] < CFG.toasts.cooldown then return end
    Toast.lastPush[key] = t
    Toast.list[#Toast.list + 1] = {
        key = key, header = header, segs = segs, accent = accent or CFG.colors.accent,
        born = t, dieAt = t + CFG.toasts.life,
    }
    while #Toast.list > CFG.toasts.max do table.remove(Toast.list, 1) end
end

local function toastPillSize(segs)
    local w, pad = 3 + 14, 14
    for _, s in ipairs(segs) do
        local gap = s.g or 10
        if s.t == "text" then
            w = w + (A.textSize(s.b, 18, s.s)) + gap
        elseif s.t == "icon" then
            w = w + 18 + gap
        elseif s.t == "hero" then
            w = w + 26 + gap
        elseif s.t == "sep" then
            w = w + 1 + 10
        end
    end
    return w + pad - 10, 40
end

function Toast.draw()
    if #Toast.list == 0 then return end
    local t = A.time()
    local sw = A.screen()
    local y = CFG.toasts.y
    local i = 1
    while i <= #Toast.list do
        local it = Toast.list[i]
        if t >= it.dieAt then
            table.remove(Toast.list, i)
        else
            local age, left = t - it.born, it.dieAt - t
            local a = math.min(1, age / 0.18) * math.min(1, left / 0.35)
            local slide = (1 - math.min(1, age / 0.18)) * -14
            local w, h = toastPillSize(it.segs)
            local x = (sw - w) / 2
            local yy = y + slide

            A.text(true, 12, it.header, x + 2, yy, CFG.colors.gray, a)
            local py = yy + 18
            A.rect(x, py, w, h, CFG.colors.pill, a, 8)
            A.rect(x, py + 6, 3, h - 12, it.accent, a, 2)

            local cx = x + 3 + 14
            local cy = py + h / 2
            for _, s in ipairs(it.segs) do
                local gap = s.g or 10
                if s.t == "text" then
                    local tw, th = A.textSize(s.b, 18, s.s)
                    A.text(s.b, 18, s.s, cx, cy - th / 2, s.c, a)
                    cx = cx + tw + gap
                elseif s.t == "icon" then
                    Icon.draw(s.n, cx + 9, cy, 18, s.c, a)
                    cx = cx + 18 + gap
                elseif s.t == "sep" then
                    A.rect(cx, py + 8, 1, h - 16, CFG.colors.gray, a * 0.35)
                    cx = cx + 1 + 10
                elseif s.t == "hero" then
                    local img = (s.kind == "hero") and A.heroImage(s.unit)
                    if img then
                        A.image(img, cx, cy - 13, 26, a, 13)
                    else
                        A.circle(cx + 13, cy, 12, CFG.colors.red, a * 0.8)
                        A.text(true, 14, s.kind == "tower" and "T" or "C", cx + 8, cy - 8, CFG.colors.white, a)
                    end
                    cx = cx + 26 + gap
                end
            end
            y = y + 18 + h + 10
            i = i + 1
        end
    end
end

---------------------------------------------------------------------------
-- 11. PANEL (drag & drop + compact mode)
---------------------------------------------------------------------------
local Panel = { dragging = false, dx = 0, dy = 0, pressT = 0, pressX = 0, pressY = 0, wasDown = false,
                keyWas = false }

local function heroPretty(name, kind)
    if kind == "tower" then return "Tower" end
    if kind == "creep" then return "Creep" end
    local s = (name or ""):gsub("npc_dota_hero_", ""):gsub("_", " ")
    return (s:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

local function pctOfMax(me, v) return math.floor(v / math.max(A.maxHp(me), 1) * 100 + 0.5) end

function Panel.handleInput(x, y, w, hdrH)
    local mx, my = A.cursor()
    local down = A.mouseDown()
    local inHeader = mx >= x and mx <= x + w and my >= y and my <= y + hdrH

    if down and not Panel.wasDown and inHeader then
        Panel.dragging = true
        Panel.dx, Panel.dy = mx - CFG.panel.x, my - CFG.panel.y
        Panel.pressT, Panel.pressX, Panel.pressY = os.clock(), mx, my
    end
    if Panel.dragging and down then
        local sw, sh = A.screen()
        CFG.panel.x = clamp(mx - Panel.dx, 0, sw - 60)
        CFG.panel.y = clamp(my - Panel.dy, 0, sh - 40)
    end
    if Panel.dragging and not down then
        Panel.dragging = false
        local moved = math.abs(mx - Panel.pressX) + math.abs(my - Panel.pressY)
        if moved < 4 and os.clock() - Panel.pressT < 0.3 then   -- click without dragging
            CFG.panel.compact = not CFG.panel.compact
        end
    end
    Panel.wasDown = down

    -- hotkey
    local pressed = try(function() return UI.compactKey and UI.compactKey:IsPressed() end) == true
    if pressed and not Panel.keyWas then CFG.panel.compact = not CFG.panel.compact end
    Panel.keyWas = pressed
end

function Panel.draw(me)
    if not uiGet(UI.panel, true) then return end
    local p = CFG.panel
    local ch = State.chance or 100
    local cc = Surv.color(ch)
    local armOn = State.armletOn

    if p.compact then
        local w, h = 150, 34
        Panel.handleInput(p.x, p.y, w, h)
        A.rect(p.x, p.y, w, h, CFG.colors.panel, 1, 8)
        A.rect(p.x, p.y + 6, 3, h - 12, CFG.colors.accent, 1, 2)
        Icon.draw("heart", p.x + 20, p.y + h / 2, 16, CFG.colors.red)
        A.text(true, 16, math.floor(ch + 0.5) .. "%", p.x + 36, p.y + 8, cc)
        A.circle(p.x + 92, p.y + h / 2, 4, armOn and CFG.colors.green or CFG.colors.gray)
        A.text(true, 13, armOn and "ON" or "OFF", p.x + 102, p.y + 9, armOn and CFG.colors.green or CFG.colors.gray)
        return
    end

    local w, hdr = p.w, 28
    local h = hdr + 4 * 26 + 10
    Panel.handleInput(p.x, p.y, w, hdr)
    A.rect(p.x, p.y, w, h, CFG.colors.panel, 1, 8)
    A.rect(p.x, p.y + 6, 3, hdr - 8, CFG.colors.accent, 1, 2)
    A.text(true, 12, "SMART ARMLET", p.x + 14, p.y + 8, CFG.colors.gray)
    triangleDown(p.x + w - 16, p.y + 11, 9, 6, CFG.colors.gray, 1)

    local ry = p.y + hdr + 6
    local function row(label, value, vc)
        A.text(false, 14, label, p.x + 14, ry, CFG.colors.gray)
        local tw = A.textSize(true, 14, value)
        A.text(true, 14, value, p.x + w - 14 - tw, ry, vc or CFG.colors.white)
        ry = ry + 26
    end

    row("HP Threshold", math.floor(Threshold.value + 0.5) .. "  (" .. pctOfMax(me, Threshold.value) .. "%)")
    row("Survival Chance", math.floor(ch + 0.5) .. "%", cc)
    -- thin chance bar
    A.rect(p.x + 14, ry - 8, w - 28, 3, CFG.colors.gray, 0.25, 2)
    A.rect(p.x + 14, ry - 8, (w - 28) * ch / 100, 3, cc, 1, 2)

    -- who will kill you
    local k = State.killer
    A.text(false, 14, "Who Will Kill You", p.x + 14, ry, CFG.colors.gray)
    if k then
        local label = "-" .. math.floor(k.burst + 0.5)
        local tw = A.textSize(true, 14, label)
        A.text(true, 14, label, p.x + w - 14 - tw, ry, CFG.colors.red)
        local nm = heroPretty(k.name, k.kind)
        local nw = A.textSize(true, 14, nm)
        local img = (k.kind == "hero") and A.heroImage(k.name)
        local ix = p.x + w - 14 - tw - 10 - nw - 24
        if img then A.image(img, ix, ry - 3, 20, 1, 10) end
        A.text(true, 14, nm, p.x + w - 14 - tw - 6 - nw, ry, CFG.colors.white)
    else
        local tw = A.textSize(true, 14, "—")
        A.text(true, 14, "—", p.x + w - 14 - tw, ry, CFG.colors.gray)
    end
    ry = ry + 26

    -- Armlet status
    local st = State.armletOn and "ON" or "OFF"
    A.text(false, 14, "Armlet", p.x + 14, ry, CFG.colors.gray)
    local reason = State.lastReason or "—"
    if #reason > 22 then reason = reason:sub(1, 21) .. "…" end
    local rw = A.textSize(false, 12, reason)
    A.text(false, 12, reason, p.x + w - 14 - rw, ry + 2, CFG.colors.gray)
    A.circle(p.x + 64, ry + 8, 4, State.armletOn and CFG.colors.green or CFG.colors.gray)
    A.text(true, 14, st, p.x + 74, ry, State.armletOn and CFG.colors.green or CFG.colors.gray)
end

---------------------------------------------------------------------------
-- 12. WORLD PING RINGS
---------------------------------------------------------------------------
local Pings = { list = {}, lastBy = {} }

function Pings.spawn(key, pos, radius, color, life)
    if not CFG.pings.enabled or not uiGet(UI.pings, true) or not pos then return end
    local t = A.time()
    if Pings.lastBy[key] and t - Pings.lastBy[key] < CFG.pings.cooldown then return end
    Pings.lastBy[key] = t
    Pings.list[#Pings.list + 1] = { pos = pos, r = radius, c = color, born = t, life = life or CFG.pings.life }
    if #Pings.list > 24 then table.remove(Pings.list, 1) end
end

local function worldRing(center, radius, c, aMul, thickness)
    local seg, px, py = 36
    for i = 0, seg do
        local ang = (i / seg) * math.pi * 2
        local x, y = A.worldToScreen(Vector(center.x + math.cos(ang) * radius,
                                            center.y + math.sin(ang) * radius, center.z))
        if x and px then A.line(px, py, x, y, c, aMul, thickness) end
        px, py = x, y
    end
end

function Pings.draw()
    local t = A.time()
    local i = 1
    while i <= #Pings.list do
        local p = Pings.list[i]
        local k = (t - p.born) / p.life
        if k >= 1 then
            table.remove(Pings.list, i)
        else
            local ease = 1 - (1 - k) * (1 - k)
            local r = p.r * (0.35 + 0.65 * ease)
            local a = (1 - k)
            worldRing(p.pos, r, p.c, a, 2)
            worldRing(p.pos, r * 0.82, p.c, a * 0.45, 1)
            i = i + 1
        end
    end
end

function Pings.threats(snap, stateName)
    if stateName == "calm" or not snap then return end
    for n, th in ipairs(snap.threats) do
        if n > 3 then break end
        local pos = A.pos(th.ent)
        local c = (th == snap.killer) and CFG.colors.red or CFG.colors.yellow
        Pings.spawn("threat" .. A.index(th.ent), pos, math.max(th.range + 50, 150), c)
    end
end

---------------------------------------------------------------------------
-- 13. ARMLET LOGIC
---------------------------------------------------------------------------
State.armletOn, State.lastReason, State.chance, State.killer = false, "—", 100, nil
-- The script does NOT toggle Armlet. Umbrella's built-in abuse does; we only
-- (1) write the calculated threshold to its slider and (2) observe toggles.
local Armlet = { lastToggle = -10, pendingOn = nil, prevOn = nil, widget = nil,
                 lastSearch = -10, warned = false, lastSet = -10, lastValue = nil }

local function mark(me, on, reason)
    State.armletOn, State.lastReason = on, reason
    Armlet.lastToggle = A.time()
    log(on and "ON" or "OFF", reason)
    Pings.spawn("armlet", A.pos(me), 220, on and CFG.colors.ringOn or CFG.colors.ringOff, CFG.pings.toggleLife)
end

-- Find the threshold slider in built-in abuse using paths from CFG.builtin.paths
function Armlet.findWidget()
    if Armlet.widget then return Armlet.widget end
    local now = A.time()
    if now - Armlet.lastSearch < 5 then return nil end   -- do not search every tick
    Armlet.lastSearch = now
    local unpack_ = table.unpack or unpack

    -- candidates: explicit paths + name variants (with/without tab and group)
    if not Armlet.candidates then
        local c = {}
        for _, p in ipairs(CFG.builtin.paths) do c[#c + 1] = p end
        local g = CFG.builtin.guess
        for _, a in ipairs(g.top) do
            for _, b in ipairs(g.second) do
                for _, d in ipairs(g.third) do
                    for _, n in ipairs(g.name) do
                        c[#c + 1] = { a, b, d, n }
                        for _, tb in ipairs(g.tab) do
                            c[#c + 1] = { a, b, d, tb, n }
                            for _, gr in ipairs(g.group) do
                                c[#c + 1] = { a, b, d, tb, gr, n }
                            end
                        end
                    end
                end
            end
        end
        Armlet.candidates = c
    end

    for _, path in ipairs(Armlet.candidates) do
        local ok, w = pcall(function() return Menu.Find(unpack_(path)) end)
        if ok and w and w.Set then
            Armlet.widget, Armlet.foundPath = w, path
            print("[SmartArmlet] found built-in abuse slider: " .. table.concat(path, " > "))
            return w
        end
    end
    if not Armlet.warned then
        Armlet.warned = true
        print("[SmartArmlet] did not find the built-in Armlet abuse threshold slider. "
            .. "Set the path in CFG.builtin.paths. Continuing without threshold writes.")
    end
    return nil
end

function Armlet.step(me, snap, thr, ev)
    local item = A.armlet(me)
    if not item then State.armletOn = false; return end
    local on = A.toggleState(item)
    State.armletOn = on

    -- record toggles made by built-in abuse
    if Armlet.prevOn ~= nil and on ~= Armlet.prevOn then
        mark(me, on, string.format("built-in: %s (HP %d, threshold %d)",
            on and "ON" or "OFF", math.floor(A.hp(me) + 0.5), math.floor(thr + 0.5)))
    end
    Armlet.prevOn = on

    if ev.blocked then State.lastReason = "Blocked: " .. table.concat(ev.flags, ",") end

    -- write the threshold to built-in abuse
    local b = CFG.builtin
    if not b.enabled then return end
    local w = Armlet.findWidget()
    if not w then return end

    local v = b.percent and (thr / math.max(A.maxHp(me), 1) * 100) or thr
    v = math.max(1, math.floor(v + 0.5))                 -- the slider expects an integer
    local t = A.time()
    if Armlet.lastValue and math.abs(v - Armlet.lastValue) < b.minChange then return end
    if t - Armlet.lastSet < b.minInterval then return end

    local ok, err = pcall(w.Set, w, v)
    if ok then
        Armlet.lastValue, Armlet.lastSet = v, t
        log("built-in abuse threshold =", v)
    else
        log("failed to write threshold:", err)
    end
end

---------------------------------------------------------------------------
-- 14. CHANGE NOTIFICATIONS
---------------------------------------------------------------------------
local Notify = { lastState = nil, lastThr = nil, lastChanceShown = nil, lastKillerIdx = nil }

function Notify.step(thr, chance, killer, capped, need)
    -- threshold change
    if Notify.lastThr and math.abs(thr - Notify.lastThr) >= CFG.threshold.notifyDelta then
        Toast.push("threshold", HEADERS.threshold, Toast.segsThreshold(thr, thr > Notify.lastThr), CFG.colors.accent)
        Notify.lastThr = thr
    elseif not Notify.lastThr then
        Notify.lastThr = thr
    end

    -- threshold reached the slider maximum: more is needed than can be set
    local now = A.time()
    if capped and now - (Notify.capT or -10) > 4 then
        Notify.capT = now
        Toast.push("cap", "THRESHOLD CAPPED", Toast.segsCap(CFG.threshold.max), CFG.colors.red)
    end

    -- state notification: only when chance shifts by ±N% (configured in the menu)
    local st = Surv.stateOf(chance)
    local kIdx = killer and A.index(killer.ent) or nil
    local delta = uiGet(UI.chanceDelta, CFG.toasts.chanceDelta)
    local changed = Notify.lastChanceShown == nil
        or math.abs(chance - Notify.lastChanceShown) >= delta
        or (uiGet(UI.notifyOnState, false) and st ~= Notify.lastState)

    if changed then
        local compact = uiGet(UI.compactToast, CFG.toasts.compact)
        Toast.push("state", HEADERS[st], Toast.segsState(st, thr, chance, killer, compact), Surv.color(chance))
        Notify.lastState, Notify.lastChanceShown, Notify.lastKillerIdx = st, chance, kIdx
    end
    return st
end

---------------------------------------------------------------------------
-- 15. UMBRELLA CALLBACKS
---------------------------------------------------------------------------
local lastScan, lastUpdateT = 0, nil

function script.OnUpdate()
    if not uiGet(UI.enable, true) then return end
    local me = A.me()
    if not me or not A.alive(me) then State.armletOn = false return end
    if not A.armlet(me) then return end   -- no Armlet — stay silent

    local t = A.time()
    if t - lastScan < CFG.scanInterval then return end
    local dt = clamp(t - (lastUpdateT or t), 0, 0.25)
    lastScan, lastUpdateT = t, t

    local ok, err = pcall(function()
        local snap = Dmg.scan(me)
        if not snap then return end

        local item = A.armlet(me)
        Taken.update(A.hp(me), A.toggleState(item), t)
        snap.takenDps = Taken.dps

        local modelRate = snap.burst / CFG.window
        if Taken.dps > 150 and modelRate > 20 then
            Calib.k = Calib.k * 0.92 + clamp(Taken.dps / modelRate, 1, 3) * 0.08
        else
            Calib.k = Calib.k * 0.995 + 0.005          -- slowly return to 1.0 outside combat
        end
        snap.burst, snap.landing = snap.burst * Calib.k, snap.landing * Calib.k

        local thr = Threshold.update(snap, dt)
        local ev = Surv.evaluate(me, snap)

        -- debugging: once per second, show what the script actually sees nearby
        if dbg() and t - (State.lastDump or 0) > 1.0 then
            State.lastDump = t
            log(string.format("threats=%d  takenDPS=%d  landing=%d  burst=%d  k=%.2f  needed=%d  threshold=%d%s  chance=%d%%",
                #snap.threats, math.floor(Taken.dps), math.floor(snap.landing),
                math.floor(snap.burst), Calib.k, math.floor(Threshold.need or 0), math.floor(thr),
                Threshold.capped and "(CAPPED)" or "", math.floor(ev.chance)))
            for i = 1, math.min(4, #snap.threats) do
                local th = snap.threats[i]
                log(string.format("   #%d %s [%s] dist=%d burst=%d landing=%d crit=%.2f ult=%s",
                    i, th.name, th.kind, math.floor(th.dist), math.floor(th.burst),
                    math.floor(th.landing), th.critF, tostring(th.hasUlt)))
            end
        end

        State.chance, State.killer = ev.chance, ev.killer
        local stName = Notify.step(thr, ev.chance, ev.killer, Threshold.capped, Threshold.need)
        Pings.threats(snap, stName)
        Armlet.step(me, snap, thr, ev)
    end)
    if not ok then log("OnUpdate error:", err) end
end

function script.OnDraw()
    Net.frame()
    if not uiGet(UI.enable, true) then return end
    local me = A.me()
    if not me then return end
    local ok, err = pcall(function()
        Pings.draw()
        Toast.draw()
        if A.armlet(me) then Panel.draw(me) end
    end)
    if not ok then log("OnDraw error:", err) end
end

-- entity_hurt game event (if your build provides it in this form)
function script.OnEntityHurt(data)
    local me = A.me()
    if not me or type(data) ~= "table" then return end
    local target = data.target or data.entindex_killed
    local src = data.source or data.entindex_attacker
    local dmg = data.damage or 0
    -- target/src may be entities or indices
    local tIdx = type(target) == "number" and target or A.index(target)
    if tIdx == A.index(me) and src then
        Recent.add(type(src) == "number" and src or A.index(src), dmg, A.time())
    end
end

-- General game event handler (dota_player_gained_level, dota_item_purchased...)
function script.OnGameEvent(name, _)
    if name == "dota_player_gained_level" or name == "dota_item_purchased"
       or name == "dota_item_spawned" then
        Dmg.invalidate()
    end
end

function script.OnGameEnd()
    Toast.list, Pings.list, Recent.list = {}, {}, {}
    Threshold.value = CFG.threshold.base
    Armlet.pendingOn = nil
    Calib.k, Taken.dps = 1.0, 0
    State.chance, State.killer = 100, nil
    Dmg.invalidate()
end

-- Find the built-in abuse widget separately; the script menu remains on the desired page.
do
    Armlet.findWidget()
    UI.create(CFG.menu.page)
end

print("[SmartArmlet] loaded")
return script
