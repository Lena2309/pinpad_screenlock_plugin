--[[
Author: Lena2309, oleasteo (original inspiration)
Inspiration and original skeleton from `https://github.com/oleasteo/koreader-screenlockpin`
Description: Utility to prevent screensaver from closing and manage z-order
]]
local Device = require("device")
local Screensaver = require("ui/screensaver")
local UIManager = require("ui/uimanager")

local ScreensaverUtil = {}

local _original_setup = nil
local _original_close = nil
local _original_show = nil
local _on_resuspend = nil
local _frozen = false

-- Prevent screensaver from closing.
function ScreensaverUtil.freeze(on_resuspend)
    _on_resuspend = on_resuspend
    Device.screen_saver_lock = false
    Device.screen_saver_mode = false

    UIManager:unschedule(Screensaver.close_widget)
    Screensaver.delayed_close = nil

    if _frozen then
        return
    end
    if not _original_setup then
        _original_setup = Screensaver.setup
    end
    _original_close = Screensaver.close
    _original_show = Screensaver.show
    Screensaver.setup = function()
    end
    Screensaver.close = function()
    end

    Screensaver.show = function()
        local on_resuspend = _on_resuspend
        if on_resuspend then
            on_resuspend()
        end
        local widget = Screensaver.screensaver_widget
        if widget and UIManager:isWidgetShown(widget) then
            Device.screen_saver_mode = true
            UIManager:setDirty(widget, "full")
            return
        end
        ScreensaverUtil.unfreeze()
        Screensaver:setup()
        return Screensaver:show()
    end
    _frozen = true
end

-- Restore screensaver normal behavior
function ScreensaverUtil.unfreeze(callback)
    local orig_setup = _original_setup or (callback and Screensaver.setup) or nil
    if orig_setup then
        if callback then
            Screensaver.setup = function(...)
                Screensaver.setup = orig_setup
                callback()
                return orig_setup(...)
            end
        else
            Screensaver.setup = orig_setup
        end
        _original_setup = nil
    end
    if _original_close then
        Screensaver.close = _original_close
        _original_close = nil
    end
    if _original_show then
        Screensaver.show = _original_show
        _original_show = nil
    end
    _on_resuspend = nil
    _frozen = false
end

function ScreensaverUtil.forceClose(callback)
    ScreensaverUtil.unfreeze(callback)
    Screensaver:close_widget()
end

return ScreensaverUtil
