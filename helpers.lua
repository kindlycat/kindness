---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2015 Grigory Mishchenko
-- @release awesome-git
---------------------------------------------------------------------------
local floor = math.floor
naughty = require('naughty')

local helpers = {}

function helpers.round(x)
    return floor(x + 0.5)
end

function helpers.debug(t, timeout)
    naughty.notify({text=tostring(t), timeout=timeout or 0})
end

return helpers