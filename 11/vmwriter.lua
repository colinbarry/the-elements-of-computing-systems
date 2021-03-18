local VmWriter = {}
VmWriter.__index = VmWriter

local Segment = {
  CONST = 1,
  ARG = 2,
  LOCAL = 3,
  STATIC = 4,
  THIS = 5,
  THAT = 6,
  POINTER = 7,
  TEMP = 8
}

local segmentnames = { 
  "constant",
  "argument", 
  "local",
  "static",
  "this",
  "that",
  "pointer",
  "temp"
}

local Arithmetic  = {
  ADD = 1,
  SUB = 2,
  NEG = 3,
  EQ = 4,
  GT = 5,
  LT = 6,
  AND = 7,
  OR = 8,
  NOT = 9
}

local arithmeticnames = {
  "add",
  "sub",
  "neg",
  "eq",
  "gt",
  "lt",
  "and",
  "or",
  "not"
}

function VmWriter:writeln(s)
  self.output:write(s, "\n")
end

function VmWriter:writefunction(name, nlocals)
  self:writeln("function " ..  name .. " " .. nlocals)
end

function VmWriter:writepush(segment, index)
  self:writeln("push " .. segmentnames[segment] .. " " .. index)
end

function VmWriter:writepop(segment, index)
  self:writeln("pop " .. segmentnames[segment] .. " " .. index)
end

function VmWriter:writecall(name, args)
  self:writeln("call " .. name .. " " .. args)
end

function VmWriter:writereturn()
  self:writeln("return")
end

function VmWriter:writelabel(label)
  self:writeln("label " .. label)
end

function VmWriter:writeif(label)
  self:writeln("if-goto " .. label)
end

function VmWriter:writegoto(label)
  self:writeln("goto " .. label)
end

function VmWriter:writearithmetic(op)
  self:writeln(arithmeticnames[op])
end

function new(output)
  local writer = {
    output = output
  }
  return setmetatable(writer, VmWriter)
end

return {
  new = new,
  Segment = Segment,
  Arithmetic = Arithmetic
}
