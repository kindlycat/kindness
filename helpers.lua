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

function helpers.debug(t, timeout)
    naughty.notify({text=tostring(t), timeout=timeout or 0})
end

-- Patched version of base.draw_widget. Register only wisible part of widget.
function helpers.draw_widget(wibox, cr, widget, x, y, width, height, reg_w, reg_h)
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
    wibox:widget_at(widget, base.rect_to_device_geometry(cr, 0, 0, reg_w, reg_h))

    cr:restore()
end

return helpers