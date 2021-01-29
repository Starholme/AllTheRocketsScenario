-- For each other player force, share a chat msg.
local function ShareChatBetweenForces(player, msg)
    for _,force in pairs(game.forces) do
        if (force ~= nil) then
            if ((force.name ~= "enemy") and
                (force.name ~= "neutral") and
                (force.name ~= "player") and
                (force ~= player.force)) then
                force.print(player.name..": "..msg)
            end
        end
    end
end

return {
    ShareChatBetweenForces = ShareChatBetweenForces
}
