--!nonstrict
-- Generates the Midway (the hub) at server start. Nothing is pre-built: the
-- place file has an empty Workspace and this module renders the circus from
-- the UTC date, so all servers share "today's build" and tomorrow differs.
--
-- Client-side FX hook onto CollectionService tags set here:
--   GlitchSpin    slowly tumbling debris
--   GlitchBob     gentle float
--   GlitchFlicker neon that stutters

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Rng = require(ReplicatedStorage.Shared.Rng)

local WorldGen = {}
WorldGen.leaderboardLabel = nil :: TextLabel?

local TAU = math.pi * 2
local NEON = Enum.Material.Neon

local function polar(angle: number, radius: number, y: number): Vector3
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function lighting(palette)
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(96, 80, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 60, 110)
	Lighting.GlobalShadows = true
	Lighting.FogColor = palette.fog
	Lighting.FogEnd = 1400

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Color = palette.fog
	atmosphere.Decay = palette.glow
	atmosphere.Haze = 1.4
	atmosphere.Glare = 0.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Saturation = 0.18
	grade.Contrast = 0.08
	grade.Parent = Lighting
end

local function floor(hub: Instance, palette)
	local tile = 16
	local rings = math.floor(Config.HubRadius / tile)
	for x = -rings, rings do
		for z = -rings, rings do
			local center = Vector3.new(x * tile, -1, z * tile)
			if center.Magnitude <= Config.HubRadius then
				Build.part({
					Name = "Tile",
					Size = Vector3.new(tile, 2, tile),
					Position = center,
					Color = if (x + z) % 2 == 0 then palette.a else palette.b,
				}, hub)
			end
		end
	end
	for i = 1, 8 do
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = polar(i / 8 * TAU, 34, 0.5)
		spawn.Parent = hub
	end
end

local function bigTop(hub: Instance, palette, rng: Random)
	local poles, radius, height = 12, 62, 46
	local tops = {}
	for i = 1, poles do
		local base = polar(i / poles * TAU, radius, height / 2)
		Build.cylinder(base, 1.2, height, { Name = "Pole", Color = palette.accent, Material = Enum.Material.Metal }, hub)
		local top = polar(i / poles * TAU, radius, height + 1.5)
		local bulb = Build.ball(top, 4, { Name = "Bulb", Color = palette.glow, Material = NEON, Tags = { "GlitchFlicker" } }, hub)
		Build.light(bulb, palette.glow, 40, 1.4)
		table.insert(tops, top)
	end

	-- String lights sagging between neighbouring poles.
	for i = 1, poles do
		local from, to = tops[i], tops[i % poles + 1]
		for step = 1, 5 do
			local t = step / 6
			local sag = math.sin(t * math.pi) * 6
			Build.ball(from:Lerp(to, t) - Vector3.new(0, sag, 0), 1.2, {
				Name = "Fairy", CanCollide = false, Material = NEON,
				Color = if step % 2 == 0 then palette.accent else palette.glow,
			}, hub)
		end
	end

	-- Canopy: stacked discs shrinking toward the mast, alternating stripes.
	local layers = 11
	for layer = 0, layers - 1 do
		local t = layer / (layers - 1)
		Build.cylinder(Vector3.new(0, height + 2 + layer * 3.4, 0), 68 - t * 62, 3.4, {
			Name = "Canopy", CanCollide = false,
			Color = if layer % 2 == 0 then palette.a else palette.b,
			Material = Enum.Material.Fabric,
		}, hub)
	end
	Build.ball(Vector3.new(0, height + 2 + layers * 3.4 + 2, 0), 7, {
		Name = "Finial", Color = palette.accent, Material = NEON, Tags = { "GlitchFlicker" },
	}, hub)

	-- Centre ring
	Build.cylinder(Vector3.new(0, 0.3, 0), 22, 0.6, { Name = "RingGlow", Color = palette.glow, Material = NEON }, hub)
	Build.cylinder(Vector3.new(0, 0.6, 0), 20, 1.2, { Name = "Ring", Color = Color3.fromRGB(28, 22, 44) }, hub)

	-- BARKER.EXE: a floating top hat with a monitor for a face.
	local y = 24
	local face = Build.part({
		Name = "BarkerFace", CanCollide = false,
		Size = Vector3.new(11, 7, 1.2),
		Position = Vector3.new(0, y, 0),
		Color = Color3.fromRGB(10, 10, 16),
		Material = Enum.Material.Glass,
	}, hub)
	for _, side in { -1, 1 } do
		for _, sign in { -1, 1 } do
			Build.part({
				Name = "Eye", CanCollide = false,
				Size = Vector3.new(1.6, 2.6, 0.3),
				Position = Vector3.new(side * 2.6, y + 0.9, sign * 0.7),
				Color = palette.glow, Material = NEON,
				Tags = { "GlitchFlicker" },
			}, hub)
			for step = -2, 2 do
				Build.part({
					Name = "Grin", CanCollide = false,
					Size = Vector3.new(1.1, 0.5, 0.3),
					Position = Vector3.new(step * 1.3, y - 2 + math.abs(step) * 0.45, sign * 0.7),
					Color = palette.accent, Material = NEON,
				}, hub)
			end
		end
	end
	Build.cylinder(Vector3.new(0, y + 4.4, 0), 8, 0.9, { Name = "HatBrim", CanCollide = false, Color = Color3.fromRGB(18, 14, 30) }, hub)
	Build.cylinder(Vector3.new(0, y + 9, 0), 5, 8.4, { Name = "HatBody", CanCollide = false, Color = Color3.fromRGB(18, 14, 30) }, hub)
	Build.cylinder(Vector3.new(0, y + 6, 0), 5.2, 1.4, { Name = "HatBand", CanCollide = false, Color = palette.a, Material = NEON }, hub)
	Build.light(face, palette.glow, 60, 2)
	Build.billboard(face, "BARKER.EXE", { offset = Vector3.new(0, 17, 0), size = UDim2.fromScale(20, 3.4), color = palette.accent, maxDistance = 400 })
	Build.billboard(face, `BUILD #{workspace:GetAttribute("BuildNumber")}  //  {string.upper(palette.name)}`, {
		name = "Build", offset = Vector3.new(0, -7, 0), size = UDim2.fromScale(22, 2), color = palette.glow, maxDistance = 400,
	})
	local _ = rng
