-------------------------------------------------------------------------------------
-------- Configure PED density, spawn ambient events, spawn more Police      --------
-------------------------------------------------------------------------------------
-- Global config options
local config = {
  debug_enabled       = true,            -- Enable debug messages in console
  ambientEvents       = false,            -- Native ambients - Enable built-in ambient events for realism
  pedFrequency        = 0.0,             -- Native ambients - Built-in frequency of PED (0.0 = no peds, 1.0 = normal peds)
  trafficFrequency    = 0.0,             -- Native ambients - Built-in frequency of traffic (0.0 = no traffic, 1.0 = normal traffic)
  extraPoliceSpawns   = true,            -- Police PED spawner - Enable additional Police PED spawner
  maxPoliceSpawned    = 5,               -- Police PED spawner - Set the maximum number of cops to be spawned in area
  copSpawnDistance    = 75.0,            -- Police PED spawner - Set the distance from the player where cops will spawn
  copDespawnDistance  = 750.0,           -- Police PED spawner - Set the distance when cops are de-spawned
  copDrivingStyle     = 1074528677,      -- Police PED spawner - https://vespura.com/fivem/drivingstyle/
  showBlipsOnCops     = true,            -- Police PED spawner - show a constant blip on cops spawned from this script
  filterPedChat       = true,            -- PED chat filter - Enable a filter for managing the phrases a PED can say
  caseInsensitive     = true,            -- PED chat filter - Set to true to make filtering case-insensitive
  replacementPhrase   = 'I love you',    -- PED chat filter - Default phrase for PEDs when filtered words are encountered
  filteredWords       = {                -- PED chat filter - Add the words you want to filter
    "bitch",
    "cunt",
    "fuck",
  },
}
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Local tables for storing data
local spawnedPolice = {}
local policeBlips = {}


-- Function that returns a valid Z coordinate only if that point is not in water
local function GetGroundZ(coords)
  local result, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, true) -- ignoreWater = true
  return result, vector3(coords.x, coords.y, groundZ)
end


-- Function that returns randomly generated coords within configured spwan distance
local function GetRandomCoordsNearby(coords)
  local spawnX, spawnY = coords.x, coords.y
  while GetDistanceBetweenCoords(coords.x, coords.y, 0.0, spawnX, spawnY, 0.0, true) < config.copSpawnDistance do
    spawnX = coords.x + math.random(-500, 500) -- Adjust the range as needed
    spawnY = coords.y + math.random(-500, 500) -- Adjust the range as needed
  end
  return vector3(spawnX, spawnY, coords.z)
end


-- Function that returns a vehicles heading nearby to coords passed in
local function GetNearbyVehicleHeading(coords)
  local closestVehicle = nil
  local closestDistance = math.huge
  local vehicles = GetGamePool("CVehicle")
  for _, vehicle in ipairs(vehicles) do
    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, true)
    if distance < closestDistance then
      closestVehicle = vehicle
      closestDistance = distance
    end
  end
  if closestVehicle then
    local vehicleHeading = GetEntityHeading(closestVehicle)
    return vehicleHeading
  else
    return 0.0 -- Default heading if no nearby vehicles found
  end
end


