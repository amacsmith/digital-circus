--!nonstrict
-- Applies equipped cosmetics (trail, aura, nameplate title) to characters.
-- Built from Config.Cosmetics rows; no assets are required.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)

local CosmeticService = {}

local function sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

local function clear(character: Model)
	for _, child in character:GetDescendants() do
		if child:GetAttribute("GlitchtopCosmetic") then
			child:Destroy()
		end
	end
end

local function mark(instance: Instance)
	instance:SetAttribute("GlitchtopCosmetic", true)
	return instance
end

function CosmeticService.apply(player: Player)
	local profile = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not profile or not character or not root or not head then
		return
	end
	clear(character)

	local trail = Config.CosmeticById[profile.equipped.trail or ""]
	if trail then
		local top = mark(Instance.new("Attachment")) :: Attachment
		top.Position = Vector3.new(0, 1.1, 0)
		top.Parent = root
		local bottom = mark(Instance.new("Attachment")) :: Attachment
		bottom.Position = Vector3.new(0, -1.1, 0)
		bottom.Parent = root
		local fx = mark(Instance.new("Trail")) :: Trail
		fx.Attachment0 = top
		fx.Attachment1 = bottom
		fx.Color = sequence(trail.colors)
		fx.Lifetime = 0.9
		fx.LightEmission = 0.8
		fx.Transparency = NumberSequence.new(0.1, 1)
		fx.Parent = root
	end

	local aura = Config.CosmeticById[profile.equipped.aura or ""]
	if aura then
		local fx = mark(Instance.new("ParticleEmitter")) :: ParticleEmitter
		fx.Color = sequence(aura.colors)
		fx.Rate = 14
		fx.Lifetime = NumberRange.new(0.8, 1.4)
		fx.Speed = NumberRange.new(2, 5)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		fx.LightEmission = 0.9
		fx.RotSpeed = NumberRange.new(-120, 120)
		fx.Parent = root
	end

	local title = Config.CosmeticById[profile.equipped.title or ""]
	local gui = mark(Instance.new("BillboardGui")) :: BillboardGui
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromScale(7, 1.1)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	local prefix = if PassService.owns(player, "VIP") then "[VIP] " else ""
	local level = Config.levelFor(profile.applause)
	label.Text = `{prefix}{if title then title.text else "ACT"} · LV {level}`
	label.TextColor3 = if prefix ~= "" then Color3.fromRGB(255, 210, 80) elseif title then title.colors[1] else Color3.fromRGB(220, 220, 235)
	label.Parent = gui
	gui.Parent = head
end

local function equip(player: Player, kind: any, id: any)
	local profile = DataService.get(player)
	if not profile or (kind ~= "trail" and kind ~= "aura" and kind ~= "title") then
		return
	end
	if id == nil or id == false then
		profile.equipped[kind] = nil
	else
		local item = Config.CosmeticById[id]
		if type(id) ~= "string" or not item or item.kind ~= kind or not profile.owned[id] then
			return
		end
		profile.equipped[kind] = id
	end
	DataService.replicate(player)
	CosmeticService.apply(player)
end

function CosmeticService.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			CosmeticService.apply(player)
		end)
		player:GetAttributeChangedSignal("Level"):Connect(function()
			CosmeticService.apply(player)
		end)
		CosmeticService.apply(player)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	DataService.ProfileLoaded:Connect(CosmeticService.apply)
	PassService.Changed:Connect(CosmeticService.apply)
	Net.onServer("Equip", equip, 0.2)
end

return CosmeticService
