-- Global config options
local config = {
    debug_enabled       = true,            -- Enable debug messages in console

    -- Native ambient configs
    ambientEvents       = true,            -- Enable built-in ambient events for realism
    pedFrequency        = 1.0,             -- Built-in frequency of PED (max value 1.0)
    trafficFrequency    = 1.0,             -- Built-in frequency of traffic (max value 1.0)

    -- Police PED spawner
    extraPoliceSpawns   = true,            -- Enable additional Police PED spawner
	maxPoliceSpawned    = 5,               -- Set the maximum number of cops to be spawned in area
	copSpawnDistance    = 100.0,           -- Set the distance from the player where cops will spawn
	copDespawnDistance  = 750.0,           -- Set the distance when cops are de-spawned
	copDrivingStyle     = 1074528677,      -- https://vespura.com/fivem/drivingstyle/
	showBlipsOnCops     = false,           -- show a constant blip on cops spawned from this script

    -- PED chat filter
    filterPedChat       = true,            -- Enable a filter for managing the phrases a PED can say
    caseInsensitive     = true,            -- Set to true to make filtering case-insensitive
    filteredWords       = {                -- Add the words you want to filter
        "bitch",
        "cunt",
        "fuck",
    },
    replacementPhrase   = 'I love you',    -- Default phrase for PEDs to read when filtered words are encountered
}

-- Function to replace a specific phrase a PED is going to say with another
function ReplacePedPhrase(ped, originalPhrase, replacementString)
    local dialogues = Citizen.InvokeNative(0x049E937F18F4020C, ped, false, true)

    if dialogues ~= nil then
        for _, dialogue in pairs(dialogues) do
            if config.debug_enabled then
                print('ReplacePedPhrase() - ' .. dialogue.text)
            end
            if dialogue.text == originalPhrase then
                dialogue.text = replacementString
            end
        end
    end
end

local spawnedPolice = {}
local policeBlips = {}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- once per second
        ----------------------------------
        ----------------------------------
        ----------------------------------
        -- ensure ambients spawn
        SetCreateRandomCops(config.ambientEvents)
        SetCreateRandomCopsNotOnScenarios(config.ambientEvents)
        SetCreateRandomCopsOnScenarios(config.ambientEvents)
        SetGarbageTrucks(config.ambientEvents)
        SetRandomBoats(config.ambientEvents)
        ----------------------------------
        ----------------------------------
        ----------------------------------
        -- https://docs.fivem.net/natives/#_0x95E3D6257B166CF2
        -- https://docs.fivem.net/natives/#_0x7A556143A1C03898
        SetPedDensityMultiplierThisFrame(config.pedFrequency) -- 0.0 = no peds, 1.0 = normal peds
        SetScenarioPedDensityMultiplierThisFrame(config.pedFrequency, config.pedFrequency)
        ----------------------------------
        ----------------------------------
        ----------------------------------
        -- https://docs.fivem.net/natives/?_0x90B6DA738A9A25DA
        -- https://docs.fivem.net/natives/#_0xB3B3359379FE77D3
        -- https://docs.fivem.net/natives/#_0xEAE6DCC7EEE3DB1D
        -- https://docs.fivem.net/natives/#_0x245A6883D966D537
        SetAmbientVehicleRangeMultiplierThisFrame(config.trafficFrequency) -- 0.0 = no vehicles, 1.0 = normal vehicles
        SetRandomVehicleDensityMultiplierThisFrame(config.trafficFrequency)
        SetParkedVehicleDensityMultiplierThisFrame(config.trafficFrequency)
        SetVehicleDensityMultiplierThisFrame(config.trafficFrequency)
        ----------------------------------
        ----------------------------------
        ----------------------------------
        -- Spawn police officers in vehicles and add a blip
        if config.extraPoliceSpawns then
            if IsPedInAnyVehicle(PlayerPedId(), false) then
                local playerPed = PlayerId()
                local playerPos = GetEntityCoords(GetPlayerPed(-1))

                -- Check the maximum number of cops spawned
                if #spawnedPolice < config.maxPoliceSpawned and GetDistanceBetweenCoords(playerPos.x, playerPos.y, playerPos.z, spawnX, spawnY, playerPos.z, true) > config.copSpawnDistance then
                    local vehicleModel = "police" -- Adjust the police vehicle model as needed
                    local pedModel = "s_m_y_cop_01" -- Adjust the police ped model as needed
                
                    RequestModel(vehicleModel)
                    RequestModel(pedModel)
                
                    while not HasModelLoaded(vehicleModel) or not HasModelLoaded(pedModel) do
                        Citizen.Wait(1)
                    end

                    -- Generate a random spawn location far from the player
                    local spawnX, spawnY = playerPos.x, playerPos.y
                    while GetDistanceBetweenCoords(playerPos.x, playerPos.y, 0.0, spawnX, spawnY, 0.0, true) < config.copSpawnDistance do
                        spawnX = playerPos.x + math.random(-500, 500) -- Adjust the range as needed
                        spawnY = playerPos.y + math.random(-500, 500) -- Adjust the range as needed
                    end

                    local vehicle = CreateVehicle(vehicleModel, spawnX, spawnY, playerPos.z, 0.0, true, true)
                    local ped = CreatePedInsideVehicle(vehicle, 6, pedModel, -1, true, true)
                    SetEntityAsMissionEntity(vehicle, true, true)
                    SetEntityAsMissionEntity(ped, true, true)

                    if config.debug_enabled then
                        print('Main Thread - Police PED created (' .. ped .. ')')
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
                        SetBlipSprite(blip, 56) -- Set the blip sprite to police blip
                        SetBlipScale(blip, 0.5)
                        table.insert(policeBlips, blip)
                    end
                end

                -- Check for despawning
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
        ----------------------------------
        ----------------------------------
        ----------------------------------
    end
