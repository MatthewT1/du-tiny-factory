for name, switch in pairs(buttons) do
    if switch.isActive() == false then
        switch.activate() -- fix: one try per tick; a while loop here spins forever if the switch only changes state after the tick
        return
    end
end
