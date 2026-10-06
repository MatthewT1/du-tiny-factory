local now = math.floor(system.getArkTime())
for name, switch in pairs(buttons) do
    -- fix: leave a board off while its restart hold (set in next()) is running
    if switch.isActive() == false and not (hold_until[name] and now < hold_until[name]) then
        while switch.isActive() == false do switch.activate() end
        -- fix: grace period - give the freshly started board 30 s to write its first ping; otherwise next() sees
        -- the OLD stale ping and switches it off again before it has even started
        databank.setIntValue("ping:" .. name, now)
        return
    end
end
