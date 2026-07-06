local uv = vim.uv or vim.loop
local bit = bit or bit32

local M = {}

local function bxor(a, b)
  return bit.bxor(a, b)
end

local function band(a, b)
  return bit.band(a, b)
end

local function rshift(a, b)
  return bit.rshift(a, b)
end

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function scheduled(callback, ...)
  if not callback then
    return
  end
  local args = { ... }
  vim.schedule(function()
    callback(unpack(args))
  end)
end

local function base64(data)
  local out = {}
  local len = #data

  for i = 1, len, 3 do
    local a = data:byte(i) or 0
    local b = data:byte(i + 1) or 0
    local c = data:byte(i + 2) or 0
    local n = a * 65536 + b * 256 + c

    local pad = ""
    if i + 1 > len then
      pad = "=="
    elseif i + 2 > len then
      pad = "="
    end

    out[#out + 1] = alphabet:sub(rshift(n, 18) + 1, rshift(n, 18) + 1)
    out[#out + 1] = alphabet:sub(band(rshift(n, 12), 63) + 1, band(rshift(n, 12), 63) + 1)
    out[#out + 1] = pad == "==" and "=" or alphabet:sub(band(rshift(n, 6), 63) + 1, band(rshift(n, 6), 63) + 1)
    out[#out + 1] = pad ~= "" and "=" or alphabet:sub(band(n, 63) + 1, band(n, 63) + 1)
  end

  return table.concat(out)
end

local function random_key()
  math.randomseed(os.time() + vim.fn.getpid())
  local bytes = {}
  for _ = 1, 16 do
    bytes[#bytes + 1] = string.char(math.random(0, 255))
  end
  return base64(table.concat(bytes))
end

local function mask_payload(payload, mask)
  local out = {}
  for i = 1, #payload do
    local key = mask:byte(((i - 1) % 4) + 1)
    out[i] = string.char(bxor(payload:byte(i), key))
  end
  return table.concat(out)
end

local function encode_frame(payload, opcode)
  opcode = opcode or 1
  local len = #payload
  local mask = ""
  for _ = 1, 4 do
    mask = mask .. string.char(math.random(0, 255))
  end

  local header = { string.char(0x80 + opcode) }
  if len < 126 then
    header[#header + 1] = string.char(0x80 + len)
  elseif len <= 65535 then
    header[#header + 1] = string.char(0x80 + 126, rshift(len, 8), band(len, 255))
  else
    local b1 = band(rshift(len, 24), 255)
    local b2 = band(rshift(len, 16), 255)
    local b3 = band(rshift(len, 8), 255)
    local b4 = band(len, 255)
    header[#header + 1] = string.char(0x80 + 127, 0, 0, 0, 0, b1, b2, b3, b4)
  end

  return table.concat(header) .. mask .. mask_payload(payload, mask)
end

local function decode_one(buffer)
  if #buffer < 2 then
    return nil
  end

  local b1, b2 = buffer:byte(1, 2)
  local opcode = band(b1, 0x0f)
  local masked = band(b2, 0x80) ~= 0
  local len = band(b2, 0x7f)
  local offset = 3

  if len == 126 then
    if #buffer < 4 then
      return nil
    end
    local a, b = buffer:byte(3, 4)
    len = a * 256 + b
    offset = 5
  elseif len == 127 then
    if #buffer < 10 then
      return nil
    end
    local b5, b6, b7, b8 = buffer:byte(7, 10)
    len = b5 * 16777216 + b6 * 65536 + b7 * 256 + b8
    offset = 11
  end

  local mask
  if masked then
    if #buffer < offset + 3 then
      return nil
    end
    mask = buffer:sub(offset, offset + 3)
    offset = offset + 4
  end

  local finish = offset + len - 1
  if #buffer < finish then
    return nil
  end

  local payload = buffer:sub(offset, finish)
  if masked then
    payload = mask_payload(payload, mask)
  end

  return {
    opcode = opcode,
    payload = payload,
    rest = buffer:sub(finish + 1),
  }
end

function M.connect(socket_path, callbacks)
  callbacks = callbacks or {}
  local pipe = uv.new_pipe(false)
  local client = {
    pipe = pipe,
    connected = false,
    closed = false,
    buffer = "",
    handshake_done = false,
  }

  function client:send_text(text)
    if self.closed or not self.connected then
      return false, "websocket is not connected"
    end
    self.pipe:write(encode_frame(text, 1))
    return true
  end

  function client:close()
    if self.closed then
      return
    end
    self.closed = true
    pcall(function()
      self.pipe:write(encode_frame("", 8))
    end)
    pcall(function()
      self.pipe:read_stop()
    end)
    pcall(function()
      self.pipe:close()
    end)
  end

  local function fail(err)
    if client.closed then
      return
    end
    client.closed = true
    pcall(function()
      pipe:close()
    end)
    scheduled(callbacks.on_error, err)
  end

  pipe:connect(socket_path, function(err)
    if err then
      fail(err)
      return
    end

    local key = random_key()
    local request = table.concat({
      "GET / HTTP/1.1",
      "Host: localhost",
      "Upgrade: websocket",
      "Connection: Upgrade",
      "Sec-WebSocket-Key: " .. key,
      "Sec-WebSocket-Version: 13",
      "",
      "",
    }, "\r\n")

    pipe:write(request)
    pipe:read_start(function(read_err, chunk)
      if read_err then
        fail(read_err)
        return
      end

      if not chunk then
        scheduled(callbacks.on_close)
        return
      end

      client.buffer = client.buffer .. chunk

      if not client.handshake_done then
        local header_end = client.buffer:find("\r\n\r\n", 1, true)
        if not header_end then
          return
        end

        local header = client.buffer:sub(1, header_end + 3)
        if not header:match("^HTTP/1%.1 101") and not header:match("^HTTP/1%.0 101") then
          fail("websocket handshake failed: " .. vim.split(header, "\r\n")[1])
          return
        end

        client.handshake_done = true
        client.connected = true
        client.buffer = client.buffer:sub(header_end + 4)
        scheduled(callbacks.on_open, client)
      end

      while client.handshake_done do
        local frame = decode_one(client.buffer)
        if not frame then
          break
        end

        client.buffer = frame.rest
        if frame.opcode == 1 then
          scheduled(callbacks.on_message, frame.payload)
        elseif frame.opcode == 8 then
          client:close()
          scheduled(callbacks.on_close)
          break
        elseif frame.opcode == 9 then
          pipe:write(encode_frame(frame.payload, 10))
        end
      end
    end)
  end)

  return client
end

return M
