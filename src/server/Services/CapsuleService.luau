--!nonstrict
-- Prize Claw: a capsule machine paid for with earned tickets.
--  * odds come from Config.capsuleOdds, the same table the UI prints
--  * pity guarantees Epic+ every Config.Capsule.Pity pulls
--  * duplicates refund tickets
--  * every item also has a fixed direct price, and players in regions where
--    paid random items are restricted only ever get the direct route

local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Rng = require(ReplicatedStorage.Shared.Rng)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PassService = require(script.Parent.PassService)

local CapsuleService = {}
local rng = Random.new()

local byRarity: { [string]: { any } } = {}
for _, item in Config.Cosmetics do
	byRarity[item.rarity] = byRarity[item.rarity] or {}
	table.insert(byRarity[item.rarity], item)
end

local function checkPolicy(player: Player)
	-- Fail closed: if the policy lookup errors, treat the player as restricted.
	local restricted = true
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if ok and info then
		restricted = info.ArePaidRandomItemsRestricted == true
	end
	if player.Parent then
		player:SetAttribute("CapsuleRestricted", restricted)
	end
end

local function pull(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if player:GetAttribute("CapsuleRestricted") ~= false then
		Net.fire(player, "Toast", "Capsules aren't available in your region. Buy items directly in the Wardrobe.", "bad")
		return
	end
	if not EconomyService.spend(player, Config.Capsule.Cost) then
		Net.fire(player, "Toast", `A capsule costs {Config.Capsule.Cost} tickets.`, "bad")
		return
	end

	local pityHit = profile.pity + 1 >= Config.Capsule.Pity
	local odds = Config.capsuleOdds(PassService.owns(player, "Lucky"), pityHit)
	local rarity = Rng.weighted(rng, Config.RarityOrder, function(name)
		return if byRarity[name] then odds[name] else 0
	end) or "Common"
	local item = Rng.pick(rng, byRarity[rarity])

	local floorIndex = table.find(Config.RarityOrder, Config.Capsule.PityFloor) or 1
	if (table.find(Config.RarityOrder, rarity) or 1) >= floorIndex then
		profile.pity = 0
	else
		profile.pity += 1
	end
	profile.stats.capsules += 1

	local duplicate = profile.owned[item.id] == true
	local refund = 0
	if duplicate then
		refund = Config.Rarities[rarity].refund
		EconomyService.award(player, refund, { raw = true })
	else
		profile.owned[item.id] = true
	end
	DataService.replicate(player)
	Net.fire(player, "CapsuleResult", { id = item.id, duplicate = duplicate, refund = refund })
	if not duplicate and (rarity == "Legendary" or rarity == "Glitched") then
		Net.fireAll("Barker", `{player.DisplayName} just pulled a {string.upper(rarity)}: {item.name}!`)
	end
end

local function buy(player: Player, id: any)
	local profile = DataService.get(player)
	local item = if type(id) == "string" then Config.CosmeticById[id] else nil
	if not profile or not item or profile.owned[item.id] then
		return
	end
	local price = Config.Rarities[item.rarity].price
	if not EconomyService.spend(player, price) then
		Net.fire(player, "Toast", `{item.name} costs {price} tickets.`, "bad")
		return
	end
	profile.owned[item.id] = true
	DataService.replicate(player)
	Net.fire(player, "Toast", `Unlocked {item.name}!`, "good")
end

function CapsuleService.init()
	Players.PlayerAdded:Connect(checkPolicy)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPolicy, player)
	end
	Net.onServer("PullCapsule", pull, 0.6)
	Net.onServer("BuyCosmetic", buy, 0.4)
end

return CapsuleService
