local isAiming = false
local lastAimTime = 0
local pedToHoldUp = nil

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)

    local playerPed = GetPlayerPed(-1)
    local entity = nil

    if IsPlayerFreeAiming(playerPed) then
      local aiming, targetEntity = GetEntityPlayerIsFreeAimingAt(playerPed)
      if aiming then
        entity = targetEntity
      end
    end

    if entity and IsEntityAPed(entity) and not IsEntityDead(entity) then
      if not isAiming then
        -- Player just started aiming at a PED
        isAiming = true
        lastAimTime = GetGameTimer()
        pedToHoldUp = entity
        TaskHandsUp(entity, -1, 0, -1, true) -- Raise hands up indefinitely
      else
        -- Player continues to aim at the same PED
        local currentTime = GetGameTimer()
        local timeSinceAimStart = currentTime - lastAimTime

        if timeSinceAimStart >= 5000 then -- Adjust this time as needed
          UpdateTaskHandsUpDuration(pedToHoldUp, -1) -- Extend the duration
        end
      end
    else
      -- Player is not aiming at a valid PED
      isAiming = false
      lastAimTime = 0
      pedToHoldUp = nil
    end
  end
end)
