--[[
Author: oleasto
Original from `https://github.com/oleasteo/koreader-screenlockpin/tree/main`
Description: Allows to display the screenlock PIN when the device is booted
]]

local UIManager = require("ui/uimanager")

local _run

local function enable(callback)
    if _run then return end
    _run = UIManager.run
    local function uiRunInjected(self)
        callback()
        return _run(self)
    end
    UIManager.run = uiRunInjected
end

local function disable()
    if not _run then return end
    UIManager.run = _run
    _run = nil
end

return {
    enable = enable,
    disable = disable,
}
