local config = {
  debug_enabled = true,      -- Debug logs to console
  globalSpeedLimit = 70,     -- Global speed limit for any vehicle (simpleCarHUD sets this value also)
  policePedFOV = 90.0,       -- FOV angle at which PED can see player based on heading
  TOG_WarningCounter = 0,    -- Counter for tires off the ground
  TOG_WarningThreshold = 20, -- Threshold for tires off the ground
  BO_WarningCounter = 0,     -- Counter for burnouts
  BO_WarningThreshold = 10,  -- Threshold for burnouts
  VW_WarningCounter = 0,     -- Counter for wanted vehicle
  VW_WarningThreshold = 10,  -- Threshold for wanted vehicle
  nearbyDistance = 100.0,    -- While driving, monitor vehicles nearby that are stopped at red light
  angleThreshold = 90.0,     -- If player passes this vehicle within set angle based on heading, report traffic violation
  headingThreshold = 90.0,   -- Heading comparison between AI and player vehicles for determining direction
  limitSearchVehicles = 30,  -- Only ever test a maximum of 30 vehicles nearby to player for checking red light status
  maxLosDist = 60,           -- Global maximum line of sight for Police PED's
}

-- Function for displaying notifications to player
local function ShowNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text)
  DrawNotification(false, false)
end

-- Function to round a float to the nearest decimal places
local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

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

-- Function for returning if Player has run a red light
local function hasPlayerRunRedLight(playerVeh)
  local nearbyVehicles = {}
  local playerCoords = GetEntityCoords(player, false)
  local playerHeading = GetEntityHeading(playerVeh)
  local vehicleCount = 0

  for _, aiVehicle in pairs(GetGamePool("CVehicle")) do
    if DoesEntityExist(aiVehicle) and aiVehicle ~= playerVeh then
      local aiCoords = GetEntityCoords(aiVehicle)
      local aiHeading = GetEntityHeading(aiVehicle)
      local distance = #(playerCoords - aiCoords) -- Calulate the distance from AI vehicle to player
      local directionToPlayer = playerCoords - aiCoords -- Calculate the vector from AI vehicle to player
      local forwardVector = NormalizeVector(GetEntityForwardVector(aiVehicle))
      local directionVector = NormalizeVector(directionToPlayer)

      -- Calculate the angle between AI vehicle's forward vector and direction to player
      local angle = math.deg(math.acos(DotProduct3D(forwardVector, directionVector)))

      -- Calculate the absolute heading diff
      local headingDiff = math.abs(playerHeading - aiHeading)

      if distance <= config.nearbyDistance and distance >= 5 then
        if angle <= config.fovAngle and headingDiff <= config.headingThreshold then
          if vehicleCount >= config.limitSearchVehicles then
            break  -- break once limit is hit
          end
          table.insert(nearbyVehicles, { vehicle = aiVehicle, angle = angle, headingDiff = headingDiff })
          vehicleCount = vehicleCount + 1
          if config.debug_enabled then
            print('hasPlayerRunRedLight() - PED vehicle added to check (' .. aiVehicle .. ')')
          end
        end
      end
    end
  end

  -- Read the table data of vehicles nearby
  for _, aiData in pairs(nearbyVehicles) do
    local aiVehicle = aiData.vehicle
    if DoesEntityExist(aiVehicle) and IsVehicleStoppedAtTrafficLights(aiVehicle) then
      local ent, dist = GetClosestPolicePed()
      -- dont continue if Police PED's cannot see the player
      if ent ~= -1 and dist ~= -1 then -- implies IsPlayerInPedFOV() is true
        if config.debug_enabled then
          print('hasPlayerRunRedLight() - The player ran a red light in front of a stopped AI vehicle.. and a Police PED saw you')
        end
        return true
      else
        if config.debug_enabled then
          print('hasPlayerRunRedLight() - The player ran a red light in front of a stopped AI vehicle.. BUT no Police PED are nearby')
        end
      end
    end
  end
  -- All tests have failed, return false
  return false
end

