--!nonstrict
-- FLOOR_NOT_FOUND : the stage is garbage-collected tile by tile. Tiles flash
-- before they are freed. Last performers standing take the bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Rng = require(ReplicatedStorage.Shared.Rng)

local GRID = 10
local TILE = 10
local WARN_TIME = 1.1
local KEEP = 4

local Act = { id = "FloorDelete" }

function Act.build(ctx)
	local rng: Random = ctx.rng
	local origin: Vector3 = ctx.origin
	local tiles = {}
	ctx.tiles = tiles

	local hue = rng:NextNumber()
	local colorA = Color3.fromHSV(hue, 0.7, 0.95)
	local colorB = Color3.fromHSV((hue + 0.5) % 1, 0.15, 1)
	local half = (GRID - 1) * TILE / 2

	for x = 0, GRID - 1 do
		for z = 0, GRID - 1 do
			local tile = Build.part({
				Name = "Tile",
				Size = Vector3.new(TILE - 0.3, 1.5, TILE - 0.3),
				Position = origin + Vector3.new(x * TILE - half, 0, z * TILE - half),
				Color = if (x + z) % 2 == 0 then colorA else colorB,
			}, ctx.folder)
			table.insert(tiles, tile)
		end
	end

	local spawns = {}
	local shuffled = Rng.shuffle(rng, table.clone(tiles))
	for i = 1, math.min(16, #shuffled) do
		table.insert(spawns, CFrame.new(shuffled[i].Position + Vector3.new(0, 1, 0)))
	end
	return { spawns = spawns, revive = CFrame.new(origin + Vector3.new(0, 16, 0)) }
end

function Act.run(ctx)
	local rng: Random = ctx.rng
	local remaining = Rng.shuffle(rng, table.clone(ctx.tiles))
	local duration = ctx.meta.duration
	task.wait(2)
	while ctx.running and #remaining > KEEP do
		-- Ramps from slow singles to fast clusters as the act goes on.
		local progress = math.clamp(1 - ctx:timeLeft() / duration, 0, 1)
		local batch = 1 + math.floor(progress * 3.5)
		for _ = 1, batch do
			local tile = table.remove(remaining)
			if not tile or #remaining < KEEP then
				break
			end
			task.spawn(function()
				tile.Color = Color3.fromRGB(255, 50, 80)
				tile.Material = Enum.Material.Neon
				task.wait(WARN_TIME)
				if tile.Parent then
					tile.CanCollide = false
					tile.Transparency = 1
				end
			end)
		end
		task.wait(2 - progress * 1.35)
	end
end

return Act