-- Main thread runs once per second
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    -- Ensure ambients spawn
    SetCreateRandomCops(config.ambientEvents) -- https://docs.fivem.net/natives/?_0x102E68B2024D536D
    SetCreateRandomCopsNotOnScenarios(config.ambientEvents) --https://docs.fivem.net/natives/?_0x8A4986851C4EF6E7
    SetCreateRandomCopsOnScenarios(config.ambientEvents) -- https://docs.fivem.net/natives/?_0x444CB7D7DBE6973D
    SetGarbageTrucks(config.ambientEvents) -- https://docs.fivem.net/natives/?_0x2AFD795EEAC8D30D
    SetRandomBoats(config.ambientEvents) -- https://docs.fivem.net/natives/?_0x84436EC293B1415F
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    -- Modify built-in ped density
    SetPedDensityMultiplierThisFrame(config.pedFrequency) -- https://docs.fivem.net/natives/#_0x95E3D6257B166CF2
    SetScenarioPedDensityMultiplierThisFrame(config.pedFrequency, config.pedFrequency) -- https://docs.fivem.net/natives/#_0x7A556143A1C03898
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    -- Modify built-in traffic density
    SetAmbientVehicleRangeMultiplierThisFrame(config.trafficFrequency) -- https://docs.fivem.net/natives/?_0x90B6DA738A9A25DA
    SetRandomVehicleDensityMultiplierThisFrame(config.trafficFrequency) -- https://docs.fivem.net/natives/#_0xB3B3359379FE77D3
    SetParkedVehicleDensityMultiplierThisFrame(config.trafficFrequency) -- https://docs.fivem.net/natives/#_0xEAE6DCC7EEE3DB1D
    SetVehicleDensityMultiplierThisFrame(config.trafficFrequency) -- https://docs.fivem.net/natives/#_0x245A6883D966D537
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    -- Spawn police officers in vehicles and add a blip
    if config.extraPoliceSpawns then
      local playerPos = GetEntityCoords(GetPlayerPed(-1))

      -- Check the maximum number of cops spawned
      if #spawnedPolice < config.maxPoliceSpawned and GetDistanceBetweenCoords(playerPos.x, playerPos.y, playerPos.z, spawnX, spawnY, playerPos.z, true) > config.copSpawnDistance then
        local vehicleModel = "police3" -- Adjust the police vehicle model as needed
        local pedModel = "s_m_y_cop_01" -- Adjust the police ped model as needed todo: add more models

        RequestModel(vehicleModel)
        RequestModel(pedModel)

        while not HasModelLoaded(vehicleModel) or not HasModelLoaded(pedModel) do
          Citizen.Wait(1000)
        end

        -- Initializing random spawn location
        local isValidLocation, modifiedCoords = false, vector3(0.0, 0.0, 0.0)

        -- Generate a random spawn location away from the player
        while not isValidLocation do
          local PoliceCoords = GetRandomCoordsNearby(playerPos)
          isValidLocation, modifiedCoords = GetGroundZ(PoliceCoords)
          if config.debug_enabled then
            if isValidLocation then
              print("Valid Location: ", modifiedCoords.x, modifiedCoords.y, modifiedCoords.z)
            else
              print("Invalid Location: In water")
            end
          end
        end

        local closestHeading = GetNearbyVehicleHeading(playerPos)
        local vehicle = CreateVehicle(vehicleModel, modifiedCoords.x, modifiedCoords.y, modifiedCoords.z, closestHeading, true, true)
        local ped = CreatePedInsideVehicle(vehicle, 6, pedModel, -1, true, true)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetEntityAsMissionEntity(ped, true, true)

        if DoesEntityExist(ped) and DoesEntityExist(vehicle) then
          if config.debug_enabled then
            print('Police PED created (' .. ped .. ') in vehicle (' .. vehicle .. ') at (' .. modifiedCoords.x .. ',' .. modifiedCoords.y .. ',' .. modifiedCoords.z .. ')')
          end

          -- Make the police ped enter the vehicle
          TaskWarpPedIntoVehicle(ped, vehicle, -1)

          -- Make the vehicle patrol randomly
          local heading = GetEntityHeading(vehicle)
          TaskVehicleDriveWander(ped, vehicle, 20.0, config.copDrivingStyle, heading)

          -- Record and log spawned cop
          table.insert(spawnedPolice, {vehicle, ped})

          -- Add a blip to the police vehicle
          if config.showBlipsOnCops then
            local blip = AddBlipForEntity(vehicle)
            SetBlipAsFriendly(false)
            SetBlipSprite(blip, 56) -- Set the blip sprite to police blip
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.5)
            table.insert(policeBlips, blip)
          end
        end
      end

      -- Check if despawning is needed
      if #spawnedPolice > 0 then
        for i, policeData in ipairs(spawnedPolice) do
          local vehicle = policeData[1] -- Access the vehicle directly
          local ped = policeData[2] -- Access the ped directly
          local distance = GetDistanceBetweenCoords(playerPos.x, playerPos.y, playerPos.z, GetEntityCoords(vehicle))
          if distance > config.copDespawnDistance then
            if config.showBlipsOnCops then
              local blip = policeBlips[i]
              RemoveBlip(blip)
              table.remove(policeBlips, i)
            end
            DeleteEntity(vehicle)
            DeleteEntity(ped)
            table.remove(spawnedPolice, i)
          end
        end
      end

    end
  end
end)

---- Function to replace a specific phrase a PED is going to say with another todo: overwrite animation? repace with other phrase?
--local function ReplacePedPhrase(ped, originalPhrase, replacementString)
--  local dialogues = Citizen.InvokeNative(0x049E937F18F4020C, ped, false, true)
--  print(dialogues)
--
--  if dialogues ~= nil then
--    for _, dialogue in pairs(dialogues) do
--      if config.debug_enabled then
--        print('ReplacePedPhrase() - ' .. dialogue.text)
--      end
--      if dialogue.text == originalPhrase then
--        dialogue.text = replacementString
--      end
--    end
--  end
--end

---- Language filter needs to run with its own thread and no wait time
--Citizen.CreateThread(function()
--  while true do
--    Citizen.Wait(0)
--    ----------------------------------
--    ----------------------------------
--    ----------------------------------
--    -- Check and filter PED chat for specific words
--    if config.filterPedChat then
--      local playerPos = GetEntityCoords(GetPlayerPed(-1))
--      local ped = GetClosestPed(playerPos.x, playerPos.y, playerPos.z, 5.0, 0, 71)
--
--      if DoesEntityExist(ped) then
--        local pedHandle = NetworkGetNetworkIdFromEntity(ped)
--
--        -- todo: wip.. prob not even working
--        if IsPedInCurrentConversation(pedHandle) then
--          for _, dialogue in pairs(dialogues) do
--            local filteredText = dialogue.text
--            print('filteredText: ' .. filteredText)
--
--            -- Make the filtering case-insensitive if needed
--            if config.caseInsensitive then
--              filteredText = string.lower(filteredText)
--            end
--
--            for _, word in ipairs(config.filteredWords) do
--              local wordToCheck = word
--
--              -- Make the filtering case-insensitive if needed
--              if config.caseInsensitive then
--                wordToCheck = string.lower(wordToCheck)
--              end
--
--              if string.find(filteredText, wordToCheck, 1, true) then
--                print('Matched (' .. wordToCheck .. ') in phrase (' .. filteredText .. ')')
--                -- The dialogue contains a filtered word, you can take action here
--                -- For example, you can mute the PED or replace the phrase
--                -- This is just a placeholder action, you should implement your desired logic
--                ReplacePedPhrase(ped, filteredText, replacementString)
--                --Citizen.InvokeNative(0xD3B5AFC4E1D15F4D, pedHandle, "GENERIC_CURSE_MED", 0, 1, 1)
--                --Citizen.InvokeNative(0x742A6D07CEA95D48, pedHandle, "SHAME", 1)
--                Citizen.Wait(5000)
--              end
--            end
--          end
--        end
--      end
--    end
--    ----------------------------------
--    ----------------------------------
--    ----------------------------------
--  end
--end)
