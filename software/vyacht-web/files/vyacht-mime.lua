--[[

HTTP protocol implementation for LuCI
(c) 2008 Freifunk Leipzig / Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

$Id: protocol.lua 9195 2012-08-29 13:06:58Z jow $

Simplified and stripped for vyacht by bernd@vyacht.net

]]--

module(..., package.seeall)

HTTP_MAX_CONTENT      = 1024*8		-- 8 kB maximum content size

-- (Internal function)
-- Initialize given parameter and coerce string into table when the parameter
-- already exists.
-- @param tbl	Table where parameter should be created
-- @param key	Parameter name
-- @return		Always nil
local function __initval( tbl, key )
	if tbl[key] == nil then
		tbl[key] = ""
	elseif type(tbl[key]) == "string" then
		tbl[key] = { tbl[key], "" }
	else
		table.insert( tbl[key], "" )
	end
end

-- (Internal function)
-- Append given data to given parameter, either by extending the string value
-- or by appending it to the last string in the parameter's value table.
-- @param tbl	Table containing the previously initialized parameter value
-- @param key	Parameter name
-- @param chunk	String containing the data to append
-- @return		Always nil
-- @see			__initval
local function __appendval( tbl, key, chunk )
	if type(tbl[key]) == "table" then
		tbl[key][#tbl[key]] = tbl[key][#tbl[key]] .. chunk
	else
		tbl[key] = tbl[key] .. chunk
	end
end

-- (Internal function)
-- Finish the value of given parameter, either by transforming the string value
-- or - in the case of multi value parameters - the last element in the
-- associated values table.
-- @param tbl		Table containing the previously initialized parameter value
-- @param key		Parameter name
-- @param handler	Function which transforms the parameter value
-- @return			Always nil
-- @see				__initval
-- @see				__appendval
local function __finishval( tbl, key, handler )
	if handler then
		if type(tbl[key]) == "table" then
			tbl[key][#tbl[key]] = handler( tbl[key][#tbl[key]] )
		else
			tbl[key] = handler( tbl[key] )
		end
	end
end

--- Decode a mime encoded http message body with multipart/form-data
-- Content-Type. Stores all extracted data associated with its parameter name
-- in the params table withing the given message object. Multiple parameter
-- values are stored as tables, ordinary ones as strings.
-- If an optional file callback function is given then it is feeded with the
-- file contents chunk by chunk and only the extracted file name is stored
-- within the params table. The callback function will be called subsequently
-- with three arguments:
--  o Table containing decoded (name, file) and raw (headers) mime header data
--  o String value containing a chunk of the file data
--  o Boolean which indicates wheather the current chunk is the last one (eof)
-- @param src		Ltn12 source function
-- @param msg		HTTP message object
-- @param filecb	File callback function (optional)
-- @return			Value indicating successful operation (not nil means "ok")
-- @return			String containing the error if unsuccessful
-- @see				parse_message_header

function mimedecode_message_body( msg, readcb, filecb )

	if msg and msg.env.CONTENT_TYPE then
		msg.mime_boundary = msg.env.CONTENT_TYPE:match("^multipart/form%-data; boundary=(.+)$")
	end

	if not msg.mime_boundary then
		return nil, "Invalid Content-Type found"
	end

	-- print("boundary= " .. msg.mime_boundary)

	local tlen   = 0
	local inhdr  = false
	local field  = nil
	local lchunk = nil
	local delim = "\r\n"

	local function parse_headers( chunk, field )

		local stat
		repeat
			chunk, stat = chunk:gsub(
				"^([A-Z][A-Za-z0-9%-_]+): +([^" .. delim .. "]+)" .. delim,
				function(k,v)
					field.headers[k] = v
					return ""
				end
			)
		until stat == 0

		chunk, stat = chunk:gsub("^" .. delim, "")

		-- End of headers
		if stat > 0 then
			if field.headers["Content-Disposition"] then
				if field.headers["Content-Disposition"]:match("^form%-data; ") then
					field.name = field.headers["Content-Disposition"]:match('name="(.-)"')
					field.file = field.headers["Content-Disposition"]:match('filename="(.+)"$')
				end
			end

			if not field.headers["Content-Type"] then
				field.headers["Content-Type"] = "text/plain"
			end

			if field.name and field.file and filecb then
				__initval( msg.params, field.name )
				__appendval( msg.params, field.name, field.file )

			elseif field.name then
				__initval( msg.params, field.name )

				-- store = function( hdr, buf, eof )
				-- __appendval( msg.params, field.name, buf )
				-- end
			end

			return chunk, true
		end
		return chunk, false
	end

	local function snk( chunk )
		tlen = tlen + ( chunk and #chunk or 0 )

		if msg.env.CONTENT_LENGTH and tlen > tonumber(msg.env.CONTENT_LENGTH) + 2 then
			return nil, "Message body size exceeds Content-Length"
		end

		if chunk and not lchunk then
			lchunk = delim .. chunk

		elseif lchunk then
			local data = lchunk .. ( chunk or "" )
			local spos, epos, found

			repeat
				spos, epos = data:find( delim .. "--" .. msg.mime_boundary .. delim, 1, true )

				if not spos then
					spos, epos = data:find( delim .. "--" .. msg.mime_boundary .. "--" .. delim, 1, true )
				end

				-- print("spos = " .. (spos or "-") .. ", epos = " .. (epos or "-"))

				if spos then
					local predata = data:sub( 1, spos - 1 )

					if inhdr then
						predata, eof = parse_headers( predata, field )

						if not eof then
							return nil, "Invalid MIME section header"
						elseif not field.name then
							return nil, "Invalid Content-Disposition header"
						end
					end

					local res, err = filecb( field, predata, true )
					if not res then
						return nil, err
					end

					field = { headers = { } }
					found = found or true

					data, eof = parse_headers( data:sub( epos + 1, #data ), field )
					inhdr = not eof
				end
			until not spos
			-- print("until not spos\n")

			if found then
				-- We found at least some boundary. Save
				-- the unparsed remaining data for the
				-- next chunk.
				lchunk, data = data, nil
				-- print("found")
			else
				-- There was a complete chunk without a boundary. Parse it as headers or
				-- append it as data, depending on our current state.
				if inhdr then
					lchunk, eof = parse_headers( data, field )
					inhdr = not eof
					-- print("inhdr\n")
				else
					-- We're inside data, so append the data. Note that we only append
					-- lchunk, not all of data, since there is a chance that chunk
					-- contains half a boundary. Assuming that each chunk is at least the
					-- boundary in size, this should prevent problems
					local res, err = filecb( field, lchunk, false )
					if not res then
						return nil, err
					end
					lchunk, chunk = chunk, nil
					-- print("not inhdr\n")
				end
			end
		end

		return true
	end

	local function readAll(readcb)
		local data = ""
		local error = "" 
		while (true) do
			local content = readcb()
			data, error = snk(content)
			if(not content) then break; end
	  	end
		return data, error 
	end

	return readAll(readcb)
end
