local nixio = require "nixio"
local bit   = nixio.bit

module(..., package.seeall)

function IPv4ValidPrefix(prefix)
  if prefix == nil then
    return false
  end
  
  prefix = tonumber(prefix)
  
  if prefix < 0 or prefix > 32 then
    return false
  end
  
  return true
end

function IPv4InRange(testAddress, testPrefix, address, prefix)

  -- print("taddr = " .. testAddress .. ", tpref= " .. testPrefix ..
  --  ", addr= " .. address .. ", pref= " .. prefix)

  local ipar = IPv4ToLong(address)
  local tipar = IPv4ToLong(testAddress)
  
  local mask = getNetmaskValue(prefix)
  local hosts = getHosts(prefix)
  local tmask = getNetmaskValue(testPrefix)
  local thosts = getHosts(testPrefix)
 
  local lower = bit.band(ipar, mask) 
  local upper = lower + hosts - 1
  local tlower = bit.band(tipar, tmask) 
  local tupper = tlower + thosts - 1
  
  -- print("test= [" .. tlower .. ", " .. tupper .."], other= [" .. lower .. ", " .. upper .."]")
  
  if tupper <  lower or tlower > upper then
  	return false
  else
  	return true
  end
end

function IPv4ValidIP(ip)

	local lip = IPv4IpToArray(ip)
	
	if lip == nil then
		return false
	end
	
	if #lip ~= 4 then
		return false
	end
	
	if lip[1] == 127 then
		return false
	end
	
	if lip[1] == 0 and lip[2] == 0  and lip[3] == 0  and lip[4] == 0 then
		return false
	end
	
        return true
end

function IPv4ToLong(address)
	local ip = IPv4AddressToArray(address)
	local l = nil 
	if ip ~= nil then
		l = 256^3*ip[1] + 256^2* ip[2] + 256*ip[3] + ip[4]
	end
	return l
end

function IPv4ToIPAndPrefix(address)

        local addr = address or "0.0.0.0/0"

        local prefix = addr:match("/(.+)")
        addr = addr:gsub("/.+","")
        
        if prefix then
                prefix = tonumber(prefix)
                if not prefix or prefix < 0 or prefix > 32 then 
                  prefix = nil 
                  addr = nil
                end
        else
        	-- TODO - we hardcode this here for now
                prefix = 24
        end
        
        return addr, prefix

end

function IPv4AddressToArray(address)
        
        address = address or "0.0.0.0/0"
        
	address, prefix = IPv4ToIPAndPrefix(address)        
	if address == nil then
	  return nil
	end
	
	local ip = IPv4IpToArray(address)
	
	if ip ~= nil and prefix then
		return ip, prefix;
        end
end

function IPv4IpToArray(ip)

	local ok = 0
        local ipaddress = {0,0,0,0} 
        
        ipaddress[1], ipaddress[2],ipaddress[3],ipaddress[4] = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	 
	i = 1	
	if #ipaddress == 4 then
		ok = 1
	end
	for i = 1, #ipaddress do
		if ipaddress[i] ~= nil then
	        	ipaddress[i] = tonumber(ipaddress[i])
			if ipaddress[i] < 0 or ipaddress[i] > 255 then
				ok = 0
			end 
		else
			ok = 0
		end
	end
	if ok == 1 then
		return ipaddress;
        end
        
	return nil
end

-- will return the netmask as a long value between 0 and 2^32 - 1 
function getNetmaskValue(prefix)
  local n = 4294967295
  local l = 0
  for i = 1, 32 - prefix  do
    l = bit.lshift(l, 1)
    l = bit.bor(1, l)
  end
  return n - l
end

-- returns netmask as a string
function getNetmaskString(prefix)
  local m = getNetmask(prefix)
  return string.format("%i.%i.%i.%i", m[1],  m[2],  m[3],  m[4])
end

-- returns netmask as an array[4]
function getNetmask(prefix)
  local m = {255, 255, 255, 255}
  -- print("getNetmask: prefix = " .. prefix)
 
  for i = 1, 4 do 
    local l = 0 
    if (i * 8) > (32 - prefix) then 
      v = (32 - prefix) - (i-1)*8 
    else 
      v = 8 
    end
    -- print("i= " .. i .. ", v= " .. v)
    for i2 = 1, v do
      l = bit.lshift(l, 1)
      l = bit.bor(1, l)
    end
    m[5-i] = 255 - l
    if m[5-i] > 0 then return m end
    end
  return m  
end

-- returns the number of hosts for a give netmask prefix
function getHosts(prefix)
  return 2 ^ (32 -prefix)
end



