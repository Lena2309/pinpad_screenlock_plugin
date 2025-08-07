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
local config = require("config")

local ENTER_PIN_TEXT = _("Enter your PIN")

local PinPadDialog = FrameContainer:extend {
    correct_pin = config.pin or "1234", -- Default PIN or from a config file
    icon = "lock",
}

function PinPadDialog:init()
    self.pin = ""
    self.pin_dialog = ENTER_PIN_TEXT
    self.buttons = self:initializeButtons()
    return self
end

function PinPadDialog:initializeButtons()
    local ref_self = self
    local buttons = {
        {
            self:createButton("1", function() ref_self:appendToPin("1") end),
            self:createButton("2", function() ref_self:appendToPin("2") end),
            self:createButton("3", function() ref_self:appendToPin("3") end),
        },
        {
            self:createButton("4", function() ref_self:appendToPin("4") end),
            self:createButton("5", function() ref_self:appendToPin("5") end),
            self:createButton("6", function() ref_self:appendToPin("6") end),
        },
        {
            self:createButton("7", function() ref_self:appendToPin("7") end),
            self:createButton("8", function() ref_self:appendToPin("8") end),
            self:createButton("9", function() ref_self:appendToPin("9") end),
        },
        {
            self:createButton("Cancel", function() ref_self:onCancel() end),
            self:createButton("0", function() ref_self:appendToPin("0") end),
            self:createButton("OK", function() ref_self:onOk() end),
        },
    }
    return buttons
end

function PinPadDialog:showPinPad()
    self.dialog = PinPadButtonDialog:new {
        icon = self.icon,
        title = self.pin_dialog,
        title_align = "center",
        use_info_style = false,
        buttons = self.buttons,
        dismissable = false,
    }

    UIManager:show(self.dialog)
end

function PinPadDialog:refreshUI()
    if self.dialog then
        UIManager:close(self.dialog)
    end
    self:showPinPad()
end

function PinPadDialog:createButton(text, callback)
    local button = Button:new {
        text = text,
        callback = callback,
    }
    return button
end

function PinPadDialog:appendToPin(digit)
    if self.pin_dialog == ENTER_PIN_TEXT then
        self.pin_dialog = ""
    end
    self.pin_dialog = self.pin_dialog .. "*"
    self.pin = self.pin .. digit
    self:refreshUI()
end

function PinPadDialog:onOk()
    if self.pin == self.correct_pin then
        self:close()
        UIManager:show(InfoMessage:new { text = _("Correct PIN, have fun !"), timeout = 1 })
    else
        UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 1 })
        self:onCancel()
    end
end

function PinPadDialog:onCancel()
    self.pin = ""
    self.pin_dialog = ENTER_PIN_TEXT
    self:refreshUI()
end

function PinPadDialog:close()
    self.pin = ""
    self.pin_dialog = ENTER_PIN_TEXT
    UIManager:close(self.dialog)
end

return PinPadDialog
