--!nonstrict
-- FOLLOW_SPOT : only what the spotlight touches gets rendered. The light
-- wanders and shrinks; stand outside it and you fill with static until
-- you are unrendered.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Build = require(ReplicatedStorage.Shared.Build)

local RADIUS = 56
local START_SPOT = 22
local END_SPOT = 8
local HOP_TIME = 3.2
local TOLERANCE = 3 -- seconds outside the light before elimination
local GRACE = 4
local TICK = 0.2

local Act = { id = "Spotlight" }

function Act.build(ctx)
	local origin: Vector3 = ctx.origin
	Build.cylinder(origin, RADIUS, 2, { Name = "Stage", Color = Color3.fromRGB(24, 20, 36) }, ctx.folder)
	Build.cylinder(origin - Vector3.new(0, 0.3, 0), RADIUS + 1.5, 2, {
		Name = "Rim", Color = Color3.fromRGB(120, 80, 255), Material = Enum.Material.Neon,
	}, ctx.folder)

	local spot = Build.cylinder(origin + Vector3.new(0, 1.1, 0), START_SPOT, 0.3, {
		Name = "Spot",
		Color = Color3.fromRGB(255, 244, 200),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.25,
	}, ctx.folder)
	Build.light(spot, Color3.fromRGB(255, 240, 200), 50, 3)
	ctx.spot = spot

	local spawns = {}
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		table.insert(spawns, CFrame.new(origin + Vector3.new(math.cos(angle) * 9, 2, math.sin(angle) * 9)))
	end
	return { spawns = spawns, revive = CFrame.new(origin + Vector3.new(0, 14, 0)) }
end

function Act.run(ctx)
	local rng: Random = ctx.rng
	local origin: Vector3 = ctx.origin
	local spot: Part = ctx.spot
	local duration = ctx.meta.duration
	local static: { [Player]: number } = {}
	local nextHop = 0
	local elapsed = 0

	while ctx.running do
		if elapsed >= nextHop then
			nextHop = elapsed + HOP_TIME + 0.4
			local progress = math.clamp(elapsed / duration, 0, 1)
			local size = START_SPOT + (END_SPOT - START_SPOT) * progress
			local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, RADIUS - size - 2)
			local target = origin + Vector3.new(math.cos(angle) * distance, 1.1, math.sin(angle) * distance)
			TweenService:Create(spot, TweenInfo.new(HOP_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				CFrame = CFrame.new(target) * CFrame.Angles(0, 0, math.rad(90)),
				Size = Vector3.new(0.3, size * 2, size * 2),
			}):Play()
		end

		if elapsed > GRACE then
			local center = spot.Position
			local radius = spot.Size.Y / 2
			for _, player in ctx:activePlayers() do
				local root = ctx:root(player)
				if root then
					local offset = root.Position - center
					local outside = Vector3.new(offset.X, 0, offset.Z).Magnitude > radius
					local value = static[player] or 0
					value = if outside then value + TICK / TOLERANCE else math.max(value - TICK / (TOLERANCE * 3), 0)
					static[player] = value
					player:SetAttribute("Static", value)
					if value >= 1 then
						static[player] = 0
						ctx:eliminate(player, "The spotlight moved on without you.")
					end
				end
			end
		end

		task.wait(TICK)
		elapsed += TICK
	end
end

return Act
