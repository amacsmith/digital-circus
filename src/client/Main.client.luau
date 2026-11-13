--!nonstrict
-- GLITCHTOP client: HUD, panels, BARKER.EXE subtitles and local-only FX.
-- All state arrives through attributes (numbers) and the Profile remote
-- (inventory); the client never decides anything about currency.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local Theme = Ui.Theme
local studio = RunService:IsStudio()

local profile = {
	owned = {}, equipped = {}, pity = 0, reviveTokens = 0, directorCuts = 0,
	streak = 0, lastDaily = 0, stats = {},
}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function attr(name: string, default: any): any
	local value = player:GetAttribute(name)
	return if value == nil then default else value
end

---------------------------------------------------------------------------
-- Root
---------------------------------------------------------------------------
local gui = Ui.new("ScreenGui", {
	Name = "Glitchtop",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local function pill(width: number, color: Color3)
	return Ui.new("Frame", {
		Size = UDim2.fromOffset(width, 38),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.1,
	}, { Ui.corner(19), Ui.stroke(color, 2) })
end

---------------------------------------------------------------------------
-- Static overlay (FOLLOW_SPOT) - sits under everything else
---------------------------------------------------------------------------
local staticOverlay = Ui.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.bad,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = false,
	Parent = gui,
})

---------------------------------------------------------------------------
-- Stats (top left)
---------------------------------------------------------------------------
local stats = Ui.new("Frame", {
	Position = UDim2.fromOffset(16, 66),
	Size = UDim2.fromOffset(230, 130),
	BackgroundTransparency = 1,
	Parent = gui,
}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
Ui.autoScale(stats)

local ticketPill = pill(230, Theme.gold)
ticketPill.LayoutOrder = 1
ticketPill.Parent = stats
local ticketLabel = Ui.label({
	Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(14, 0),
	TextSize = 20, TextColor3 = Theme.gold, Text = "🎟 0", Parent = ticketPill,
})

local levelPill = pill(230, Theme.cyan)
levelPill.LayoutOrder = 2
levelPill.Parent = stats
local levelFill = Ui.new("Frame", {
	Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.cyan, BackgroundTransparency = 0.7,
	BorderSizePixel = 0, Parent = levelPill,
}, { Ui.corner(19) })
local levelLabel = Ui.label({
	Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(14, 0),
	TextSize = 16, TextColor3 = Theme.cyan, Text = "LV 1", Parent = levelPill,
})

local multPill = pill(230, Theme.pink)
multPill.LayoutOrder = 3
multPill.Parent = stats
local multLabel = Ui.label({
	Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(14, 0),
	TextSize = 15, TextColor3 = Theme.pink, Text = "x1.00 tickets", Parent = multPill,
})

---------------------------------------------------------------------------
-- Show banner (top centre)
---------------------------------------------------------------------------
local banner = Ui.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.fromOffset(460, 84),
	BackgroundColor3 = Theme.bg,
	BackgroundTransparency = 0.15,
	Parent = gui,
}, { Ui.corner(14), Ui.stroke(Theme.stroke, 2) })
Ui.autoScale(banner)

local phaseLabel = Ui.label({
	Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 6),
	Font = Ui.HeadFont, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center,
	Text = "BOOTING CIRCUS…", Parent = banner,
})
local subLabel = Ui.label({
	Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 40),
	TextSize = 13, TextColor3 = Theme.dim, TextXAlignment = Enum.TextXAlignment.Center,
	Text = Config.Tagline, Parent = banner,
})
local hypeBack = Ui.new("Frame", {
	Size = UDim2.new(1, -28, 0, 8), Position = UDim2.new(0, 14, 1, -16),
	BackgroundColor3 = Theme.row, BorderSizePixel = 0, Parent = banner,
}, { Ui.corner(4) })
local hypeFill = Ui.new("Frame", {
	Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.gold, BorderSizePixel = 0, Parent = hypeBack,
}, { Ui.corner(4) })

