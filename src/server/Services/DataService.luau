--!nonstrict
-- Player profiles: load, reconcile against a template, replicate, autosave.
-- If a profile fails to LOAD it is marked session-only and is never written
-- back, so a DataStore outage cannot overwrite real progress.
--
-- NOTE: there is no cross-server session lock here. For a large live game,
-- swap the load/save internals for ProfileStore; the public API can stay.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local DataService = {}

local TEMPLATE = {
	tickets = 0,
	applause = 0,
	encores = 0,
	streak = 0,
	lastDaily = 0,
	pity = 0,
	reviveTokens = 0,
	directorCuts = 0,
	owned = {},
	equipped = {},
	stats = { acts = 0, wins = 0, ticketsEarned = 0, capsules = 0 },
	receipts = {},
}

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}
local loaded = Instance.new("BindableEvent")
DataService.ProfileLoaded = loaded.Event

local store: DataStore? = nil
local ordered: OrderedDataStore? = nil

local function retry(attempts: number, fn: () -> any): (boolean, any)
	local result
	for attempt = 1, attempts do
		local ok, value = pcall(fn)
		if ok then
			return true, value
		end
		result = value
		if attempt < attempts then
			task.wait(attempt * 1.5)
		end
	end
	return false, result
end

local function reconcile(data: any, template: any): any
	for key, default in template do
		if data[key] == nil then
			data[key] = if type(default) == "table" then reconcile({}, default) else default
		elseif type(default) == "table" and type(data[key]) == "table" then
			reconcile(data[key], default)
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

function DataService.get(player: Player): any
	return profiles[player]
end

function DataService.canSave(player: Player): boolean
	return canSave[player] == true
end

-- Numeric state rides on attributes (cheap, automatic replication).
function DataService.sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local level = Config.levelFor(profile.applause)
	player:SetAttribute("Tickets", profile.tickets)
	player:SetAttribute("Applause", profile.applause)
	player:SetAttribute("Level", level)
	player:SetAttribute("Encores", profile.encores)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats :: any).Tickets.Value = profile.tickets;
		(stats :: any).Level.Value = level;
		(stats :: any).Encores.Value = profile.encores
	end
end

-- Structured state (inventory, tokens, streak) goes over one remote.
function DataService.replicate(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Net.fire(player, "Profile", {
		owned = profile.owned,
		equipped = profile.equipped,
		pity = profile.pity,
		reviveTokens = profile.reviveTokens,
		directorCuts = profile.directorCuts,
		streak = profile.streak,
		lastDaily = profile.lastDaily,
		stats = profile.stats,
	})
end

function DataService.save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not canSave[player] or not store then
		return false
	end
	local ok, err = retry(3, function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function()
			return profile
		end)
	end)
	if not ok then
		warn(`[Data] save failed for {player.Name}: {err}`)
		return false
	end
	if ordered then
		pcall(function()
			(ordered :: OrderedDataStore):SetAsync(tostring(player.UserId), math.floor(profile.applause))
		end)
	end
	return true
end

-- Top performers by lifetime applause: { { name = string, value = number } }
function DataService.top(count: number): { any }
	local out = {}
	if not ordered then
		return out
	end
	local ok, pages = pcall(function()
		return (ordered :: OrderedDataStore):GetSortedAsync(false, count)
	end)
	if not ok then
		return out
	end
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		local name = "???"
		if userId then
			local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			if okName then
				name = result
			end
		end
		table.insert(out, { name = name, value = entry.value })
	end
	return out
end

local function load(player: Player)
	local data = nil
	local savable = false
	if store then
		local ok, result = retry(3, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			data = result
			savable = true
		else
			warn(`[Data] load failed for {player.Name}; session-only profile. {result}`)
		end
	end
	if player.Parent == nil then
		return
	end
	local profile = reconcile(if type(data) == "table" then data else {}, TEMPLATE)
	profiles[player] = profile
	canSave[player] = savable

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Tickets", "Level", "Encores" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	DataService.sync(player)
	DataService.replicate(player)
	player:SetAttribute("DataLoaded", true)
	loaded:Fire(player)
end

function DataService.init()
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName)
		ordered = DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_Applause")
	end)
	if not ok then
		warn(`[Data] DataStores unavailable, running session-only: {err}`)
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(120)
			for player in profiles do
				task.spawn(DataService.save, player)
			end
		end
	end)
end

return DataService
