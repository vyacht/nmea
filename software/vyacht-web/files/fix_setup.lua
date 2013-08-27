
local uci      = require "luci.model.uci"
local _go      = require "get-opt-alt"


vtest = 1
local vy      = require "vyacht"

_uci_real  = cursor or _uci_real or uci.cursor()                   

-- option lua_prefix       /lua              
-- option lua_handler      /www/vyacht.lua
        
_uci_real:set("uhttpd", "main", "lua_prefix", "/lua")
_uci_real:set("uhttpd", "main", "lua_handler", "/www/vyacht.lua")
                                      
_uci_real:commit("uhttpd")

os.execute("/etc/init.d/uhttpd restart");

-- vi /etc/inittab
local file = io.open("/etc/inittab", "w")
if file ~= nil then
   file:write("::sysinit:/etc/init.d/rcS S boot\n")
   file:write("::shutdown:/etc/init.d/rcS K shutdown\n")
   file:flush()
   io.close(file) 
end

-- vi /etc/config/vyacht
local opts = _go.getopt(arg, options)
local eths = -1

if opts["eth"] == nil then
  print("no number of ethernet devices given")
  return
else 
  eths = tonumber(opts["eth"])
end

if eths < 0 or eths > 2 then
  print("wrong number of ethernet devices given")
  return
end

local hw = readHardwareOptions()

if eths == 1 then
  hw.network.devices = {"radio0", "eth0.2"}
elseif eths == 2 then
  hw.network.devices = {"radio0", "eth0.1", "eth0.2"}
else 
  hw.network.devices = {"radio0"}
end

writeHardwareOptions(hw)

-- rather check if the wanted file is there before removing
local f=io.open("/www/index2.html", "r")
if f~=nil then 
   io.close(f) 
   
   os.remove("/www/index.html")
   os.rename("/www/index2.html", "/www/index.html")
end
                                                                      
resetSystem()

