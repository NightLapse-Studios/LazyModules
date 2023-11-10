local EntityDbg = {}

local Game
local Entity

local Labels = { }

-- @param String: Subcommand
-- @param Number: EntityID
EntityDbg.Parameters = { "Text", "Number" }
local SubCmds = {
	label_ids = function(commandDataTable)
		for i,v in Entity:GetAll() do
			local model = v.Model
			if not model.PrimaryPart then
				continue
			end
	
			local billboard = Game.DebugAdorneText(model.PrimaryPart, v.ID)
			table.insert(Labels, billboard)
		end
	end,

	remove_ids = function(commandDataTable)
		for i,v in Labels do
			v:Destroy()
		end
	end,

	kill = function(commandDataTable)
		local _, ent_id = table.unpack(commandDataTable)

		local ent = Entity.GetByID(ent_id)
		if not ent then
			return
		end

		Entity.Kill(ent, nil)
	end,

	kill_all = function(commandDataTable)
		for i,v in Entity:GetAll() do
			Entity.Kill(v, nil)
		end
	end
}

function EntityDbg.execute(sender, commandDataTable)
    local sub_cmd = commandDataTable[1]

	local cmd = SubCmds[sub_cmd]
	if not cmd then
		return
	end

	cmd(commandDataTable)
end

function EntityDbg:__init(G)
    Game = G
	Entity = G.Load("Entity")
end

return EntityDbg