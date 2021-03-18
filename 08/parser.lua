local AsmGen = {}
AsmGen.__index = AsmGen

function AsmGen:write(instr)
  if type(instr) == 'string' then
    self.parser.output:write(instr, "\n")
  else
    for _, v in ipairs(instr) do
      self.parser.output:write(v, "\n")
    end
  end
end

function AsmGen:uniquelabel(prefix)
  self.parser.labelid = self.parser.labelid + 1
  return prefix .. "_" .. self.parser.labelid
end

function AsmGen:bootstrap(callinit)
  self:write{
    " // bootstrap",
    "  @256",
     "  D=A",
     "  @0",
     "  M=D"
   }
   if callinit then
     self:call('Sys.init', 0)
  end
end

function AsmGen:poptoreg(reg)
  self:write{"  @SP",
             "  M=M-1",
             "  A=M",
             "  D=M",
             "  @" .. reg,
             "  M=D"}
end

function AsmGen:popd()
  self:write{"  @SP",
             "  M=M-1",
             "  A=M",
             "  D=M"}
end

function AsmGen:cmp(type)
  local neqlabel = self:uniquelabel "neq"
  local joinlabel = self:uniquelabel "join"
  self:write{"  @SP",
             "  M=M-1",
             "  A=M",
             "  D=M",
             "  @SP",
             "  M=M-1",
             "  A=M",
             "  A=M",
             "  D=A-D",
             "  @" .. neqlabel,
             "  D;" .. type}
  self:pushbool(false)
  self:write{"  @" .. joinlabel,
             "  0;JMP",
             "(" .. neqlabel .. ")"}
  self:pushbool(true)
  self:write{"(" .. joinlabel .. ")"}
end

function AsmGen:binarylogic(type)
  self:write{"  @SP",
             "  M=M-1",
             "  A=M",
             "  D=M",
             "  @SP",
             "  M=M-1",
             "  A=M",
             "  A=M",
             "  D=D" .. type .. "A"}
  self:pushd()
end

function AsmGen:addsub(type)
  self:poptoreg "R13"
  self:poptoreg "R14"
  self:write{"  @R13",
             "  D=M",
             "  @R14",
             "  A=M",
             "  D=A" .. type .. "D"}
  self:pushd()
end

function AsmGen:neg()
  self:poptoreg "R13"
  self:write{
    "  @R13",
    "  D=-M"
  }
  self:pushd()
end

function AsmGen:lnot()
  self:poptoreg "R13"
  self:write{
    "  @R13",
    "  D=!M"
  }
  self:pushd()
end

function AsmGen:push(index, dest)
  self:write{
    "  @" .. index,
    "  D=A",
    "  @" .. dest,
    "  A=M",
    "  A=D+A",
    "  D=M"
  }
  self:pushd()
end

function AsmGen:pushfixed(index, dest)
  self:write{
    "  @" .. index,
    "  D=A",
    "  @" .. dest,
    "  A=D+A",
    "  D=M"
  }
  self:pushd()
end

function AsmGen:pushd()
  self:write{
    "  @SP",
    "  A=M",
    "  M=D",
    "  @SP",
    "  M=M+1"
  }
end

function AsmGen:pushbool(n)
  if n then 
    self:write"  D=-1"
  else
    self:write"  D=0"
  end
  self:pushd()
end

function AsmGen:pushconstant(n)
  self:write{
    "  @" .. n,
    "  D=A"
  }
  self:pushd()
end

function AsmGen:popstatic(id)
  self:poptoreg(self.staticprefix .. "." .. id)
end

function AsmGen:pushstatic(id)
  self:write{
    "  @" .. self.staticprefix .. "." .. id,
    "  D=M"
  }
  self:pushd()
end

-- pop, with index relative to the value of @dest
function AsmGen:pop(index, dest)
  self:poptoreg "R13"
  self:write{
    "  @" .. index,
    "  D=A",
    "  @" .. dest,
    "  A=M",
    "  D=D+A",
    "  @R15",
    "  M=D",
    "  @R13",
    "  D=M",
    "  @R15",
    "  A=M",
    "  M=D"
  }
