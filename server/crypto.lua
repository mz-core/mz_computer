MZComputer = MZComputer or {}
local Crypto = {}
local MASK = 0xffffffff

local K = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}

local function ror(x, n)
    x = x & MASK
    return ((x >> n) | ((x << (32 - n)) & MASK)) & MASK
end

local function be32(n)
    return string.char((n >> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff)
end

local function be64(n)
    -- FiveM strings cannot practically approach 2^32 bits here, but encode full 64-bit length.
    local hi = math.floor(n / 0x100000000)
    local lo = n & MASK
    return be32(hi) .. be32(lo)
end

local function sha256Raw(message)
    message = tostring(message or '')
    local bitLength = #message * 8
    local padLen = (56 - ((#message + 1) % 64)) % 64
    local data = message .. string.char(0x80) .. string.rep('\0', padLen) .. be64(bitLength)

    local h0,h1,h2,h3,h4,h5,h6,h7 =
        0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
        0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19

    for offset = 1, #data, 64 do
        local w = {}
        for i = 0, 15 do
            local p = offset + i * 4
            local b1,b2,b3,b4 = data:byte(p, p + 3)
            w[i + 1] = (((b1 << 24) | (b2 << 16) | (b3 << 8) | b4) & MASK)
        end
        for i = 17, 64 do
            local x = w[i - 15]
            local y = w[i - 2]
            local s0 = (ror(x,7) ~ ror(x,18) ~ (x >> 3)) & MASK
            local s1 = (ror(y,17) ~ ror(y,19) ~ (y >> 10)) & MASK
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & MASK
        end

        local a,b,c,d,e,f,g,h = h0,h1,h2,h3,h4,h5,h6,h7
        for i = 1, 64 do
            local s1 = (ror(e,6) ~ ror(e,11) ~ ror(e,25)) & MASK
            local ch = ((e & f) ~ (((~e) & MASK) & g)) & MASK
            local t1 = (h + s1 + ch + K[i] + w[i]) & MASK
            local s0 = (ror(a,2) ~ ror(a,13) ~ ror(a,22)) & MASK
            local maj = ((a & b) ~ (a & c) ~ (b & c)) & MASK
            local t2 = (s0 + maj) & MASK
            h,g,f,e,d,c,b,a = g,f,e,(d + t1) & MASK,c,b,a,(t1 + t2) & MASK
        end

        h0 = (h0 + a) & MASK
        h1 = (h1 + b) & MASK
        h2 = (h2 + c) & MASK
        h3 = (h3 + d) & MASK
        h4 = (h4 + e) & MASK
        h5 = (h5 + f) & MASK
        h6 = (h6 + g) & MASK
        h7 = (h7 + h) & MASK
    end

    return be32(h0)..be32(h1)..be32(h2)..be32(h3)..be32(h4)..be32(h5)..be32(h6)..be32(h7)
end

local function toHex(raw)
    return (raw:gsub('.', function(c) return string.format('%02x', string.byte(c)) end))
end

local function fromHex(hex)
    if type(hex) ~= 'string' or #hex % 2 ~= 0 or hex:find('[^0-9a-fA-F]') then return nil end
    return (hex:gsub('..', function(cc) return string.char(tonumber(cc, 16)) end))
end

function Crypto.sha256(value, raw)
    local digest = sha256Raw(value)
    return raw and digest or toHex(digest)
end

local function hmacSha256(key, message)
    if #key > 64 then key = sha256Raw(key) end
    if #key < 64 then key = key .. string.rep('\0', 64 - #key) end
    local o, i = {}, {}
    for idx = 1, 64 do
        local b = key:byte(idx)
        o[idx] = string.char(b ~ 0x5c)
        i[idx] = string.char(b ~ 0x36)
    end
    return sha256Raw(table.concat(o) .. sha256Raw(table.concat(i) .. message))
end

local function xorRaw(a, b)
    local out = {}
    for idx = 1, math.min(#a, #b) do
        out[idx] = string.char(a:byte(idx) ~ b:byte(idx))
    end
    return table.concat(out)
end

function Crypto.pbkdf2(password, saltRaw, iterations)
    iterations = math.max(1, math.floor(tonumber(iterations) or Config.Auth.pbkdf2Iterations))
    local u = hmacSha256(password, saltRaw .. be32(1))
    local result = u
    local yieldEvery = math.max(50, tonumber(Config.Auth.pbkdf2YieldEvery) or 250)
    for round = 2, iterations do
        u = hmacSha256(password, u)
        result = xorRaw(result, u)
        if round % yieldEvery == 0 then Wait(0) end
    end
    return result
end

local entropyCounter = 0
local function entropyContext(source, purpose)
    entropyCounter = entropyCounter + 1
    local chunks = {
        tostring(os.time()), tostring(GetGameTimer()), tostring(entropyCounter), tostring(math.random()),
        tostring({}), tostring(source or 0), tostring(purpose or '')
    }
    if source and source > 0 then
        for i = 0, 3 do
            local ok, token = pcall(GetPlayerToken, source, i)
            if ok and token then chunks[#chunks + 1] = tostring(token) end
        end
    end
    return table.concat(chunks, '|')
end

function Crypto.randomHex(bytes, source, purpose)
    bytes = math.max(8, math.floor(tonumber(bytes) or 16))
    local out, prev = {}, ''
    local seed = entropyContext(source, purpose)
    while #table.concat(out) < bytes do
        prev = sha256Raw(seed .. prev .. tostring(#out + 1) .. tostring(math.random()))
        out[#out + 1] = prev
    end
    return toHex(table.concat(out):sub(1, bytes))
end

function Crypto.hashPassword(password, source)
    local saltHex = Crypto.randomHex(16, source, 'password-salt')
    local saltRaw = assert(fromHex(saltHex))
    local iterations = Config.Auth.pbkdf2Iterations
    local derived = Crypto.pbkdf2(password, saltRaw, iterations)
    return string.format('pbkdf2-sha256$%d$%s$%s', iterations, saltHex, toHex(derived)), 'pbkdf2-sha256', 1
end

function Crypto.constantTimeEquals(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' then return false end
    local diff = #a ~ #b
    local max = math.max(#a, #b)
    for i = 1, max do
        local aa = a:byte(i) or 0
        local bb = b:byte(i) or 0
        diff = diff | (aa ~ bb)
    end
    return diff == 0
end

function Crypto.verifyPassword(password, encoded)
    if type(encoded) ~= 'string' then return false end
    local algo, iterText, saltHex, hashHex = encoded:match('^([%w%-]+)%$(%d+)%$([0-9a-fA-F]+)%$([0-9a-fA-F]+)$')
    if algo ~= 'pbkdf2-sha256' then return false end
    local iterations = tonumber(iterText)
    if not iterations or iterations < 1000 or iterations > 1000000 then return false end
    local saltRaw = fromHex(saltHex)
    if not saltRaw then return false end
    local derived = toHex(Crypto.pbkdf2(password, saltRaw, iterations))
    return Crypto.constantTimeEquals(string.lower(derived), string.lower(hashHex))
end

MZComputer.Crypto = Crypto
