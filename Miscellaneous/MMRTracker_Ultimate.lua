local MMRTracker = {}

local DB_KEY = "mmr_tracker_ult"

local function InitDB()
    if type(db["x"]) ~= "userdata" then
        db["x"] = {}
    end
    if type(db["x"][DB_KEY]) ~= "userdata" then
        db["x"][DB_KEY] = {}
    end
end


local g_main = Menu.Create("Scripts", "Other", "MMR Tracker Ultimate", "Settings", "Main")
g_main:Parent():Parent():Icon("\u{f080}") 

local s_enable = g_main:Switch("Включить панель", true)
local s_lock   = g_main:Switch("Заблокировать позицию", false)

local s_x = g_main:Slider("Pos X", 0, 1920, 300, "%d")
local s_y = g_main:Slider("Pos Y", 0, 1080, 100, "%d")
s_x:Visible(false)
s_y:Visible(false)

g_main:Button("Сбросить позицию", function() 
    s_x:Set(300) 
    s_y:Set(100) 
end)

local g_stats = Menu.Create("Scripts", "Other", "MMR Tracker Ultimate", "Settings", "\u{f080} Statistics")

local s_session_show  = g_stats:Switch("Показывать сессию", true)

g_stats:Button("Сбросить сессию", function() 
    MMRTracker.ResetSession() 
end)

local g_calc = Menu.Create("Scripts", "Other", "MMR Tracker Ultimate", "Settings", "\u{f1ec} Calculator")

local s_avg_delta  = g_calc:Slider("Средний MMR за игру", 10, 100, 25, "%d")
local s_calc_show  = g_calc:Switch("Показывать калькулятор игр", true)
local s_target_use = g_calc:Switch("Использовать свою цель", false)
local s_target_val = g_calc:Slider("Цель MMR", 1000, 12000, 5000, "%d")
local s_rank_icon = g_calc:Switch("Показывать иконку ранга", false)

local g_tilt = Menu.Create("Scripts", "Other", "MMR Tracker Ultimate", "Settings", "\u{f132} Tilt Guard")

local s_tilt_enable = g_tilt:Switch("Включить защиту от тильта", true)
local s_tilt_limit  = g_tilt:Slider("Лимит слива для тревоги", 50, 200, 75, "-%d")



local theme = {
    bg      = Color(20, 20, 20, 240),
    border  = Color(60, 60, 60, 255),
    text    = Color(220, 220, 220, 255),
    accent  = Color(255, 195, 15, 255),
    bar     = Color(255, 195, 15, 255),
    
    tilt_bg     = Color(50, 0, 0, 240),
    tilt_border = Color(255, 0, 0, 255),
    tilt_text   = Color(255, 50, 50, 200),
    
    win     = Color(100, 255, 100, 255),
    loss    = Color(255, 100, 100, 255),
    dim     = Color(150, 150, 150, 255),
    subtext = Color(200, 200, 200, 180)
}

local fonts = {
    main = Render.LoadFont("Cascadia Code", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL),
    bold = Render.LoadFont("Cascadia Code", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD),
    small = Render.LoadFont("Cascadia Code", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL),
    icon = Render.LoadFont("FontAwesomeEx", 14, 16),
    warn = Render.LoadFont("Cascadia Code", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)
}

local function mmr_to_rank_tier(mmr)
    if mmr >= 5620 then
        return 80
    elseif mmr >= 5420 then
        return 75
    elseif mmr >= 5220 then
        return 74
    elseif mmr >= 5020 then
        return 73
    elseif mmr >= 4820 then
        return 72
    elseif mmr >= 4620 then
        return 71
    elseif mmr >= 4466 then
        return 65
    elseif mmr >= 4312 then
        return 64
    elseif mmr >= 4158 then
        return 63
    elseif mmr >= 4004 then
        return 62
    elseif mmr >= 3850 then
        return 61
    elseif mmr >= 3696 then
        return 55
    elseif mmr >= 3542 then
        return 54
    elseif mmr >= 3388 then
        return 53
    elseif mmr >= 3234 then
        return 52
    elseif mmr >= 3080 then
        return 51
    elseif mmr >= 2926 then
        return 45
    elseif mmr >= 2772 then
        return 44
    elseif mmr >= 2618 then
        return 43
    elseif mmr >= 2464 then
        return 42
    elseif mmr >= 2310 then
        return 41
    elseif mmr >= 2156 then
        return 35
    elseif mmr >= 2002 then
        return 34
    elseif mmr >= 1848 then
        return 33
    elseif mmr >= 1694 then
        return 32
    elseif mmr >= 1540 then
        return 31
    elseif mmr >= 1386 then
        return 25
    elseif mmr >= 1232 then
        return 24
    elseif mmr >= 1078 then
        return 23
    elseif mmr >= 924 then
        return 22
    elseif mmr >= 770 then
        return 21
    elseif mmr >= 616 then
        return 15
    elseif mmr >= 462 then
        return 14
    elseif mmr >= 308 then
        return 13
    elseif mmr >= 154 then
        return 12
    elseif mmr > 0 then
        return 11
    end
    return 0
