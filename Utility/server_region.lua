-- Shows the region of the current game server as a pill under the watermark.
-- The region is `server_region` (field 21) of the lobby object the game coordinator sends.
local region_script = {}

local JSON = require("assets.JSON")
local protobuf = require("protobuf")

local LOBBY_OBJECT = 2004
local FIELD_LOBBY_ID, FIELD_SERVER_REGION = 1, 21

-- Region ids from the game's scripts/regions.txt: {localization key, fallback name, code}
local REGIONS = {
	[1] = { "us_west", "US West", "EAT" },
	[2] = { "us_east", "US East", "IAD" },
	[3] = { "europe", "Europe", "FRA" },
	[5] = { "singapore", "Singapore", "SGP" },
	[6] = { "dubai", "Dubai", "DXB" },
	[7] = { "australia", "Australia", "SYD" },
	[8] = { "stockholm", "Stockholm", "STO" },
	[9] = { "austria", "Austria", "VIE" },
	[10] = { "brazil", "Brazil", "GRU" },
	[11] = { "southafrica", "South Africa", "JNB" },
	[14] = { "chile", "Chile", "SCL" },
	[15] = { "peru", "Peru", "LIM" },
	[16] = { "india", "India", "BOM" },
	[19] = { "japan", "Japan", "TYO" },
	[27] = { "us_north_central", "US North Central", "ORD" },
	[28] = { "warsaw", "Poland", "WAW" },
	[31] = { "us_south_central", "US South Central", "DFW" },
	[38] = { "argentina", "Argentina", "EZE" },
	[42] = { "pw_chengdu", "Chengdu", "CTU" },
	[46] = { "pw_telecom_shanghai", "Shanghai", "PVG" },
	[49] = { "pw_guangzhou", "Guangzhou", "TGD" },
	[51] = { "pw_beijing", "Beijing", "PEK" },
}

local BASE64 = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do BASE64[alphabet:byte(i)] = i - 1 end
end