-- Find the closest Police PED within line of sight of player, and report crimes on player
-- Crime types reference: https://docs.fivem.net/natives/?_0xE9B09589827545E7
Citizen.CreateThread(function()
  while true do
    Wait(1000) -- every 1 second
    local playerPed = PlayerPedId()
    local playerName = GetPlayerName(PlayerId())
    local ent, dist = GetClosestPolicePed()

    -- dont continue if Police PED's cannot see the player
    if ent ~= -1 and dist ~= -1 then

      -- traffic violations only (is the player in a vehicle or getting in?)
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
              print('Report System thread - Police PED distance (' .. dist .. ') maxLosDist (' .. config.maxLosDist .. ')')
            end
            if vehicleClass == 14 or vehicleClass == 15 or vehicleClass == 16 or vehicleClass == 21 then
              -- vehicle is either a boat, helicopter, plane, or train... do nothing
              if config.debug_enabled then
                print('Report System thread - Police can see the player in either a boat, helicopter, plane, or train')
              end
            else

              -- cop sees you speeding in car
              if speedmph > config.globalSpeedLimit then
                local rounded_speedmph = Round(speedmph, 2)
                ShowNotification("Speeding Violation! (~r~" .. rounded_speedmph .. " mph~s~)")
                print(playerName .. " got a speeding violation! (" .. rounded_speedmph .. ") cop (" .. ent .. ") dist (" .. dist .. ")")
                ReportCrime(PlayerId(), 4, GetWantedLevelThreshold(1)) -- 4: Speeding vehicle (a "5-10")

              -- cop sees you run a red light
              elseif hasPlayerRunRedLight() then
                ShowNotification("~r~Police~s~ witnessed you running a red light!")
                print("Police witnessed you running a red light! cop (" .. ent .. ") dist (" .. dist .. ")")
                ReportCrime(PlayerId(), 2, GetWantedLevelThreshold(1)) -- 2: Person ran a red light ("5-0-5")

              -- cop sees you doing a wheelie
              elseif GetVehicleWheelieState(playerveh) == 129 then
                ShowNotification("~r~Police~s~ witnessed you doing a wheelie!")
                print(playerName .. "Police witnessed you doing a wheelie! cop (" .. ent .. ") dist (" .. dist .. ")")
                ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver

              -- cop sees you driving known stolen vehicle
              elseif IsVehicleStolen(playerveh) then
                ShowNotification("~r~Police~s~ witnessed you driving a stolen vehicle!")
                print(playerName .. "Police witnessed you driving a stolen vehicle! cop (" .. ent .. ") dist (" .. dist .. ")")
                ReportCrime(PlayerId(), 7, GetWantedLevelThreshold(1)) -- 7: Vehicle theft (a "5-0-3")

              -- cop sees you hit any entity with vehicle
              elseif HasEntityCollidedWithAnything(playerveh) then
                ShowNotification("~r~Police~s~ witnessed bad driving!")
                print(playerName .. "Police witnessed bad driving! cop (" .. ent .. ") dist (" .. dist .. ")")
                ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver

              -- cop sees you driving a known wanted vehicle (evaded successfully)
              elseif IsVehicleWanted(playerveh) then
                config.VW_WarningCounter = config.VW_WarningCounter + 1
                if config.VW_WarningCounter >= config.VW_WarningThreshold then
                  ShowNotification("~r~Police~s~ witnessed you driving a known wanted vehicle!")
                  print("Police witnessed " .. playerName .. " driving a known wanted vehicle! cop (" .. ent .. ") dist (" .. dist .. ")")
                  ReportCrime(PlayerId(), 9, GetWantedLevelThreshold(1)) -- 9: ???
                  config.VW_WarningCounter = 0 -- reset counter
                end

              -- cop sees you burning out
              elseif IsVehicleInBurnout(playerveh) then
                config.BO_WarningCounter = config.BO_WarningCounter + 1
                if config.BO_WarningCounter >= config.BO_WarningThreshold then
                  ShowNotification("~r~Police~s~ witnessed your burnout!")
                  print("Police witnessed " .. playerName .. " doing a burnout! cop (" .. ent .. ") dist (" .. dist .. ")")
                  ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver
                  config.BO_WarningCounter = 0 -- reset counter
                end

              -- cop sees your vehicle no on all wheels (air time)
              elseif not IsVehicleOnAllWheels(playerveh) then
                config.TOG_WarningCounter = config.TOG_WarningCounter + 1
                if config.TOG_WarningCounter >= config.TOG_WarningThreshold then
                  ShowNotification("~r~Police~s~ witnessed reckless driving!")
                  print("Police witnessed tires off ground! cop (" .. ent .. ") dist (" .. dist .. ")")
                  ReportCrime(PlayerId(), 3, GetWantedLevelThreshold(1)) -- 3: Reckless driver
                  config.TOG_WarningCounter = 0 -- reset counter
                end

              end

            end
          end
        end
      else -- non-moving violations (player is not in vehicle)

        -- line of sight has no limit so we manually set threshold
        if dist < config.maxLosDist then
          -- cop sees you fighting
          if IsPedInMeleeCombat(ped) then
            ShowNotification("~r~Police~s~ witnessed you attacking someone!")
            print("Police witnessed " .. playerName .. " attacking someone! cop (" .. ent .. ") dist (" .. dist .. ")")
            ReportCrime(PlayerId(), 11, GetWantedLevelThreshold(1)) -- 11: Assault on a civilian (a "2-40")
          end
        end

      end
    end
  end
end)
