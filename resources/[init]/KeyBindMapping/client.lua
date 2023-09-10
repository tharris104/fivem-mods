----------------------------------------
-- Custom Key Bind Mappings for FiveM --
----------------------------------------

local controlsBound = false -- trigger to only apply on startup

local controlKeyName = "INPUT_VEH_FLY_SELECT_PREV_WEAPON" -- 116
local controlKeyHash = GetHashKey(controlKeyName)
local replaceKeyName = "replace_with_something" -- https://docs.fivem.net/docs/game-references/controls/#controls
local replaceKeyHash = GetHashKey(replaceKeyName)

-- Unset the control hash 116 (currently used by simpleCarHUD)
-- Main thread checking if player is in a bounty area
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(5000) -- check every 5 seconds
    if not controlsBound then
      -- DISABLED FOR NOW

      -- Unset a control key
      --N_0x06462a961e94b67c(controlKeyHash) -- https://docs.fivem.net/natives/?_0x06462A961E94B67C
      --print('cleared keybind for ' .. controlKeyName)

      -- Replace control key hash native function
      --N_0x5b73c77d9eb66e24(controlKeyHash, replaceKeyHash) -- https://docs.fivem.net/natives/?_0x5B73C77D9EB66E24
      --print('replaced keybind ' .. controlKeyName .. ' with ' .. replaceKeyName)

      controlsBound = true

    end
  end
end)
