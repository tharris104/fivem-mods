local config = {
  debug_enabled = true,      -- Debug logs to console
  globalSpeedLimit = 70,     -- Global speed limit for any vehicle (simpleCarHUD sets this value also)
  policePedFOV = 90.0,       -- FOV angle at which PED can see player based on heading
  TOG_WarningCounter = 0,    -- Counter for tires off the ground
  TOG_WarningThreshold = 20, -- Threshold for tires off the ground
  BO_WarningCounter = 0,     -- Counter for burnouts
  BO_WarningThreshold = 10,  -- Threshold for burnouts
  --VW_WarningCounter = 0,     -- Counter for wanted vehicle
  --VW_WarningThreshold = 10,  -- Threshold for wanted vehicle
  nearbyDistance = 200.0,    -- While driving, monitor vehicles nearby that are stopped at red light
  angleThreshold = 90.0,     -- If player passes this vehicle within set angle, police nearby can report traffic violation
  maxLosDist = 60,           -- Global maximum line of sight for Police PED's
}

-- Function for displaying notifications to player
local function ShowNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text)
  DrawNotification(false, false)
end

-- Function to calculate dot product of two vectors
local function DotProduct3D(a, b)
  return a.x * b.x + a.y * b.y + a.z * b.z
end

-- Function for checking if a player is in the field of view of a ped (with raycasting)
local function IsPlayerInPedFOV(ped, player, fovAngle)
  local pedCoords = GetEntityCoords(ped, false)
  local playerCoords = GetEntityCoords(player, false)
  local pedForwardVector = GetEntityForwardVector(ped)
  local directionToPlayer = playerCoords - pedCoords
  directionToPlayer = directionToPlayer / #(directionToPlayer) -- normalize vector
  local angle = math.deg(math.acos(DotProduct3D(pedForwardVector, directionToPlayer)))

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
        if config.debug_enabled then
          print('GetClosestPolicePed() - Police PED (' .. closestPed .. ') can see the player from distance (' .. distance .. ')')
        end
        return closestPed, closestDist
      end
    end
  end

  if not closestPed then
    return nil, -1 -- Return nil and -1 if no suitable ped was found
  end
end

