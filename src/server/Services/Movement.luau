--!nonstrict
-- One place that decides how a character moves: hub defaults, the speed
-- pass (hub only, so acts stay fair) and the current act's mutator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PassService = require(script.Parent.PassService)

local Movement = {}

-- mutator = nil restores hub movement. frozen = true roots the player.
function Movement.apply(player: Player, mutator: any?, frozen: boolean?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local base = Config.Movement
	local walk = base.WalkSpeed
	local jump = base.JumpHeight
	local scale = 1
	if mutator then
		walk = mutator.walkSpeed or walk
		jump = mutator.jumpHeight or jump
		scale = mutator.scale or 1
	elseif PassService.owns(player, "Speed") then
		walk = base.PassWalkSpeed
	end
	if frozen then
		walk, jump = 0, 0
	end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = walk
	humanoid.JumpHeight = jump
	if math.abs(character:GetScale() - scale) > 0.01 then
		pcall(character.ScaleTo, character, scale)
	end
end

function Movement.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			Movement.apply(player, nil)
		end)
		if player.Character then
			Movement.apply(player, nil)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	PassService.Changed:Connect(function(player)
		if not player:GetAttribute("InAct") then
			Movement.apply(player, nil)
		end
	end)
end

return Movement
