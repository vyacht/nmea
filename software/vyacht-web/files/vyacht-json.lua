
module(..., package.seeall)

--- Send the given data as JSON encoded string.

-- @param data          Data to send
function write_json(x, writecb)

	if not writecb then
		return
	end
	
        if x == nil then
                writecb("null")
        elseif type(x) == "table" then
                local k, v
                if type(next(x)) == "number" then
                        writecb("[ ")
                        for k, v in ipairs(x) do
                                write_json(v, writecb)
                                if next(x, k) then
                                        writecb(", ")
                                end
                        end
                        writecb(" ]")
                else
                        writecb("{ ")
                        for k, v in pairs(x) do
                        writecb("%q: " % k)
                                write_json(v, writecb)
                                if next(x, k) then
                                        writecb(", ")
                                end
                        end
                        writecb(" }")
                end
        elseif type(x) == "number" or type(x) == "boolean" then
                if (x ~= x) then
                        -- NaN is the only value that doesn't equal to itself.
                        writecb("Number.NaN")
                else
                        writecb(tostring(x))
                end
        else
                writecb('"%s"' % tostring(x):gsub('["%z\1-\31]', function(c)
                        return '\\u%04x' % c:byte(1)
                end))
        end
end

