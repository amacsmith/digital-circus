--!nonstrict
-- Retention rewards: the 7-day call sheet (login streak) and the playtime
-- gift that recharges while you stay in the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Rng = require(ReplicatedStorage.Shared.Rng)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local RewardService = {}

local function claimDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local today = Rng.dayIndex()
	if profile.lastDaily >= today then
		Net.fire(player, "Toast", "Already checked in today. Come back tomorrow!", "bad")
		return
	end
	profile.streak = if profile.lastDaily == today - 1 then profile.streak + 1 else 1
	profile.lastDaily = today
	local slot = (profile.streak - 1) % #Config.Daily + 1
	local amount = EconomyService.award(player, Config.Daily[slot], { raw = true })
	local extra = ""
	if slot == #Config.Daily then
		profile.reviveTokens += Config.DailyDay7ReviveTokens
		extra = " + a free Second Take"
	end
	player:SetAttribute("DailyReady", false)
	DataService.replicate(player)
	Net.fire(player, "Toast", `Day {profile.streak} streak! +{amount} tickets{extra}.`, "gold")
end

local function armGift(player: Player)
	player:SetAttribute("GiftReadyAt", workspace:GetServerTimeNow() + Config.Gift.Interval)
end

local function claimGift(player: Player)
	local profile = DataService.get(player)
	local readyAt = player:GetAttribute("GiftReadyAt")
	if not profile or not readyAt or workspace:GetServerTimeNow() < readyAt then
		return
	end
	armGift(player)
	local base = Config.Gift.Base + Config.Gift.PerLevel * Config.levelFor(profile.applause)
	local amount = EconomyService.award(player, base)
	Net.fire(player, "Toast", `Stagehand gift: +{amount} tickets. Next one is already warming up.`, "good")
end

function RewardService.init()
	DataService.ProfileLoaded:Connect(function(player)
		local profile = DataService.get(player)
		player:SetAttribute("DailyReady", profile.lastDaily < Rng.dayIndex())
		armGift(player)
	end)
	Net.onServer("ClaimDaily", claimDaily, 1)
	Net.onServer("ClaimGift", claimGift, 1)
end

return RewardService
