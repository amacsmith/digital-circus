--!nonstrict
-- Developer product receipts. Grants are driven by Config.Products[*].kind,
-- so adding a product of an existing kind is a Config row and nothing else.
--
-- Receipt safety:
--  * a purchase id is recorded in the profile the moment it is granted, so a
--    retried receipt can never grant twice
--  * PurchaseGranted is only returned once the profile has actually saved
--  * nothing is granted to a profile that failed to load

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ActDirector = require(script.Parent.ActDirector)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PassService = require(script.Parent.PassService)

local MonetizationService = {}

local MAX_RECEIPTS = 100

local Grants = {}

function Grants.tickets(player: Player, _profile: any, product: any)
	EconomyService.award(player, product.amount, { raw = true })
	Net.fire(player, "Toast", `+{product.amount} tickets. Thank you for supporting the show!`, "gold")
end

function Grants.boost(player: Player, _profile: any, product: any)
	EconomyService.extendBoost(product.seconds)
	EconomyService.barker("Ovation", { PLAYER = player.DisplayName })
end

function Grants.revive(player: Player, profile: any, product: any)
	profile.reviveTokens += product.amount
	DataService.replicate(player)
	-- Bought from the "you're out" prompt: use it right away if still possible.
	if not ActDirector.tryRevive(player) then
		Net.fire(player, "Toast", "Second Take saved. It never expires.", "good")
	end
end

function Grants.director(player: Player, profile: any, product: any)
	profile.directorCuts += product.amount
	DataService.replicate(player)
	Net.fire(player, "Toast", "Director's Cut ready. Pick the next act at the Director's Chair.", "gold")
end

local function grant(player: Player, profile: any, product: any)
	local handler = Grants[product.kind]
	if not handler then
		error(`no grant handler for product kind "{product.kind}"`)
	end
	handler(player, profile, product)
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local NotYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and DataService.get(player)
	if not player or not profile then
		return NotYet
	end
	local product = nil
	for _, candidate in Config.Products do
		if candidate.id == info.ProductId then
			product = candidate
		end
	end
	if not product then
		warn(`[Shop] unknown product id {info.ProductId}`)
		return NotYet
	end

	local studio = RunService:IsStudio()
	if not table.find(profile.receipts, info.PurchaseId) then
		if not DataService.canSave(player) and not studio then
			return NotYet
		end
		local ok, err = pcall(grant, player, profile, product)
		if not ok then
			warn(`[Shop] grant failed: {err}`)
			return NotYet
		end
		table.insert(profile.receipts, info.PurchaseId)
		while #profile.receipts > MAX_RECEIPTS do
			table.remove(profile.receipts, 1)
		end
	end

	if studio or DataService.save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return NotYet
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	-- Studio-only: products/passes with id = 0 grant for free so the full
	-- purchase loop can be play-tested before anything exists on the dashboard.
	Net.onServer("DevGrant", function(player, kind, key)
		if not RunService:IsStudio() or type(key) ~= "string" then
			return
		end
		local profile = DataService.get(player)
		if kind == "pass" and Config.Passes[key] then
			PassService.grant(player, key)
			Net.fire(player, "Toast", `[Studio] granted pass {key}`, "good")
		elseif kind == "product" and Config.Products[key] and profile then
			grant(player, profile, Config.Products[key])
		end
	end, 0.5)
end

return MonetizationService
