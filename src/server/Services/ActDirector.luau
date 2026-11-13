--!nonstrict
-- The show loop. Every round BARKER.EXE picks an act and a glitch mutator,
-- asks the act module to generate a brand new arena from a fresh seed, runs
-- it, pays everyone out and deletes the arena again.
--
-- An act is a ModuleScript in server/Acts returning:
--   { id = string,
--     build = function(ctx) -> { spawns = { CFrame }, revive = CFrame? },
--     run = function(ctx),            -- loop while ctx.running
--     onFall = function(ctx, player)? -- optional; default is elimination
--   }
-- Its name, mode and duration live in Config.Acts[id]. Adding an act is one
-- module plus one Config row; the director needs no changes.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Rng = require(ReplicatedStorage.Shared.Rng)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Movement = require(script.Parent.Movement)

local ActDirector = {}

local impls: { [string]: any } = {}
local actIds: { string } = {}
local queue: { string } = {}
local afk: { [Player]: boolean } = {}
local current: any = nil
local lastActId: string? = nil
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function setPhase(phase: string, seconds: number)
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseEndsAt", now() + seconds)
end

local function sendHome(player: Player)
	if player.Parent == nil then
		return
	end
	player:SetAttribute("InAct", false)
	player:SetAttribute("Static", 0)
	Movement.apply(player, nil)
	local character = player.Character
	if character and rootOf(player) then
		local angle = rng:NextNumber(0, math.pi * 2)
		character:PivotTo(CFrame.new(math.cos(angle) * 30, 6, math.sin(angle) * 30))
	end
end

---------------------------------------------------------------------------
-- Context handed to act modules
---------------------------------------------------------------------------
local Ctx = {}
Ctx.__index = Ctx

function Ctx:isActive(player: Player): boolean
	local state = self.participants[player]
	return state ~= nil and state.alive and not state.finished
end

function Ctx:activePlayers(): { Player }
	local out = {}
	for player in self.participants do
		if self:isActive(player) then
			table.insert(out, player)
		end
	end
	return out
end

function Ctx:root(player: Player): BasePart?
	return rootOf(player)
end

-- Resolves a Touched hit to a participant who is still in the act.
function Ctx:playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	local player = model and Players:GetPlayerFromCharacter(model)
	if player and self:isActive(player) then
		return player
	end
	return nil
end

function Ctx:addScore(player: Player, amount: number)
	local state = self.participants[player]
	if state and self.running then
		state.score = math.max(state.score + amount, 0)
		player:SetAttribute("ActScore", math.floor(state.score))
	end
end

function Ctx:timeLeft(): number
	return self.endsAt - now()
end

function Ctx:teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character and rootOf(player) then
		local root = rootOf(player) :: BasePart
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cframe)
	end
end

function Ctx:finish(player: Player)
	if not self:isActive(player) or not self.running then
		return
	end
	local state = self.participants[player]
	self.finishCount += 1
	state.finished = true
	state.place = self.finishCount
	local round = Config.Round
	self:addScore(player, math.max(round.RaceFirst - round.RaceStep * (state.place - 1), round.RaceMin))
	Net.fire(player, "Toast", `Finished #{state.place}! Take a bow.`, "gold")
	sendHome(player)
end

function Ctx:eliminate(player: Player, reason: string?)
	if not self:isActive(player) then
		return
	end
	local state = self.participants[player]
	state.alive = false
	sendHome(player)
	Net.fire(player, "Toast", reason or "You have been unrendered.", "bad")
	if self.running and self.meta.mode ~= "collect" and self:timeLeft() > Config.Round.ReviveMinTimeLeft then
		Net.fire(player, "OfferRevive", math.floor(self:timeLeft()))
	end
end

---------------------------------------------------------------------------
-- Second Take (revive)
---------------------------------------------------------------------------
function ActDirector.tryRevive(player: Player): boolean
	local ctx = current
	local profile = DataService.get(player)
	if not ctx or not ctx.running or not profile or profile.reviveTokens <= 0 then
		return false
	end
	local state = ctx.participants[player]
	if not state or state.alive or state.finished or not rootOf(player) then
		return false
	end
	if ctx:timeLeft() < Config.Round.ReviveMinTimeLeft / 2 then
		return false
	end
	profile.reviveTokens -= 1
	DataService.replicate(player)
	state.alive = true
	player:SetAttribute("InAct", true)

	local target = state.checkpoint or ctx.arena.revive or (ctx.arena.spawns[1] + Vector3.new(0, 14, 0))
	if ctx.meta.mode == "survive" then
		-- A short-lived safety pad so a revive never drops you into nothing.
		local pad = Build.part({
			Name = "SecondTakePad",
			Size = Vector3.new(10, 1, 10),
			CFrame = target - Vector3.new(0, 3.5, 0),
			Color = Color3.fromRGB(255, 214, 70),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		}, ctx.folder)
		Debris:AddItem(pad, 3)
	end
	ctx:teleport(player, target)
	Movement.apply(player, ctx.mutator)
	Net.fire(player, "Toast", "SECOND TAKE! You've been re-rendered.", "gold")
	return true
