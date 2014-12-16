---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2014 Grigory Mishchenko
-- @release @AWESOME_VERSION@
---------------------------------------------------------------------------

local type = type
local pairs = pairs
local setmetatable = setmetatable
local base = require("wibox.layout.base")
local widget_base = require("wibox.widget.base")
local table = table

-- wibox.layout.relative
local relative = { mt = {} }

--- Draw a relative layout.
-- @param wibox The wibox that this widget is drawn to.
-- @param cr The cairo context to use.
-- @param width The available width.
-- @param height The available height.
function relative:draw(wibox, cr, width, height)
    for k, v in pairs(self.widgets) do
        w, h = base.fit_widget(v, width, height)
        v.rw = v.rw or w
        v.rh = v.rh or h
        base.draw_widget(wibox, cr, v, v.rx, v.ry , v.rw, v.rh)
    end
end

--- Fit the relative layout into the given area.
-- @param w The available width.
-- @param h The available height.
-- @return The width and height that the widget wants to use.
function relative:fit(w, h)
    local w = self._width and self._width or w
    local h = self._height and self._height or h
    return w, h
end

--- Add a widget to the given relative layout.
-- @param widget
-- @param x The x coord for given widget. (default: 0)
-- @param y The y coord for given widget. (default: 0)
-- @param width The width for given widget. (default: fit to layout)
-- @param height The height for given widget. (default: fit to layout)
function relative:add(widget, args)
    local args = args or {}
    
    widget_base.check_widget(widget)
    table.insert(self.widgets, widget)
    
    widget.rx = args.x or 0
    widget.ry = args.y or 0
    widget.rw = args.width or nil
    widget.rh = args.height or nil
    
    widget:connect_signal("widget::updated", self._emit_updated)
    self:emit_signal("widget::updated")
end

--- Reset relative layout. This removes all widgets from the layout.
function relative:reset()
    for k, v in pairs(self.widgets) do
        v:disconnect_signal("widget::updated", self._emit_updated)
    end
    self.widgets = {}
    self:emit_signal("widget::updated")
end

--- Returns a new relative layout.
-- @param width The maximum width of the layout. nil for no limit. (optional)
-- @param height The maximum height of the layout. nil for no limit. (optional)
local function new(args)
    local args = args or {}
    local ret = widget_base.make_widget()

    for k, v in pairs(relative) do
        if type(v) == "function" then
            ret[k] = v
        end
    end
    
    ret.widgets = {}
    ret._width = args.width or nil
    ret._height = args.height or nil
    
    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    return ret
end

function relative.mt:__call(...)
    return new(...)
end

return setmetatable(relative, relative.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