end

local session = {
    startMMR = 0,
    initialized = false,
    wins = 0,
    losses = 0
}

local rank_icon_cache = {}

local state = {
    lastMMR = 0,
    mmr_diff = 0,
    drag = { active = false, offset = Vec2(0,0) },
    ui_height = 95,
    panel_pos = Vec2(0, 0),
    panel_size = Vec2(280, 95),
    panel_visible = false
}

local rankTable = {
    {154,"Herald",2}, {308,"Herald",3}, {462,"Herald",4}, {616,"Herald",5},
    {770,"Guardian",1}, {924,"Guardian",2}, {1078,"Guardian",3}, {1232,"Guardian",4}, {1386,"Guardian",5},
    {1540,"Crusader",1}, {1694,"Crusader",2}, {1848,"Crusader",3}, {2002,"Crusader",4}, {2156,"Crusader",5},
    {2310,"Archon",1}, {2464,"Archon",2}, {2618,"Archon",3}, {2772,"Archon",4}, {2926,"Archon",5},
    {3080,"Legend",1}, {3234,"Legend",2}, {3388,"Legend",3}, {3542,"Legend",4}, {3696,"Legend",5},
    {3850,"Ancient",1}, {4004,"Ancient",2}, {4158,"Ancient",3}, {4312,"Ancient",4}, {4466,"Ancient",5},
    {4620,"Divine",1}, {4820,"Divine",2}, {5020,"Divine",3}, {5220,"Divine",4}, {5420,"Divine",5},
    {5600,"Immortal",0}
}

function MMRTracker.ResetSession()
    session.initialized = false
    session.startMMR = 0
    session.wins = 0
    session.losses = 0
    state.lastMMR = 0
    state.mmr_diff = 0
    
    InitDB()
    local mmr = Engine.GetMMRV2()
    local steamid = GC.GetSteamID()
    if mmr > 0 then
        session.startMMR = mmr
        session.initialized = true
        db["x"][DB_KEY]["session_start_mmr"] = mmr
        db["x"][DB_KEY]["session_steam_id"] = steamid
        db["x"][DB_KEY]["session_wins"] = 0
        db["x"][DB_KEY]["session_losses"] = 0
    else
        db["x"][DB_KEY]["session_start_mmr"] = nil
        db["x"][DB_KEY]["session_steam_id"] = nil
        db["x"][DB_KEY]["session_wins"] = nil
        db["x"][DB_KEY]["session_losses"] = nil
    end
    db["x"][DB_KEY]["mmr"] = nil
    db["x"][DB_KEY]["steam_id"] = nil
end

function MMRTracker.OnGameThreadInit()
    InitDB()
    
    local mmr = Engine.GetMMRV2()
    local steamid = GC.GetSteamID()
    
    if db["x"][DB_KEY]["mmr"] ~= nil and db["x"][DB_KEY]["steam_id"] == steamid then
        state.mmr_diff = mmr - db["x"][DB_KEY]["mmr"]
    end
    
    if mmr > 0 then
        if db["x"][DB_KEY]["session_start_mmr"] == nil or db["x"][DB_KEY]["session_steam_id"] ~= steamid then
            session.startMMR = mmr
            session.wins = 0
            session.losses = 0
            session.initialized = true
            db["x"][DB_KEY]["session_start_mmr"] = mmr
            db["x"][DB_KEY]["session_steam_id"] = steamid
            db["x"][DB_KEY]["session_wins"] = 0
            db["x"][DB_KEY]["session_losses"] = 0
        else
            session.startMMR = db["x"][DB_KEY]["session_start_mmr"]
            session.wins = db["x"][DB_KEY]["session_wins"] or 0
            session.losses = db["x"][DB_KEY]["session_losses"] or 0
            session.initialized = true
        end
    end
    
    db["x"][DB_KEY]["mmr"] = mmr
    db["x"][DB_KEY]["steam_id"] = steamid
    
    state.lastMMR = mmr