end

local function booth(hub: Instance, palette, info, angle: number)
	local position = polar(angle, 104, 0)
	local frame = CFrame.lookAt(position, Vector3.new(0, 0, 0))
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end

	Build.part({ Name = "Base", Size = Vector3.new(20, 1, 14), CFrame = at(0, 0.5, 0), Color = palette.accent }, hub)
	for _, x in { -9, 9 } do
		for _, z in { -6, 6 } do
			Build.part({ Name = "Post", Size = Vector3.new(1, 12, 1), CFrame = at(x, 7, z), Color = palette.b }, hub)
		end
	end
	for stripe = 0, 4 do
		Build.part({
			Name = "Awning", CanCollide = false,
			Size = Vector3.new(4, 1, 16),
			CFrame = at(-8 + stripe * 4, 13.5, 0),
			Color = if stripe % 2 == 0 then palette.a else palette.b,
			Material = Enum.Material.Fabric,
		}, hub)
	end
	local counter = Build.part({ Name = "Counter", Size = Vector3.new(16, 4, 2), CFrame = at(0, 3, -4), Color = palette.a }, hub)
	local sign = Build.part({
		Name = "Sign", CanCollide = false,
		Size = Vector3.new(18, 3.4, 0.6), CFrame = at(0, 16.2, -7),
		Color = Color3.fromRGB(16, 12, 28),
	}, hub)
	Build.billboard(sign, info.label, { offset = Vector3.new(0, 0, 0), size = UDim2.fromScale(18, 3.2), color = palette.glow })
	Build.light(sign, palette.glow, 30, 1.6)

	-- A little prop so each booth reads at a glance.
	local prop = Build.ball((at(0, 8, 2)).Position, 6, {
		Name = "Prop", CanCollide = false, Material = Enum.Material.Glass,
		Transparency = 0.45, Color = palette.glow, Tags = { "GlitchBob" },
	}, hub)
	Build.ball(prop.Position, 2.4, { Name = "Core", CanCollide = false, Material = NEON, Color = palette.accent, Tags = { "GlitchSpin" } }, hub)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = info.action
	prompt.ObjectText = info.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Booth", info.id)
	prompt.Parent = counter
end

