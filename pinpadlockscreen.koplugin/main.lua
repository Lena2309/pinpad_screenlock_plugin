--[[
Author: yogi81 (original inspiration and main skeleton), Lena2309 (adaptation and improvements), oleasteo (on boot execution)
Inspiration and original skeleton from `https://github.com/yogi81/screenlock_koreader_plugin/tree/main`
On Boot Execution from `https://github.com/oleasteo/koreader-screenlockpin/tree/main`
Description: implements a screen lock mechanism for KOReader
using a PIN pad interface. Also adds a menu entry in Settings -> Screen
]]

local Dispatcher = require("dispatcher")
local PinPadDialog = require("ui/pinpaddialog")
local EventListener = require("ui/widget/eventlistener")
local _ = require("gettext")
local UIManager = require("ui/uimanager")
local onBootHook = require("hook/onboot")
local MenuEntryItems = require("menu/menuentryitems")

local LoggerFactory = require("logger")
local log = (type(LoggerFactory) == "function" and LoggerFactory("FolderCover"))
    or (LoggerFactory and LoggerFactory.new and LoggerFactory:new("FolderCover"))
    or { dbg = function() end, info = print, warn = print, err = print }

-- Default settings
if G_reader_settings:hasNot("pinpadlock_pin_code") then
    G_reader_settings:saveSetting("pinpadlock_pin_code", "1234")
end
if G_reader_settings:hasNot("pinpadlock_activated") then
    G_reader_settings:makeFalse("pinpadlock_activated")
end
-- ... (rest of the settings are the same, omitted for brevity)
if G_reader_settings:hasNot("pinpadlock_show_message") then
    G_reader_settings:makeFalse("pinpadlock_show_message")
end
if G_reader_settings:hasNot("pinpadlock_message") then
    G_reader_settings:saveSetting("pinpadlock_message", "Locked")
end
if G_reader_settings:hasNot("pinpadlock_message_position") then
    G_reader_settings:saveSetting("pinpadlock_message_position", "top")
end
if G_reader_settings:hasNot("pinpadlock_message_alignment") then
    G_reader_settings:saveSetting("pinpadlock_message_alignment", "center")
end


local ScreenLock = EventListener:extend {}

------------------------------------------------------------------------------
-- REGISTER DISPATCHER ACTIONS
------------------------------------------------------------------------------
function ScreenLock:onDispatcherRegisterActions()
    Dispatcher:registerAction("screenlock_pin_pad_lock_screen", {
        category    = "none",
        event       = "LockScreenPinPad",
        title       = _("Lock Screen (PinPad)"),
        filemanager = true,
        device      = true,
    })
end

------------------------------------------------------------------------------
-- INIT & WAKE-UP HANDLING (NOW WITH ON-BOOT HOOK)
------------------------------------------------------------------------------

onBootHook.enable(function() ScreenLock:onResume() end)

function ScreenLock:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)

    local self_ref = self
    if G_reader_settings:isTrue("pinpadlock_activated") then
        self_ref:lockScreen()
    end

    return self
end

function ScreenLock:onResume()
    if self.pinPadDialog then
        self.pinPadDialog:close()
        self.pinPadDialog = nil
    end

    if G_reader_settings:isTrue("pinpadlock_activated") then
        self:lockScreen()
    end
end

------------------------------------------------------------------------------
-- LOCK SCREEN
------------------------------------------------------------------------------
function ScreenLock:lockScreen()
    UIManager:nextTick(function()
        if not self.pinPadDialog then
            self.pinPadDialog = PinPadDialog:init()
            self.pinPadDialog:showPinPad()
        end
    end)
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
    menu_items.pinpad = MenuEntryItems
end

return ScreenLock