end

local function GetRankInfo(mmr)
    if mmr == 0 then return nil, nil end 

    local current = {mmr=0, name="Herald", tier=1}
    local nextRank = nil
    for i, data in ipairs(rankTable) do
        if mmr < data[1] then
            nextRank = {mmr = data[1], name = data[2], tier = data[3]}
            if i > 1 then
                local prev = rankTable[i-1]
                current = {mmr = prev[1], name = prev[2], tier = prev[3]}
            end
            break
        end
    end
    
    -- Immortal: (MMR >= 5600)
    if not nextRank and #rankTable > 0 then
        local last = rankTable[#rankTable]
        current = {mmr = last[1], name = last[2], tier = last[3]}
    end
    
    return current, nextRank
end

local function HandleDrag(pos, size)
    if s_lock:Get() then return end
    if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
        local cursor = Vec2(Input.GetCursorPos())
        if not state.drag.active and Input.IsCursorInRect(pos.x, pos.y, size.x, size.y) then
            state.drag.active = true
            state.drag.offset = cursor - pos
        elseif state.drag.active then
            local newPos = cursor - state.drag.offset
            s_x:Set(math.floor(newPos.x))
            s_y:Set(math.floor(newPos.y))
        end
    else
        state.drag.active = false
    end
end


function MMRTracker.OnFrame()
    if not s_enable:Get() then 
        state.panel_visible = false
        return 
    end
    if Engine.GetUIState() ~= Enum.UIState.DOTA_GAME_UI_STATE_DASHBOARD then 
        state.panel_visible = false
        return 
    end
    
    state.panel_visible = true
    
    local pos = Vec2(s_x:Get(), s_y:Get())
    local myMMR = Engine.GetMMRV2()
    
    if not session.initialized and myMMR > 0 then
        InitDB()
        local steamid = GC.GetSteamID()
        session.startMMR = myMMR
        session.wins = 0
        session.losses = 0
        session.initialized = true
        db["x"][DB_KEY]["session_start_mmr"] = myMMR
        db["x"][DB_KEY]["session_steam_id"] = steamid
        db["x"][DB_KEY]["session_wins"] = 0
        db["x"][DB_KEY]["session_losses"] = 0
    end

    local currentRank, nextRank = GetRankInfo(myMMR)
    local avgGain = s_avg_delta:Get()
    
    local pad_y = 10
    local gap = 15
    
    local h_rank = 0
    if myMMR == 0 then 
        h_rank = 70 
    elseif not nextRank then 
        h_rank = 40 
    else 
        h_rank = 50 
    end
    
    local h_wl = 0
    if session.initialized and session.startMMR > 0 then
        local iconSize = 28
        local iconHeight = iconSize + 2 + 12
        h_wl = math.max(20, iconHeight)
    end
    
    local h_session = 0
    if s_session_show:Get() and session.initialized and session.startMMR > 0 then
        h_session = 1 
    end
    
    local total_h = pad_y + h_rank
    if h_wl > 0 then total_h = total_h + gap + h_wl end
    if h_session > 0 then total_h = total_h + gap + h_session end
    total_h = total_h + pad_y
    
    local dt = GlobalVars.GetAbsFrameTime and GlobalVars.GetAbsFrameTime() or 0.016
    if dt > 0.1 then dt = 0.016 end 
    state.ui_height = math.lerp(state.ui_height, total_h, dt * 10) 
    
    local size = Vec2(300, state.ui_height)
    
    state.panel_pos = pos
    state.panel_size = size

    HandleDrag(pos, size)

    local sessionDiff = myMMR - session.startMMR
    local isTilt = s_tilt_enable:Get() and (sessionDiff <= -(s_tilt_limit:Get())) and (myMMR > 0)
    
    local bgColor = isTilt and theme.tilt_bg or Menu.Style("additional_background")

    Render.FilledRect(pos, pos + size, bgColor, 32, Enum.DrawFlags.RoundCornersAll)
    Render.Blur(pos, pos + size, 1, 0.9, 32, Enum.DrawFlags.RoundCornersAll)

    if isTilt then
        Render.TextCentered(fonts.warn, pos.x + size.x / 2, pos.y + size.y / 2 - 10, "STOP PLAYING!", theme.tilt_text)
        Render.TextCentered(fonts.small, pos.x + size.x / 2, pos.y + size.y / 2 + 15, "Lose limit reached", theme.subtext)
    end

    local drawY = pad_y

    if myMMR == 0 then
        -- Uncalibrated
        Render.Text(fonts.icon, 16, "\u{f059}", pos + Vec2(20, drawY), theme.accent)
        Render.Text(fonts.main, 15, "No Rank", pos + Vec2(45, drawY), theme.accent)
        
        Render.Text(fonts.main, 14, "Uncalibrated", pos + Vec2(20, drawY + 22), theme.text)
        
        local barStart = pos + Vec2(15, drawY + 45)
        Render.FilledRect(barStart, barStart + Vec2(size.x - 30, 5), Color(0,0,0,150), 2)
        Render.Text(fonts.small, 11, "Play Ranked to unlock", pos + Vec2(15, drawY + 55), theme.subtext)
        
        drawY = drawY + h_rank
    
    elseif not nextRank then 
        -- Immortal
        if s_rank_icon:Get() then
            local rank_tier = mmr_to_rank_tier(myMMR)
            local rank_tier_id = math.floor(rank_tier / 10)
            if rank_icon_cache[rank_tier_id] == nil then
                rank_icon_cache[rank_tier_id] = Render.LoadImage("panorama/images/rank_tier_icons/rank" .. tostring(rank_tier_id) .. "_psd.vtex_c")
            end
            Render.Image(rank_icon_cache[rank_tier_id], pos + Vec2(20, drawY+5), Vec2(18, 18), Color(255, 255, 255, 255))
            Render.Text(fonts.main, 15, "Immortal", pos + Vec2(45, drawY+5), theme.accent)
        else
            Render.Text(fonts.icon, 16, "\u{f091}", pos + Vec2(20, drawY+5), theme.accent)
            Render.Text(fonts.main, 15, "Immortal", pos + Vec2(45, drawY+5), theme.accent)
        end
        
        
        Render.Text(fonts.main, 14, "MMR: " .. myMMR, pos + Vec2(20, drawY+30), theme.text)
        
        drawY = drawY + h_rank
    else
        -- Normal
        local curName = currentRank.name .. " " .. currentRank.tier
        local targetVal = s_target_use:Get() and s_target_val:Get() or nextRank.mmr
        local targetName = s_target_use:Get() and "Goal" or (nextRank.name .. " " .. nextRank.tier)

        local textX = 15
        if s_rank_icon:Get() then
            local rank_tier = mmr_to_rank_tier(myMMR)
            local rank_tier_id = math.floor(rank_tier / 10)
            if rank_icon_cache[rank_tier_id] == nil then
                rank_icon_cache[rank_tier_id] = Render.LoadImage("panorama/images/rank_tier_icons/rank" .. tostring(rank_tier_id) .. "_psd.vtex_c")
            end
            Render.Image(rank_icon_cache[rank_tier_id], pos + Vec2(15, drawY), Vec2(16, 16), Color(255, 255, 255, 255))
            textX = 38
        end

        Render.Text(fonts.main, 14, curName, pos + Vec2(textX, drawY), theme.text)
        local arrowX = textX + Render.TextSize(fonts.main, 14, curName).x + 10
        Render.Text(fonts.icon, 12, "\u{f061}", pos + Vec2(arrowX, drawY+2), theme.accent)
        local targetNameSize = Render.TextSize(fonts.main, 14, targetName)
        Render.Text(fonts.main, 14, targetName, pos + Vec2(arrowX + 20, drawY), theme.text)

        -- Bar at +25
        local barStart = pos + Vec2(15, drawY + 25)
        local barW = size.x - 30
        local startRange = currentRank.mmr
        local totalRange = targetVal - startRange
        local progress = myMMR - startRange
        local pct = math.max(0, math.min(1, progress / totalRange))

        Render.FilledRect(barStart, barStart + Vec2(barW, 5), Color(0,0,0,150), 2)
        if pct > 0 then
            Render.FilledRect(barStart, barStart + Vec2(barW * pct, 5), theme.bar, 2)
        end

        -- Text at +35
        Render.Text(fonts.small, 11, string.format("%d / %d", myMMR, targetVal), pos + Vec2(15, drawY + 35), theme.subtext)

        if s_calc_show:Get() then
            local needed = targetVal - myMMR
            if needed > 0 then
                local wins = math.ceil(needed / avgGain)
                local dd = math.ceil(needed / (avgGain * 2))
                local tStr = string.format("%d W (%d DD)", wins, dd)
                local tSize = Render.TextSize(fonts.small, 11, tStr)
                Render.Text(fonts.small, 11, tStr, pos + Vec2(size.x - 15 - tSize.x - 60, drawY + 35), theme.text)
            end
        end
        
        drawY = drawY + h_rank
    end

    if h_wl > 0 then
        drawY = drawY + gap
        
        local winText = string.format("Win (%d)", session.wins)
        local loseText = string.format("Lose (%d)", session.losses)
        local sessionText = sessionDiff > 0 and string.format("+%d", sessionDiff) or (sessionDiff < 0 and tostring(sessionDiff) or "0")
        
        Render.Text(fonts.small, 12, winText, pos + Vec2(15, drawY), theme.win)
        local winSize = Render.TextSize(fonts.small, 12, winText)
        
        Render.Text(fonts.small, 12, loseText, pos + Vec2(15 + winSize.x + 10, drawY), theme.loss)
        local loseSize = Render.TextSize(fonts.small, 12, loseText)
        
        local sessionColor = sessionDiff > 0 and theme.win or (sessionDiff < 0 and theme.loss or theme.text)
        local sessionTextSize = Render.TextSize(fonts.small, 12, sessionText)
        Render.Text(fonts.small, 12, sessionText, pos + Vec2(15 + winSize.x + 10 + loseSize.x + 10, drawY), sessionColor)
        
        if myMMR > 0 then
            local rank_tier = mmr_to_rank_tier(myMMR)
            local rank_tier_id = math.floor(rank_tier / 10)
            if rank_tier_id > 0 then
                if rank_icon_cache[rank_tier_id] == nil then
                    rank_icon_cache[rank_tier_id] = Render.LoadImage("panorama/images/rank_tier_icons/rank" .. tostring(rank_tier_id) .. "_psd.vtex_c")
                end
                local iconSize = 36
                local iconX = size.x - iconSize - 10
                local iconY = drawY - 36
                Render.Image(rank_icon_cache[rank_tier_id], pos + Vec2(iconX, iconY), Vec2(iconSize, iconSize), Color(255, 255, 255, 255))
                local mmrTextSize = Render.TextSize(fonts.small, 12, tostring(myMMR))
                Render.Text(fonts.small, 12, tostring(myMMR), pos + Vec2(iconX + (iconSize - mmrTextSize.x) / 2, iconY + iconSize + 2), theme.text)
            end
        end
    end

    if h_session > 0 and session.initialized and session.startMMR > 0 then
        drawY = drawY + gap 
        
        Render.Rect(pos + Vec2(15, drawY), pos + Vec2(size.x - 15, drawY), Color(255,255,255,20), 1) -- Separator
        
        local txt, col = "Session: 0", theme.text
        if sessionDiff > 0 then 
            txt = string.format("Session: +%d (~%d W)", sessionDiff, math.ceil(sessionDiff/avgGain))
            col = theme.win
        elseif sessionDiff < 0 then
            txt = string.format("Session: %d (~%d L)", sessionDiff, math.ceil(math.abs(sessionDiff)/avgGain))
            col = theme.loss
        end
        
        Render.Text(fonts.small, 12, txt, pos + Vec2(15, drawY + 5), col)
        drawY = drawY + h_session
    end
end

function MMRTracker.OnGameEnd()
    if not Engine.IsInGame() then
        local mmr = Engine.GetMMRV2()
        
        state.mmr_diff = mmr - state.lastMMR
        
        if state.mmr_diff > 0 then
            session.wins = session.wins + 1
            InitDB()
            db["x"][DB_KEY]["session_wins"] = session.wins
        elseif state.mmr_diff < 0 then
            session.losses = session.losses + 1
            InitDB()
            db["x"][DB_KEY]["session_losses"] = session.losses
        end
        
        state.lastMMR = mmr
        
        db["x"][DB_KEY]["mmr"] = mmr
    end
end

function MMRTracker.OnKeyEvent(data)
    if not state.panel_visible then
        return true
    end
    
    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and data.key == Enum.ButtonCode.KEY_MOUSE1 then
        local pos = state.panel_pos
        local size = state.panel_size
        if Input.IsCursorInRect(pos.x, pos.y, size.x, size.y) then
            return false
        end
    end
    
    return true
end

return MMRTracker