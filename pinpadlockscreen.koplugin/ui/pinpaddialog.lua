--[[
Author: Lena2309
Description: represents a PIN pad interface and its behavior within KOReader.
It handles user input, PIN validation, and UI interactions.
]]

local Button = require("ui/widget/button")
local PinPadButtonDialog = require("ui/pinpadbuttondialog")
local FrameContainer = require("ui/widget/container/framecontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local LOCKED_TEXT = _("Enter your PIN")
local CONFIRM_CURRENT_CODE_TEXT = _("Enter the current PIN Code")
local NEW_CODE_TEXT = _("Enter the new PIN Code")

local MAX_TRIES_LIMIT = 3
local TIMEOUT_TIME = 30

if G_reader_settings:hasNot("current_tries_number") then
    G_reader_settings:saveSetting("current_tries_number", 0)
end
if G_reader_settings:hasNot("block_start_time") then
    G_reader_settings:saveSetting("block_start_time", 0)
end
if G_reader_settings:hasNot("currently_blocked") then
    G_reader_settings:makeFalse("currently_blocked")
end

local PinPadDialog = FrameContainer:extend {
    icon = "lock",
    stage = "locked", -- "confirm_current_code" or "enter_new_code"
}

function PinPadDialog:init()
    self:setDialogText()
    self.pin = ""
    self.buttons = self:initializeButtons()
    return self
end

function PinPadDialog:setDialogText()
    if self.stage == "locked" then
        self.dialog_text = LOCKED_TEXT
    elseif self.stage == "confirm_current_code" then
        self.dialog_text = CONFIRM_CURRENT_CODE_TEXT
    else
        self.dialog_text = NEW_CODE_TEXT
    end
end

function PinPadDialog:createButton(text, callback, hold_callback)
    local button = Button:new {
        text = text,
        callback = callback,
        hold_callback = hold_callback,
    }
    return button
end

function PinPadDialog:initializeButtons()
    local ref_self = self
    local buttons = {
        {
            self:createButton("1", function() ref_self:onAppendToPin("1") end),
            self:createButton("2", function() ref_self:onAppendToPin("2") end),
            self:createButton("3", function() ref_self:onAppendToPin("3") end),
        },
        {
            self:createButton("4", function() ref_self:onAppendToPin("4") end),
            self:createButton("5", function() ref_self:onAppendToPin("5") end),
            self:createButton("6", function() ref_self:onAppendToPin("6") end),
        },
        {
            self:createButton("7", function() ref_self:onAppendToPin("7") end),
            self:createButton("8", function() ref_self:onAppendToPin("8") end),
            self:createButton("9", function() ref_self:onAppendToPin("9") end),
        },
        {
            self:createButton("Cancel", function() ref_self:onDelete() end, function() ref_self:onCancel() end),
            self:createButton("0", function() ref_self:onAppendToPin("0") end),
            self:createButton("OK", function() ref_self:onOk() end),
        }
    }
    return buttons
end

function PinPadDialog:isBlocked()
    local block_start = G_reader_settings:readSetting("block_start_time") or 0
    if block_start == 0 then
        return false
    end

    local elapsed = os.time() - block_start
    if elapsed >= TIMEOUT_TIME then
        -- Timeout expired, unblockS
        G_reader_settings:makeFalse("currently_blocked")
        G_reader_settings:saveSetting("block_start_time", 0)
        G_reader_settings:saveSetting("current_tries_number", 0)
        return false
    else
        self.remaining_block_time = TIMEOUT_TIME - elapsed
        return true
    end
end

function PinPadDialog:showPinPad()
    if self.stage == "locked" then
        self.dialog = PinPadButtonDialog:new {
            icon = self.icon,
            title = self.dialog_text,
            title_align = "center",
            use_info_style = false,
            buttons = self.buttons,
            dismissable = false,
        }
    else
        self.dialog = PinPadButtonDialog:new {
            icon = self.icon,
            title = self.dialog_text,
            title_align = "center",
            use_info_style = false,
            buttons = self.buttons,
            dismissable = true,
            override_show_message = true,
        }
    end
    UIManager:show(self.dialog)

    -- overlay the blocking message if needed
    if self.stage == "locked" and self:isBlocked() then
        self.blocking_dialog = InfoMessage:new {
            text = _("Too many failed attempts. Wait " .. self.remaining_block_time .. " seconds."),
            timeout = self.remaining_block_time,
            dismissable = false,
            dismiss_callback = function()
                UIManager:scheduleIn(0, function()
                    self:refreshUI()
                end)
            end,
        }
        UIManager:show(self.blocking_dialog)
    end
end

function PinPadDialog:reset()
    self.pin = ""
    self:setDialogText()
end

function PinPadDialog:closeDialogs()
    if self.blocking_dialog then
        UIManager:close(self.blocking_dialog)
    end
    if self.dialog then
        UIManager:close(self.dialog)
    end
end

function PinPadDialog:refreshUI()
    self:closeDialogs()
    self:showPinPad()
end

function PinPadDialog:close()
    self:reset()
    self:closeDialogs()
end

function PinPadDialog:onAppendToPin(digit)
    if self.dialog_text == LOCKED_TEXT or self.dialog_text == CONFIRM_CURRENT_CODE_TEXT or self.dialog_text == NEW_CODE_TEXT then
        self.dialog_text = ""
    end
    self.dialog_text = self.dialog_text .. "*"
    self.pin = self.pin .. digit
    self:refreshUI()
end

function PinPadDialog:onOk()
    if self.stage == "locked" then
        if self.pin == G_reader_settings:readSetting("pinpadlock_pin_code") then
            self:close()
            UIManager:show(InfoMessage:new { text = _("Correct PIN, have fun !"), timeout = 2 })
            G_reader_settings:saveSetting("current_tries_number", 0)
            G_reader_settings:saveSetting("block_start_time", 0)
        else
            local current_tries = G_reader_settings:readSetting("current_tries_number")
            if (current_tries + 1) >= MAX_TRIES_LIMIT then
                G_reader_settings:saveSetting("block_start_time", os.time())
            else
                G_reader_settings:saveSetting("current_tries_number", current_tries + 1)
                UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 2 })
            end
            self:onCancel()
        end
    elseif self.stage == "confirm_current_code" then
        if self.pin == G_reader_settings:readSetting("pinpadlock_pin_code") then
            self:close()
            UIManager:show(InfoMessage:new { text = _("Correct PIN, you may change your PIN Code !"), timeout = 2 })
            local enterNewCode = PinPadDialog:new { stage = "enter_new_code" }
            enterNewCode:showPinPad()
        else
            UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 2 })
            self:onCancel()
        end
    else
        G_reader_settings:saveSetting("pinpadlock_pin_code", self.pin)
        self:close()
        UIManager:show(InfoMessage:new { text = _("PIN Code changed successfully !"), timeout = 2 })
    end
end

function PinPadDialog:onDelete()
    if #self.pin > 1 then
        self.pin = self.pin:sub(1, #self.pin - 1)
    elseif #self.pin == 1 then
        self.pin = ""
    end
    if #self.dialog_text == 1 then -- display default text back
        self:setDialogText()
    elseif not (self.dialog_text == LOCKED_TEXT or self.dialog_text == CONFIRM_CURRENT_CODE_TEXT or self.dialog_text == NEW_CODE_TEXT) then
        self.dialog_text = self.dialog_text:sub(1, #self.dialog_text - 1)
    end
    self:refreshUI()
end

function PinPadDialog:onCancel()
    self:reset()
    self:refreshUI()
end

return PinPadDialog
