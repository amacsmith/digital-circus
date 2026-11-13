--!nonstrict
-- Thin remote registry. The server creates every remote named in
-- Config.Remotes at boot; both sides then address remotes by name.
-- Server handlers are rate limited per player and wrapped in pcall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Net = {}
local folder: Instance? = nil
local lastCall: { [Player]: { [string]: number } } = {}

function Net.setup()
	local created = Instance.new("Folder")
	created.Name = "Remotes"
	for _, name in Config.Remotes do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = created
	end
	created.Parent = ReplicatedStorage
	folder = created
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

local function get(name: string): RemoteEvent
	local root = folder or ReplicatedStorage:WaitForChild("Remotes")
	folder = root
	return root:WaitForChild(name) :: RemoteEvent
end

-- server -> client
function Net.fire(player: Player, name: string, ...: any)
	get(name):FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	get(name):FireAllClients(...)
end

-- client -> server
function Net.send(name: string, ...: any)
	get(name):FireServer(...)
end

function Net.onClient(name: string, handler: (...any) -> ())
	return get(name).OnClientEvent:Connect(handler)
end

function Net.onServer(name: string, handler: (Player, ...any) -> (), cooldown: number?)
	local minGap = cooldown or 0.25
	return get(name).OnServerEvent:Connect(function(player, ...)
		local calls = lastCall[player]
		if not calls then
			calls = {}
			lastCall[player] = calls
		end
		local now = os.clock()
		if calls[name] and now - calls[name] < minGap then
			return
		end
		calls[name] = now
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(`[Net] {name} from {player.Name} failed: {err}`)
		end
	end)
end

return Net