end)

-- Language filter needs to run with its own thread and no wait time
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        ----------------------------------
        ----------------------------------
        ----------------------------------
        -- Check and filter PED chat for specific words
        if config.filterPedChat then
            local playerPos = GetEntityCoords(GetPlayerPed(-1))
            local ped = GetClosestPed(playerPos.x, playerPos.y, playerPos.z, 5.0, 0, 71)

            if DoesEntityExist(ped) then
                local pedHandle = NetworkGetNetworkIdFromEntity(ped)
                --local dialogues = Citizen.InvokeNative(0x049E937F18F4020C, pedHandle, false, true)
                local dialogues = IsPedInCurrentConversation(pedHandle)

                if dialogues ~= nil then
                    for _, dialogue in pairs(dialogues) do
                        local filteredText = dialogue.text
                        print('filteredText: ' .. filteredText)

                        -- Make the filtering case-insensitive if needed
                        if config.caseInsensitive then
                            filteredText = string.lower(filteredText)
                        end

                        for _, word in ipairs(config.filteredWords) do
                            local wordToCheck = word

                            -- Make the filtering case-insensitive if needed
                            if config.caseInsensitive then
                                wordToCheck = string.lower(wordToCheck)
                            end

                            if string.find(filteredText, wordToCheck, 1, true) then
                                print('Matched (' .. wordToCheck .. ') in phrase (' .. filteredText .. ')')
                                -- The dialogue contains a filtered word, you can take action here
                                -- For example, you can mute the PED or replace the phrase
                                -- This is just a placeholder action, you should implement your desired logic
                                Citizen.InvokeNative(0xD3B5AFC4E1D15F4D, pedHandle, "GENERIC_CURSE_MED", 0, 1, 1)
                                Citizen.InvokeNative(0x742A6D07CEA95D48, pedHandle, "SHAME", 1)
                                Citizen.Wait(5000)

                            end
                        end
                    end
                end
            end
        end
        ----------------------------------
        ----------------------------------
        ----------------------------------
    end
end)
