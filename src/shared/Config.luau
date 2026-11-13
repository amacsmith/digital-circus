--!nonstrict
-- GLITCHTOP // single source of truth for every tunable in the game.
-- Everything here is data: add an act, a cosmetic, a product or a mutator by
-- adding a row. No other file needs to change for balance or catalogue edits.

local Config = {}

Config.GameName = "GLITCHTOP"
Config.Tagline = "The circus is still rendering. You're the act."
Config.DataStoreName = "Glitchtop_v1"

---------------------------------------------------------------------------
-- Remotes (created by the server at boot, see Net.luau)
---------------------------------------------------------------------------
Config.Remotes = {
	-- server -> client
	"Profile", "Toast", "Barker", "ActResult", "OfferRevive", "CapsuleResult", "Fling",
	-- client -> server
	"PullCapsule", "BuyCosmetic", "Equip", "ClaimDaily", "ClaimGift", "SetAFK",
	"Encore", "QueueAct", "UseRevive", "DevGrant",
}

---------------------------------------------------------------------------
-- Monetization. Paste the ids from the Creator Dashboard. id = 0 means
-- "not configured": the button is disabled live, and grants for free in Studio
-- so the whole loop can be tested before anything is published.
---------------------------------------------------------------------------
Config.Passes = {
	VIP = { id = 0, order = 1, name = "VIP Box Seat", price = 399,
		desc = "2x tickets forever + gold [VIP] nameplate." },
	Speed = { id = 0, order = 2, name = "Stagehand Sneakers", price = 149,
		desc = "Move faster on the Midway. (Acts stay fair.)" },
	Lucky = { id = 0, order = 3, name = "Lucky Claw", price = 249,
		desc = "Doubles Epic, Legendary and Glitched capsule odds." },
}

Config.Products = {
	Tickets1 = { id = 0, order = 1, kind = "tickets", amount = 1500, price = 49,
		name = "Pocketful of Tickets", desc = "+1,500 tickets" },
	Tickets2 = { id = 0, order = 2, kind = "tickets", amount = 6000, price = 149,
		name = "Roll of Tickets", desc = "+6,000 tickets (25% bonus)" },
	Tickets3 = { id = 0, order = 3, kind = "tickets", amount = 20000, price = 399,
		name = "Ticket Cannon", desc = "+20,000 tickets (60% bonus)" },
	Tickets4 = { id = 0, order = 4, kind = "tickets", amount = 60000, price = 999,
		name = "The Whole Box Office", desc = "+60,000 tickets (100% bonus)" },
	Ovation = { id = 0, order = 5, kind = "boost", seconds = 900, price = 99,
		name = "Standing Ovation", desc = "2x tickets for EVERYONE in the server for 15 min. Stacks." },
	SecondTake = { id = 0, order = 6, kind = "revive", amount = 1, price = 25,
		name = "Second Take", desc = "Get re-rendered into an act after you're out. Never expires." },
	DirectorsCut = { id = 0, order = 7, kind = "director", amount = 1, price = 59,
		name = "Director's Cut", desc = "You choose the next act for the whole server." },
}

Config.PremiumBonus = 0.10 -- Roblox Premium members
Config.FriendBonus = 0.05 -- per friend in the same server
Config.FriendBonusCap = 5

---------------------------------------------------------------------------
-- Round flow
---------------------------------------------------------------------------
Config.Round = {
	Intermission = 22,
	Loading = 5,
	Countdown = 3,
	Results = 6,
	BasePay = 25,
	SurvivePerSecond = 2,
	SurvivorBonus = 60,
	WinnerMultiplier = 1.5,
	RaceFirst = 150,
	RaceStep = 25,
	RaceMin = 50,
	CheckpointScore = 15,
	ReviveMinTimeLeft = 10,
	KillDepth = 45,
}

Config.ArenaOrigin = Vector3.new(4000, 300, 0)
Config.HubRadius = 176

