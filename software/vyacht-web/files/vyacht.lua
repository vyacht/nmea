local io       = require "io"
local os       = require "os"
local table    = require "table"
local nixio    = require "nixio"
local fs       = require "nixio.fs"
local sys      = require "luci.sys"
local version  = require "luci.version"
local util     = require "luci.util"
local protocol = require "luci.http.protocol"
local uci      = require "luci.model.uci"
local bus      = require "ubus"
local _ip      = require "vyacht-ip"
local mime     = require "vyacht-mime"
local json     = require "vyacht-json"

require "luci.tools.status"

if mtest == 1 then
-- module only for testing
module(..., package.seeall)
end

-- only change files but do not restart network, etc.
ptest = 0

-- print to out instead of web server
vtest = 0
            
function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then 
    io.close(f) 
    return true 
  else 
    return false
  end
end

function uuid()
  local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function (c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

function cmdExecute(command)
  
  local resultfile = "/tmp" .. uuid()

  local rs = os.execute(command .. " > " .. resultfile ..  " 2>&1")

  if rs ~= 0 then
    local data = readFile(resultfile)
    return false, data 
  end
  
  return true
  
end 

function readFile(file)
  local f = io.open(file, "rb")
  local content = nil
  if f then 
    content = f:read("*all")
    f:close()
  end
  return content
end

function isNumber(num)

	if type(num) == "number" then
		return true
	end

        if num == nil or type(num) ~= "string" then
		return false
	end

        if num:match("^%d+$") then
		return true
        else
		return false
        end

end


function vWrite(txt)
  if vtest == 1 then
    print(txt)
  else
    uhttpd.send(txt)
  end
end

--- Send the given data as JSON encoded string.
-- @param data          Data to send
function _write_json(x)
	json.write_json(x, vWrite)
end


function wrap(txt)
  return "\"" .. txt .. "\"";
end

function keyvalue(key, val)
  if type(val) == "string" then
    return wrap(key) .. ": " .. wrap(val)
  else 
    return wrap(key) .. ": " .. val
  end
end

function handle_request(env)

        exectime = os.clock()
        local renv = {
                CONTENT_LENGTH  = env.CONTENT_LENGTH,
                CONTENT_TYPE    = env.CONTENT_TYPE,
                REQUEST_METHOD  = env.REQUEST_METHOD,
                REQUEST_URI     = env.REQUEST_URI,
                PATH_INFO       = env.PATH_INFO,
                SCRIPT_NAME     = env.SCRIPT_NAME:gsub("/+$", ""),
                SCRIPT_FILENAME = env.SCRIPT_NAME,
                SERVER_PROTOCOL = env.SERVER_PROTOCOL,
                QUERY_STRING    = env.QUERY_STRING
        }

	-- get parameter from query string
	local params = protocol.urldecode_params(env.QUERY_STRING or "")
	local path = ""
	_uci_real  = cursor or _uci_real or uci.cursor()
        vubus = bus.connect()

	os.execute("logger -s -t device -p daemon.info " .. "uri: " .. env.REQUEST_URI)

	if (env.PATH_INFO) then
		path = env.PATH_INFO
  		os.execute("logger -s -t device -p daemon.info " .. "path: " .. env.PATH_INFO)
  	end

        for k, v in pairs(params) do
		os.execute("logger -s -t device -p daemon.info " .. k .. ": " .. tostring(v))
        end

	if string.find(path, "getStatus") then
		return getStatus()
	elseif string.find(path, "changeWifi") then
		return changeWifi(params)
	elseif string.find(path, "changeGps") then
		return changeGps(params)
	elseif string.find(path, "changeNMEA") then
		return changeNMEA(params)
	elseif string.find(path, "resetSystem") then
		return resetSystem(params)
	elseif string.find(path, "systemStatus") then
		return systemStatus(params)
	elseif string.find(path, "changeEthernet") then
		return changeEthernet(params)
	elseif string.find(path, "upload") then
	        return uploadFile(env)
	else
	        vWrite("HTTP/1.0 200 OK\r\n")
        	vWrite("Content-Type: application/json\r\n\r\n")
        	vWrite("{}")
	end
end

function readHardwareOptions()

--  config hardware board
--    option version '8.3'
--        
--  config hardware module
--    option type nmea-iso
--    option version '1.2'
--                       
--  config hardware network
--    list device radio0
--    list device eth0.1
--    list device eth0.2
 
  local hw = {
    board = {version = ""},
    module = {type = "", version = ""},
    network = {devices = {}}
  }
  
  hw.board.version = _uci_real:get("vyacht", "board", "version")
  hw.module.version = _uci_real:get("vyacht", "module", "version")
  hw.module.type = _uci_real:get("vyacht", "module", "type")
  local lst = _uci_real:get("vyacht", "network", "device")                                                                            
  for i = 1, #lst do                                                                                                            
    table.insert(hw.network.devices, lst[i])
  end
  
  return hw
  
end

function writeHardwareOptions(hw)

  _uci_real:set("vyacht", "board", "version", hw.board.version)
  _uci_real:set("vyacht", "module", "version", hw.module.version)
  _uci_real:set("vyacht", "module", "type", hw.module.type)
  _uci_real:set("vyacht", "network", "device", hw.network.devices)
  _uci_real:commit("vyacht")
  
end

function uploadFile(env)
 
  local lf = nil
  local filename = ""
  local fileshort = ""
    
  function filecb(field, data, bl)
  
	local d = data or ""
	
--	_write_json(field)
--	vWrite("\n")
	
	if not lf then
	  if field and field.name then
  	    fileshort = field.file
  	    filename = "/tmp/" .. fileshort
            lf = io.open(filename, "wb")
            if not lf then
              return false, "Couldn't write file (%s)" % filename
            end
          end
        end
        if lf then 
  	  lf:write(data)
  	end
  	return true
  end
	
	function readcb() 
		local rv, buf
		rv, buf = uhttpd.recv(4096)
		if buf and rv > 0 then
			return buf
		end
		return nil
	end
    
	local _debug = false
	local msg = {
    	env = env,
    	params = {}
  	}

  vWrite("HTTP/1.0 200 OK\r\n")
  vWrite("Content-Type: application/json\r\n\r\n")
  
  local contentLength = math.floor(tonumber(env.CONTENT_LENGTH) / 1024)
  
  local ps = sys.mounts()
  local blocks = -1 
    
  for k, v in ipairs( ps) do
    if v["mountpoint"] == "/tmp" then
      blocks = tonumber(v["blocks"])
    end
  end
  
  if blocks < 0 then
    vWrite("{\"error\": \"No suitable temporary storage found on device.\"}")
    return
  end
  
  if blocks <= contentLength then
    vWrite("{%q: \"Only %d kByte of space found for a %d kByte file. Try to reboot the device.\"}" % {"error", blocks, contentLength})
    return
  end
  
  if env.REQUEST_METHOD == "POST" then
	mime.mimedecode_message_body(msg, readcb, filecb)
        io.close(lf)
  end
  
  if not file_exists(filename) then
    vWrite("{\"error\": \"No installable file found (%s)!\"}" % fileshort)
    return
  end
  
  local ipk = string.match(fileshort, "^vyacht%-web(.+).ipk$")
  if ipk then
  
    local hw = readHardwareOptions()

    -- installable ipk package
    local res, data = cmdExecute("opkg install " .. filename)
    
    if not res then
      vWrite(string.format("{%q: \"Installation of %s failed.\"}", "error", fileshort))
      return
    end
    
    writeHardwareOptions(hw)
    
    -- rather check if the wanted file is there before removing
    local f=io.open("/www/index2.html", "r")
    if f~=nil then
       io.close(f)
    
       os.remove("/www/index.html")
       os.rename("/www/index2.html", "/www/index.html")
    end
             
    vWrite("{}") 
    
  else
    -- for now we only support ipk
    vWrite("{%q: \"No valid file for installation (%s)!\"}" % {"error", fileshort})
    return
    
--    local tgz = string.match(filename, "^(.+).tgz$")
--    if tgz then
--      vWrite("{\"error\": \"%s matches tgz!\"}" % filename)
--    else 
--      local bin = string.match(filename, "^(.+).bin$")
--      if bin then
--        vWrite("{\"error\": \"%s matches bin!\"}" % filename)
--      end
--    end -- tgz
  end -- ipk
  
end

function systemStatus(params) 
  -- return system tools installed
  vWrite("HTTP/1.0 200 OK\r\n")
  vWrite("Content-Type: application/json\r\n\r\n")
  
  local systemData = {
    io = file_exists("/usr/bin/io"),
    fix_hosts = {
      init = file_exists("/etc/init.d/fix_hosts")
    },
    iomode = {
      init = file_exists("/etc/init.d/iomode"),
      config = file_exists("/etc/config/iomode")
    }
  }
  _write_json(systemData)
  
end

function dhcpHostsFromPrefix(prefix)

  local hosts = _ip.getHosts(prefix) - 1
  local start = 100
  local count = 25
   
  if hosts < 255 then
    start = 1
    count = hosts - 1
  end
  
  return start, start + count
end

function setLoopback() 
  _uci_real:set("network", "loopback", "interface")
  _uci_real:set("network", "loopback", "ifname", "lo")
  _uci_real:set("network", "loopback", "proto", "static")
  _uci_real:set("network", "loopback", "ipaddr", "127.0.0.1")
  _uci_real:set("network", "loopback", "netmask", "255.0.0.0")
end

function setStaticNetwork(netName, device, ipaddr, prefix)

  local netmask
  if prefix ~= nil then
    netmask = _ip.getNetmaskString(prefix)
  else
    netmask = "255.255.255.0"
    prefix = 24
  end
  
  local start, limit = dhcpHostsFromPrefix(prefix) 
  
  _uci_real:set("network", netName, "interface")
  _uci_real:set("network", netName, "ifname", device)
  _uci_real:set("network", netName, "type", "bridge")
  _uci_real:set("network", netName, "proto", "static")
  _uci_real:set("network", netName, "ipaddr", ipaddr)
  _uci_real:set("network", netName, "netmask", netmask)

  -- start is offset from ip
  -- max 150 different IPs to lease
  _uci_real:set("dhcp", netName, "dhcp")
  _uci_real:set("dhcp", netName, "interface", netName)
  _uci_real:set("dhcp", netName, "start", start)
  _uci_real:set("dhcp", netName, "limit", limit)
  _uci_real:set("dhcp", netName, "leasetime", "12h")
end  

function setDhcpNetwork(netName, device)
  _uci_real:set("network", netName, "interface")
  _uci_real:set("network", netName, "ifname", device)
  _uci_real:set("network", netName, "proto", "dhcp")
  
  _uci_real:set("dhcp", netName, "dhcp")
  _uci_real:set("dhcp", netName, "interface", netName)
  _uci_real:set("dhcp", netName, "ignore", "1")
end

function typeDeleteAll(config, type)

  local secs = {}
  _uci_real:foreach(config, type, function(s)
    secs[#secs + 1] = s[".name"]
  end)
  
  for i = 1, #secs do
    _uci_real:delete(config, secs[i])
  end
  
end

function resetSystem(params) 
  -- 
  --  change wireless settings
  --
  local sec_name
  _uci_real:foreach("wireless", "wifi-device", function(s)
    sec_name = s[".name"]
  end)
  _uci_real:set("wireless", sec_name, "disabled", "0")
 
  typeDeleteAll("wireless", "wifi-iface") 
  
  local sec_name = _uci_real:add("wireless", "wifi-iface")
  _uci_real:set("wireless", sec_name, "device", "radio0")
  _uci_real:set("wireless", sec_name, "network", "wifi")
  _uci_real:set("wireless", sec_name, "mode", "ap")
  _uci_real:set("wireless", sec_name, "encryption", "psk2")
  _uci_real:set("wireless", sec_name, "key", "vYachtWifi")
  _uci_real:set("wireless", sec_name, "ssid", "vYachtWifi")
  _uci_real:commit("wireless")

 --
  --  change hostname
  --
  _uci_real:foreach("system", "system", function(s)            
      sec_name = s[".name"]                                            
  end)                                                               
  _uci_real:set("system", sec_name, "hostname", "vYachtWifi")
  _uci_real:commit("system")
  
  --
  --  change network & dhcp
  --
  -- for resetting the network we want: 
  --     lan1, wan, wifi  
  -- or  lan1, wifi
  
  typeDeleteAll("dhcp", "dhcp") 
  typeDeleteAll("network", "interface") 
  
  -- add loopback
  setLoopback() 
  
  local devs = {
    eth01 = {name = "eth0.1", installed = 0},
    eth02 = {name = "eth0.2", installed = 0},
    wifi  = {name = "radio0", installed = 0}
  }
  
  devs.eth01.installed = deviceInstalled("eth0.1")
  devs.eth02.installed = deviceInstalled("eth0.2")
  devs.wifi.installed = deviceInstalled("radio0")
  
  if devs.eth01.installed == 1 then
    setStaticNetwork("lan1", "eth0.1", "192.168.1.1", 24)
    if devs.eth02.installed == 1 then
      setDhcpNetwork("wan", "eth0.2")
    end
  else
    if devs.eth02.installed == 1 then
      setStaticNetwork("lan2", "eth0.2", "192.168.1.1", 24)
    end
  end
  
  if devs.wifi.installed == 1 then
    setStaticNetwork("wifi", "radio0", "192.168.10.1", 24)
  end
  
  _uci_real:commit("network")
  _uci_real:commit("dhcp")
  
  --
  --  firewall
  --
  typeDeleteAll("firewall", "zone") 
  typeDeleteAll("firewall", "forwarding") 
  
  local sec = _uci_real:add("firewall", "zone")
  writeZoneLocal(sec, "wifi") 
 
  sec = _uci_real:add("firewall", "zone")
  writeZoneLocal(sec, "lan1") 
  
  sec = _uci_real:add("firewall", "zone")
  writeZoneLocal(sec, "lan2") 
  
  sec = _uci_real:add("firewall", "zone")
  writeZoneWan(sec, "wan") 
  
  sec = _uci_real:add("firewall", "forwarding")
  _uci_real:set("firewall", sec, "src", "wifi")
  _uci_real:set("firewall", sec, "dest", "wan")
  
  sec = _uci_real:add("firewall", "forwarding")
  _uci_real:set("firewall", sec, "src", "lan1")
  _uci_real:set("firewall", sec, "dest", "wan")
  
  sec = _uci_real:add("firewall", "forwarding")
  _uci_real:set("firewall", sec, "src", "lan2")
  _uci_real:set("firewall", sec, "dest", "wan")
  
  _uci_real:commit("firewall")

end

function writeZoneLocal(sec_name, zoneName) 
        _uci_real:set("firewall", sec_name, "name", zoneName)
        _uci_real:set("firewall", sec_name, "network", zoneName)
        _uci_real:set("firewall", sec_name, "input", "ACCEPT")
        _uci_real:set("firewall", sec_name, "output", "ACCEPT")
        _uci_real:set("firewall", sec_name, "forward", "REJECT")
end

function writeZoneWan(sec_name, zoneName)
  _uci_real:set("firewall", sec_name, "name", "wan")
  _uci_real:set("firewall", sec_name, "network", "wan")
  _uci_real:set("firewall", sec_name, "input", "REJECT")
  _uci_real:set("firewall", sec_name, "output", "ACCEPT")
  _uci_real:set("firewall", sec_name, "forward", "REJECT")
  _uci_real:set("firewall", sec_name, "masq", "1")
  _uci_real:set("firewall", sec_name, "mtu_fix", "1")
end

function changeWan(addr, realDev, lanwan, netName)

	if realDev ~= "eth0.2" then
        	vWrite("{\"error\": \"Cannot convert %s to WAN or LAN!\"}" % realDev)
        	return
        end
        
	if netName ~= "wan" and netName ~= "lan2" then
        	vWrite("{\"error\": \"Change WAN: Not a valid network (%s)!\"}" % netName)
        	return
	end
	
	local lanNetName = "lan2"
	
	if netName == lanNetName then
	  if lanwan == "wan" then
	    -- now we make this interface new wan interface
	    _uci_real:delete("network", lanNetName)
	    _uci_real:delete("dhcp", lanNetName)
	    setDhcpNetwork("wan", realDev)
	  else
	    -- nothing to do - there is none and we keep it that way
	    -- print("nothing to do")
	  end
	else
	
	  -- we have the device name and it should be eth02
	  
	  if lanwan == "lan" then
            local ip, prefix = checkForAddressChange(addr, realDev)
	    if ip == nil or prefix == nil then
              return
            end
            
            if prefix > 30 then
              vWrite("{\"error\": \"This router requires prefixes between 0 and 30 to allow for a minimum of 4 hosts on the network\"}" % ip)
	      return  
            end
            
            -- check that we are not in range of the lan1
	    if IPInNetRange(ip, prefix, "lan1") then
              vWrite("{\"error\": \"New IP %s is in the IP range of the Ethernet 1\"}" % ip)
	      return  
	    end
	    if IPInNetRange(ip, prefix, "wifi") then
              vWrite("{\"error\": \"New IP %s is in the IP range of the wireless network\"}" % ip)
	      return  
	    end
		
	    _uci_real:delete("network", "wan")
	    _uci_real:delete("dhcp", "wan")
	    setStaticNetwork(lanNetName, "eth0.2", ip, prefix)
	    
	  else
	    -- nothing to do its eth01 already
	  end
	end
	
  	_uci_real:commit("network")
  	_uci_real:commit("dhcp")

        if ptest == 1 then
          return
        end  	
	-- requires restart of ifdown/up lan and dnsmasq
	luci.sys.call("env -i /sbin/ifdown %s >/dev/null" % netName)
	luci.sys.call("env -i /sbin/ifup %s >/dev/null" % netName)
	
	luci.sys.call("env -i /etc/init.d/fix_hosts start >/dev/null")
	luci.sys.call("env -i /etc/init.d/dnsmasq restart >/dev/null")
	luci.sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
	luci.sys.call("env -i /etc/init.d/gpsd start >/dev/null")
end

function changeEthernet(params)
	local addr
	local device
	local lanwan
	
	for k, v in pairs(params) do
		if k == "ip" then
			if v then
				addr = v
			end
		end
		if k == "device" then
			if v then
				device = v
			end
		end
		if k == "wan" then
			if v then
				lanwan = v
			end
		end
	end
	
	vWrite("HTTP/1.0 200 OK\r\n")
        vWrite("Content-Type: application/json\r\n\r\n")
        
        -- print("device= " .. device .. ", lanwan= " .. lanwan .. ", ip= " .. ip)
	
	if device ~= "eth01" and device ~= "eth02" then
        	vWrite("{\"error\": \"Not a valid device (%s)!\"}" % device)
        	return
	end
	
	local realDev = "eth0.1"
	if device == "eth02" then
	  realDev = "eth0.2"
	end
	
	if lanwan == nil and realDev == "eth0.2" then
        	vWrite("{\"error\": \"Don't recognize empty command!\"}")
        	return
	end
	
	if lanwan ~= nil and lanwan ~= "lan" and lanwan ~= "wan" then
        	vWrite("{\"error\": \"Don't recognize command (%s)!\"}" % wan)
        	return
	end
	
	if realDev == "eth0.1" and lanwan == "wan" then
        	vWrite("{\"error\": \"Only Ethernet 2 can be made WAN!\"}")
        	return
	end
	
	local netName = getNetNameByDevice(realDev) 
	if netName ~= "wan" and netName ~= "lan2"  and netName ~= "lan1" then
        	vWrite("{\"error\": \"Not a valid network (%s)!\"}" % netName)
        	return
	end
	
	if netName == "wan" then
  	  if realDev == "eth0.1" then
        	vWrite("{\"error\": \"Wrong network state: Ethernet 1 is configured as WAN! Refuse to change.\"}")
        	return
	  end
	  if lanwan == "lan" then
		-- print("going to change to lan = " .. netName)
		changeWan(addr, realDev, "lan", netName)
	  end
	  if lanwan == "wan" then
	    -- nothing error like to report
	    -- later we could change a static IP for WAN
	  end
	else
          -- is currently lan
          if lanwan == "wan" and realDev == "eth0.2" then  
            changeWan(addr, realDev, "wan", netName) 
          else 
            changeEthernetAddress(addr, realDev, netName) 
          end
	end
end

function checkForAddressChange(addr, realDev)

	if addr == nil then
        	vWrite("{\"error\": \"No new ip given!\"}")
        	return nil
	end
	
	local ip, prefix = _ip.IPv4ToIPAndPrefix(addr)
	if ip == nil or prefix == nil then
        	vWrite("{\"error\": \"%s is not a valid address!\"}" % addr)
        	return nil
	end
	
	-- _ip.IPv4ToIPAndPrefix checks prefix but not IP	
	if _ip.IPv4ValidIP(ip) ~= true then
        	vWrite("{\"error\": \"%s is not a valid ip address!\"}" % ip)
        	return nil
	end
	
	if _ip.IPv4ValidPrefix(prefix) ~= true then
        	vWrite("{\"error\": \"%s is not a valid ip address!\"}" % ip)
        	return nil
	end
	
        if prefix > 30 then
           vWrite("{\"error\": \"This router requires prefixes between 0 and 30 to allow for a minimum of 4 hosts on the network\"}" % ip)
           return  
        end
        
	local inst = deviceInstalled(realDev)
	if inst == 0 then
        	vWrite("{\"error\": \"Device %s is not installed\"}" % realDev)
        	return nil
	end
	
	return ip, prefix;
end

function IPInNetRange(ip, prefix, netName)

  local d = {network = netName, installed = 1}
  
  networkStatus(d)		
		
  if d.available == 1 then 
    if _ip.IPv4InRange(ip, prefix, d.HostIP, d.prefix) then
      return true
    end  
  end
  
  return false
  
end

-- addr address (ip/prefix or ip)
-- realDev radio0, eth0.1 or eth0.2
-- netName is the network for this device
function changeEthernetAddress(addr, realDev, net_name)

        local ip, prefix = checkForAddressChange(addr, realDev)
        if net_name == nil or ip == nil or prefix == nil then
        	return
        end
	
	if net_name == "wan" then
       		vWrite("{\"error\": \"You cannot set an ip address for WAN!\"}")
       		return
	end
	
	if realDev == "eth0.1" then
		if net_name ~= "lan1" then 
        		vWrite("{\"error\": \"No network lan1 for this ethernet interface found!\"}")
        		return
		end
		
		-- check that we are not in range of the WAN or lan2
		if IPInNetRange(ip, prefix, "wan") then
        		vWrite("{\"error\": \"New IP %s is in the IP range of the WAN\"}" % ip)
        		return
		end
		
		if IPInNetRange(ip, prefix, "lan2") then
        		vWrite("{\"error\": \"New IP %s is in the IP range of the other LAN interface\"}" % ip)
        		return
		end
	elseif realDev == "eth0.2" then
		if net_name ~= "lan2" then 
        		vWrite("{\"error\": \"No network lan2 for this ethernet interface found!\"}")
        		return
		end
		
		if IPInNetRange(ip, prefix, "lan1") then
        		vWrite("{\"error\": \"New IP %s is in the IP range of the other LAN interface\"}" % ip)
        		return
		end
	else
        	vWrite("{\"error\": \"You cannot change %s with this function!\"}" % realDev)
        	return
	end
  
	if IPInNetRange(ip, prefix, "wifi") then
       		vWrite("{\"error\": \"New IP %s is in the IP range of the wireless interface\"}" % ip)
       		return
	end
		
	setStaticNetwork(net_name, realDev, ip, prefix)
	
	_uci_real:commit("network")
	_uci_real:commit("wireless")
	
	-- requires restart of ifdown/up lan and dnsmasq
	if ptest == 1 then
		return
	end
	
	luci.sys.call("env -i /sbin/ifdown %s >/dev/null" % net_name)
	luci.sys.call("env -i /sbin/ifup %s >/dev/null" % net_name)
	
	luci.sys.call("env -i /etc/init.d/fix_hosts start >/dev/null")
	luci.sys.call("env -i /etc/init.d/dnsmasq restart >/dev/null")
	luci.sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
	luci.sys.call("env -i /etc/init.d/gpsd start >/dev/null")
end

function getNetNameByDevice(devName) 

        local net_name
        _uci_real:foreach("network", "interface", function(s)            
          local sec_name = s[".name"]  -- network name                                          
          typ_name = s[".type"]                                            
          if devName == s.ifname then
            net_name = sec_name
          end
        end)
        
        return net_name
end

function changeWifiKey(key) 
	local sec_name
	
	vWrite("HTTP/1.0 200 OK\r\n")
        vWrite("Content-Type: application/json\r\n\r\n")
        
	if not key then
       		vWrite("{\"error\": \"No new key given.\"}")
       		return
	end
	
	_uci_real:foreach("wireless", "wifi-iface",
	function(s)
    		sec_name = s[".name"]
      	end)
      
      	_uci_real:set("wireless", sec_name, "key", key)
		
	_uci_real:commit("wireless")
	
	-- requires restart of wifi, ifdown/up wifi and dnsmasq
	luci.sys.call("env -i /sbin/ifdown wifi >/dev/null")
	luci.sys.call("env -i /sbin/ifup wifi >/dev/null")
	luci.sys.call("env -i /sbin/wifi down >/dev/null")
	luci.sys.call("env -i /sbin/wifi up >/dev/null")
	
        vWrite("{}")
end

function changeWifi(params) 
	local addr
	local key
	local switch
	local restartWifi = 0
	
	for k, v in pairs(params) do
		if k == "ip" then
			if v then
				addr = v
			end
		end
		if k == "key" then
			if v then
				key = v
			end
		end
		if k == "switch" then
			if v then
				switch = v
			end
		end
	end
	
	if key ~= nil then
	  changeWifiKey(key)
	  return
	end

	vWrite("HTTP/1.0 200 OK\r\n")
        vWrite("Content-Type: application/json\r\n\r\n")
        
        if switch ~= nil then
        	if switch ~= "on" and switch ~= "off" then
	       		vWrite("{\"error\": \"Unkown wifi switch command %s\"}" % switch)
       			return
        	end
        end
        
        if switch == "off" then
        	-- check for at least one other access method (LAN)
        	local devices = getNetDevices()
        	
  		networkStatus(devices.eth01);
		networkStatus(devices.eth02);
        
        	if devices.eth01.available < 1 and devices.eth02.available < 1 then
	       		vWrite("{\"error\": \"You need to have at least one wired access available to switch wireless off. Neither LAN nor WAN are connected.\"}")
       			return
        	end
        	
                local sec_dev_name                                                                                                                                                  
                _uci_real:foreach("wireless", "wifi-device", function(s)                                                                                                        
                        sec_dev_name = s[".name"]                                                                                                                                         
                end)                                                                                                                                                            
                _uci_real:set("wireless", sec_dev_name, "disabled", "1")     
                    	
		_uci_real:commit("wireless")
		
		luci.sys.call("env -i /sbin/ifdown wifi >/dev/null")
		luci.sys.call("env -i /sbin/wifi down >/dev/null")
		
		return
        else
        	-- ignore - its done here anyways
        end
        
	local ip, prefix = checkForAddressChange(addr, "radio0")
	if ip == nil or prefix == nil then
		return
	end
	
	if IPInNetRange(ip, prefix, "wan") then
       		vWrite("{\"error\": \"New IP %s is in the IP range of the WAN network\"}" % ip)
       		return
	end
	if IPInNetRange(ip, prefix, "lan1") then
       		vWrite("{\"error\": \"New IP %s is in the IP range of the first LAN network\"}" % ip)
       		return
	end
	if IPInNetRange(ip, prefix, "lan2") then
       		vWrite("{\"error\": \"New IP %s is in the IP range of the second LAN network\"}" % ip)
       		return
	end
	
	if ip ~= nil then
		setStaticNetwork("wifi", "radio0", ip, prefix)
		restartWifi = 2
	end
	
        local sec_dev_name                                                                                                                                                  
        _uci_real:foreach("wireless", "wifi-device", function(s)                                                                                                        
	        sec_dev_name = s[".name"]                                                                                                                                         
        end)                                                                                                                                                            
        _uci_real:set("wireless", sec_dev_name, "disabled", "0")     
                
	if (restartWifi > 0) then
		_uci_real:commit("network")
		_uci_real:commit("wireless")
	end
	
        if ptest == 1 then
          return
        end  	
	
	if (restartWifi > 0) then
		-- requires restart of wifi, ifdown/up wifi and dnsmasq
		luci.sys.call("env -i /sbin/ifdown wifi >/dev/null")
		luci.sys.call("env -i /sbin/ifup wifi >/dev/null")
		luci.sys.call("env -i /sbin/wifi down >/dev/null")
		luci.sys.call("env -i /sbin/wifi up >/dev/null")
	end
	
	
	if (restartWifi > 1) then
		luci.sys.call("env -i /etc/init.d/fix_hosts start >/dev/null")
		luci.sys.call("env -i /etc/init.d/dnsmasq restart >/dev/null")
		luci.sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
		luci.sys.call("env -i /etc/init.d/gpsd start >/dev/null")
	end
	
       	vWrite("{}")
end

function changeNMEA(params) 
	local speed
	local device
	for k, v in pairs(params) do
		if k == "speed" then
			if isNumber(v) then
				speed = tonumber(v)
			end
		end
		if k == "device" then
			if isNumber(v) then
				device = tonumber(v)
			end
		end
	end

	vWrite("HTTP/1.0 200 OK\r\n")
        vWrite("Content-Type: application/json\r\n\r\n")
        
        if (device == nil ) or ((device < 0) or (device > 1)) then
        	vWrite("{\"internal error\": \"%d is an illegal device number\"}" % {device})
        	return
        end

	if (speed ~= nil) then
	        local dev = ""
	        local name = ""
	        if(device == 0) then 
	          dev = "/dev/ttyS0"
	          name= "serial0"
	        else
	          dev = "/dev/ttyS1"
	          name= "serial1"
	        end
	        
		_uci_real:set("iomode", name, "speed", speed)
		_uci_real:commit("iomode")
		
                sys.call("env -i /etc/init.d/iomode start >/dev/null")
        	vWrite("{}")
	else
        	vWrite("{\"error\": \"%s is not a valid speed!\"}" % {speed})
	end
end

function changeGps(params) 
	local port
	for k, v in pairs(params) do
		if k == "port" then
			if isNumber(v) then
				port = v
			end
		end
	end

	vWrite("HTTP/1.0 200 OK\r\n")
        vWrite("Content-Type: application/json\r\n\r\n")

	if port ~= nil then
		_uci_real:set("gpsd", "core", "port", port)
		_uci_real:commit("gpsd")
		luci.sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
		luci.sys.call("env -i /etc/init.d/gpsd start >/dev/null")
        	vWrite("{}")
	else
        	vWrite("{\"error\": \"Not a valid port number!\"}")
	end

end

function deviceInstalled(device)
        lst = _uci_real:get("vyacht", "network", "device")
        local installed = 0 
        for i = 1, #lst do
          if lst[i] == device then 
            installed = 1 
          end
        end
        return installed
end

function networkStatus(device) 
  device.available = 0
  if device.installed == 1 then
    local isUp = vubus:call("network.interface.%s" % device.network, "status", { })
    if isUp ~= nil then
      if isUp.up then
        device.status = "Up"
	device.available = 1
      else
        device.status = "Down"
      end
      for k, v in pairs(isUp) do
        if k == "ipv4-address" then
          -- array of pairs
          if #v > 0 then
            device.HostIP = v[1].address
            device.prefix = v[1].mask
          end
        end
      end
    else
      device.status = "Not connected"
    end
  else
    device.status = "Not installed"
  end
end

function getWifiKey(device)
  _uci_real:foreach("wireless", "wifi-iface",
  function(s)
    if s.device == device.name then
      device.key = s.key
    end
  end) 
	
  return wifi_data
end

function getNetDevices()
       
        -- first step: look at network devices and get their network names 
        -- this works only from /etc/config/vyacht or network
        local devices = {
          eth01 = {name = "eth0.1", installed = 0, network = ""}, 
          eth02 = {name = "eth0.2", installed = 0, network = ""}, 
          wifi  = {name = "radio0", installed = 0, network = ""}
        } 
        
        devices.eth01.installed = deviceInstalled(devices.eth01.name)
        devices.eth02.installed = deviceInstalled(devices.eth02.name)
        devices.wifi.installed = deviceInstalled(devices.wifi.name)
      
        _uci_real:foreach("network", "interface", function(s)            
          local sec_name = s[".name"]  -- network name                                          
          local net_name = sec_name
          typ_name = s[".type"]                                            
          
          local dev = _uci_real:get("network", sec_name, "ifname")
          local ip = _uci_real:get("network", sec_name, "ipaddr")
          local proto = _uci_real:get("network", sec_name, "proto")
          
          if dev ~= "lo" then
            for k, v in pairs(devices) do
              if v.installed == 1 then 
                if dev == v.name then
                  if net_name == "wan" then
                    v.type = "wan"
                  else
                    v.type = "lan"
                  end
                  
                  v.network = net_name
                  if proto ~= "dhcp" then
                    v.HostIP = ip 
                  end
                  v.proto = proto
                end
              else
                v.HostIP = "" 
                v.proto = ""
              end
            end
          end
        end)
        
        return devices
end

function getStatus() 

	-- network
        ntm = require "luci.model.network".init()
       
       
        -- first step: look at network devices and get their network names 
        -- this works only from /etc/config/vyacht or network

        local dev
        local devices = getNetDevices()
        
	-- GPS
	local port = _uci_real:get("gpsd", "core", "port")
	local has_gpsd = fs.access("/var/run/gpsd.pid")


	local gps_data = {
		Status = "Disconnected",
		Port   = port
	}
	if has_gpsd then
		gps_data.Status = "Running"
	end
	
	local NMEA_data = {{
		DeviceName = "/dev/ttyS0",
		Status = "TEST",
		Speed  = 4800
	}, 
	{
		DeviceName = "/dev/ttyS1",
		Status = "TEST",
		Speed = "4800",
	}}
		
        -- 3 devices: wifi, wan, lan1 or wifi, lan1, lan2
        -- max 1 wan
        -- 2 devices: wifi, wan or wifi, lan2
	networkStatus(devices.wifi);
  	networkStatus(devices.eth01);
	networkStatus(devices.eth02);
	
	getWifiKey(devices.wifi)

        -- NMEA speed
        local dev  = "/dev/ttyS0"
        local speed  = util.exec("stty -F %s speed" %{dev} )
        if speed then
          -- remember 0 is 1, lua is weird
          NMEA_data[1].Speed = speed:gsub("^%s*(.-)%s*$", "%1")
        end

        dev  = "/dev/ttyS1"
        speed  = util.exec("stty -F %s speed" %{dev} )
        if speed then
          NMEA_data[2].Speed = speed:gsub("^%s*(.-)%s*$", "%1")
        end
        
        vWrite("HTTP/1.0 200 OK\r\n")
        vWrite("Content-Type: application/json\r\n\r\n")

        local distversion = version.distversion

        -- kernel version needs some trimming
        local kernel = sys.exec("uname -r")
        kernel = kernel:find'^%s*$' and '' or kernel:match'^%s*(.*%S)'

	local data_to = {
		Hostname      = sys.hostname(),
		Firmware      = distversion,
		Time          = os.date(),
		Uptime        = sys.uptime(),
		KernelVersion = kernel,
		GpsStatus     = gps_data,
		NMEAStatus    = NMEA_data,
		NetDevices    = devices,
	}	
       
        _write_json(data_to)
end

-- _uci_real  = cursor or _uci_real or uci.cursor()
-- getStatus()

--local pkgname = "io"
--local package = util.exec("opkg list-installed | grep " .. pkgname)            
--for k in string.gmatch(package, "(.-)(%s)-(%s)(.-)\n") do
  -- wpad-mini - 20120910-1
--  print("line: " .. k)
--end 