end

-- pop, with index relative to a fixed point dest
function AsmGen:popfixed(index, dest)
  self:poptoreg "R13"
  self:write{
    "  @" .. index,
    "  D=A",
    "  @" .. dest,
    "  D=D+A",
    "  @R15",
    "  M=D",
    "  @R13",
    "  D=M",
    "  @R15",
    "  A=M",
    "  M=D"
  }
end

function AsmGen:label(id)
  self:write('(' .. id .. ')')
end

function AsmGen:ifgoto(id)
  self:popd()
  self:write{
    '  @' .. id,
    '  D;JNE'
  }
end

function AsmGen:jump(id)
  self:write{
    '  @' .. id,
      '  0;JMP'
    }
end

function AsmGen:func(label, numlocals)
  self:write{
    '(' .. label .. ')',
    "  @0",
    "  D=A"
  }
  for i = 1, numlocals do
    self:pushd()
  end
end

function AsmGen:ret()
  self:write{
    '// FRAME (R13) = LCL',
    '  @LCL',
    '  D=M',
    '  @R13',
    '  M=D',
    '// RET (R14) = *(FRAME - 5)',
    '  @5',
    '  A=D-A',
    '  D=M',
    '  @R14',
    '  M=D',
    '// *ARG = pop()'
  }
  self:popd();
  self:write{
    '  @ARG',
    '  A=M',
    '  M=D',
    '// SP = ARG + 1',
    '  @ARG',
    '  D=M+1',
    '  @SP',
    '  M=D',

    '// THAT = *(FRAME - 1)',
    '  @R13',
    '  D=M',
    '  @1',
    '  A=D-A',
    '  D=M',
    '  @THAT',
    '  M=D',
    '// THIS = *(FRAME - 2)',
    '  @R13',
    '  D=M',
    '  @2',
    '  A=D-A',
    '  D=M',
    '  @THIS',
    '  M=D',
    '// ARG = *(FRAME - 3)',
    '  @R13',
    '  D=M',
    '  @3',
    '  A=D-A',
    '  D=M',
    '  @ARG',
    '  M=D',
    '// LCL = *(FRAME - 4)',
    '  @R13',
    '  D=M',
    '  @4',
    '  A=D-A',
    '  D=M',
    '  @LCL',
    '  M=D',
    '// goto RET',
    '  @R14',
    '  A=M',
    '  0;JMP'
  }
end

function AsmGen:call(name, numargs)
  local retlabel = self:uniquelabel('ret' .. name)
  self:write{
    '  @' .. retlabel,
    '  D=A'
   }
  self:pushd();
  self:write{
    '  @LCL',
    '  D=M'
  }
  self:pushd();
  self:write{
    '  @ARG',
    '  D=M'
  }
  self:pushd();
  self:write{
    '  @THIS',
    '  D=M'
  }
  self:pushd();
  self:write{
    '  @THAT',
    '  D=M'}
  self:pushd();

  -- ARG = SP - n - 5

  self:write{
    '  @SP',
    '  D=M',
    '  @' .. math.tointeger(numargs + 5),
    '  D=D-A',
    '  @ARG',
    '  M=D',

  -- LCL = SP
    '  @SP',
    '  D=M',
    '  @LCL',
    '  M=D',

  -- goto f
    '  @' .. name,
    '  0;JMP',

  -- (return-address)
    '(' .. retlabel .. ')'}
end