-- mode: race (reach the end) | survive (don't get unrendered) | collect (score)
Config.Acts = {
	Tightrope = { order = 1, name = "TIGHTROPE.DLL", mode = "race", duration = 90,
		tagline = "A fresh obstacle course, compiled just now, never seen again." },
	FloorDelete = { order = 2, name = "FLOOR_NOT_FOUND", mode = "survive", duration = 70,
		tagline = "The stage is being garbage-collected. Stand somewhere else." },
	BalloonHeist = { order = 3, name = "BALLOON.POP()", mode = "collect", duration = 60,
		tagline = "Pop everything. Gold pays 5x. Do not touch the black ones." },
	Spotlight = { order = 4, name = "FOLLOW_SPOT", mode = "survive", duration = 70,
		tagline = "Only what the spotlight touches gets rendered. Stay in it." },
}

-- Glitch modifiers rolled on top of every act: acts x mutators = variety.
Config.Mutators = {
	{ id = "Stable", name = "Stable Build", weight = 40 },
	{ id = "Turbo", name = "Framerate Uncapped", weight = 12, walkSpeed = 26 },
	{ id = "Moon", name = "gravity.cfg Missing", weight = 12, jumpHeight = 18 },
	{ id = "Tiny", name = "Scale = 0.5", weight = 9, scale = 0.55 },
	{ id = "Lag", name = "Lag Spike", weight = 8, walkSpeed = 12, exclude = { race = true } },
	{ id = "Blackout", name = "lights.dll Unloaded", weight = 8 },
	{ id = "Golden", name = "GOLDEN BUILD  (2x pay)", weight = 6, payout = 2 },
}

Config.Movement = { WalkSpeed = 16, JumpHeight = 7.2, PassWalkSpeed = 23 }

---------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------
function Config.levelFor(applause: number): number
	return math.floor(math.sqrt(math.max(applause, 0) / 40)) + 1
end

function Config.applauseForLevel(level: number): number
	return (level - 1) ^ 2 * 40
end

Config.Encore = { BonusPerEncore = 0.25 }
function Config.Encore.cost(encores: number): number
	return 5000 * (encores + 1) ^ 2
end

Config.Daily = { 150, 250, 400, 600, 900, 1300, 2500 } -- 7-day streak ladder
Config.DailyDay7ReviveTokens = 1

Config.Gift = { Interval = 480, Base = 60, PerLevel = 12 } -- playtime gift

Config.Hype = { PerParticipant = 9, PerTicketEarned = 0.02, RainPickups = 45, RainValue = 12 }

---------------------------------------------------------------------------
-- Capsules (earned-currency gacha; odds are computed here and shown in UI)
---------------------------------------------------------------------------
Config.Capsule = { Cost = 250, Pity = 40, PityFloor = "Epic" }

Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Glitched" }
Config.Rarities = {
	Common = { weight = 6000, lucky = 1, price = 600, refund = 60, color = Color3.fromRGB(190, 196, 214) },
	Rare = { weight = 2700, lucky = 1, price = 1800, refund = 150, color = Color3.fromRGB(86, 170, 255) },
	Epic = { weight = 1000, lucky = 2, price = 6000, refund = 500, color = Color3.fromRGB(190, 110, 255) },
	Legendary = { weight = 270, lucky = 2, price = 25000, refund = 2000, color = Color3.fromRGB(255, 196, 64) },
	Glitched = { weight = 30, lucky = 2, price = 120000, refund = 10000, color = Color3.fromRGB(60, 255, 190) },
}

-- Returns { [rarity] = probability 0..1 }. The server rolls with this exact
-- table and the client prints it, so displayed odds can never drift.
function Config.capsuleOdds(lucky: boolean?, pityOnly: boolean?): { [string]: number }
	local weights, total = {}, 0
	local floorIndex = table.find(Config.RarityOrder, Config.Capsule.PityFloor) or 1
	for index, rarity in Config.RarityOrder do
		local info = Config.Rarities[rarity]
		local weight = info.weight * (if lucky then info.lucky else 1)
		if pityOnly and index < floorIndex then
			weight = 0
		end
		weights[rarity] = weight
		total += weight
	end
	for rarity, weight in weights do
		weights[rarity] = weight / total
	end
	return weights
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- kind: trail | aura | title
Config.Cosmetics = {
	{ id = "trail_popcorn", kind = "trail", rarity = "Common", name = "Popcorn Trail", colors = { rgb(255, 240, 190), rgb(255, 200, 90) } },
	{ id = "trail_cotton", kind = "trail", rarity = "Common", name = "Cotton Candy Trail", colors = { rgb(255, 150, 210), rgb(140, 210, 255) } },
	{ id = "trail_ticket", kind = "trail", rarity = "Common", name = "Ticket Stub Trail", colors = { rgb(255, 90, 90), rgb(255, 230, 230) } },
	{ id = "title_understudy", kind = "title", rarity = "Common", name = "Title: Understudy", text = "UNDERSTUDY", colors = { rgb(200, 200, 220) } },
	{ id = "title_clown", kind = "title", rarity = "Common", name = "Title: Certified Clown", text = "CERTIFIED CLOWN", colors = { rgb(255, 120, 120) } },
	{ id = "aura_confetti", kind = "aura", rarity = "Rare", name = "Confetti Aura", colors = { rgb(255, 90, 120), rgb(90, 200, 255), rgb(255, 220, 80) } },
	{ id = "trail_neon", kind = "trail", rarity = "Rare", name = "Neon Marquee Trail", colors = { rgb(255, 60, 200), rgb(60, 255, 240) } },
	{ id = "title_headliner", kind = "title", rarity = "Rare", name = "Title: Headliner", text = "HEADLINER", colors = { rgb(90, 180, 255) } },
	{ id = "title_patchnotes", kind = "title", rarity = "Rare", name = "Title: Reads Patch Notes", text = "READS PATCH NOTES", colors = { rgb(140, 255, 170) } },
	{ id = "aura_spotlight", kind = "aura", rarity = "Epic", name = "Spotlight Aura", colors = { rgb(255, 250, 210), rgb(255, 220, 120) } },
	{ id = "trail_scanline", kind = "trail", rarity = "Epic", name = "Scanline Trail", colors = { rgb(0, 255, 140), rgb(0, 60, 40) } },
	{ id = "title_showstopper", kind = "title", rarity = "Epic", name = "Title: Showstopper", text = "SHOWSTOPPER", colors = { rgb(200, 120, 255) } },
	{ id = "aura_fireworks", kind = "aura", rarity = "Legendary", name = "Grand Finale Aura", colors = { rgb(255, 80, 60), rgb(255, 200, 60), rgb(255, 255, 255) } },
	{ id = "trail_gold", kind = "trail", rarity = "Legendary", name = "Golden Encore Trail", colors = { rgb(255, 215, 80), rgb(255, 255, 220) } },
	{ id = "title_ringleader", kind = "title", rarity = "Legendary", name = "Title: Ringleader", text = "RINGLEADER", colors = { rgb(255, 200, 70) } },
	{ id = "aura_corrupt", kind = "aura", rarity = "Glitched", name = "Corrupted Sprite Aura", colors = { rgb(60, 255, 190), rgb(255, 0, 140), rgb(20, 20, 30) } },
	{ id = "trail_missing", kind = "trail", rarity = "Glitched", name = "MISSING_TEXTURE Trail", colors = { rgb(255, 0, 220), rgb(10, 10, 10) } },
	{ id = "title_null", kind = "title", rarity = "Glitched", name = "Title: nil", text = "<nil>", colors = { rgb(60, 255, 190) } },
}

Config.CosmeticById = {}
for _, item in Config.Cosmetics do
	Config.CosmeticById[item.id] = item
end

---------------------------------------------------------------------------
-- The daily build: the Midway is regenerated from the UTC date, so every
-- server shares today's circus and tomorrow's is a different one.
---------------------------------------------------------------------------
Config.Palettes = {
	{ name = "Candy Kernel", a = rgb(214, 48, 92), b = rgb(250, 244, 232), accent = rgb(255, 205, 60), glow = rgb(60, 235, 255), fog = rgb(38, 16, 60) },
	{ name = "Blue Screen", a = rgb(40, 84, 220), b = rgb(232, 240, 255), accent = rgb(255, 110, 190), glow = rgb(120, 255, 200), fog = rgb(10, 20, 60) },
	{ name = "Toxic Matinee", a = rgb(90, 200, 70), b = rgb(28, 24, 44), accent = rgb(255, 80, 200), glow = rgb(220, 255, 80), fog = rgb(16, 34, 30) },
	{ name = "Sunset Overflow", a = rgb(255, 120, 50), b = rgb(60, 28, 90), accent = rgb(255, 225, 120), glow = rgb(255, 80, 150), fog = rgb(50, 18, 44) },
	{ name = "Grape Soda Panic", a = rgb(140, 70, 230), b = rgb(244, 232, 255), accent = rgb(80, 255, 200), glow = rgb(255, 230, 90), fog = rgb(26, 12, 56) },
}

Config.Booths = {
	{ id = "Capsule", label = "PRIZE CLAW", action = "Pull a capsule" },
	{ id = "Shop", label = "BOX OFFICE", action = "Open shop" },
	{ id = "Daily", label = "DAILY CALL SHEET", action = "Check in" },
	{ id = "Encore", label = "ENCORE STAGE", action = "Take a bow" },
	{ id = "Wardrobe", label = "WARDROBE", action = "Change look" },
	{ id = "Director", label = "DIRECTOR'S CHAIR", action = "Pick next act" },
}

-- BARKER.EXE, the ringmaster process that nobody remembers launching.
Config.Barker = {
	Intermission = {
		"Intermission! Please do not feed the unrendered geometry.",
		"Compiling the next act. If you smell burning, that's the shaders.",
		"Today's circus is build #%BUILD%. Yesterday's has been deleted. Probably.",
		"Reminder: the exits are purely decorative.",
		"I generate the whole show from scratch every round. You're welcome.",
	},
	Loading = {
		"Up next: %ACT%. Modifier: %MUTATOR%. I did not test this.",
		"Now rendering %ACT% with %MUTATOR%. Hold on to your hitboxes.",
		"%ACT% is compiling. Warnings: several. Errors: we'll find out together.",
	},
	Win = {
		"%PLAYER% steals the show! The crowd is 40% real and 100% impressed.",
		"A flawless performance by %PLAYER%. I'm adding it to the highlight cache.",
		"%PLAYER% wins. Everyone else has been gently garbage-collected.",
	},
	NoWin = {
		"Nobody survived that one. Bold artistic choice.",
		"That act had no winners, only content.",
	},
	Ovation = {
		"%PLAYER% triggered a STANDING OVATION! Double tickets for the whole tent!",
	},
	Director = {
		"%PLAYER% took the Director's Chair. Next act: %ACT%.",
	},
	Rain = {
		"The crowd meter is FULL. It's raining tickets on the Midway. Go go go!",
	},
}

return Config