local function leaderboard(hub: Instance, palette)
	local position = polar(math.rad(-90) + TAU / 24, 84, 12)
	local board = Build.part({
		Name = "Leaderboard",
		Size = Vector3.new(26, 20, 1),
		CFrame = CFrame.lookAt(position, Vector3.new(0, 12, 0)),
		Color = Color3.fromRGB(14, 10, 26),
	}, hub)
	Build.light(board, palette.accent, 30, 1)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(520, 400)
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextSize = 30
	label.TextColor3 = palette.accent
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.RichText = true
	label.Text = "TOP BILLING\n\nloading…"
	label.Parent = gui
	gui.Parent = board
	WorldGen.leaderboardLabel = label
end

local function ferrisWheel(hub: Instance, palette, rng: Random)
	local angle = rng:NextNumber(0, TAU)
	local centre = polar(angle, 150, 44)
	local frame = CFrame.lookAt(centre, Vector3.new(0, 44, 0))
	Build.cylinder(centre, 3, 4, { Name = "Hub", CanCollide = false, Color = palette.accent, Material = NEON,
		CFrame = frame * CFrame.Angles(0, math.rad(90), 0) }, hub)
	local cabins = 14
	for i = 1, cabins do
		local a = i / cabins * TAU
		local offset = Vector3.new(math.cos(a) * 34, math.sin(a) * 34, 0)
		Build.part({
			Name = "Spoke", CanCollide = false,
			Size = Vector3.new(0.6, 34, 0.6),
			CFrame = frame * CFrame.new(offset / 2) * CFrame.Angles(0, 0, a - math.pi / 2),
			Color = palette.b,
		}, hub)
		Build.part({
			Name = "Cabin", CanCollide = false,
			Size = Vector3.new(5, 5, 5),
			CFrame = frame * CFrame.new(offset),
			Color = if i % 2 == 0 then palette.a else palette.glow,
			Material = NEON,
			Tags = { "GlitchFlicker" },
		}, hub)
	end
	for _, side in { -1, 1 } do
		Build.part({
			Name = "Leg",
			Size = Vector3.new(2, 50, 2),
			CFrame = frame * CFrame.new(side * 12, -22, 0) * CFrame.Angles(0, 0, side * math.rad(-28)),
			Color = palette.accent,
			Material = Enum.Material.Metal,
		}, hub)
	end
end

local function debris(hub: Instance, palette, rng: Random)
	local colors = { palette.a, palette.b, palette.accent, palette.glow }
	for _ = 1, 46 do
		local size = rng:NextNumber(2, 9)
		Build.part({
			Name = "Glitch", CanCollide = false,
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(polar(rng:NextNumber(0, TAU), rng:NextNumber(80, 260), rng:NextNumber(30, 150)))
				* CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0),
			Color = Rng.pick(rng, colors),
			Material = if rng:NextNumber() < 0.5 then NEON else Enum.Material.SmoothPlastic,
			Transparency = rng:NextNumber(0, 0.4),
			Tags = { "GlitchSpin" },
		}, hub)
	end
	-- Balloon bunches around the rim
	for i = 1, 10 do
		local base = polar(i / 10 * TAU + 0.3, Config.HubRadius - 12, 0)
		for _ = 1, 5 do
			Build.ball(base + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(10, 22), rng:NextNumber(-4, 4)), rng:NextNumber(3, 5), {
				Name = "Balloon", CanCollide = false, Material = NEON,
				Color = Rng.pick(rng, colors), Tags = { "GlitchBob" },
			}, hub)
		end
	end
end

function WorldGen.build()
	local seed = Rng.daySeed()
	local rng = Random.new(seed)
	local palette = Rng.pick(rng, Config.Palettes)
	workspace:SetAttribute("BuildNumber", seed)
	workspace:SetAttribute("PaletteName", palette.name)

	local hub = Instance.new("Folder")
	hub.Name = "Midway"

	lighting(palette)
	floor(hub, palette)
	bigTop(hub, palette, rng)
	local offset = rng:NextNumber(0, TAU)
	local order = Rng.shuffle(rng, table.clone(Config.Booths))
	for index, info in order do
		booth(hub, palette, info, offset + index / #order * TAU)
	end
	leaderboard(hub, palette)
	ferrisWheel(hub, palette, rng)
	debris(hub, palette, rng)

	hub.Parent = workspace
end

return WorldGen