---------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------
local toasts = Ui.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 160),
	Size = UDim2.fromOffset(520, 220),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	Ui.new("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})
Ui.autoScale(toasts)

local toastOrder = 0
local function toast(text: string, kind: any)
	local color = if typeof(kind) == "Color3" then kind else (Theme[kind or "text"] or Theme.text)
	toastOrder += 1
	local frame = Ui.new("Frame", {
		Size = UDim2.fromOffset(500, 36), BackgroundColor3 = Theme.bg, BackgroundTransparency = 0.1,
		LayoutOrder = toastOrder, Parent = toasts,
	}, { Ui.corner(10), Ui.stroke(color, 2) })
	local label = Ui.label({
		Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0),
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = color, TextSize = 15,
		Text = text, Parent = frame,
	})
	task.delay(4, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		task.wait(0.45)
		frame:Destroy()
	end)
end

---------------------------------------------------------------------------
-- BARKER.EXE subtitles (typewriter with a corrupted cursor)
---------------------------------------------------------------------------
local barker = Ui.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(680, 58),
	BackgroundColor3 = Theme.bg,
	BackgroundTransparency = 0.2,
	Visible = false,
	Parent = gui,
}, { Ui.corner(12), Ui.stroke(Theme.pink, 2) })
Ui.autoScale(barker)
Ui.label({
	Size = UDim2.fromOffset(120, 16), Position = UDim2.fromOffset(14, 5),
	Font = Ui.HeadFont, TextSize = 13, TextColor3 = Theme.pink, Text = "BARKER.EXE", Parent = barker,
})
local barkerText = Ui.label({
	Size = UDim2.new(1, -28, 0, 34), Position = UDim2.fromOffset(14, 20),
	TextSize = 15, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Text = "", Parent = barker,
})

local GLITCH = { "#", "%", "▓", "?", "_", "/", "▒" }
local barkerToken = 0
local function say(line: string)
	barkerToken += 1
	local token = barkerToken
	barker.Visible = true
	-- Step by UTF-8 characters so display names never get cut mid-codepoint.
	local length = utf8.len(line) or #line
	for index = 1, length, 2 do
		if token ~= barkerToken then
			return
		end
		local stop = (utf8.offset(line, index + 1) or (#line + 1)) - 1
		barkerText.Text = string.sub(line, 1, stop) .. GLITCH[math.random(#GLITCH)]
		task.wait(0.02)
	end
	barkerText.Text = line
	task.wait(6)
	if token == barkerToken then
		barker.Visible = false
	end
end

---------------------------------------------------------------------------
-- Panel (one reusable modal; every screen is a list of rows)
---------------------------------------------------------------------------
local panel = Ui.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(560, 470),
	BackgroundColor3 = Theme.panel,
	Visible = false,
	Parent = gui,
}, { Ui.corner(16), Ui.stroke(Theme.stroke, 3) })
Ui.autoScale(panel)

local panelTitle = Ui.label({
	Size = UDim2.new(1, -80, 0, 40), Position = UDim2.fromOffset(20, 10),
	Font = Ui.HeadFont, TextSize = 28, TextColor3 = Theme.gold, Text = "", Parent = panel,
})
local panelList = Ui.new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 1, -100),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Theme.stroke,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
local panelFooter = Ui.label({
	Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 1, -38),
	TextSize = 12, TextColor3 = Theme.dim, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
	Text = "", Parent = panel,
})

local builders: { [string]: () -> any } = {}
local currentPanel: string? = nil
local renderQueued = false