function AsmGen:parsetokens(tokens, linenum, line)
  self:write('// ' .. line)
  if tokens[1] == 'add' then
    self:addsub '+' 
  elseif tokens[1] == 'sub' then
    self:addsub '-'
  elseif tokens[1] == 'neg' then
    self:neg()
  elseif tokens[1] == 'eq' then
    self:cmp 'JEQ'
  elseif tokens[1] == 'lt' then
    self:cmp 'JLT'
  elseif tokens[1] == 'gt' then
    self:cmp 'JGT'
  elseif tokens[1] == 'and' then
    self:binarylogic '&'
  elseif tokens[1] == 'or' then
    self:binarylogic '|'
  elseif tokens[1] == 'not' then
    self:lnot()
  elseif tokens[1] == 'push' and tokens[2] == 'constant' then
    self:pushconstant(tokens[3])
  elseif tokens[1] == 'pop' and tokens[2] == 'local' then
    self:pop(tokens[3], 'LCL')
  elseif tokens[1] == 'pop' and tokens[2] == 'argument' then
    self:pop(tokens[3], 'ARG')
  elseif tokens[1] == 'pop' and tokens[2] == 'this' then
    self:pop(tokens[3], 'THIS')
  elseif tokens[1] == 'pop' and tokens[2] == 'that' then
    self:pop(tokens[3], 'THAT')
  elseif tokens[1] == 'pop' and tokens[2] == 'temp' then
    self:popfixed(tokens[3], 'R5')
  elseif tokens[1] == 'pop' and tokens[2] == 'pointer' then
    self:popfixed(tokens[3], 'R3')
  elseif tokens[1] == 'pop' and tokens[2] == 'static' then
    self:popstatic(tokens[3])
  elseif tokens[1] == 'push' and tokens[2] == 'local' then
    self:push(tokens[3], 'LCL')
  elseif tokens[1] == 'push' and tokens[2] == 'this' then
    self:push(tokens[3], 'THIS')
  elseif tokens[1] == 'push' and tokens[2] == 'that' then
    self:push(tokens[3], 'THAT')
  elseif tokens[1] == 'push' and tokens[2] == 'argument' then
    self:push(tokens[3], 'ARG')
  elseif tokens[1] == 'push' and tokens[2] == 'pointer' then
    self:pushfixed(tokens[3], 'R3')
  elseif tokens[1] == 'push' and tokens[2] == 'temp' then
    self:pushfixed(tokens[3], 'R5')
  elseif tokens[1] == 'push' and tokens[2] == 'static' then
    self:pushstatic(tokens[3])
  elseif tokens[1] == 'label' then 
    self:label(tokens[2])
  elseif tokens[1] == 'if-goto' then 
    self:ifgoto(tokens[2])
  elseif tokens[1] == 'goto' then 
    self:jump(tokens[2])
  elseif tokens[1] == 'function' then 
    self:func(tokens[2], tokens[3])
  elseif tokens[1] == 'return' then 
    self:ret()
  elseif tokens[1] == 'call' then 
    self:call(tokens[2], tokens[3])
  else
    local err  = linenum .. ": unknown instruction '" .. line .. "'\n"
    io.stderr:write(err)
  end
end

function tokenise(line)
  local tokens = {}
  for token in line:gmatch("([%w_.:-]+)") do
    tokens[#tokens + 1] = token
  end
  return tokens
end

function makeAsmGen(parser, staticprefix)
  return setmetatable({
    parser = parser,
    staticprefix = staticprefix,
  }, AsmGen)
end

-------------------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

function Parser:parse(filename)
  io.stdout:write('parsing ' .. filename .. '\n')
  local linenum = 0
  local staticprefix = filename:gsub("[%/%\\]", "_")
  local gen = makeAsmGen(self, staticprefix)
  for line in io.lines(filename) do
    linenum = linenum + 1
    
    -- remove comments and whitespace
    line = line:gsub("//.*", "")
    line = line:gsub("^[%s]*(.-)[%s]*$", "%1")

    local tokens = tokenise(line)
    if #tokens > 0 then
      gen:parsetokens(tokens, linenum, line, filename)
    end
  end
end


function make(outputfile, callinit)
  io.stdout:write('destination ' .. outputfile .. '\n')
  local p = setmetatable({
    output = assert(io.open(outputfile, "w")),
    labelid = 0
  }, Parser)

  local gen = makeAsmGen(p, "")
  gen:bootstrap(callinit)

  return p
end

return {
  make = make
}
