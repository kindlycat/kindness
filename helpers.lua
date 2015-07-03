---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2015 Grigory Mishchenko
-- @release awesome-git
---------------------------------------------------------------------------
local floor = math.floor
local base = require("wibox.layout.base")
naughty = require('naughty')

local helpers = {}

function helpers.round(x)
    return floor(x + 0.5)
end

function helpers.notzero(a, b)
    return (a == 0) and b or a
end

function helpers.debug(t, timeout)
    if type(t) == 'table' then
        local text = ''
        for k, v in pairs(t) do
            text = text .. '\n' .. k .. ' => ' .. tostring(v)
        end
        t = text
    end
    naughty.notify({text=tostring(t), timeout=timeout or 0})
end

-- Patched version of base.draw_widget. Register widget at given area.
function helpers.draw_widget(wibox, cr, widget, x, y, width, height, reg_x, reg_y, reg_w, reg_h)
    local reg_x = reg_x or 0
    local reg_y = reg_y or 0
    local reg_w = reg_w or width
    local reg_h = reg_h or height
    -- Use save() / restore() so that our modifications aren't permanent
    cr:save()

    -- Move (0, 0) to the place where the widget should show up
    cr:translate(x, y)

    -- Make sure the widget cannot draw outside of the allowed area
    cr:rectangle(0, 0, width, height)
    cr:clip()

    -- Let the widget draw itself
    local success, msg = pcall(widget.draw, widget, wibox, cr, width, height)
    if not success then
        print("Error while drawing widget: " .. msg)
    end

    -- Register the widget for input handling
    wibox:widget_at(widget, base.rect_to_device_geometry(cr, reg_x, reg_y, reg_w, reg_h))

    cr:restore()
end

function helpers.cap(val, min, max)
    if (val < min) then return min end
    if (val > max) then return max end
    return val
end

return helpers