local function render()
	renderQueued = false
	local builder = currentPanel and builders[currentPanel]
	if not builder then
		panel.Visible = false
		return
	end
	local spec = builder()
	panelTitle.Text = spec.title
	panelFooter.Text = spec.footer or ""
	for _, child in panelList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, row in spec.rows do
		local frame = Ui.new("Frame", {
			Size = UDim2.new(1, -10, 0, if row.sub then 62 else 40),
			BackgroundColor3 = Theme.row,
			BackgroundTransparency = if row.header then 1 else 0,
			LayoutOrder = index,
			Parent = panelList,
		}, { Ui.corner(10) })
		local textWidth = if row.button then -160 else -24
		Ui.label({
			Size = UDim2.new(1, textWidth, 0, 24), Position = UDim2.fromOffset(12, if row.sub then 8 else 8),
			Font = if row.header then Ui.HeadFont else Ui.BodyFont,
			TextSize = if row.header then 18 else 16,
			TextColor3 = row.color or (if row.header then Theme.cyan else Theme.text),
			Text = row.title, Parent = frame,
		})
		if row.sub then
			Ui.label({
				Size = UDim2.new(1, textWidth, 0, 20), Position = UDim2.fromOffset(12, 34),
				TextSize = 12, TextColor3 = Theme.dim, Text = row.sub, Parent = frame,
			})
		end
		if row.button then
			local spec2 = row.button
			local disabled = spec2.disabled == true
			Ui.button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(134, 38),
				BackgroundColor3 = if disabled then Theme.disabled else (spec2.color or Theme.good),
				TextColor3 = if disabled then Theme.dim else Theme.bg,
				Text = spec2.text, Parent = frame,
			}, function()
				if not disabled and spec2.onClick then
					spec2.onClick()
				end
			end)
		end
	end
	panel.Visible = true
end

local function refresh()
	if currentPanel and not renderQueued then
		renderQueued = true
		task.defer(render)
	end
end

local function openPanel(name: string?)
	currentPanel = if currentPanel == name then nil else name
	panelList.CanvasPosition = Vector2.zero
	render()
end

Ui.button({
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(40, 36), BackgroundColor3 = Theme.bad, Text = "X", Parent = panel,
}, function()
	openPanel(nil)
end)

---------------------------------------------------------------------------
-- Purchases
---------------------------------------------------------------------------
local prices: { [number]: number } = {}

local function livePrice(entry: any, infoType: Enum.InfoType): number
	if entry.id ~= 0 and prices[entry.id] == nil then
		prices[entry.id] = entry.price
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, entry.id, infoType)
			if ok and info and info.PriceInRobux then
				prices[entry.id] = info.PriceInRobux
				refresh()
			end
		end)
	end
	return prices[entry.id] or entry.price
end

local function buy(kind: string, key: string)
	local entry = if kind == "pass" then Config.Passes[key] else Config.Products[key]
	if entry.id == 0 then
		if studio then
			Net.send("DevGrant", kind, key)
		else
			toast("That item isn't on sale yet. Check back soon!", "bad")
		end
	elseif kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, entry.id)
	else
		MarketplaceService:PromptProductPurchase(player, entry.id)
	end
end

local function sorted(dict: { [string]: any }): { { key: string, value: any } }
	local list = {}
	for key, value in dict do
		table.insert(list, { key = key, value = value })
	end
	table.sort(list, function(a, b)
		return a.value.order < b.value.order
	end)
	return list
end

---------------------------------------------------------------------------
-- Panel builders
---------------------------------------------------------------------------
builders.Shop = function()
	local rows = { { header = true, title = "GAME PASSES  ·  forever" } }
	for _, item in sorted(Config.Passes) do
		local pass = item.value
		local owned = attr("Pass_" .. item.key, false)
		table.insert(rows, {
			title = pass.name, sub = pass.desc, color = Theme.gold,
			button = {
				text = if owned then "OWNED" else `R$ {livePrice(pass, Enum.InfoType.GamePass)}`,
				disabled = owned, color = Theme.gold,
				onClick = function()
					buy("pass", item.key)
				end,
			},
		})
	end
	table.insert(rows, { header = true, title = "BOX OFFICE" })
	for _, item in sorted(Config.Products) do
		local product = item.value
		table.insert(rows, {
			title = product.name, sub = product.desc,
			button = {
				text = `R$ {livePrice(product, Enum.InfoType.Product)}`,
				onClick = function()
					buy("product", item.key)
				end,
			},
		})
	end
	local boost = (workspace:GetAttribute("BoostEndsAt") or 0) - serverNow()
	return {
		title = "BOX OFFICE",
		rows = rows,
		footer = (if boost > 0 then `Standing Ovation active: {Ui.clock(boost)} left.  ` else "")
			.. `Second Takes: {profile.reviveTokens}  ·  Director's Cuts: {profile.directorCuts}`,
	}
