local tokens = {}

tokens.split = function(input, separator)
    if separator == nil then
        separator = "%s"
    end
    local t = {}
    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
        table.insert(t, str)
    end
    return t
end

--; @Kiko
--; https://yourmomgae.yes
tokens.Initialize = function(self, input)
    self.ParsedString = self.split(input)

    local extra_tokens = {}

    extra_tokens.tokens = self.ParsedString

    extra_tokens.pop = function()
        table.remove(self.ParsedString, 1)
    end
    extra_tokens.get_and_pop = function()
        local TopToken = rawget(self.ParsedString, 1)
        table.remove(self.ParsedString, 1)
        return TopToken
    end
    extra_tokens.get = function()
        return rawget(self.ParsedString, 1)
    end
    
    return extra_tokens
end

local luau_op = {
    OGETENV = "A4",
    LOADNUMBER = "8C",
    MOVE = "52",
    LOADK = "6F",
    LOADNIL = "C6",
    CLEARSTACK = "A3",
    FORPREP = "A8",
    CALL = "9F",
    FORLOOP = "8B",
    RETURN = "82",
    CONCAT = "73"
}
local parsedBytes = tokens:Initialize("01 02 05 70 72 69 6E 74 04 77 61 72 6E 01 05 00 00 01 0F A3 00 00 00 8C 02 01 00 8C 00 0A 00 8C 01 01 00 A8 00 09 00 A4 03 01 00 00 00 00 40 52 04 02 00 9F 03 02 01 A4 03 03 00 00 00 20 40 52 04 02 00 9F 03 02 01 8B 00 F7 FF 82 00 01 00 04 03 01 04 00 00 00 40 03 02 04 00 00 20 40 00 00 01 18 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 01 00 00 00 00 00")

parsedBytes:get_and_pop()

function int_to_hex(num)
    if num == 0 then
        return '0'
    end
    local neg = false
    if num < 0 then
        neg = true
        num = num * -1
    end
    local hexstr = "0123456789ABCDEF"
    local result = ""
    while num > 0 do
        local n = math.mod(num, 16)
        result = string.sub(hexstr, n + 1, n + 1) .. result
        num = math.floor(num / 16)
    end
    if neg then
        result = '-' .. result
    end
    return result
end

function hex_format(hex)
    local str = "0000"
    return string.sub(str, 0, string.len(str) - string.len(hex)) .. hex
end

local constantSize  = tonumber(parsedBytes:get_and_pop(), 16)
local constantArray = {}
for i = 1, constantSize do
    local length = tonumber(parsedBytes:get_and_pop(), 16)
    local constant = ""
    for i2 = 1, length do
        constant = constant .. string.char(tonumber(parsedBytes:get_and_pop(), 16))
    end
    table.insert(constantArray, constant)
end 
print(string.format("local constantPool = {\n\t'%s'\n}", table.concat(constantArray, "',\n\t'")))
local Protos = tonumber(parsedBytes:get_and_pop(), 16)

function case(value, table, default)
    if rawget(table, value) then
        return rawget(table, value)();
    end
    if default == nil then
        return
    end
    return default();
end

function DebugOutput(Index, OP, A, B, C, Extra)
    local FormattedIndex = string.format("[%s]", hex_format(int_to_hex(Index)))
    print(FormattedIndex, OP, string.format("{ %s, %s, %s }", A, B, C), "\t\t\\", Extra)
end
for i = 1, Protos do
    local maxStackSize  = tonumber(parsedBytes:get_and_pop(), 16)
    local numParameters = tonumber(parsedBytes:get_and_pop(), 16)
    local numUpvalues   = tonumber(parsedBytes:get_and_pop(), 16)
    local isVarArg      = tonumber(parsedBytes:get_and_pop(), 16)
    local numInstructs  = tonumber(parsedBytes:get_and_pop(), 16)
    print("-= FUNCTION " .. tostring(i) .. " =-\n")
    print(".isVarArg", (isVarArg == "1" and "true" or "false"))
    print(".size", maxStackSize)
    print(".instruction(s)", numInstructs)
    print(".param(s)", numParameters)
    print(".upvalue(s)", numUpvalues)
    local i2 = 1
    local c_idx = 0
    local LastA = 0
    repeat
        i2 = i2 + 4
        local OP = tonumber(parsedBytes:get_and_pop(), 16)
        local A  = tonumber(parsedBytes:get_and_pop(), 16)
        local B  = tonumber(parsedBytes:get_and_pop(), 16)
        local C  = tonumber(parsedBytes:get_and_pop(), 16)
        case(int_to_hex(OP), {
            [luau_op.OGETENV] = function()
                c_idx = c_idx + 1
                DebugOutput(i2, "OGETENV", A, B, C, string.format("R[%d] = %s", A, constantArray[c_idx]))
                LastA = A
            end,
            [luau_op.LOADNUMBER] = function()
                DebugOutput(i2, "LOADNUMBER", A, B, C, string.format("R[%d] = %d", A, B))
                LastA = A
            end,
            [luau_op.MOVE] = function()
                DebugOutput(i2, "MOVE", A, B, C, string.format("R[%d] = R[%d]", A, B))
                LastA = A
            end,
            [luau_op.LOADK] = function()
                c_idx = c_idx + 1
                DebugOutput(i2, "LOADK", A, B, C, string.format("R[%d] = %s", A, constantArray[c_idx]))
                LastA = A
            end,
            [luau_op.LOADNIL] = function()
                DebugOutput(i2, "LOADNIL", A, B, C, string.format("R[%d] = nil", A))
                LastA = A
            end,
            [luau_op.CLEARSTACK] = function()
                DebugOutput(i2, "CLEARSTACK", A, B, C, "R = {}")
            end,
            [luau_op.FORPREP] = function()
                DebugOutput(i2, "FORPREP", A, B, C, string.format("R[%d] -= R[%d + 2]", A, A))
            end,
            [luau_op.FORLOOP] = function()
                DebugOutput(i2, "FORLOOP", A, B, C, string.format("R[%d] += R[%d + 2]", A, A))
            end,
            [luau_op.CONCAT] = function()
                DebugOutput(i2, "CONCAT", A, B, C, string.format("R[%d] = R[%d] .. R[%d]", A, B, C))
            end,
            [luau_op.RETURN] = function()
                if B == 1 then 
                    DebugOutput(i2, "RETURN", A, B, C, "return")
                elseif B >= 2 then
                    DebugOutput(i2, "RETURN", A, B, C, "return " .. string.format("R[%d] to R[%d]", A, A + B - 2))
                elseif B == 0 then
                    DebugOutput(i2, "RETURN", A, B, C, "return " .. string.format("R[%d] to R[%d]", A, LastA))
                end
            end,
            [luau_op.CALL] = function()
                local ReturnStr = ""
                if B == 0 then -- Has not been tested
                    ReturnStr = string.format("R[%d](R[%d] to R[%d])", A, A + 1, LastA)
                elseif B == 1 then 
                    ReturnStr = string.format("R[%d]()", A)
                elseif B >= 2 then
                    ReturnStr = string.format("R[%d](R[%d] to R[%d])", A, A + 1, A + B - 1)
                end
                local ReturnResults = ""
                -- Not tested
                if C >= 2 then 
                    ReturnResults = string.format("R[%d] to R[%d]", A, A+C-2) .. " = "
                elseif C == 0 then
                    ReturnResults = string.format("R[%d] = ", LastA + 1)
                end
                DebugOutput(i2, "CALL", A, B, C, ReturnResults .. ReturnStr)
            end,
        })
    until i2 >= (numInstructs * 4)
end
