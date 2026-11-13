--!nonstrict
-- GLITCHTOP server entry point. Boot order matters: remotes first, then
-- data, then everything that listens for loaded profiles, then the world
-- and finally the show loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
Net.setup()

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PassService = require(Services.PassService)
local Movement = require(Services.Movement)
local EconomyService = require(Services.EconomyService)
local CosmeticService = require(Services.CosmeticService)
local CapsuleService = require(Services.CapsuleService)
local RewardService = require(Services.RewardService)
local MonetizationService = require(Services.MonetizationService)
local WorldGen = require(Services.WorldGen)
local ActDirector = require(Services.ActDirector)

WorldGen.build()

PassService.init()
EconomyService.init()
CosmeticService.init()
CapsuleService.init()
RewardService.init()
MonetizationService.init()
Movement.init()
DataService.init() -- last: its ProfileLoaded listeners are all connected now

ActDirector.start()

-- "Top billing" board on the Midway, refreshed from the ordered DataStore.
task.spawn(function()
	while true do
		local label = WorldGen.leaderboardLabel
		if label then
			local lines = { "<b>TOP BILLING</b>", "<font size=\"20\">lifetime applause</font>", "" }
			local rows = DataService.top(8)
			for rank, row in rows do
				table.insert(lines, `{rank}. {row.name}  —  {row.value}`)
			end
			if #rows == 0 then
				table.insert(lines, "No headliners yet.")
				table.insert(lines, "Be the first.")
			end
			label.Text = table.concat(lines, "\n")
		end
		task.wait(150)
	end
end)
