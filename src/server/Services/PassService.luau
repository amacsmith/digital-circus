--!nonstrict
-- Game pass ownership cache. Mirrors ownership onto player attributes
-- ("Pass_VIP" etc.) so the client can render it without asking.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PassService = {}
local changed = Instance.new("BindableEvent")
PassService.Changed = changed.Event -- (player, passKey)

function PassService.owns(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function PassService.grant(player: Player, key: string)
	if not PassService.owns(player, key) then
		player:SetAttribute("Pass_" .. key, true)
		changed:Fire(player, key)
	end
end

local function check(player: Player)
	for key, pass in Config.Passes do
		if pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns and player.Parent then
				PassService.grant(player, key)
			end
		end
	end
end

function PassService.init()
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Config.Passes do
			if pass.id == passId then
				PassService.grant(player, key)
			end
		end
	end)
end

return PassService