local function fromBase64(text)
	local out, bits, count = {}, 0, 0
	for i = 1, #text do
		local value = BASE64[text:byte(i)]
		if value then
			bits, count = bits * 64 + value, count + 6
			if count >= 8 then
				count = count - 8
				local divisor = 2 ^ count
				local byte = math.floor(bits / divisor)
				out[#out + 1] = string.char(byte)
				bits = bits - byte * divisor
			end
		end
	end
	return table.concat(out)
end

local function readVarint(data, pos)
	local value, scale = 0, 1
	while pos <= #data do
		local byte = data:byte(pos)
		pos = pos + 1
		value = value + (byte % 128) * scale
		if byte < 128 then return value, pos end
		scale = scale * 128
	end
	return nil, pos
end

-- Returns the varint fields listed in `wanted`, or nil if the bytes are not a well-formed message.
local function readVarintFields(data, wanted)
	local found, pos, size = {}, 1, #data
	while pos <= size do
		local key
		key, pos = readVarint(data, pos)
		if not key then return nil end
		local field, wire = math.floor(key / 8), key % 8
		if wire == 0 then
			local value
			value, pos = readVarint(data, pos)
			if not value then return nil end
			if wanted[field] then found[field] = value end
		elseif wire == 1 then
			pos = pos + 8
		elseif wire == 5 then
			pos = pos + 4
		elseif wire == 2 then
			local length
			length, pos = readVarint(data, pos)
			if not length then return nil end
			pos = pos + length
		else
			return nil
		end
	end
	return pos == size + 1 and found or nil
end

local WANTED = { [FIELD_LOBBY_ID] = true, [FIELD_SERVER_REGION] = true }

-- `blob` is a serialized CSODOTALobby, raw or base64. Returns nil if it is not a lobby.
local function parseLobby(blob)
	if type(blob) ~= "string" or blob == "" then return nil end
	local found = readVarintFields(blob, WANTED)
	if not (found and found[FIELD_LOBBY_ID]) and blob:find("^[A-Za-z0-9+/=]+$") then
		found = readVarintFields(fromBase64(blob), WANTED)
	end
	if found and found[FIELD_LOBBY_ID] then
		return { region = found[FIELD_SERVER_REGION] or 0 }
	end
	return nil
end

local ui, font
local state = { region = nil, owner = nil, inGameSince = nil, requests = 0, nextRequest = 0, names = {} }

local function ownerKey(owner)
	return owner and (tostring(owner.type) .. ":" .. tostring(owner.id))
end

local function lobbyObject(typeID, blob, owner, removed)
	if typeID ~= LOBBY_OBJECT then return end
	if removed then
		state.region, state.owner = nil, nil
		return
	end
	local lobby = parseLobby(blob)
	if not lobby then
		Log.Write("[ServerRegion] received a lobby object but could not read it")
		return
	end
	if lobby.region ~= state.region then
		Log.Write("[ServerRegion] lobby server_region = " .. tostring(lobby.region))
	end
	state.region, state.owner = lobby.region, ownerKey(owner)
end

local function cache(entry)
	for _, object in ipairs(entry.objects or {}) do
		for _, blob in ipairs(object.object_data or {}) do
			lobbyObject(object.type_id, blob, entry.owner_soid, false)
		end
	end
end

local MESSAGE_NAMES = {
	[21] = "CMsgSOSingleObject", [22] = "CMsgSOSingleObject", [23] = "CMsgSOSingleObject",
	[24] = "CMsgSOCacheSubscribed", [25] = "CMsgSOCacheUnsubscribed",
	[26] = "CMsgSOMultipleObjects", [4004] = "CMsgClientWelcome",
}

local function handleMessage(data)
	local id = data.msg_type % 2147483648
	local name = MESSAGE_NAMES[id]
	if not name or not data.binary_buffer_recv then return end
	local value = JSON:decode(protobuf.decodeToJSON(name, data.binary_buffer_recv, data.size))
	if id == 24 then
		cache(value)
	elseif id == 4004 then
		for _, entry in ipairs(value.outofdate_subscribed_caches or {}) do cache(entry) end
	elseif id == 26 then
		for _, key in ipairs({ "objects_added", "objects_modified", "objects_removed" }) do
			for _, entry in ipairs(value[key] or {}) do
				lobbyObject(entry.type_id, entry.object_data, value.owner_soid, key == "objects_removed")
			end
		end
	elseif id == 25 then
		if state.owner and ownerKey(value.owner_soid) == state.owner then
			state.region, state.owner = nil, nil
		end
	else
		lobbyObject(value.type_id, value.object_data, value.owner_soid, id == 23)
	end
end

function region_script.OnGCMessage(data)
	handleMessage(data)
	return true
end

-- Loaded mid-match, the lobby message was missed; a new hello makes the coordinator
-- resend our subscribed caches, lobby included (same message as self_play/queue_account.lua).
local function requestLobby()
	local steamID = GC.GetSteamID()
	if steamID == "" or steamID == "0" then return end
	local hello = protobuf.encodeFromJSON("CMsgClientHello", JSON:encode({ engine = 1 }))
	GC.SendMessage(hello.binary, 4006, hello.size)
	protobuf.free(hello.binary)
	Log.Write("[ServerRegion] asked the game coordinator for the current lobby")
end

function region_script.OnGameEnd()
	state.region, state.owner, state.inGameSince, state.requests = nil, nil, nil, 0
end

do
	local general = Menu.Create("Scripts", "Main", "Server Region", "Main", "Server Region")
	local enabled = general:Switch("Enabled", true)
	local gear = enabled:Gear("Settings")
	ui = {
		enabled = enabled,
		x = gear:Slider("Position X (%)", 0, 100, 100, "%d"),
		y = gear:Slider("Position Y (%)", 0, 100, 3, "%d"),
		scale = gear:Slider("Scale (%)", 60, 200, 100, "%d"),
		request = gear:Switch("Ask coordinator if loaded mid-match", true),
	}
	font = Render.LoadFont("Cascadia Code", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
end

local function regionName(id, info)
	local cached = state.names[id]
	if cached then return cached end
	local text = GameLocalizer.Find("#dota_region_" .. info[1])
	if text == "" then return info[2] end
	state.names[id] = text
	return text
end

local function describe()
	local region = state.region
	if region == nil then return "locating", nil, false end
	local info = REGIONS[region]
	if info then return regionName(region, info), info[3], true end
	if region == 0 then return "no region", nil, false end
	return "region " .. region, nil, true
end

function region_script.OnDraw()
	if not ui.enabled:Get() or not Engine.IsInGame() then
		state.inGameSince, state.requests = nil, 0
		return
	end

	local now = os.clock()
	state.inGameSince = state.inGameSince or now
	if state.region == nil and ui.request:Get() and state.requests < 2
		and now - state.inGameSince > 4 and now >= state.nextRequest then
		state.requests, state.nextRequest = state.requests + 1, now + 20
		requestLobby()
	end

	local scale = ui.scale:Get() / 100
	local name, code, known = describe()
	local size, gap, pad, dot = 12 * scale, 6 * scale, 10 * scale, 3 * scale
	local nameSize = Render.TextSize(font, size, name)
	local codeSize = code and Render.TextSize(font, size, code)
	local width = pad * 2 + dot * 2 + gap + nameSize.x + (codeSize and gap + codeSize.x or 0)
	local height = 28 * scale
	local margin = 4 * scale
	local screen = Render.ScreenSize()
	local x = margin + (screen.x - width - margin * 2) * ui.x:Get() / 100
	local y = margin + (screen.y - height - margin * 2) * ui.y:Get() / 100

	local from, to = Vec2(x, y), Vec2(x + width, y + height)
	Render.FilledRect(from, to, Menu.Style("additional_background"), 32, Enum.DrawFlags.RoundCornersAll)
	Render.Blur(from, to, 1, 0.9, 32, Enum.DrawFlags.RoundCornersAll)

	local text = Menu.Style("primary_second_tab_text")
	local muted = text:AlphaModulate(0.55)
	local cx, cy = x + pad + dot, y + height / 2
	Render.FilledCircle(Vec2(cx, cy), dot, known and Menu.Style("primary") or muted)
	local tx = cx + dot + gap
	Render.Text(font, size, name, Vec2(tx, cy - nameSize.y / 2), known and text or muted)
	if code then
		Render.Text(font, size, code, Vec2(tx + nameSize.x + gap, cy - codeSize.y / 2), muted)
	end
end

region_script.parseLobby = parseLobby

return region_script
