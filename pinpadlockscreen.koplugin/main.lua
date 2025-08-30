--[[
Author: yogi81 (original), Lena2309 (adaptation and improvements)
Original from `https://github.com/yogi81/screenlock_koreader_plugin/tree/main`
Description: implements a screen lock mechanism for KOReader
using a PIN pad interface. Also adds a menu entry in Settings -> Screen
]]

local Dispatcher = require("dispatcher")
local PinPadDialog = require("ui/pinpaddialog")
local PinPadMenuEntry = require("ui/pinpadmenuentry")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

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

local ScreenLock = WidgetContainer:extend {
    name = "pinpadlock",
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
    self.ui.menu:registerToMainMenu(self)
    return self
end

function ScreenLock:onResume()
    if self.pinPadDialog then
        self.pinPadDialog:close()
        self.pinPadDialog = nil
    end
    if not self.locked and G_reader_settings:isTrue("pinpadlock_activated") then
        self:lockScreen()
    end
    self.locked = false
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
    menu_items.pinpad = {
        text = _("PIN Pad Lock"),
        sorting_hint = "screen",
        sub_item_table = {
            {
                text = _("Activated"),
                checked_func = function()
                    return PinPadMenuEntry:pinPadEnabled()
                end,
                callback = function()
                    G_reader_settings:toggle("pinpadlock_activated")
                end,
                separator = true,
            },
            {
                text = _("Manage PIN Code"),
                keep_menu_open = true,
                sub_item_table = {
                    {
                        text = _("Change PIN Code"),
                        callback = function()
                            PinPadMenuEntry:changePinCode()
                        end
                    },
                    {
                        text = _("Reset PIN Code"),
                        callback = function()
                            PinPadMenuEntry:resetPinCode()
                        end,
                    },
                }
            },
            {
                text = _("PIN pad lock message"),
                separator = true,
                sub_item_table = {
                    {
                        text = _("Add custom message to lock"),
                        checked_func = function()
                            return PinPadMenuEntry:showMessageEnabled()
                        end,
                        callback = function()
                            G_reader_settings:toggle("pinpadlock_show_message")
                        end,
                        separator = true,
                    },
                    {
                        text = _("Edit PIN pad lock message"),
                        enabled_func = function()
                            return PinPadMenuEntry:showMessageEnabled()
                        end,
                        keep_menu_open = true,
                        callback = function()
                            PinPadMenuEntry:setMessage()
                        end,
                    },
                    {
                        text = _("Message position"),
                        enabled_func = function()
                            return PinPadMenuEntry:showMessageEnabled()
                        end,
                        sub_item_table = {
                            PinPadMenuEntry:genRadioMenuItem(_("Top"), "pinpadlock_message_position", "top"),
                            PinPadMenuEntry:genRadioMenuItem(_("Middle"), "pinpadlock_message_position", "middle"),
                            PinPadMenuEntry:genRadioMenuItem(_("Bottom"), "pinpadlock_message_position", "bottom"),
                        },
                    },
                    {
                        text = _("Message alignment"),
                        enabled_func = function()
                            return PinPadMenuEntry:showMessageEnabled()
                        end,
                        sub_item_table = {
                            PinPadMenuEntry:genRadioMenuItem(_("Left"), "pinpadlock_message_alignment", "left"),
                            PinPadMenuEntry:genRadioMenuItem(_("Center"), "pinpadlock_message_alignment", "center"),
                            PinPadMenuEntry:genRadioMenuItem(_("Right"), "pinpadlock_message_alignment", "right"),
                        },
                    },
                }
            },
            {
                text = _("Check for updates"),
                callback = function()
                    PinPadMenuEntry:checkForUpdates()
                end,
            }
        }
    }
end

return ScreenLock
