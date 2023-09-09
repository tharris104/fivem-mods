-- Unset default built-in controls for FiveM --
local controlCleared = false
local controlKeyName = "INPUT_VEH_FLY_SELECT_PREV_WEAPON" -- 116
local controlKeyHash = GetHashKey(controlKeyName)
local replaceKeyName = "replace_with_something" -- https://docs.fivem.net/docs/game-references/controls/#controls
local replaceKeyHash = GetHashKey(replaceKeyName)
-- Unset the control hash 116 (currently used by simpleCarHUD)
-- Main thread checking if player is in a bounty area
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(5000) -- check every 5 seconds
    if not controlCleared then
      N_0x06462a961e94b67c(controlKeyHash) -- https://docs.fivem.net/natives/?_0x06462A961E94B67C
      print('cleared keybind for ' .. controlKeyName)

      -- Disabling this - not sure if its even working or not
      -- N_0x5b73c77d9eb66e24(controlKeyHash, replaceKeyHash)

      controlCleared = true
    end
  end
end)
