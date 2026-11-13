--!nonstrict
-- BALLOON.POP() : a score attack. Balloons spawn over a generated playground
-- of stepped towers. Gold pays 5x; black "virus" balloons launch you instead.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Net = require(ReplicatedStorage.Shared.Net)
local Rng = require(ReplicatedStorage.Shared.Rng)

local RADIUS = 58
local TOWERS = 6
local STEPS_PER_TOWER = 5

local TYPES = {
	{ id = "normal", weight = 82, score = 5 },
	{ id = "gold", weight = 8, score = 25, color = Color3.fromRGB(255, 214, 70) },
	{ id = "virus", weight = 10, score = 0, color = Color3.fromRGB(14, 14, 20) },
}

local Act = { id = "BalloonHeist" }

function Act.build(ctx)
	local rng: Random = ctx.rng
	local origin: Vector3 = ctx.origin
	local points = {}
	ctx.points = points

	Build.cylinder(origin, RADIUS, 2, { Name = "Floor", Color = Color3.fromHSV(rng:NextNumber(), 0.35, 0.35) }, ctx.folder)
	Build.cylinder(origin - Vector3.new(0, 0.3, 0), RADIUS + 1.5, 2, {
		Name = "Rim", Color = Color3.fromRGB(255, 80, 200), Material = Enum.Material.Neon,
	}, ctx.folder)

	for _ = 1, 26 do
		local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(6, RADIUS - 6)
		table.insert(points, origin + Vector3.new(math.cos(angle) * distance, 5.5, math.sin(angle) * distance))
	end

	-- Spiral staircases: each step is a comfortable jump above the last.
	for tower = 1, TOWERS do
		local baseAngle = (tower / TOWERS) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local distance = rng:NextNumber(20, RADIUS - 14)
		local color = Color3.fromHSV(rng:NextNumber(), 0.7, 1)
		for step = 1, STEPS_PER_TOWER do
			local angle = baseAngle + step * 0.22
			local position = origin + Vector3.new(math.cos(angle) * distance, 1 + step * 4.5, math.sin(angle) * distance)
			Build.part({
				Name = "Step",
				Size = Vector3.new(8, 1, 8),
				CFrame = CFrame.new(position) * CFrame.Angles(0, -angle, 0),
				Color = if step % 2 == 0 then color else Color3.fromRGB(245, 240, 255),
			}, ctx.folder)
			table.insert(points, position + Vector3.new(0, 5, 0))
			if step == STEPS_PER_TOWER then
				-- The top of every tower is a premium spot.
				table.insert(points, position + Vector3.new(0, 9, 0))
			end
		end
	end

	local spawns = {}
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		table.insert(spawns, CFrame.new(origin + Vector3.new(math.cos(angle) * 10, 2, math.sin(angle) * 10)))
	end
	return { spawns = spawns }
end

function Act.run(ctx)
	local rng: Random = ctx.rng
	local live = 0
	while ctx.running do
		local cap = 22 + 5 * #ctx:activePlayers()
		if live < cap then
			local kind = Rng.weighted(rng, TYPES, function(entry)
				return entry.weight
			end) or TYPES[1]
			local balloon = Build.ball(Rng.pick(rng, ctx.points) + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), 3.6, {
				Name = "Balloon",
				CanCollide = false,
				Material = Enum.Material.Neon,
				Color = kind.color or Color3.fromHSV(rng:NextNumber(), 0.8, 1),
				Tags = { "GlitchBob" },
			}, ctx.folder)
			live += 1
			local popped = false
			balloon.Destroying:Connect(function()
				live -= 1
			end)
			balloon.Touched:Connect(function(hit)
				local player = ctx:playerFromHit(hit)
				if not player or popped then
					return
				end
				popped = true
				balloon:Destroy()
				if kind.id == "virus" then
					Net.fire(player, "Fling", Vector3.new(rng:NextNumber(-40, 40), 95, rng:NextNumber(-40, 40)))
				else
					ctx:addScore(player, kind.score)
				end
			end)
			Debris:AddItem(balloon, 14)
		end
		task.wait(0.3)
	end
end

return Act
