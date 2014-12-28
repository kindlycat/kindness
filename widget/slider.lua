---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2014 Grigory Mishchenko
-- @release @AWESOME_VERSION@
---------------------------------------------------------------------------
local setmetatable = setmetatable
local type = type
local widget = require("wibox.widget.base")
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
    -- todo: refactor
    local w, h = width, height
    self._max = self.data.vertical and h or w
    
    if self._set_value or self._set_vertical then
        if not self.data.vertical then
            self._pos = self._max / 100 * self._val
        else
            self._pos = self._max / 100 * (100 - self._val)
        end
        if self._set_value and not self._set_value_silent then self._move_function(self._val) end
        self._set_value = false
        self._set_vertical = false
    else
        if not self.data.vertical then
            self._val = round(self._pos * 100 / self._max)
        else
            self._val = round((self._max - self._pos) * 100 / self._max)
        end
        if self._val < 0 then self._val = 0 end
        if self._val > 100 then self._val = 100 end
    end

    local pointer, center
    local _pos = self._pos
    if _pos < 0 then _pos = 0 end
    if _pos > self._max then _pos = self._max end
    
    local pointer_max = self.data.vertical and h - self.data.pointer_radius or w - self.data.pointer_radius
    local pointer_pos = (_pos < self.data.pointer_radius) and self.data.pointer_radius or _pos
    pointer_pos = pointer_pos > pointer_max and pointer_max or pointer_pos
    
    cr:set_line_width(self.data.bar_line_width)
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
    self._pos = _pos
end

function slider:fit(w, h)
    return w, h
end

function slider:set_vertical(vertical)
    self.data.vertical = vertical or false
    self._set_vertical = true
    self:emit_signal("widget::updated")
end

function slider:set_value(val, silent)
    if val < 0 then val = 0 end
    if val > 100 then val = 100 end
    self._val = val
    self._set_value = true
    self._set_value_silent = silent or false
    self:emit_signal("widget::updated")
end

function slider:get_value()
    return self._val
end

--- Create a slider widget.
-- @return A slider widget.
local function new(move, args)
    local ret = widget.make_widget()
    local args = args or {}
    ret._pos = 0
    ret._val = 0
    ret._max = 0
    ret._set_value = false
    ret._set_value_silent = false
    ret._set_vertical = false
    ret._move_function = move or nil
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

    for k, v in pairs(ret.data) do
        ret['set_' .. k] = function(self, val)
            self.data[k] = val
            self:emit_signal("widget::updated")
        end
    end

    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    ret:connect_signal("button::press", function (v, x, y)
        ret._pos = ret.data.vertical and y or x
        ret._emit_updated()
        if ret._move_function then ret._move_function(ret._val) end
        if ret.data.draggable then
            local mc = mouse:coords()
            local minx = mc['x'] - x
            local miny = mc['y'] - y
            capi.mousegrabber.run(function (_mouse)
                for k, v in ipairs(_mouse.buttons) do
                    if k == 1 and v then
                        ret._pos = _mouse.x - minx
                        ret._pos = ret.data.vertical and _mouse.y - miny or _mouse.x - minx
                        ret._emit_updated()
                        if ret._move_function then ret._move_function(ret._val) end
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