---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2015 Grigory Mishchenko
-- @release awesome-git
---------------------------------------------------------------------------
local join = require('awful.util').table.join
local timer = timer
local round = require('kindness.helpers').round
local rl = require('kindness.layout.relative')
local tween = require('kindness.libs.tween')
local capi = {
    screen = screen,
    mouse = mouse
}

local animation = {}

function animation.animate(obj, to, args)
    local args = args or {}
    local to = to or {}
    local t = timer({timeout=args.timeout or 0.01})
    local duration = args.duration or 0.3
    local dt = args.dt or 0.01

    local tw = tween.new(duration, obj, to, args.method or 'linear')

    t:connect_signal("timeout", function()
        local complete = tw:update(dt)
        if type(args.onupdate) == 'function' then args.onupdate() end

        if complete then
            t:stop()
            if type(args.after_func) == 'function' then args.after_func() end
        end
    end)
    t:start()
end

function animation.fadeOut(obj, args)
    local args = args or {}
    local to = {opacity=args.opacity or 0}
    local _args = {
        after_func = function() 
            obj.visible = false
            obj.opacity = 1 
        end
    }
    args = join(_args, args)

    animation.animate(obj, to, args)
end

function animation.fadeIn(obj, args)
    local args = args or {}
    local to = {opacity=args.opacity or 1}

    args = join(_args, args)

    obj.opacity = 0
    obj.visible = true

    animation.animate(obj, to, args)
end

function animation.move(obj, args)
    local args = args or {}
    local to = {x=args.x or obj.x, y=args.y or obj.y}

    animation.animate(obj, to, args)
end


function animation.resize(obj, args)
    local args = args or {}
    local _args = {dir = 'tl'}
    local to = {
        width = args.width or obj.width,
        height = args.height or obj.height,
        x = args.x or obj.x,
        y = args.y or obj.y
    }
    local geom = args.geom or {x=obj.x, y=obj.y, width=obj.width, height=obj.height}
    local _w = obj._drawable.widget
    local after_func = args.after_func
    args = join(_args, args)

    local to_dir = {
        tr = {x=geom.x + (geom.width - to.width)},
        r = {x=geom.x + (geom.width - to.width)},
        c = {x=geom.x + (geom.width - to.width)/2, 
             y=geom.y + (geom.height - to.height)/2},
        bl = {y=geom.y + (geom.height - to.height)},
        b = {y=geom.y + (geom.height - to.height)},
        br = {x=geom.x + (geom.width - to.width),
              y=geom.y + (geom.height - to.height)}
    }

    args['after_func'] = function()
        if type(after_func) == 'function' then after_func() end
        if args.relative then
            obj:set_widget(_w)
        end
    end

    dummy = {x=obj.x, y=obj.y, width=obj.width, height=obj.height}

    args.onupdate = args.onupdate or function()
        obj:geometry({
            x = round(dummy.x),
            y = round(dummy.y),
            width = round(dummy.width),
            height = round(dummy.height)
        })
    end

    if args.relative then
        local layout = rl()
        layout:add(_w, {width=geom.width, height=geom.height})
        obj:set_widget(layout)
    end

    to = to_dir[args.dir] and join(to, to_dir[args.dir]) or to
    
    animation.animate(dummy, to, args)
end

function animation.slideIn(obj, args)
    local args = args or {}
    local from_dir = {
        tl = {width=1, height=1},
        t = {height=1},
        tr = {width=1, height=1, x=obj.x+(obj.width-1)},
        l = {width=1},
        c = {width=1, height=1, x=obj.x+(obj.width-1)/2, y=obj.y+(obj.height-1)/2},
        r = {width=1, x=obj.x+(obj.width-1)},
        bl = {width=1, height=1, y=obj.y+(obj.height-1)},
        b = {height=1, y=obj.y+(obj.height-1)},
        br = {width=1, height=1, x=obj.x+(obj.width-1) , y=obj.y+(obj.height-1)}
    }
    local _args = {
        dir = 'tl',
        width = args.width or obj.width,
        height = args.height or obj.height,
        x = obj.x,
        y = obj.y,
        geom = {x=obj.x, y=obj.y, width=obj.width, height=obj.height}
    }
    args = join(_args, args)

    obj:geometry(from_dir[args.dir])
    obj.visible = true

    animation.resize(obj, args)
end

function animation.slideOut(obj, args)
    local args = args or {}
    local geom = {x=obj.x, y=obj.y, width=obj.width, height=obj.height}
    local to_dir = {
        tl = {width=1, height=1},
        t = {height=1},
        tr = {width=1, height=1, x=obj.x+(obj.width-1)},
        l = {width=1},
        c = {width=1, height=1, x=obj.x+(obj.width-1)/2, y=obj.y+(obj.height-1)/2},
        r = {width=1, x=obj.x+(obj.width-1)},
        bl = {width=1, height=1, y=obj.y+(obj.height-1)},
        b = {height=1, y=obj.y+(obj.height-1)},
        br = {width=1, height=1, x=obj.x+(obj.width-1) , y=obj.y+(obj.height-1)}
    }
    local _args = {
        after_func = function()
            obj.visible = false
            obj:geometry(geom)
        end,
        geom = geom
    }
    
    if to_dir[args.dir] then args = join(_args, to_dir[args.dir]) end
    args = join(_args, args)

    animation.resize(obj, args)
end

function animation.moveIn(obj, args)
    local args = args or {}
    local geom = {x=obj.x, y=obj.y, width=obj.width, height=obj.height}
    local screen_workarea = screen[mouse.screen].workarea
    local from_dir = {
        tl = {x=-obj.width, y=-obj.height},
        t = {y=-obj.height},
        tr = {x=screen_workarea.width, y=-obj.height},
        l = {x=-obj.width},
        r = {x=screen_workarea.width},
        bl = {x=-screen_workarea.width, y=screen_workarea.height},
        b = {y=screen_workarea.height},
        br = {x=screen_workarea.width, y=screen_workarea.height}
    }
    local _args = {
        x = obj.x,
        y = obj.y,
        dir = obj.x < screen_workarea.width/2 and 'l' or 'r'
    }
    
    args = join(_args, args)
    obj:geometry(from_dir[args.dir])
    obj.visible = true

    animation.move(obj, args)
end

function animation.moveOut(obj, args)
    local args = args or {}
    local geom = {x=obj.x, y=obj.y, width=obj.width, height=obj.height}
    local screen_workarea = screen[mouse.screen].workarea
    local to_dir = {
        tl = {x=-obj.width, y=-obj.height},
        t = {y=-obj.height},
        tr = {x=screen_workarea.width, y=-obj.height},
        l = {x=-obj.width},
        r = {x=screen_workarea.width},
        bl = {x=-screen_workarea.width, y=screen_workarea.height},
        b = {y=screen_workarea.height},
        br = {x=screen_workarea.width, y=screen_workarea.height}
    }
    local _args = {
        dir = args.dir or obj.x < screen_workarea.width/2 and 'l' or 'r',
        after_func = function()
            obj.visible = false
            obj:geometry(geom)
        end
    }
    
    if to_dir[_args.dir] then args = join(_args, to_dir[_args.dir]) end
    args = join(_args, args)

    animation.move(obj, args)
end

return animation