end

---------------------------------------------------------------------------
-- Round
---------------------------------------------------------------------------
local function eligible(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if not afk[player] and DataService.get(player) and rootOf(player) then
			table.insert(out, player)
		end
	end
	return out
end

local function pickAct(): string
	local queued = table.remove(queue, 1)
	if queued then
		return queued
	end
	local pool = {}
	for _, id in actIds do
		if id ~= lastActId or #actIds == 1 then
			table.insert(pool, id)
		end
	end
	return Rng.pick(rng, pool)
end

local function payout(ctx: any)
	local round = Config.Round
	local rows = {}
	for player, state in ctx.participants do
		if ctx.meta.mode == "survive" and state.alive then
			state.score += round.SurvivorBonus
		end
		table.insert(rows, { player = player, state = state })
	end
	table.sort(rows, function(a, b)
		local pa, pb = a.state.place or math.huge, b.state.place or math.huge
		if pa ~= pb then
			return pa < pb
		end
		return a.state.score > b.state.score
	end)

	local winner: Player? = nil
	local top = rows[1]
	if top and top.state.score > 0 then
		local earnedIt = top.state.finished or ctx.meta.mode == "collect" or (ctx.meta.mode == "survive" and top.state.alive)
		if earnedIt then
			winner = top.player
		end
	end

	for rank, row in rows do
		local player: Player = row.player
		local profile = DataService.get(player)
		if player.Parent and profile then
			local scale = ctx.mutator.payout or 1
			if player == winner then
				scale *= round.WinnerMultiplier
				profile.stats.wins += 1
			end
			profile.stats.acts += 1
			local tickets = EconomyService.award(player, round.BasePay + row.state.score, { scale = scale })
			EconomyService.addApplause(player, 10 + row.state.score / 4)
			EconomyService.addHype(Config.Hype.PerParticipant)
			Net.fire(player, "ActResult", {
				act = ctx.meta.name,
				rank = rank,
				total = #rows,
				tickets = tickets,
				score = math.floor(row.state.score),
				won = player == winner,
			})
		end
	end

	if winner then
		EconomyService.barker("Win", { PLAYER = winner.DisplayName })
	else
		EconomyService.barker("NoWin")
	end
end

local function cleanup(ctx: any?)
	if not ctx then
		return
	end
	ctx.running = false
	for player in ctx.participants do
		if player:GetAttribute("InAct") then
			sendHome(player)
		end
		player:SetAttribute("ActScore", nil)
	end
	if ctx.folder then
		ctx.folder:Destroy()
	end
	if current == ctx then
		current = nil
	end
end

local function runRound()
	setPhase("Intermission", Config.Round.Intermission)
	EconomyService.barker("Intermission")
	task.wait(Config.Round.Intermission)

	if #eligible() == 0 then
		setPhase("Waiting", 0)
		task.wait(3)
		return
	end

	local actId = pickAct()
	local meta = Config.Acts[actId]
	local impl = impls[actId]
	lastActId = actId
	local mutator = Rng.weighted(rng, Config.Mutators, function(m)
		return if m.exclude and m.exclude[meta.mode] then 0 else m.weight
	end) or Config.Mutators[1]

	workspace:SetAttribute("ActId", actId)
	workspace:SetAttribute("ActName", meta.name)
	workspace:SetAttribute("ActTagline", meta.tagline)
	workspace:SetAttribute("Mutator", mutator.id)
	workspace:SetAttribute("MutatorName", mutator.name)
	setPhase("Loading", Config.Round.Loading)
	EconomyService.barker("Loading", { ACT = meta.name, MUTATOR = mutator.name })

	local folder = Instance.new("Folder")
	folder.Name = "Arena_" .. actId
	folder.Parent = workspace

	local ctx = setmetatable({
		id = actId,
		meta = meta,
		mutator = mutator,
		rng = Random.new(os.time() + rng:NextInteger(1, 1e6)),
		origin = Config.ArenaOrigin,
		folder = folder,
		participants = {},
		finishCount = 0,
		running = false,
		endsAt = now() + meta.duration,
	}, Ctx)
	current = ctx
	ctx.arena = impl.build(ctx)
	task.wait(Config.Round.Loading)

	local players = eligible()
	if #players == 0 then
		cleanup(ctx)
		return
	end
	Rng.shuffle(rng, players)
	local spawns = ctx.arena.spawns
	for index, player in players do
		local spawnCFrame = spawns[(index - 1) % #spawns + 1] + Vector3.new(0, 4, 0)
		ctx.participants[player] = { alive = true, finished = false, score = 0, checkpoint = nil, spawn = spawnCFrame }
		player:SetAttribute("InAct", true)
		player:SetAttribute("ActScore", 0)
		player:SetAttribute("Static", 0)
		ctx:teleport(player, spawnCFrame)
		Movement.apply(player, mutator, true)
	end

	setPhase("Countdown", Config.Round.Countdown)
	task.wait(Config.Round.Countdown)
	for player in ctx.participants do
		Movement.apply(player, mutator)
	end

	setPhase("Act", meta.duration)
	ctx.endsAt = now() + meta.duration
	ctx.running = true
	task.spawn(function()
		local ok, err = pcall(impl.run, ctx)
		if not ok then
			warn(`[Act] {actId} crashed: {err}`)
		end
	end)

	local started = #players
	local killY = ctx.origin.Y - Config.Round.KillDepth
	local tick = 0.2
	while ctx:timeLeft() > 0 do
		task.wait(tick)
		local active = 0
		for player, state in ctx.participants do
			if state.alive and not state.finished then
				local root = rootOf(player)
				if player.Parent == nil or not root then
					state.alive = false
					if player.Parent then
						player:SetAttribute("InAct", false)
						Net.fire(player, "Toast", "You have been unrendered.", "bad")
					end
				elseif root.Position.Y < killY then
					if impl.onFall then
						impl.onFall(ctx, player)
					else
						ctx:eliminate(player, "You fell out of the render distance.")
					end
				end
				if state.alive then
					active += 1
					if meta.mode == "survive" then
						ctx:addScore(player, Config.Round.SurvivePerSecond * tick)
					end
				end
			end
		end
		if active == 0 then
			break
		end
		if meta.mode == "survive" and started > 1 and active <= 1 then
			break
		end
	end
	ctx.running = false

	payout(ctx)
	setPhase("Results", Config.Round.Results)
	task.wait(Config.Round.Results)
	cleanup(ctx)
end

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local function queueAct(player: Player, actId: any)
	local profile = DataService.get(player)
	if not profile or type(actId) ~= "string" or not impls[actId] then
		return
	end
	if profile.directorCuts <= 0 then
		Net.fire(player, "Toast", "You need a Director's Cut to pick the next act.", "bad")
		return
	end
	if #queue >= 3 then
		Net.fire(player, "Toast", "The director's queue is full. Try again after this act.", "bad")
		return
	end
	profile.directorCuts -= 1
	table.insert(queue, actId)
	DataService.replicate(player)
	EconomyService.barker("Director", { PLAYER = player.DisplayName, ACT = Config.Acts[actId].name })
end

function ActDirector.start()
	for _, module in script.Parent.Parent.Acts:GetChildren() do
		if module:IsA("ModuleScript") then
			local impl = require(module) :: any
			if Config.Acts[impl.id] then
				impls[impl.id] = impl
				table.insert(actIds, impl.id)
			else
				warn(`[Act] {module.Name} has no Config.Acts row; skipped.`)
			end
		end
	end
	table.sort(actIds)

	Net.onServer("QueueAct", queueAct, 1)
	Net.onServer("UseRevive", function(player)
		ActDirector.tryRevive(player)
	end, 0.5)
	Net.onServer("SetAFK", function(player, value)
		afk[player] = value == true
		player:SetAttribute("AFK", afk[player])
	end, 0.3)
	Players.PlayerRemoving:Connect(function(player)
		afk[player] = nil
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(runRound)
			if not ok then
				warn(`[Director] round failed: {err}`)
				cleanup(current)
				task.wait(5)
			end
		end
	end)
end

return ActDirector
