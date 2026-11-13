--!nonstrict
-- Tickets, applause (xp), multipliers, the server-wide boost, the shared
-- crowd meter and Encores (prestige). Every ticket in the game flows
-- through award()/spend() so multipliers and stats stay consistent.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Rng = require(ReplicatedStorage.Shared.Rng)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)

local EconomyService = {}

local rng = Random.new()
local friendPairs: { [string]: boolean } = {}

local function pairKey(a: Player, b: Player): string
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	return low .. ":" .. high
end

local function friendsOnline(player: Player): number
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and friendPairs[pairKey(player, other)] then
			count += 1
		end
	end
	return math.min(count, Config.FriendBonusCap)
end

function EconomyService.boostActive(): boolean
	return (workspace:GetAttribute("BoostEndsAt") or 0) > workspace:GetServerTimeNow()
end

function EconomyService.multiplier(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return 1
	end
	local m = 1 + profile.encores * Config.Encore.BonusPerEncore
	if PassService.owns(player, "VIP") then
		m *= 2
	end
	if EconomyService.boostActive() then
		m *= 2
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		m *= 1 + Config.PremiumBonus
	end
	m *= 1 + friendsOnline(player) * Config.FriendBonus
	return m
end

function EconomyService.sync(player: Player)
	player:SetAttribute("Multiplier", EconomyService.multiplier(player))
	player:SetAttribute("Friends", friendsOnline(player))
	DataService.sync(player)
end

-- opts.raw: skip multipliers (purchases, refunds). opts.scale: extra factor.
-- Returns the amount actually granted.
function EconomyService.award(player: Player, base: number, opts: any?): number
	local profile = DataService.get(player)
	if not profile or base <= 0 then
		return 0
	end
	local o = opts or {}
	local amount = base * (o.scale or 1)
	if not o.raw then
		amount *= EconomyService.multiplier(player)
		profile.stats.ticketsEarned += math.floor(amount)
		if not o.noHype then
			EconomyService.addHype(amount * Config.Hype.PerTicketEarned)
		end
	end
	amount = math.floor(amount)
	profile.tickets += amount
	DataService.sync(player)
	return amount
end

function EconomyService.spend(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or amount < 0 or profile.tickets < amount then
		return false
	end
	profile.tickets -= amount
	DataService.sync(player)
	return true
end

function EconomyService.addApplause(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile or amount <= 0 then
		return
	end
	local before = Config.levelFor(profile.applause)
	profile.applause += math.floor(amount)
	local after = Config.levelFor(profile.applause)
	DataService.sync(player)
	if after > before then
		Net.fire(player, "Toast", `LEVEL UP! You are now a level {after} performer.`, "gold")
	end
end

function EconomyService.extendBoost(seconds: number)
	local now = workspace:GetServerTimeNow()
	local current = math.max(workspace:GetAttribute("BoostEndsAt") or 0, now)
	workspace:SetAttribute("BoostEndsAt", current + seconds)
	for _, player in Players:GetPlayers() do
		EconomyService.sync(player)
	end
end

function EconomyService.barker(category: string, vars: { [string]: string }?)
	local lines = Config.Barker[category]
	if not lines then
		return
	end
	local line = Rng.pick(rng, lines)
	local all = vars or {}
	all.BUILD = tostring(workspace:GetAttribute("BuildNumber") or "?")
	for key, value in all do
		line = string.gsub(line, "%%" .. key .. "%%", function()
			return value
		end)
	end
	Net.fireAll("Barker", line)
end

---------------------------------------------------------------------------
-- Crowd meter: everyone fills it together; when it tops out, tickets rain
-- on the Midway. A shared goal gives a full server a reason to stay full.
---------------------------------------------------------------------------
local raining = false

local function ticketRain()
	if raining then
		return
	end
	raining = true
	EconomyService.barker("Rain")
	local folder = Instance.new("Folder")
	folder.Name = "TicketRain"
	folder.Parent = workspace
	for _ = 1, Config.Hype.RainPickups do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(24, 110)
		local pickup = Build.part({
			Name = "Ticket",
			Anchored = false,
			Size = Vector3.new(3, 0.4, 1.6),
			Color = Color3.fromRGB(255, 214, 70),
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(math.cos(angle) * radius, rng:NextNumber(50, 110), math.sin(angle) * radius)
				* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
		}, folder)
		local taken = false
		pickup.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if player and not taken then
				taken = true
				pickup:Destroy()
				EconomyService.award(player, Config.Hype.RainValue, { noHype = true })
			end
		end)
		task.wait(0.08)
	end
	Debris:AddItem(folder, 30)
	task.delay(30, function()
		raining = false
	end)
end

function EconomyService.addHype(amount: number)
	local hype = (workspace:GetAttribute("Hype") or 0) + amount
	if hype >= 100 then
		hype = 0
		task.spawn(ticketRain)
	end
	workspace:SetAttribute("Hype", hype)
end

---------------------------------------------------------------------------
-- Encore: trade your ticket pile for a permanent multiplier.
---------------------------------------------------------------------------
local function encore(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local cost = Config.Encore.cost(profile.encores)
	if profile.tickets < cost then
		Net.fire(player, "Toast", `You need {cost} tickets to take an Encore.`, "bad")
		return
	end
	profile.tickets = 0
	profile.encores += 1
	EconomyService.sync(player)
	DataService.replicate(player)
	Net.fire(player, "Toast", `ENCORE #{profile.encores}! Permanent +{Config.Encore.BonusPerEncore * 100}% tickets.`, "gold")
	Net.fireAll("Barker", `{player.DisplayName} took Encore #{profile.encores}. The crowd demands more.`)
end

function EconomyService.init()
	workspace:SetAttribute("Hype", 0)
	workspace:SetAttribute("BoostEndsAt", 0)

	local function onLoaded(player: Player)
		EconomyService.sync(player)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				task.spawn(function()
					local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
					if ok and isFriend then
						friendPairs[pairKey(player, other)] = true
						if player.Parent then
							EconomyService.sync(player)
						end
						if other.Parent then
							EconomyService.sync(other)
						end
					end
				end)
			end
		end
	end
	DataService.ProfileLoaded:Connect(onLoaded)
	for _, player in Players:GetPlayers() do
		if DataService.get(player) then
			task.spawn(onLoaded, player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			for _, other in Players:GetPlayers() do
				EconomyService.sync(other)
			end
		end)
	end)

	PassService.Changed:Connect(EconomyService.sync)
	Net.onServer("Encore", encore, 1)

	-- Keeps multipliers honest when the server boost starts or runs out.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				EconomyService.sync(player)
			end
		end
	end)
end

return EconomyService
