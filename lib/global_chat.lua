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

local function ChatEvent(event)
    if (event.player_index) then
        ServerWriteFile("server_chat", game.players[event.player_index].name .. ": " .. event.message .. "\n")
    end
    if (global.ocfg.enable_shared_chat) then
        if (event.player_index ~= nil) then
            ShareChatBetweenForces(game.players[event.player_index], event.message)
        end
    end
end

return {
    ChatEvent = ChatEvent
}
