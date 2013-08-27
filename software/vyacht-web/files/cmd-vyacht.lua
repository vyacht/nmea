local _ip    = require "vyacht-ip"
local _go    = require "get-opt-alt"

vtest = 1
local vy     = require "vyacht"
local bus    = require "ubus"

_uci_real  = cursor or _uci_real or uci.cursor()                
vubus       = bus.connect()

local opts = _go.getopt(arg, options)        
local toWan = false
local toLan = false

if opts["addr"] == nil then
  print("no addr given") return
end
if opts["dev"] == nil then
  print("no dev given") return
end
if opts["net"] == nil then
  print("no net given") return
end
if opts["wan"] ~= nil and opts["wan"] then
  toWan = true
end
if opts["lan"] ~= nil and opts["lan"] then
  toLan = true
end

if toWan then
  vy.changeWan(opts["addr"], opts["dev"], "wan", opts["net"])
elseif toLan then
  vy.changeWan(opts["addr"], opts["dev"], "lan", opts["net"])
else
  vy.changeEthernetAddress(opts["addr"], opts["dev"], opts["net"])
end
  
                
