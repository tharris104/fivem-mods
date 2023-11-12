-- Function for displaying notifications to player
local function ShowNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text)
  DrawNotification(false, false)
end


-- Function to send police to arrest a player
local function SendPoliceToArrest(playerId)
  local playerPed = GetPlayerPed(-1)
  local policePed, _ = GetClosestPolicePed(GetEntityCoords(playerPed))

  if DoesEntityExist(policePed) then
    TaskGoToEntity(policePed, playerPed, -1, 1.0, 10.0, 1073741824, 0)
    local success, arrestAnimDict = RequestAnimDict("mp_arresting")

    while not success do
      Wait(500)
    end

    TaskPlayAnim(policePed, arrestAnimDict, "a_uncuff", 8.0, -8.0, -1, 16, 0, false, false, false)
    ShowNotification("~r~Police~s~ are attempting to arrest you!")

    -- Wait for the arrest animation to complete (adjust duration as needed)
    Wait(5000)

    -- Set the player's health to 0
    SetEntityHealth(playerPed, 0)
  end
end


-- Function to check if any player has wanted level 1 or 2
local function CheckWantedLevels()
  while true do
    Wait(1000) -- Check every 1 second

    for playerId = 0, 31 do -- 32 players total
      if NetworkIsPlayerActive(playerId) then
        local wantedLevel = GetPlayerWantedLevel(playerId)

        if wantedLevel == 1 or wantedLevel == 2 then
          -- Player has wanted level 1 or 2, send police to arrest
          SendPoliceToArrest(playerId)
        end
      end
    end
  end
end


-- Main thread to check wanted levels
Citizen.CreateThread(function()
  CheckWantedLevels()
end)



local arrestAnimDict = "random@arrests"
local arrestAnimName = "kneeling_arrest_idle"

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)

    for i = 0, 31 do
      local player = GetPlayerFromServerId(i)

      if NetworkIsPlayerActive(player) then
        local wantedLevel = GetPlayerWantedLevel(player)

        if wantedLevel > 0 and wantedLevel <= 2 then
          local playerPed = GetPlayerPed(-1)
          local playerPos = GetEntityCoords(playerPed)
          local policePed = CreatePed(6, GetHashKey("s_m_y_cop_01"), playerPos.x, playerPos.y, playerPos.z, 0.0, true, false)

          TaskTurnPedToFaceEntity(policePed, playerPed, -1)
          TaskStartScenarioInPlace(policePed, "WORLD_HUMAN_SMOKING", 0, true)

          local dict = arrestAnimDict
          RequestAnimDict(dict)

          while not HasAnimDictLoaded(dict) do
            Citizen.Wait(100)
          end

          TaskPlayAnim(policePed, dict, arrestAnimName, 8.0, -8.0, -1, 49, 0, false, false, false)

          Citizen.Wait(5000)  -- Adjust the time the animation takes to complete

          ClearPedTasks(policePed)
          SetEntityAsMissionEntity(policePed, false, true)
          DeleteEntity(policePed)

          -- Set player health to 0
          SetEntityHealth(playerPed, 0)
        end
      end
    end
  end
end)
