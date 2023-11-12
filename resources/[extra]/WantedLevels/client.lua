local config = {
  debug_enabled = true, -- Debug logs to console
  policePedFOV = 90.0,  -- FOV angle at which PED can see player based on heading
}

-- Function for displaying notifications to player
local function ShowNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text)
  DrawNotification(false, false)
end

local arrestAnimDict = "random@arrests"
local arrestAnimName = "kneeling_arrest_idle"
local taserAnimDict = "weapons@first_person@aim_rng@generic@projectile@taser@base"
local taserAnimName = "aim_rng_generic_projectile_taser_fire"
local wantedTimer = {} -- Table to store timers for each player


-- Function to calculate dot product of two vectors
local function DotProduct3D(a, b)
  return a.x * b.x + a.y * b.y + a.z * b.z
end


-- Function to normalize vectors passed
local function NormalizeVector(vec)
  local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
  if length > 0 then
    return { x = vec.x / length, y = vec.y / length, z = vec.z / length }
  else
    return { x = 0, y = 0, z = 0 } -- Avoid division by zero
  end
end


-- Function for checking if a player is in the field of view of a ped (with raycasting)
local function IsPlayerInPedFOV(ped, player, fovAngle)
  local pedCoords = GetEntityCoords(ped, false)
  local playerCoords = GetEntityCoords(player, false)
  local pedForwardVector = NormalizeVector(GetEntityForwardVector(ped))
  local directionToPlayer = playerCoords - pedCoords
  local directionVector = NormalizeVector(directionToPlayer)
  local angle = math.deg(math.acos(DotProduct3D(pedForwardVector, directionVector)))

  -- if player is within the ped's fov angle
  if math.abs(angle) <= fovAngle then
    local rayHandle = StartShapeTestLosProbe(pedCoords.x,pedCoords.y,pedCoords.z + 1.0,playerCoords.x,playerCoords.y,playerCoords.z + 1.0,-1,ped,4)
    local result = -1
    local retval, hit, endCoords, surfaceNormal, entityHit
    local timeoutCounter = 0
    local timeoutThreshold = 100

    -- loop until the retval = 2 and break, which means the other values returned are accurate
    while result == -1 and timeoutCounter < timeoutThreshold do
      Citizen.Wait(0) -- yield to the game's main loop
      retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
      if retval == 2 then
        result = 1
      end
      timeoutCounter = timeoutCounter + 1
    end

    if timeoutCounter >= timeoutThreshold then
      if config.debug_enabled then
        print('IsPlayerInPedFOV() - Line of sight test timed out.. retval=' .. retval .. ' hit=' .. tostring(hit) .. ' entityHit=' .. tostring(entityHit))
      end
      return false
    end

    if retval == 2 then  -- 2 means successfully extracted test result
      if endCoords ~= vector3(0, 0, 0) and surfaceNormal ~= vector3(0, 0, 0) then
        return false  -- ped cannot see player
      else
        return true  -- ped can see player
      end
    end
  else
    return false -- player is out of the peds angle although within distance (behind the ped)
  end
end


-- Function for returning the closest police ped
local function GetClosestPolicePed(coords)
  local playerPed = PlayerPedId()
  coords = coords or GetEntityCoords(playerPed)

  local closestPed = nil
  local closestDist = -1
  for _, entity in pairs(GetGamePool("CPed")) do
    local pedType = GetPedType(entity)
    local distance = #(coords - GetEntityCoords(entity))

    if pedType == 6 or pedType == 27 or pedType == 29 then -- Cop, SWAT, Army

      local isPlayerInFOV = IsPlayerInPedFOV(entity, playerPed, config.policePedFOV)
      local isDead = IsEntityDead(entity)

      if not isDead and isPlayerInFOV and (closestDist == -1 or distance < closestDist) then
        closestPed = entity
        closestDist = distance
        --if config.debug_enabled then
        --  print('GetClosestPolicePed() - Police PED (' .. closestPed .. ') can see the player from distance (' .. distance .. ')')
        --end
        return closestPed, closestDist
      end
    end
  end

  if not closestPed then
    return nil, -1 -- Return nil and -1 if no suitable ped was found
  end
end


Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000) -- Adjust the interval as needed

    for i = 0, 31 do
      local player = GetPlayerFromServerId(i)

      if NetworkIsPlayerActive(player) then
        local wantedLevel = GetPlayerWantedLevel(player)

        if wantedLevel > 0 and wantedLevel <= 2 then
          print("Player is wanted, but less than 2 stars")
          local playerPed = GetPlayerPed(-1)

          local closestPed, closestDist = GetClosestPolicePed(playerPed)

          if DoesEntityExist(closestPed) then
            TaskTurnPedToFaceEntity(closestPed, playerPed, -1)
            ShowNotification("~r~Police~s~ are attempting to arrest you!")
            print("Closest Police PED is attempting to arrest player")
            local dict = arrestAnimDict
            RequestAnimDict(dict)

            while not HasAnimDictLoaded(dict) do
              Citizen.Wait(100)
            end

            TaskPlayAnim(closestPed, dict, arrestAnimName, 8.0, -8.0, -1, 49, 0, false, false, false)

            Citizen.Wait(5000)  -- Adjust the time the animation takes to complete

            ClearPedTasks(closestPed)

            -- Set player health to 0
            SetEntityHealth(playerPed, 0) -- todo: something else??

            -- Set a timer for wanted level reduction
            if not wantedTimer[player] then
              wantedTimer[player] = 5 -- Adjust the timer duration as needed (in seconds)
              Citizen.CreateThread(function()
                while wantedTimer[player] > 0 do
                  Citizen.Wait(1000)
                  wantedTimer[player] = wantedTimer[player] - 1
                end
                ClearPlayerWantedLevel(player)
                wantedTimer[player] = nil -- Remove the timer entry
              end)
            end
          end
        end

        -- Police behavior based on wanted level
        if wantedLevel == 1 or wantedLevel == 2 then
          local playerPed = GetPlayerPed(-1)

          local closestPed, closestDist = GetClosestPolicePed(playerPed)

          if DoesEntityExist(closestPed) then
            TaskTurnPedToFaceEntity(closestPed, playerPed, -1)

            if wantedLevel == 2 then
              local dict = taserAnimDict
              RequestAnimDict(dict)

              while not HasAnimDictLoaded(dict) do
                Citizen.Wait(100)
              end

              TaskPlayAnim(closestPed, dict, taserAnimName, 8.0, -8.0, -1, 49, 0, false, false, false)
            else
              TaskCombatPed(closestPed, playerPed, 0, 16)
            end

            local waitTime = closestDist / 1000000
            print("Police PED " .. closestPed .. " is " .. closestDist .. " away from player")
            print("waiting that distance divided by 1000 second??.. (" .. waitTime .. ") for the PED task to complete")
            Citizen.Wait(waitTime)  -- Adjust the time the animation or combat task takes to complete.. based on closestDist?

          end
        end
      end
    end
  end
end)
