--!nonstrict
-- Tiny declarative UI kit. The whole interface is built from code with these
-- helpers; there are no pre-made ScreenGuis in the place file.

local TweenService = game:GetService("TweenService")

local Ui = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Ui.Theme = {
	bg = rgb(16, 11, 30),
	panel = rgb(28, 20, 52),
	row = rgb(40, 30, 72),
	stroke = rgb(124, 92, 255),
	text = rgb(242, 238, 255),
	dim = rgb(168, 158, 200),
	gold = rgb(255, 214, 70),
	good = rgb(90, 255, 170),
	bad = rgb(255, 92, 112),
	pink = rgb(255, 80, 200),
	cyan = rgb(60, 235, 255),
	disabled = rgb(74, 66, 104),
}

Ui.HeadFont = Enum.Font.Arcade
Ui.BodyFont = Enum.Font.GothamBold

function Ui.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(class)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.stroke(color: Color3?, thickness: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color or Ui.Theme.stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.label(props: { [string]: any }): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = Ui.BodyFont,
		TextColor3 = Ui.Theme.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.new("TextLabel", merged)
end

function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local color = props.BackgroundColor3 or Ui.Theme.stroke
	local merged = {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = Ui.HeadFont,
		TextColor3 = Ui.Theme.bg,
		TextSize = 18,
	}
	for key, value in props do
		merged[key] = value
	end
	local button: TextButton = Ui.new("TextButton", merged, { Ui.corner(8) })
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
	end)
	button.Activated:Connect(onClick)
	return button
end

-- Keeps fixed-pixel widgets readable from phones to ultrawides.
function Ui.autoScale(frame: GuiObject)
	local scale: UIScale = Ui.new("UIScale", { Parent = frame })
	local camera = workspace.CurrentCamera
	local function update()
		local view = camera.ViewportSize
		scale.Scale = math.clamp(math.min(view.X / 1280, view.Y / 720), 0.55, 1.3)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

function Ui.abbrev(value: number): string
	local n = math.floor(value)
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local text = tostring(n)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function Ui.clock(seconds: number): string
	local s = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", s // 60, s % 60)
end

function Ui.percent(fraction: number): string
	local pct = fraction * 100
	return if pct >= 10 then string.format("%.0f%%", pct) elseif pct >= 1 then string.format("%.1f%%", pct) else string.format("%.2f%%", pct)
end

return Ui