-- Get the closest police within line of sight and reports crimes on player
-- Crime types reference: https://docs.fivem.net/natives/?_0xE9B09589827545E7
Citizen.CreateThread(function()
  while true do
    Wait(1000) -- every 1 second
    local playerPed = PlayerPedId()
    local playerName = GetPlayerName(PlayerId())
    local ent, dist = GetClosestPolicePed()

    -- dont continue if Police PED's cannot see the player
    if ent ~= -1 and dist ~= -1 then
      if config.debug_enabled then
        print('Report System thread - Police ped (' .. ent ..') distance (' .. dist ..') can see the player')
      end

      -- traffic violations (is the player in a vehicle or getting in?)
      if IsPedInAnyVehicle(PlayerPedId(), true) then
        -- collect more detailed info now
        local playerveh = GetVehiclePedIsUsing(playerPed)
        local speedmph = (GetEntitySpeed(playerveh) * 2.236936) -- https://docs.fivem.net/natives/?_0xD5037BA82E12416F
        local vehicleClass = GetVehicleClass(playerveh)

        -- line of sight has no limit so we manually set threshold
        if dist < config.maxLosDist then
          -- if player is not already wanted
          if not IsPlayerWantedLevelGreater(PlayerId(), 0) then
            if config.debug_enabled then
              print('Report System thread - Police PED distance: ' .. dist)
              print('Report System thread - Police PED max LOS:  ' .. config.maxLosDist)
            end
            if vehicleClass == 14 or vehicleClass == 15 or vehicleClass == 16 or vehicleClass == 21 then
              -- vehicle is either a boat, helicopter, plane, or train... do nothing
              if config.debug_enabled then
                print('Report System thread - Police can see the player in either a boat, helicopter, plane, or train')
              end
            else

              -- cop sees you speeding in car
              if speedmph > config.globalSpeedLimit then
                ShowNotification("Speeding Violation! (~r~" .. speedmph .. " mph~s~)")
                print(playerName .. " got a speeding violation! (" .. speedmph .. ") cop (" .. ent .. ") dist (" .. dist .. ")")
                local policeBlip = AddBlipForEntity(ent)
                SetBlipSprite(policeBlip, 8)
                SetBlipColour(policeBlip, 1)
                SetBlipAsShortRange(policeBlip, true)
                ReportCrime(PlayerId(), 4, GetWantedLevelThreshold(1)) -- 4: Speeding vehicle (a "5-10")

              -- cop sees you doing a wheelie
              elseif GetVehicleWheelieState(playerveh) == 129 then
                ShowNotification("~r~Police~s~ witnessed you doing a wheelie!")
                print(playerName .. "Police witnessed you doing a wheelie! cop (" .. ent .. ") dist (" .. dist .. ")")
                local policeBlip = AddBlipForEntity(ent)
                SetBlipSprite(policeBlip, 8)
                SetBlipColour(policeBlip, 1)
                SetBlipAsShortRange(policeBlip, true)
                ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver

              -- cop sees you driving known stolen vehicle
              elseif IsVehicleStolen(playerveh) then
                ShowNotification("~r~Police~s~ witnessed you driving a stolen vehicle!")
                print(playerName .. "Police witnessed you driving a stolen vehicle! cop (" .. ent .. ") dist (" .. dist .. ")")
                local policeBlip = AddBlipForEntity(ent)
                SetBlipSprite(policeBlip, 8)
                SetBlipColour(policeBlip, 1)
                SetBlipAsShortRange(policeBlip, true)
                ReportCrime(PlayerId(), 7, GetWantedLevelThreshold(1)) -- 7: Vehicle theft (a "5-0-3")

              -- cop sees you hit any entity with vehicle
              elseif HasEntityCollidedWithAnything(playerveh) then
                ShowNotification("~r~Police~s~ witnessed bad driving!")
                print(playerName .. "Police witnessed bad driving! cop (" .. ent .. ") dist (" .. dist .. ")")
                local policeBlip = AddBlipForEntity(ent)
                SetBlipSprite(policeBlip, 8)
                SetBlipColour(policeBlip, 1)
                SetBlipAsShortRange(policeBlip, true)
                ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver

              -- cop sees you driving a known wanted vehicle (evaded successfully)
              elseif IsVehicleWanted(playerveh) then
                ShowNotification("~r~Police~s~ witnessed you driving a known wanted vehicle!")
                print("Police witnessed " .. playerName .. " driving a known wanted vehicle! cop (" .. ent .. ") dist (" .. dist .. ")")
                local policeBlip = AddBlipForEntity(ent)
                SetBlipSprite(policeBlip, 8)
                SetBlipColour(policeBlip, 1)
                SetBlipAsShortRange(policeBlip, true)
                ReportCrime(PlayerId(), 9, GetWantedLevelThreshold(1)) -- 9: ???

              -- cop sees you burning out
              elseif IsVehicleInBurnout(playerveh) then
                config.BO_WarningCounter = config.BO_WarningCounter + 1
                if config.BO_WarningCounter >= config.BO_WarningThreshold then
                  ShowNotification("~r~Police~s~ witnessed your burnout!")
                  print("Police witnessed " .. playerName .. " doing a burnout! cop (" .. ent .. ") dist (" .. dist .. ")")
                  local policeBlip = AddBlipForEntity(ent)
                  SetBlipSprite(policeBlip, 8)
                  SetBlipColour(policeBlip, 1)
                  SetBlipAsShortRange(policeBlip, true)
                  ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver
                  config.BO_WarningCounter = 0
                end

              -- cop sees your vehicle no on all wheels (air time)
              elseif not IsVehicleOnAllWheels(playerveh) then
                config.TOG_WarningCounter = config.TOG_WarningCounter + 1
                if config.TOG_WarningCounter >= config.TOG_WarningThreshold then
                  ShowNotification("~r~Police~s~ witnessed reckless driving!")
                  print("Police witnessed tires off ground! cop (" .. ent .. ") dist (" .. dist .. ")")
                  local policeBlip = AddBlipForEntity(ent)
                  SetBlipSprite(policeBlip, 8)
                  SetBlipColour(policeBlip, 1)
                  SetBlipAsShortRange(policeBlip, true)
                  ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver
                  config.TOG_WarningCounter = 0
                end
              end

              -- cop sees you run a red light todo: make this a function
              local nearbyVehicles = {}
              for _, aiVehicle in pairs(GetGamePool("CVehicle")) do
                if DoesEntityExist(aiVehicle) and aiVehicle ~= playerVehicle then
                  local aiCoords = GetEntityCoords(aiVehicle)
                  local aiHeading = GetEntityHeading(aiVehicle)
                  -- Check the distance between the player's vehicle and the AI vehicle
                  local playerCoords = GetEntityCoords(player, false)
                  local distance = #(playerCoords - aiCoords)
                  if distance <= config.nearbyDistance then
                    table.insert(nearbyVehicles, { vehicle = aiVehicle, heading = aiHeading, dist = distance })
                    if config.debug_enabled then
                      print('Report System thread - PED vehicle found nearby (' .. aiVehicle .. ')')
                    end
                  end
                end
              end
              -- Process nearby vehicles that meet the criteria
              for _, aiData in pairs(nearbyVehicles) do
                local aiVehicle = aiData.vehicle
                local aiHeading = aiData.heading
                local distance = aiData.dist

                if aiVehicle and DoesEntityExist(aiVehicle) then
                  if config.debug_enabled then
                    print('Report System thread - checking if vehicle is stopped at red light')
                  end

                  -- Check if the AI vehicle is stopped at a red light
                  if IsVehicleStoppedAtRedLight(aiVehicle) then
                    -- Collect the player heading
                    local playerHeading = GetEntityHeading(playerveh)
                    -- Calculate the angle difference between the AI vehicle and the player's vehicle
                    local angleDiff = math.abs(playerHeading - aiHeading)
                    if config.debug_enabled then
                      print('Report System thread - Red light calculation (' .. angleDiff .. ' <= ' .. config.angleThreshold .. ')')
                    end
                    -- Ensure the angle difference is within the threshold
                    if angleDiff >= -config.angleThreshold and angleDiff <= config.angleThreshold then
                      -- The player ran a red light in front of the stopped AI vehicle
                      ShowNotification("~r~Police~s~ witnessed you running a red light!")
                      print("Police witnessed you running a red light! cop (" .. ent .. ") dist (" .. dist .. ")")
                      local policeBlip = AddBlipForEntity(ent)
                      SetBlipSprite(policeBlip, 8)
                      SetBlipColour(policeBlip, 1)
                      SetBlipAsShortRange(policeBlip, true)
                      ReportCrime(PlayerId(), 2, GetWantedLevelThreshold(1)) -- 2: Person running a red light ("5-0-5")
                    end
                  end
                end
              end

            end
          end
        end
      else -- non-moving violations (player is not in vehicle)

        -- line of sight has no limit so we manually set threshold
        if dist < config.maxLosDist then
          ---------------------------
          -- cop sees you fighting --
          ---------------------------
          if IsPedInMeleeCombat(ped) then
            ShowNotification("~r~Police~s~ witnessed you attacking someone!")
            print("Police witnessed " .. playerName .. " attacking someone! cop (" .. ent .. ") dist (" .. dist .. ")")
            local policeBlip = AddBlipForEntity(ent)
            SetBlipSprite(policeBlip, 8)
            SetBlipColour(policeBlip, 1)
            SetBlipAsShortRange(policeBlip, true)
            ReportCrime(PlayerId(), 11, GetWantedLevelThreshold(1)) -- 11: Assault on a civilian (a "2-40")
          end
        end

      end
    end
  end
end)