end

builders.Capsule = function()
	local rows = {}
	local restricted = attr("CapsuleRestricted", true) ~= false
	if restricted then
		table.insert(rows, {
			title = "Capsules are unavailable in your region",
			sub = "Every item can be bought directly in the Wardrobe instead.",
			button = { text = "WARDROBE", color = Theme.cyan, onClick = function()
				currentPanel = "Wardrobe"
				render()
			end },
		})
	else
		table.insert(rows, {
			title = "PULL A CAPSULE", color = Theme.gold,
			sub = `{Config.Capsule.Cost} tickets  ·  duplicates refund tickets`,
			button = {
				text = "PULL", color = Theme.gold,
				disabled = attr("Tickets", 0) < Config.Capsule.Cost,
				onClick = function()
					Net.send("PullCapsule")
				end,
			},
		})
		table.insert(rows, {
			title = `Pity: {profile.pity} / {Config.Capsule.Pity}`,
			sub = `Pull {Config.Capsule.Pity} is always {Config.Capsule.PityFloor} or better.`,
		})
	end
	local lucky = attr("Pass_Lucky", false)
	local odds = Config.capsuleOdds(lucky)
	table.insert(rows, { header = true, title = if lucky then "EXACT ODDS  ·  Lucky Claw active" else "EXACT ODDS" })
	for _, rarity in Config.RarityOrder do
		local info = Config.Rarities[rarity]
		table.insert(rows, {
			title = `{string.upper(rarity)}  ·  {Ui.percent(odds[rarity])}`,
			sub = `Duplicate refund {info.refund}  ·  direct price {Ui.abbrev(info.price)} tickets`,
			color = info.color,
		})
	end
	return {
		title = "PRIZE CLAW",
		rows = rows,
		footer = "Capsules cost tickets and contain cosmetics only. The odds shown are the exact table the server rolls.",
	}
end

builders.Wardrobe = function()
	local rows = {}
	for _, item in Config.Cosmetics do
		local info = Config.Rarities[item.rarity]
		local owned = profile.owned[item.id] == true
		local equipped = profile.equipped[item.kind] == item.id
		local button
		if owned then
			button = {
				text = if equipped then "UNEQUIP" else "EQUIP",
				color = if equipped then Theme.pink else Theme.good,
				onClick = function()
					Net.send("Equip", item.kind, if equipped then false else item.id)
				end,
			}
		else
			button = {
				text = `🎟 {Ui.abbrev(info.price)}`, color = Theme.gold,
				disabled = attr("Tickets", 0) < info.price,
				onClick = function()
					Net.send("BuyCosmetic", item.id)
				end,
			}
		end
		table.insert(rows, {
			title = item.name, color = info.color,
			sub = `{item.rarity} {item.kind}{if owned then "  ·  owned" else ""}`,
			button = button,
		})
	end
	return { title = "WARDROBE", rows = rows, footer = "Find these in Prize Claw capsules, or buy any of them outright with tickets." }
end

builders.Daily = function()
	local rows = {}
	local today = math.floor(serverNow() / 86400)
	local ready = attr("DailyReady", false)
	local count = #Config.Daily
	local slot
	if ready then
		slot = if profile.lastDaily == today - 1 then profile.streak % count + 1 else 1
	else
		slot = (math.max(profile.streak, 1) - 1) % count + 1
	end
	for day, amount in Config.Daily do
		local isSlot = day == slot
		local claimed = day < slot or (isSlot and not ready)
		table.insert(rows, {
			title = `DAY {day}  ·  {Ui.abbrev(amount)} tickets{if day == count then "  +  Second Take" else ""}`,
			sub = if claimed then "Collected" elseif isSlot then "Today's call" else "Keep the streak alive",
			color = if claimed then Theme.dim elseif isSlot then Theme.gold else Theme.text,
			button = if isSlot and ready then {
				text = "CLAIM", color = Theme.gold,
				onClick = function()
					Net.send("ClaimDaily")
				end,
			} else nil,
		})
	end
	return { title = "DAILY CALL SHEET", rows = rows, footer = `Current streak: {profile.streak} day(s). Miss a day and the ladder restarts.` }
