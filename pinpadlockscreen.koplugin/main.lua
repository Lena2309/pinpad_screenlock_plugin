--[[
Author: yogi81 (original), Lena2309 (adaptation and improvements)
Original from `https://github.com/yogi81/screenlock_koreader_plugin/tree/main`
Description: implements a screen lock mechanism for KOReader
using a PIN pad interface.
]]

local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local PinPadDialog = require("ui/pinpaddialog") -- Custom module for PIN pad UI
local _ = require("gettext")

local ScreenLock = WidgetContainer:extend {
    name = "screenlock_pinpad",
    is_doc_only = false,
    locked = false,      -- Tracks the locked state
    hide_content = true, -- Hide screen content before PIN is entered
}

------------------------------------------------------------------------------
-- REGISTER DISPATCHER ACTIONS
------------------------------------------------------------------------------
function ScreenLock:onDispatcherRegisterActions()
    Dispatcher:registerAction("screenlock_pin_pad_lock_screen", {
        category = "none",
        event = "LockScreenPinPad",
        title = _("Lock Screen (PinPad)"),
        filemanager = true,
    })
end

------------------------------------------------------------------------------
-- INIT (including wake-up handling via onResume)
------------------------------------------------------------------------------
function ScreenLock:init()
    -- 1) Register dispatcher action
    self:onDispatcherRegisterActions()

    -- 2) Add to main menu
    self.ui.menu:registerToMainMenu(self)

    -- 3) Override onResume to handle device wake-up
    function self:onResume()
        if self.pinPadDialog then
            self.pinPadDialog:close()
        end
        if not self.locked then
            self:lockScreen()
        end
        self.locked = false
    end
end

------------------------------------------------------------------------------
-- LOCK SCREEN
------------------------------------------------------------------------------
function ScreenLock:lockScreen()
    self.locked = true
    self.pinPadDialog = PinPadDialog:init()
    self.pinPadDialog:showPinPad()
end

------------------------------------------------------------------------------
-- DISPATCHER HANDLER
------------------------------------------------------------------------------
function ScreenLock:onLockScreen()
    self:lockScreen()
    return true
end

------------------------------------------------------------------------------
-- MAIN MENU ENTRY
------------------------------------------------------------------------------
function ScreenLock:addToMainMenu(menu_items)
    menu_items.screenlock_lock = {
        text = _("Lock Pin Pad"),
        callback = function()
            self:lockScreen()
        end
    }
end

return ScreenLock
