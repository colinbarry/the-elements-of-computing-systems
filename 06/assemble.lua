local dests = { 
  ['M'] = '001',
  ['D'] = '010',
  ['MD'] = '011',
  ['A'] = '100',
  ['AM'] = '101',
  ['AD'] = '110',
  ['AMD'] = '111'
}

local comps = {
  ['0'] =  '0101010',
  ['1'] =  '0111111',
  ['-1'] = '0111010',
  ['!D'] = '0001101',
  ['!A'] = '0110001',
  ['-D'] = '0001111',
  ['-A'] = '0110011',
  ['D+1'] = '0011111',
  ['A+1'] = '0110111',
  ['D-1'] = '0001110',
  ['A-1'] = '0110010',
  ['D+A'] = '0000010',
  ['D-A'] = '0010011',
  ['A-D'] = '0000111',
  ['D&A'] = '0000000',
  ['D|A'] = '0010101',
  ['!M'] = '1110001',
  ['-M'] = '1110011',
  ['M+1'] = '1110111',
  ['M-1'] = '1110010',
  ['D+M'] = '1000010',
  ['D-M'] = '1010011',
  ['M-D'] = '1000111',
  ['D&M'] = '1000000',
  ['D|M'] = '1010101',
  ['D'] = '0001100',
  ['A'] = '0110000',
  ['M'] = '1110000'
}

local jumps = {
  ['JGT'] = '001',
  ['JEQ'] = '010',
  ['JGE'] = '011',
  ['JLT'] = '100',
  ['JNE'] = '101',
  ['JLE'] = '110',
  ['JMP'] = '111'
}

local fixedsymbols = {
  ['R0'] = 0,
  ['R1'] = 1,
  ['R2'] = 2,
  ['R3'] = 3,
  ['R4'] = 4,
  ['R5'] = 5,
  ['R6'] = 6,
  ['R7'] = 7,
  ['R8'] = 7,
  ['R9'] = 9,
  ['R10'] = 10,
  ['R11'] = 11,
  ['R12'] = 12,
  ['R13'] = 13,
  ['R14'] = 14,
  ['R15'] = 15,
  ['SP'] = 0,
  ['LCL'] = 1,
  ['ARG'] = 2,
  ['THIS'] = 3,
  ['THAT'] = 4,
  ['SCREEN'] = 0x4000,
  ['KBD'] = 0x6000

}

local linenum = 0
local commands = {}
local symbols = {}
local numvars = 0

function match(token, groups)
  return groups[token]
end

function numtobinary(num)
  num = math.tointeger(num)

  local result = ''
  for i = 14, 0, -1 do
    local x = 2^i
    if num >= x then
      result = result .. '1'
      num = num -x
    else
      result = result .. '0'
    end
  end

  return result
end

function resolve(symbol)
  local c = symbol:sub(1, 1)
  if c >= '0' and c <= '9' then
    return numtobinary(symbol)
  elseif fixedsymbols[symbol] then
    return numtobinary(fixedsymbols[symbol])
  elseif symbols[symbol] then
    return numtobinary(symbols[symbol].addr)
  else
    -- must be a new variable: allocated space for it
    local addr = numvars + 0x10
    numvars = numvars + 1
    symbols[symbol] = {
      addr = addr
    }
    
    return numtobinary(addr)
  end
end

function err(msg, linenum, text)
      local msg = string.format('%i: %s, "%s"', linenum, msg, text)
      error(msg)
      os.exit(1)
end

io.input(arg[1])
local outfile = arg[1]:gsub("%..*", ".hack")
io.output(outfile)

for line in io.lines() do
  linenum = linenum + 1

  -- remove comments
  line = line:gsub("//.*$", "")

  -- remove all whitespace
  line = line:gsub("[%s%G]", "");

  if #line ~= 0 then
    local symbol = line:match("%((.-)%)")
    if symbol then
      symbols[symbol] = {
        addr = #commands
      }
    elseif line:sub(1, 1) == '@' then
      -- a-instruction
      commands[#commands + 1] = {
        type = 'a',
        value = line:sub(2)
      }
    else 
      -- c-instruction
      local originalline = line
      local dest, comp, jump

      local token, remains = line:match("(.-)=(.*)")
      if token then
        dest = match(token, dests)
        if dest == nil then
          err('invalid destination', linenum, originalline)
        else
          line = remains
        end
      end

      token, remains = line:match("(.-)(;.*)")
      if token == nil then
        token = line
        remains = ""
      end

      comp = match(token, comps)
      if comp == nil then
        err('unexpected compute', linenum, originalline)
      end

      token = line:match(";(.*)")
      if token then
        jump = match(token, jumps)
        if jump == nil then
          err('unexpected jump', linenum, originalline)
        end
      end

      commands[#commands + 1] = {
        type = 'c',
        dest = dest,
        comp = comp,
        jump = jump
      }
    end
  end
end

for _, cmd in ipairs(commands) do
  if cmd.type == 'a' then
    io.write('0', resolve(cmd.value), '\n')
  elseif cmd.type == 'c' then
    io.write('111', cmd.comp, cmd.dest or '000', cmd.jump or '000', '\n')
  end
end