end

builders.Encore = function()
	local encores = attr("Encores", 0)
	local cost = Config.Encore.cost(encores)
	local tickets = attr("Tickets", 0)
	local bonus = Config.Encore.BonusPerEncore * 100
	return {
		title = "ENCORE STAGE",
		rows = {
			{ title = `Encores taken: {encores}`, sub = `Permanent bonus so far: +{encores * bonus}% tickets` },
			{
				title = `TAKE ENCORE #{encores + 1}`, color = Theme.gold,
				sub = `Costs {Ui.abbrev(cost)} tickets  ·  resets tickets to 0  ·  +{bonus}% forever`,
				button = {
					text = "ENCORE", color = Theme.gold, disabled = tickets < cost,
					onClick = function()
						Net.send("Encore")
					end,
				},
			},
			{ title = "You keep:", sub = "Level, cosmetics, passes, streak, Second Takes and Director's Cuts." },
		},
		footer = `You have {Ui.abbrev(tickets)} of {Ui.abbrev(cost)} tickets.`,
	}
end

builders.Director = function()
	local rows = {}
	local has = profile.directorCuts > 0
	for _, item in sorted(Config.Acts) do
		table.insert(rows, {
			title = item.value.name, sub = item.value.tagline, color = Theme.cyan,
			button = {
				text = if has then "QUEUE" else "GET A CUT", color = if has then Theme.good else Theme.gold,
				onClick = function()
					if has then
						Net.send("QueueAct", item.key)
					else
						buy("product", "DirectorsCut")
					end
				end,
			},
		})
	end
	return { title = "DIRECTOR'S CHAIR", rows = rows, footer = `Director's Cuts: {profile.directorCuts}. The whole server plays what you pick.` }
end

---------------------------------------------------------------------------
-- Menu (right edge)
---------------------------------------------------------------------------
local menu = Ui.new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.55, 0),
	Size = UDim2.fromOffset(150, 330),
	BackgroundTransparency = 1,
	Parent = gui,
}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
Ui.autoScale(menu)

local function menuButton(order: number, text: string, color: Color3, onClick: () -> ()): TextButton
	return Ui.button({
		Size = UDim2.fromOffset(150, 40), BackgroundColor3 = color, Text = text,
		LayoutOrder = order, Parent = menu,
	}, onClick)
end

menuButton(1, "SHOP", Theme.gold, function()
	openPanel("Shop")
end)
menuButton(2, "CAPSULES", Theme.pink, function()
	openPanel("Capsule")
end)
menuButton(3, "WARDROBE", Theme.cyan, function()
	openPanel("Wardrobe")
end)
menuButton(4, "ENCORE", Theme.stroke, function()
	openPanel("Encore")
end)
local dailyButton = menuButton(5, "DAILY", Theme.good, function()
	openPanel("Daily")
end)
local giftButton = menuButton(6, "GIFT", Theme.good, function()
	Net.send("ClaimGift")
end)
local afkButton = menuButton(7, "SIT OUT: OFF", Theme.dim, function()
	Net.send("SetAFK", not attr("AFK", false))
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local booth = prompt:GetAttribute("Booth")
	if booth and builders[booth] then
		currentPanel = booth
		panelList.CanvasPosition = Vector2.zero
		render()
	end
end)

---------------------------------------------------------------------------
-- Second Take offer
---------------------------------------------------------------------------
local revive = Ui.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -190),
	Size = UDim2.fromOffset(420, 96),
	BackgroundColor3 = Theme.panel,
	Visible = false,
	Parent = gui,
}, { Ui.corner(14), Ui.stroke(Theme.gold, 3) })
Ui.autoScale(revive)
local reviveLabel = Ui.label({
	Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 6),
	TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
	TextSize = 15, Text = "", Parent = revive,
})
local reviveToken = 0
local reviveButton = Ui.button({
	Position = UDim2.fromOffset(20, 50), Size = UDim2.fromOffset(250, 36),
	BackgroundColor3 = Theme.gold, Text = "SECOND TAKE", Parent = revive,
}, function()
	if profile.reviveTokens > 0 then
		Net.send("UseRevive")
	else
		buy("product", "SecondTake")
	end
	revive.Visible = false
end)
Ui.button({
	Position = UDim2.fromOffset(280, 50), Size = UDim2.fromOffset(120, 36),
	BackgroundColor3 = Theme.dim, Text = "NAH", Parent = revive,
}, function()
	revive.Visible = false
end)

