local Symbols = {}
Symbols.__index = Symbols;

local Type  = { NONE = 0, STATIC = 1, FIELD = 2, ARG = 3, VAR = 4 };

-- clear the subroutine table when a new subroutine starts
function Symbols:clearsubroutinesymbols()
  self.subroutine = {}
end

function Symbols:define(name, type, kind)
  local dest 
  if kind == Type.STATIC or kind == Type.FIELD then
    dest = self.class
  else
    dest = self.subroutine
  end

  dest[#dest + 1] = {
    name = name,
    type = type,
    kind = kind,
    index = self:varcount(kind)
  }
end

function countkind(kind, table)
  local sum = 0
  for _, v in ipairs(table) do
    if v.kind == kind then sum = sum + 1 end
  end
  return sum
end

function find(self, name)
  for _, table in ipairs { self.subroutine, self.class } do
    for _, v in ipairs(table) do
      if v.name == name then return v end
    end
  end
end

function Symbols:varcount(kind)
  if kind == Type.STATIC or kind == Type.FIELD then
    return countkind(kind, self.class)
  else
    return countkind(kind, self.subroutine)
  end
end

function Symbols:kindof(name)
  local def = find(self, name)
  if def then return def.kind
  else return Type.NONE end
end

function Symbols:typeof(name)
  local def = find(self, name)
  if def then return def.type
  else error('no symbol found with name of ' .. name) end
end

function Symbols:indexof(name)
  local def = find(self, name)
  if def then return def.index
  else error('no symbol found with name of ' .. name) end
end


function new()
  local symbols = {
    class = {},
    subroutine = {}
  }

  return setmetatable(symbols, Symbols)
end

return {
  new = new,
  Type = Type
}
