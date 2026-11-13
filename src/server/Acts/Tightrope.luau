--!nonstrict
-- TIGHTROPE.DLL : a race across an obstacle course compiled from the round
-- seed. Falling returns you to your last checkpoint instead of ending your run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Rng = require(ReplicatedStorage.Shared.Rng)

local STEPS = 30
local CHECKPOINT_EVERY = 6

local KINDS = {
	{ kind = "plain", weight = 50 },
	{ kind = "beam", weight = 25 },
	{ kind = "flicker", weight = 25 },
}

local Act = { id = "Tightrope" }

function Act.build(ctx)
	local rng: Random = ctx.rng
	local origin: Vector3 = ctx.origin
	local folder = ctx.folder
	local flickers = {}
	ctx.flickers = flickers

	local colorA = Color3.fromHSV(rng:NextNumber(), 0.75, 1)
	local colorB = Color3.fromRGB(245, 240, 255)

	Build.part({ Name = "Start", Size = Vector3.new(28, 1, 24), Position = origin, Color = colorB }, folder)
	local spawns = {}
	for i = 1, 8 do
		table.insert(spawns, CFrame.new(origin + Vector3.new(-14 + i * 3.1, 1, -4)))
	end

	local function checkpoint(pad: BasePart, index: number)
		local reached = {}
		local respawn = CFrame.new(pad.Position + Vector3.new(0, 5, 0))
		pad.Touched:Connect(function(hit)
			local player = ctx:playerFromHit(hit)
			if player and not reached[player] then
				reached[player] = true
				local state = ctx.participants[player]
				if not state.checkpointIndex or state.checkpointIndex < index then
					state.checkpointIndex = index
					state.checkpoint = respawn
					ctx:addScore(player, Config.Round.CheckpointScore)
				end
			end
		end)
	end

	local cursor = origin + Vector3.new(0, 0, 12)
	local lastKind = "plain"
	for step = 1, STEPS do
		local isCheckpoint = step % CHECKPOINT_EVERY == 0
		local kind = "plain"
		if not isCheckpoint and step > 2 then
			local choice = Rng.weighted(rng, KINDS, function(entry)
				return if entry.kind == "flicker" and lastKind == "flicker" then 0 else entry.weight
			end)
			kind = if choice then choice.kind else "plain"
		end
		lastKind = kind

		local length = if isCheckpoint then 10 elseif kind == "beam" then rng:NextNumber(12, 18) else 6
		local width = if isCheckpoint then 10 elseif kind == "beam" then 1.8 else 6
		local gap = rng:NextNumber(3.5, 6)
		local rise = rng:NextNumber(-2, 2.5)
		local drift = math.clamp(cursor.X - origin.X + rng:NextNumber(-5, 5), -24, 24)
		local center = Vector3.new(origin.X + drift, cursor.Y + rise, cursor.Z + gap + length / 2)

		local pad = Build.part({
			Name = kind,
			Size = Vector3.new(width, 1, length),
			Position = center,
			Color = if isCheckpoint then Color3.fromRGB(90, 255, 170) elseif step % 2 == 0 then colorA else colorB,
			Material = if isCheckpoint or kind == "flicker" then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		}, folder)
		if isCheckpoint then
			checkpoint(pad, step)
			Build.billboard(pad, "CHECKPOINT", { color = Color3.fromRGB(90, 255, 170), size = UDim2.fromScale(10, 2) })
		elseif kind == "flicker" then
			pad.Color = Color3.fromRGB(255, 80, 200)
			table.insert(flickers, { part = pad, offset = rng:NextNumber(0, 2.6) })
		end
		cursor = Vector3.new(center.X, center.Y, center.Z + length / 2)
	end

	local finish = Build.part({
		Name = "Finish",
		Size = Vector3.new(26, 1, 22),
		Position = Vector3.new(cursor.X, cursor.Y, cursor.Z + 4 + 11),
		Color = Color3.fromRGB(255, 214, 70),
		Material = Enum.Material.Neon,
	}, folder)
	Build.billboard(finish, "CURTAIN CALL", { color = Color3.fromRGB(255, 214, 70), size = UDim2.fromScale(18, 4), offset = Vector3.new(0, 9, 0), maxDistance = 600 })
	finish.Touched:Connect(function(hit)
		local player = ctx:playerFromHit(hit)
		if player then
			ctx:finish(player)
		end
	end)

	return { spawns = spawns }
end

function Act.run(ctx)
	-- Flicker pads: solid 1.6s, ghost 1.0s, each on its own phase.
	while ctx.running do
		local t = os.clock()
		for _, entry in ctx.flickers do
			local solid = (t + entry.offset) % 2.6 < 1.6
			entry.part.CanCollide = solid
			entry.part.Transparency = if solid then 0 else 0.8
		end
		task.wait(0.1)
	end
end

function Act.onFall(ctx, player)
	local state = ctx.participants[player]
	ctx:teleport(player, state.checkpoint or state.spawn)
end

return Act