---------------------------------------------------------------------------
-- HUD refresh
---------------------------------------------------------------------------
local function refreshStats()
	ticketLabel.Text = "🎟 " .. Ui.abbrev(attr("Tickets", 0))
	local applause = attr("Applause", 0)
	local level = Config.levelFor(applause)
	local floor, ceiling = Config.applauseForLevel(level), Config.applauseForLevel(level + 1)
	levelFill.Size = UDim2.fromScale(math.clamp((applause - floor) / (ceiling - floor), 0, 1), 1)
	local encores = attr("Encores", 0)
	levelLabel.Text = `LV {level}  ·  👏 {Ui.abbrev(applause)}` .. (if encores > 0 then `  ·  E{encores}` else "")
	dailyButton.Text = if attr("DailyReady", false) then "DAILY  !" else "DAILY"
	afkButton.Text = if attr("AFK", false) then "SIT OUT: ON" else "SIT OUT: OFF"
	refresh()
end

for _, name in { "Tickets", "Applause", "Encores", "DailyReady", "AFK", "CapsuleRestricted", "Pass_VIP", "Pass_Speed", "Pass_Lucky" } do
	player:GetAttributeChangedSignal(name):Connect(refreshStats)
end
refreshStats()

local function updateHud()
	local now = serverNow()
	local phase = workspace:GetAttribute("Phase") or "Booting"
	local left = (workspace:GetAttribute("PhaseEndsAt") or 0) - now
	local actName = workspace:GetAttribute("ActName") or "?"
	local mutator = workspace:GetAttribute("MutatorName") or ""
	local inAct = attr("InAct", false)

	if phase == "Intermission" then
		phaseLabel.Text = `NEXT ACT IN {Ui.clock(left)}`
		subLabel.Text = `Build #{workspace:GetAttribute("BuildNumber") or "?"}  ·  palette: {workspace:GetAttribute("PaletteName") or "?"}`
	elseif phase == "Loading" then
		phaseLabel.Text = `COMPILING {actName}`
		subLabel.Text = `{mutator}  ·  {workspace:GetAttribute("ActTagline") or ""}`
	elseif phase == "Countdown" then
		phaseLabel.Text = `GET READY… {math.max(math.ceil(left), 1)}`
		subLabel.Text = workspace:GetAttribute("ActTagline") or ""
	elseif phase == "Act" then
		phaseLabel.Text = `{actName}  {Ui.clock(left)}`
		subLabel.Text = if inAct then `{mutator}  ·  score {attr("ActScore", 0)}` else `{mutator}  ·  you're in the audience`
	elseif phase == "Results" then
		phaseLabel.Text = "CURTAIN CALL"
		subLabel.Text = "Tickets are being counted…"
	elseif phase == "Waiting" then
		phaseLabel.Text = "WAITING FOR PERFORMERS"
		subLabel.Text = "Turn off SIT OUT to join the next act."
	end
	if phase ~= "Act" then
		revive.Visible = false
	end

	hypeFill.Size = UDim2.fromScale(math.clamp((workspace:GetAttribute("Hype") or 0) / 100, 0, 1), 1)

	local boost = (workspace:GetAttribute("BoostEndsAt") or 0) - now
	local friends = attr("Friends", 0)
	multLabel.Text = string.format("x%.2f tickets", attr("Multiplier", 1))
		.. (if boost > 0 then `  ·  OVATION {Ui.clock(boost)}` elseif friends > 0 then `  ·  {friends} friend(s)` else "")

	local giftLeft = attr("GiftReadyAt", now + 999) - now
	giftButton.Text = if giftLeft <= 0 then "CLAIM GIFT!" else `GIFT {Ui.clock(giftLeft)}`

	staticOverlay.BackgroundTransparency = 1 - math.clamp(attr("Static", 0), 0, 1) * 0.55
