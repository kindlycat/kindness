---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2014 Grigory Mishchenko
-- @release @AWESOME_VERSION@
---------------------------------------------------------------------------
local setmetatable = setmetatable
local type = type
local widget = require("wibox.widget.base")
naughty = require('naughty')
local color = require("gears.color")
local floor = math.floor
local capi = { 
    mouse = mouse,
    mousegrabber = mousegrabber
}

-- kindness.widget.slider
local slider = { mt = {} }

local function round(x)
    return floor(x + 0.5)
end

function slider:draw(wibox, cr, width, height)
    w, h = width, height
    cr:set_line_width(self.data.bar_line_width)
    local _pos = self._pos
    local pointer, center
    
    local pointer_max = self.data.vertical and h - self.data.pointer_radius or w - self.data.pointer_radius
    local pointer_pos = (_pos < self.data.pointer_radius) and self.data.pointer_radius or _pos
    pointer_pos = pointer_pos > pointer_max and pointer_max or pointer_pos
    self._max = self.data.vertical and h or w
    
    if not self.data.vertical then
        center = h/2 - self.data.bar_line_width/2
        pointer = {x=pointer_pos, y=center}
        cr:move_to(0, center)
        cr:line_to(_pos, center)
        cr:set_source(color(self.data.bar_color_active))
        cr:stroke()
        cr:move_to(_pos, center)
        cr:line_to(w, center)
        cr:set_source(color(self.data.bar_color))
        cr:stroke()
    else
        center = w/2 - self.data.bar_line_width/2
        pointer = {x=center, y=pointer_pos}
        cr:move_to(center, 0)
        cr:line_to(center, _pos)
        cr:set_source(color(self.data.bar_color))
        cr:stroke()
        cr:move_to(center, _pos)
        cr:line_to(center, h)
        cr:set_source(color(self.data.bar_color_active))
        cr:stroke()
    end

    if self.data.with_pointer then
        cr:set_source(color(self.data.pointer_color))
        cr:arc(pointer.x, pointer.y, self.data.pointer_radius, 0, 2 * math.pi)
        cr:fill()
    end
end

function slider:fit(w, h)
    return w, h
end

function slider:set_vertical(vertical)
    self.data.vertical = vertical or false
    self:emit_signal("widget::updated")
end

function slider:set_value(val)
    self._val = val
    
    if not self.data.vertical then
        self._pos = self._max_value / 100 * self._val
    else
        self._pos = self._max_value / 100 * (self._max_value - self._val)
    end
    self._move_function(self._val)
    self:emit_signal("widget::updated")
end

function slider:_update_pos(x, y)
    self._pos = self.data.vertical and y or x
    if self._pos < 0 then
        self._pos = 0
    end
    if self._pos > self._max then
        self._pos = self._max
    end
    if not self.data.vertical then
        self._val = round(self._pos * 100 / self._max)
    else
        self._val = round((self._max - self._pos) * 100 / self._max)
    end
    self:emit_signal("widget::updated")
end

--- Create a slider widget.
-- @return A slider widget.
local function new(move, args)
    local ret = widget.make_widget()
    local args = args or {}
    ret._pos = 0
    ret._val = 0
    ret._max_value = 100
    ret._move_function = move
    ret.data = {vertical=args.vertical or false,
                bar_color=args.bar_color or "#dddddd",
                bar_color_active=args.bar_color_active or bar_color,
                draggable=args.draggable==nil and true or args.draggable,
                with_pointer=args.with_pointer==nil and true or args.with_pointer,
                pointer_color=args.pointer_color or "#dddddd",
                bar_line_width=args.bar_line_width or 2,
                pointer_radius=args.pointer_radius or 5}
    
    for k, v in pairs(slider) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    ret:connect_signal("button::press", function (v, x, y)
        ret:_update_pos(x, y)
        if move then
            move(ret._val)
        end
        if ret.data.draggable then
            mc = mouse:coords()
            minx = mc['x'] - x
            miny = mc['y'] - y
            capi.mousegrabber.run(function (_mouse)
                for k, v in ipairs(_mouse.buttons) do
                    if k == 1 and v then
                        ret._pos = _mouse.x - minx
                        ret:_update_pos(_mouse.x - minx, _mouse.y - miny)
                        if move then
                            ret._move_function(ret._val)
                        end
                        return true
                    end
                end
                return false
            end, "fleur")
        end
    end)
    return ret
end

function slider.mt:__call(...)
    return new(...)
end

return setmetatable(slider, slider.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80