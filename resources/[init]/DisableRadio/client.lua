local JustGotIn = false

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsPedInAnyVehicle(PlayerPedId(), false) then
			if IsPlayerVehRadioEnable() then
				local veh = GetVehiclePedIsUsing(GetPlayerPed())
				if GetPlayerRadioStationName() ~= nil then
					SetVehRadioStation(veh, "OFF")
				end
			end
			JustGotIn = true
		end

		if not IsPedInAnyVehicle(PlayerPedId(), false) then
			JustGotIn = false
		end

		-- Check if the player is in a vehicle
		DisableControlAction(0, 116, true) -- 116 corresponds to INPUT_VEH_SELECT_PREV_WEAPON

	end
end)