end

task.spawn(function()
	while true do
		updateHud()
		task.wait(0.2)
	end
end)

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
Net.onClient("Profile", function(snapshot)
	profile = snapshot
	refresh()
end)

Net.onClient("Toast", toast)

Net.onClient("Barker", function(line)
	task.spawn(say, line)
end)

Net.onClient("ActResult", function(result)
	toast(
		`{result.act}: #{result.rank} of {result.total}  ·  +{Ui.abbrev(result.tickets)} tickets`,
		if result.won then "gold" else "good"
	)
end)

Net.onClient("CapsuleResult", function(result)
	local item = Config.CosmeticById[result.id]
	if not item then
		return
	end
	local color = Config.Rarities[item.rarity].color
	if result.duplicate then
		toast(`{string.upper(item.rarity)} duplicate: {item.name}  ·  refunded {result.refund} tickets`, color)
	else
		toast(`✦ {string.upper(item.rarity)} ✦  {item.name}  ·  equip it in the Wardrobe`, color)
	end
end)

Net.onClient("OfferRevive", function(secondsLeft)
	reviveToken += 1
	local token = reviveToken
	local product = Config.Products.SecondTake
	reviveLabel.Text = `You've been unrendered with {secondsLeft}s left. Get re-rendered into the act?`
	reviveButton.Text = if profile.reviveTokens > 0
		then `USE SECOND TAKE ({profile.reviveTokens})`
		else `SECOND TAKE  R$ {livePrice(product, Enum.InfoType.Product)}`
	revive.Visible = true
	task.delay(9, function()
		if token == reviveToken then
			revive.Visible = false
		end
	end)
end)

Net.onClient("Fling", function(velocity)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and typeof(velocity) == "Vector3" then
		(root :: BasePart).AssemblyLinearVelocity = velocity
	end
end)

---------------------------------------------------------------------------
-- Local-only world FX (driven by tags set in WorldGen and the acts)
---------------------------------------------------------------------------
local spinning: { [BasePart]: { base: CFrame, axis: Vector3, speed: number } } = {}
local bobbing: { [BasePart]: { base: CFrame, phase: number } } = {}
local flickering: { BasePart } = {}

local function track(tag: string, add: (BasePart) -> (), remove: (BasePart) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

track("GlitchSpin", function(part)
	spinning[part] = {
		base = part.CFrame,
		axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit,
		speed = 0.2 + math.random() * 0.7,
	}
end, function(part)
	spinning[part] = nil
end)

track("GlitchBob", function(part)
	bobbing[part] = { base = part.CFrame, phase = math.random() * 6.28 }
end, function(part)
	bobbing[part] = nil
end)

track("GlitchFlicker", function(part)
	table.insert(flickering, part)
end, function(part)
	local index = table.find(flickering, part)
	if index then
		table.remove(flickering, index)
	end
end)

local actFx = Ui.new("ColorCorrectionEffect", { Name = "ActFX", Parent = Lighting })

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for part, info in spinning do
		part.CFrame = info.base * CFrame.fromAxisAngle(info.axis, t * info.speed)
	end
	for part, info in bobbing do
		part.CFrame = info.base + Vector3.new(0, math.sin(t * 1.4 + info.phase) * 0.6, 0)
	end
	local dark = attr("InAct", false) and workspace:GetAttribute("Phase") == "Act" and workspace:GetAttribute("Mutator") == "Blackout"
	local target = if dark then -0.42 else 0
	actFx.Brightness += (target - actFx.Brightness) * math.min(dt * 4, 1)
end)

task.spawn(function()
	while true do
		task.wait(0.12)
		if #flickering > 0 then
			local part = flickering[math.random(#flickering)]
			part.Transparency = 0.7
			task.delay(0.08, function()
				if part.Parent then
					part.Transparency = 0
				end
			end)
		end
	end
end)

task.delay(2, function()
	say(`Welcome to {Config.GameName}. {Config.Tagline}`)
end)
