--!strict
local LazyModules = require(game.ReplicatedFirst.Shared.LazyModules)
local Config = require(game.ReplicatedFirst.Lib.Config)

local Game = LazyModules.newGame()

-- Std lib exposes a set of modules that all scripts may want
-- Generally these are exposed for rapid debug development and proper requires should be preferred
local StdLib = require(game.ReplicatedFirst.Lib.StdLib)
StdLib.LoadExports(Game)

_G.Game = Game
Game:CollectModules()


if Game.CONTEXT == "CLIENT" then
	if workspace.StreamingEnabled ~= true then
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
	end

	-- Add any additional desired loading delays such as Instances.OnAllLoaded for the clients character
else
	-- Register modules which have player-based data that will be fed into datastores as well as transmitted to clients
	-- Data synced this way will be available by _G.Game[plr][<module_name>]

	if Config.ReleaseType == "Full" then
		local Players = require(game.ReplicatedFirst.Modules.Players)
		Players.RegisterPlayerDataModule("Stats")
	end
end

return Game