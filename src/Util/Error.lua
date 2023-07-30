
local mod = { }

local RunService = game:GetService("RunService")
local HTTPService = game:GetService("HttpService")

local Secrets
if RunService:IsServer() then
	-- TODO: Generalize secrets so that we can add this back
	-- Secrets = require(game.ServerScriptService.Secrets)
end

local Paniced = false
function mod.Panic(err: string, extra: string, kick_players: boolean?)
	if Paniced then
		return
	end

	Paniced = true

	if RunService:IsStudio() then
		error(err .. "\n" .. extra)
		return
	end

	if RunService:IsServer() then
		--TODO: This depends on the __init step so some stuff 
		if Secrets then
			Secrets.SendPanicReport(err, extra)
		end
	
		if kick_players then
			for i,v in pairs(game.Players:GetPlayers()) do
				v:Kick("\nThe server encountered an issue and needs to shut down :(")
			end
		end
	end
end

function mod.unwrap_or_warn(succ: any?, err: string, scope: string?): any?
	scope = scope or debug.traceback(nil, 2)
	if not succ then
		warn(tostring(err) .. "\n\t" .. tostring(scope))
	end

	return succ
end
function mod.unwrap_or_error(succ: any?, err: string, scope: string?): any?
	scope = scope or ""
	if not succ then
		error(tostring(err) .. "\n\t" .. tostring(scope))
	end

	return succ
end

function mod.unwrap_or_panic(succ: any?, err: string, scope: string?): any?
	if not succ then
		mod.Panic(err, scope, true)
	end

	return succ
end

return mod