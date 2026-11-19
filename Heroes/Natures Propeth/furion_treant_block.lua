--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end),

			is_object = a(function(value)
				return type(value) == "table" or type(value) == "userdata"
			end),

			has_method = a(function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end),

			is_menu_object = a(function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end),

			is_list = a(function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end),

			is_indexed_list = a(function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end),
		}
	end

	function lib.new(translations)
		local languages = {}

		for i, name in ipairs(state.lang and state.lang:List() or {}) do
			local code = name:match("%a+")

			if code and translations[code] then
				languages[i - 1] = code
			end
		end

		local localization = {
			translations = translations,
			languages = languages,
			objects = {},
		}

		local methods
		do
			methods = {
				get_language = a(function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end),

				localize = a(function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end),

				localize_items = a(function(items, language_index)
					local result, localized = {}, false

					for i = 1, #items do
						local value = items[i]

						if methods.has(value) then
							result[i] = methods.localize(value, language_index)
							localized = true
						else
							result[i] = value
						end
					end

					return result, localized
				end),

				apply = a(function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end),

				track = a(function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end),

				register = a(function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end),

				update = a(function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end),

				wrap = a(function(target, bind_self)
					if not helpers.is_object(target) then
						return target
					end

					local proxy

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

							return function(...)
								local args = table.pack(...)

								if bind_self and args[1] == proxy then
									table.remove(args, 1)
									args.n = args.n - 1
								end

								if key == "Switch" and args.n < 2 then
									args[2] = false
									args.n = 2
								end

								local name_path, item_paths

								if setters[key] then
									if methods.has(args[1]) then
										methods.track(target, setters[key], args[1], false)

										args[1] = methods.localize(args[1])
									end
								else
									local name_index = bind_self and 1 or args.n

									if methods.has(args[name_index]) then
										name_path = args[name_index]
									end

									local items_index

									if key == "Combo" then
										items_index = 2
									elseif key == "Update" and helpers.is_indexed_list(target) then
										items_index = 1
									end

									if items_index ~= nil and helpers.is_list(args[items_index]) then
										local items, localized = methods.localize_items(args[items_index])

										if localized then
											item_paths = args[items_index]
											args[items_index] = items
										end
									end
								end

								local results

								if bind_self then
									results = table.pack(member(target, table.unpack(args, 1, args.n)))
								else
									results = table.pack(member(table.unpack(args, 1, args.n)))
								end

								for i = 1, results.n do
									local result = results[i]

									if helpers.is_menu_object(result) then
										if name_path then
											methods.register(result, name_path)
										end

										if item_paths then
											methods.track(result, "items", item_paths, false)
											item_paths = nil
										end

										results[i] = methods.wrap(result, true)
									end
								end

								if item_paths then
									methods.track(target, "items", item_paths, false)
								end

								return table.unpack(results, 1, results.n)
							end
						end,

						__newindex = function(_, key, value)
							target[key] = value
						end,
					})

					return proxy
				end),
			}
		end

		state.instances[methods] = true

		return {
			GetLanguage = methods.get_language,

			Get = methods.localize,
			Localize = methods.localize,

			Update = methods.update,
			Register = methods.register,

			Wrap = methods.wrap,

			WrapLibrary = function(library)
				return methods.wrap(library, false)
			end,
		}
	end

	if state.lang then
		state.lang:SetCallback(function(this)
			local language_index = this:Get()

			for methods in pairs(state.instances) do
				methods.update(language_index)
			end
		end, true)
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()

