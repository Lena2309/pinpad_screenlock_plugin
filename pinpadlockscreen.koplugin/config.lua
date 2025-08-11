--[[
Author: Lena2309
Description: provides configuration data for the PIN Pad,
currently storing the correct PIN as a hardcoded value.
Future improvements may include loading the PIN from persistent storage.
]]

local config = {
    pin = "1234",
    custom_message = nil, -- custom message, e.g. contact details
    -- message position
    -- "top"    - message displayed on top of the lock icon
    -- "center" - message displayed between the digits pad and pin text
    -- "bottom" - message displayed below the digits pad
    custom_message_position = "top",
    custom_message_alignement = "center", -- or "left" or "right"
}
return config
