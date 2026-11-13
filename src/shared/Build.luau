--!nonstrict
-- Part factory. Every piece of geometry in the game is created through here
-- at runtime; the place file ships with an empty Workspace.

local Build = {}

function Build.part(props: { [string]: any }, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key == "Tags" then
			for _, tag in value do
				part:AddTag(tag)
			end
		else
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Upright cylinder (Roblox cylinders lie along X, so rotate them).
function Build.cylinder(position: Vector3, radius: number, height: number, props: { [string]: any }, parent: Instance?): Part
	local merged = table.clone(props)
	merged.Shape = Enum.PartType.Cylinder
	merged.Size = Vector3.new(height, radius * 2, radius * 2)
	merged.CFrame = props.CFrame or CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return Build.part(merged, parent)
end

function Build.ball(position: Vector3, diameter: number, props: { [string]: any }, parent: Instance?): Part
	local merged = table.clone(props)
	merged.Shape = Enum.PartType.Ball
	merged.Size = Vector3.new(diameter, diameter, diameter)
	merged.Position = position
	return Build.part(merged, parent)
end

function Build.billboard(parent: Instance, text: string, opts: { [string]: any }?): TextLabel
	local o = opts or {}
	local gui = Instance.new("BillboardGui")
	gui.Name = o.name or "Label"
	gui.Size = o.size or UDim2.fromScale(14, 3)
	gui.StudsOffset = o.offset or Vector3.new(0, 4, 0)
	gui.MaxDistance = o.maxDistance or 220
	gui.AlwaysOnTop = o.alwaysOnTop or false
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = o.font or Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = o.color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(12, 6, 24)
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

function Build.light(parent: Instance, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Parent = parent
	return light
end

return Build
