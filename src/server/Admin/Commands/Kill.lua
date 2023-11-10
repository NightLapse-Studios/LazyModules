local Entity
local Kill = {}

--function CharacterMod.TakeDamage(humanoid: Humanoid, Damage: number, Dealer: Player?, limb, byBass): Humanoid?

Kill.Parameters = {"Players"}
function Kill.execute(sender, commandDataTable)
    if commandDataTable[1] then
        for i,plr in pairs(commandDataTable) do
            if plr.Character then
                Entity.Kill(Entity.GetFromPlayer(plr), Entity.GetFromPlayer(sender))
            end
        end
    end
end

function Kill:__init(G)
	Entity = G.Load("Entity")
end

return Kill