local localization = qLocalization.new({
	en = {
		tb_group = "Treant Camp Block",
		tb_enable = "Camp block",
		tb_enable_tip = "Treants from Nature's Call block\nthe camps you marked",
		tb_gear_main = "Settings",
		tb_debug = "Debug log",
		tb_debug_tip = "Writes what the script is doing\nto the log",
		tb_key = "Send treants",
		tb_key_tip = "Sends all your treants\nto the marked camps",
		tb_hold = "Hold position",
		tb_hold_tip = "Treants hold on the camp\nand don't chase creeps",
		tb_icons = "Camp icons",
		tb_icons_tip = "Click the icon over a camp\nto mark it on or off",
		tb_gear_icons = "Look",
		tb_icon_size = "Icon size",
		tb_icon_height = "Height",
		tb_bind_name = "Treant Camp Block",
	},
	ru = {
		tb_group = "Блок кемпов триентами",
		tb_enable = "Блок кемпов",
		tb_enable_tip = "Триенты от Nature's Call блочат\nотмеченные кемпы",
		tb_gear_main = "Настройки",
		tb_debug = "Отладка в лог",
		tb_debug_tip = "Пишет в лог, что сейчас делает скрипт",
		tb_key = "Отправить триентов",
		tb_key_tip = "Отправляет всех триентов\nна отмеченные кемпы",
		tb_hold = "Стоять на месте",
		tb_hold_tip = "Триенты стоят в кемпе\nи не бегут за крипами",
		tb_icons = "Иконки над кемпами",
		tb_icons_tip = "Клик по иконке над кемпом\nвключает или выключает его",
		tb_gear_icons = "Вид",
		tb_icon_size = "Размер иконки",
		tb_icon_height = "Высота",
		tb_bind_name = "Treant Camp Block",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local K = {
	HERO = "npc_dota_hero_furion",
	TREANTS = { npc_dota_furion_treant = true, npc_dota_furion_treant_large = true },
	ICON = "panorama/images/spellicons/furion_force_of_nature_png.vtex_c",
	CONFIG = "furion_treant_block",
	CAMP_REFRESH = 3.0,
}

local state = {
	camps = {},
	rects = {},
	selected = {},
	next_refresh = 0,
	icon = nil,
	draw_error = nil,
}

local ui = {}

do
	local hero_tab = UI.Find("Heroes", "Hero List", "Nature's Prophet")
	local page = hero_tab and hero_tab:Find("Main Settings")
	if not page then
		local tab = UI.Create("Scripts", "Scripts", "Treant Camp Block")
		tab:Icon("\u{f1bb}")
		page = tab:Create("Settings")
	end
	local group = page:Create("tb_group", Enum.GroupSide.Right)
	ui.hero_enable = Menu.Find("Heroes", "Hero List", "Nature's Prophet", "Main Settings", "Hero Settings", "Enable")

	ui.enable = group:Switch("tb_enable", false, "\u{f011}")
	ui.enable:ToolTip("tb_enable_tip")
	local g_main = ui.enable:Gear("tb_gear_main")
	ui.debug = g_main:Switch("tb_debug", false, "\u{f188}")
	ui.debug:ToolTip("tb_debug_tip")

	ui.key = group:Bind("tb_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("tb_key_tip")

	ui.hold = group:Switch("tb_hold", true, "\u{f05b}")
	ui.hold:ToolTip("tb_hold_tip")

	ui.icons = group:Switch("tb_icons", true, "\u{f03e}")
	ui.icons:ToolTip("tb_icons_tip")
	local g_icons = ui.icons:Gear("tb_gear_icons")
	ui.icon_size = g_icons:Slider("tb_icon_size", 18, 48, 28, "%d px")
	ui.icon_size:Icon("\u{f065}")
	ui.icon_height = g_icons:Slider("tb_icon_height", 0, 400, 150, "%d")
	ui.icon_height:Icon("\u{f338}")

	ui.key:Properties(L("tb_bind_name"))
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.debug:Disabled(not on)
	ui.key:Disabled(not on)
	ui.hold:Disabled(not on)
	ui.icons:Disabled(not on)
	ui.icon_size:Disabled(not on or not ui.icons:Get())
	ui.icon_height:Disabled(not on or not ui.icons:Get())
end

ui.enable:SetCallback(refresh_disabled, true)
ui.icons:SetCallback(refresh_disabled)

local function log(text)
	if ui.debug:Get() then
		Log.Write("[Treant Camp Block] " .. text)
	end
end

local function active_hero()
	if not ui.enable:Get() then return nil end
	if ui.hero_enable and not ui.hero_enable:Get() then return nil end
	local hero = Heroes.GetLocal()
	if not hero or NPC.GetUnitName(hero) ~= K.HERO then return nil end
	return hero
end

local function camp_key(pos)
	return string.format("c_%d_%d", math.floor(pos.x / 64 + 0.5), math.floor(pos.y / 64 + 0.5))
end

local function refresh_camps()
	local now = GameRules.GetGameTime()
	if now < state.next_refresh and #state.camps > 0 then return end
	state.next_refresh = now + K.CAMP_REFRESH

	local list = {}
	for _, camp in ipairs(Camps.GetAll() or {}) do
		local box = Camp.GetCampBox(camp)
		if box and box.min and box.max then
			local pos = Vector(
				(box.min.x + box.max.x) * 0.5,
				(box.min.y + box.max.y) * 0.5,
				(box.min.z + box.max.z) * 0.5
			)
			local key = camp_key(pos)
			if state.selected[key] == nil then
				state.selected[key] = Config.ReadInt(K.CONFIG, key, 0) == 1
			end
			list[#list + 1] = { key = key, pos = pos }
		end
	end
	if #list ~= #state.camps then
		log("camps found: " .. #list)
	end
	state.camps = list
end

local function toggle_camp(key)
	local on = not state.selected[key]
	state.selected[key] = on
	Config.WriteInt(K.CONFIG, key, on and 1 or 0)
	log("camp " .. key .. (on and " on" or " off"))
end

local function get_treants()
	local pid = Player.GetPlayerID(Players.GetLocal())
	local list = {}
	for _, npc in ipairs(NPCs.GetAll()) do
		if K.TREANTS[NPC.GetUnitName(npc)]
			and Entity.IsAlive(npc)
			and not Entity.IsDormant(npc)
			and Entity.IsControllableByPlayer(npc, pid) then
			list[#list + 1] = npc
		end
	end
	return list
end

local function send_treants()
	refresh_camps()
	local targets = {}
	for _, c in ipairs(state.camps) do
		if state.selected[c.key] then targets[#targets + 1] = c end
	end
	local treants = get_treants()
	log(string.format("send: %d treants, %d camps", #treants, #targets))
	if #treants == 0 or #targets == 0 then return end

	local pairs_left = math.min(#treants, #targets)
	local used_t, used_c = {}, {}
	local player = Players.GetLocal()
	local order = Enum.UnitOrder

	for _ = 1, pairs_left do
		local best_t, best_c, best_d
		for ti, t in ipairs(treants) do
			if not used_t[ti] then
				local tpos = Entity.GetAbsOrigin(t)
				for ci, c in ipairs(targets) do
					if not used_c[ci] then
						local d = tpos:DistanceSqr2D(c.pos)
						if not best_d or d < best_d then
							best_t, best_c, best_d = ti, ci, d
						end
					end
				end
			end
		end
		if not best_t then break end
		used_t[best_t], used_c[best_c] = true, true

		local treant, camp = treants[best_t], targets[best_c]
		Player.PrepareUnitOrders(player, order.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, camp.pos, nil,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, treant, false, true)
		if ui.hold:Get() then
			Player.PrepareUnitOrders(player, order.DOTA_UNIT_ORDER_HOLD_POSITION, nil, camp.pos, nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, treant, true)
		end
		log("treant " .. Entity.GetIndex(treant) .. " -> " .. camp.key)
	end

	if #targets > #treants then
		log((#targets - #treants) .. " camps left without treant")
	end
end

local function draw_icons()
	state.rects = {}
	if not ui.icons:Get() then return end
	refresh_camps()
	if not state.icon then
		state.icon = Render.LoadImage(K.ICON)
	end

	local size = ui.icon_size:Get()
	local lift = ui.icon_height:Get()
	local half = size * 0.5
	local bar = math.max(2, math.floor(size / 10))

	for _, c in ipairs(state.camps) do
		local screen, visible = Render.WorldToScreen(Vector(c.pos.x, c.pos.y, c.pos.z + lift))
		if visible then
			local x, y = math.floor(screen.x - half), math.floor(screen.y - half)
			local on = state.selected[c.key]
			local hover = Input.IsCursorInRect(x, y, size, size)
			local a = on and 255 or (hover and 210 or 140)
			Render.Image(state.icon, Vec2(x, y), Vec2(size, size), Color(255, 255, 255, a), 4,
				Enum.DrawFlags.None, Vec2(0, 0), Vec2(1, 1), on and 0 or 1)
			local bar_color = on and Color(80, 220, 120, 255) or Color(220, 70, 70, 200)
			Render.FilledRect(Vec2(x, y), Vec2(x + size, y + bar), bar_color, 2)
			state.rects[#state.rects + 1] = { key = c.key, x = x, y = y, s = size }
		end
	end
end

local script = {}

function script.OnUpdate()
	if not active_hero() then return end
	if ui.key:IsPressed() and not Input.IsInputCaptured() then
		send_treants()
	end
end

function script.OnDraw()
	if not active_hero() then
		state.rects = {}
		return
	end
	local ok, err = pcall(draw_icons)
	if not ok and err ~= state.draw_error then
		state.draw_error = err
		Log.Write("[Treant Camp Block] draw: " .. tostring(err))
	end
end

function script.OnKeyEvent(data)
	if data.key ~= Enum.ButtonCode.KEY_MOUSE1 or data.event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
		return true
	end
	if #state.rects == 0 or not active_hero() then return true end
	for _, r in ipairs(state.rects) do
		if Input.IsCursorInRect(r.x, r.y, r.s, r.s) then
			toggle_camp(r.key)
			return false
		end
	end
	return true
end

function script.OnGameEnd()
	state.camps = {}
	state.rects = {}
	state.next_refresh = 0
end

return script
