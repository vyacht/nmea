
vtest = 1
mtest = 1
ptest = 1
local _ip    = require "vyacht-ip"
local vy     = require "vyacht"
local bus    = require "ubus"

_uci_real  = cursor or _uci_real or uci.cursor()                
vubus       = bus.connect()

        
function test_validAddress(ip, valid)
	iparr, prefix = _ip.IPv4AddressToArray(ip)
	if valid then
		assert((iparr ~= nil) and (prefix ~= null))
	else
		assert((iparr == nil) and (prefix == null))
	end
end

function test_validIP(ip, valid)
	assert(_ip.IPv4ValidIP(ip) == valid)
end

function test_validPrefix(prefix, valid)
	assert(_ip.IPv4ValidPrefix(prefix) == valid)
end

function test_addressToAddressAndPrefix(address)
	local ip, prefix = _ip.IPv4ToIPAndPrefix(address)
	if prefix == nil and ip == nil then
	  prefix = ""
	  ip = ""
	end
	print("address= " .. address .. ", ip = " .. ip .. ", prefix= " .. prefix)
end


test_addressToAddressAndPrefix("192.168.1.1")
test_addressToAddressAndPrefix("192.168.1.1/33")
test_addressToAddressAndPrefix("sadsadsa/ds")
test_addressToAddressAndPrefix(".......")

function test_addressToAddressAndPrefix(address)
	local ip, prefix = _ip.IPv4ToIPAndPrefix(address)
	if prefix == nil and ip == nil then
	  prefix = ""
	  ip = ""
	end
	print("address= " .. address .. ", ip = " .. ip .. ", prefix= " .. prefix)
end

function testNetmaskValue(prefix)                                                       
	print("prefix = " .. prefix .. ", mask= " .. _ip.getNetmask(prefix))                 
end                                                                                

function testNetmask(prefix)                                                       
  local ip = _ip.getNetmask(prefix)
  if ip == nil then
    print("prefix = " .. prefix .. " is nil")
  end
  print("prefix = " .. prefix .. ", mask= " .. string.format("%i.%i.%i.%i", ip[1], ip[2], ip[3], ip[4]))
end                                                                                

test_addressToAddressAndPrefix("192.168.1.1")
test_addressToAddressAndPrefix("192.168.1.1/33")
test_addressToAddressAndPrefix("sadsadsa/ds")
test_addressToAddressAndPrefix(".......")

test_validAddress("192.168.1.1", true)
test_validAddress("192.168.1.1", true)
test_validAddress("192.1.1", false)
test_validAddress("192.168..1", false)
test_validAddress("192.168.256.1", false)
test_validAddress("192.168.-11.1", false)
test_validAddress("192.168.11.1/24", true)
test_validAddress("192.168.11.1/0", true)
test_validAddress("192.168.11.1/33", false)
test_validAddress("sumpf", false)
test_validAddress("sadhjjsad.asdsad.aasd.sss/sd", false)
test_validAddress("........./.", false)
test_validAddress("..../.", false)

test_validIP("192.168.1.1", true)
test_validIP("192.168.1.1", true)
test_validIP("192.1.1", false)
test_validIP("192.168..1", false)
test_validIP("192.168.256.1", false)
test_validIP("192.168.-11.1", false)
test_validIP("192.168.11.1", true)
test_validIP("sumpf", false)
test_validIP("sadhjjsad.asdsad.aasd.sss", false)
test_validIP(".........", false)

test_validPrefix(0, true)
test_validPrefix(14, true)
test_validPrefix(-1, false)
test_validPrefix(33, false)

test_validPrefix("0", true)
test_validPrefix("14", true)
test_validPrefix("-1", false)
test_validPrefix("33", false)

assert(         1 == _ip.getHosts(32))
assert(         2 == _ip.getHosts(31))
assert(       256 == _ip.getHosts(24))
assert(    262144 == _ip.getHosts(14))
assert(2147483648 == _ip.getHosts(1))
assert(4294967296 == _ip.getHosts(0))

function testInRange(testIp, testPrefix, rangeIp, prefix, valid)
  if _ip.IPv4InRange(testIp, testPrefix, rangeIp, prefix) then
  	assert(valid)
  else
  	assert(valid ~= true)
  end
end

testNetmask(32)
testNetmask(31)
testNetmask(24)
testNetmask(14)
testNetmask(1)
testNetmask(0)

testInRange("192.168.10.1", "24", "192.168.10.148", "24", true)
testInRange("192.168.10.1", "32", "192.168.10.148", "24", true)
testInRange("192.168.9.1", "24", "192.168.10.148", "24", false)
testInRange("192.168.9.1", "16", "192.168.10.148", "16", true)
testInRange("1.1.1.1", "32", "192.168.10.148", "1", false)
testInRange("1.1.1.1", "32", "192.168.10.148", "0", true)

vy.changeEthernetAddress("192.168.10.1", "eth01", "lan1")
vy.changeEthernetAddress("192.168.10.1", "eth02", "lan2")

vy.changeEthernetAddress("192.168.10.1", "eth0.1", "lan1")
vy.changeEthernetAddress("192.168.10.1", "eth0.2", "lan2")
vy.changeEthernetAddress("192.168.10.1/32", "eth0.2", "lan2")
vy.changeEthernetAddress("192.168.10.1/33", "eth0.2", "lan2")
vy.changeEthernetAddress("192.168..1/32", "eth0.2", "lan2")
vy.changeEthernetAddress("192.168.10.1/32", "radio0", "wifi")
vy.changeEthernetAddress("192.168.10.1/32", "eth0.2", "lan2")
vy.changeEthernetAddress("192.168.9.1/16", "eth0.2", "lan2")
vy.changeEthernetAddress("192.168.9.1/24", "eth0.2", "lan2")

print("-- changing wan")
vy.changeWan("192.168.10.1", "eth0.2", "wan", "lan2")
vy.changeWan("192.168.10.1", "eth0.2", "lan", "wan")
vy.changeWan("192.168.2.1", "eth0.2", "lan", "wan")


local start, limit = vy.dhcpHostsFromPrefix(24)
print("start = %s, limit = %s" % {start, limit})
assert(start == 100 and limit == 125)             
  
start, limit = vy.dhcpHostsFromPrefix(30)
print("start = %s, limit = %s" % {start, limit})
assert(start == 1 and limit == 3)             
                
