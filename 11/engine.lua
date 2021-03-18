local symbols = require 'symbols'
local vmwriter = require 'vmwriter'

local Compiler = {}
Compiler.__index = Compiler

function Compiler:next()
  local t = self.tokens[self.index]
  self:advance()
  return t
end

function Compiler:peek()
  local t = self.tokens[self.index]
  return t
end

function Compiler:advance()
  self.index = self.index + 1
end

function Compiler:syntaxerror(msg)
  local token = self:peek()
  local err
  if token then
    err = token.line .. ": " .. msg .. " got " .. token.tag .. " " .. token.content
  else
    err = msg .. " got nothing"
  end
  error(err, 2)
end

-- checks that that next token is has the given tag and content. If content is
-- not specified, only the tag type will be compared. This will consume
-- the next token. If the token is not of the expected type, compilation
-- will throw an error.
-- @return the matched token
function Compiler:expect(tag, content)
  local t = self:peek()
  if not t or t.tag ~= tag or (content and t.content ~= content) then
    local s
    if content then
      s = string.format("expected %s %s", tag, content)
    else
      s = string.format("expected %s", tag)
    end

    self:syntaxerror(s)
  else
    self:advance()
    return t
  end
end

-- without consuming the token, checks that it matches the tag and content.
-- If content is not specified, only the tag type is compared.
-- @return the matching token
function Compiler:check(tag, content)
  local t = self.tokens[self.index]
  return t and t.tag == tag and (not content or t.content == content)
end

-- without consuming the token, checks that it matches the tag and content.
-- If content is not specified, only the tag type is compared.
-- @return the matching token
function Compiler:checkahead(places, tag, content)
  local t = self.tokens[self.index + places]
  return t and t.tag == tag and (not content or t.content == content)
end

function Compiler:label(prefix)
  local id = self.nextlabelid
  self.nextlabelid = self.nextlabelid + 1
  return prefix .. id
end

function Compiler:compileclassvardec()
  local kind, type, identifier, storage

  assert(self:check("keyword", "static") or self:check("keyword", "field"))
  kind = self:next();
  if kind.content == "static" then
    storage = symbols.Type.STATIC
  else
    storage = symbols.Type.FIELD
  end

  type = self:compiletype()

  identifier = self:expect("identifier")
  self.symbols:define(identifier.content, type.content, storage)
  
  while self:check("symbol", ",") do
    self:next()
    local identifier = self:expect("identifier")
    self.symbols:define(identifier.content, type.content, storage)
  end
  self:expect("symbol", ";")
end

function Compiler:compiletype()
  if self:check("keyword", "int")
      or self:check("keyword", "char")
      or self:check("keyword", "boolean") then
      return self:next()
  elseif self:check("identifier") then
      local id = self:next()
      id.symbol = { category = "type", use = "ref" }
      return id
  else
    self:syntaxerror("expected type")
  end
end

function Compiler:compileparameterlist()
  if not self:check("symbol", ")") then
    local identifier, type

    type = self:compiletype()

    identifier = self:expect("identifier")
    self.symbols:define(identifier.content, type.content, symbols.Type.ARG)

    while self:check("symbol", ",") do
      self:next()

      type = self:compiletype()

      identifier = self:expect("identifier")
      self.symbols:define(identifier.content, type.content, symbols.Type.ARG)
    end
  end
end

function Compiler:pushstringliteral(str)
  local len = #str
  self.writer:writepush(vmwriter.Segment.CONST, len)
  self.writer:writecall("String.new", 1)

  for i = 1, len do
    self.writer:writepush(vmwriter.Segment.CONST, str:sub(i, i):byte())
    self.writer:writecall("String.appendChar", 2)
  end
end

function Compiler:pushvar(name)
  local kind = self.symbols:kindof(name)
  local index = self.symbols:indexof(name)
  local segment

  if kind == symbols.Type.VAR then
    segment = vmwriter.Segment.LOCAL
  elseif kind == symbols.Type.ARG then
    segment = vmwriter.Segment.ARG
  elseif kind == symbols.Type.FIELD then
    segment = vmwriter.Segment.THIS
  elseif kind == symbols.Type.STATIC then
    segment = vmwriter.Segment.STATIC
  end

  self.writer:writepush(segment, index);
end

function Compiler:popvar(name)
  local kind = self.symbols:kindof(name)
  local index = self.symbols:indexof(name)
  local segment

  if kind == symbols.Type.VAR then
    segment = vmwriter.Segment.LOCAL
  elseif kind == symbols.Type.ARG then
    segment = vmwriter.Segment.ARG
  elseif kind == symbols.Type.FIELD then
    segment = vmwriter.Segment.THIS
  elseif kind == symbols.Type.STATIC then
    segment = vmwriter.Segment.STATIC
  end

  self.writer:writepop(segment, index);
end

function Compiler:compilevardec()
  local type, identifier
  self:expect("keyword", "var")
  type = self:compiletype()
  identifier = self:expect("identifier")

  self.symbols:define(identifier.content, type.content, symbols.Type.VAR)

  while self:check("symbol", ",") do
    self:next()
    identifier = self:expect("identifier")

    self.symbols:define(identifier.content, type.content, symbols.Type.VAR)
  end
  self:expect("symbol", ";")
end

function Compiler:checkop()
  return self:check("symbol", "+")
    or self:check("symbol", "-")
    or self:check("symbol", "*")
    or self:check("symbol", "/")
    or self:check("symbol", "&")
    or self:check("symbol", "|")
    or self:check("symbol", "<")
    or self:check("symbol", ">")
    or self:check("symbol", "=")
end

function Compiler:compileop()
  if self:checkop() then
    return self:next()
  else
    self:syntaxerror("expected op")
  end
end

function Compiler:checkunaryop()
  return self:check("symbol", "-") or self:check("symbol", "~")
end

function Compiler:compilesubroutinecall()
  local funcname, numexprs
  local args = 0

  if self:checkahead(1, "symbol", ".") then
    local class, subroutine
    class = self:expect("identifier") -- class / var name

    -- lookup class in symbols
    local kind = self.symbols:kindof(class.content)
    if kind ~= symbols.Type.NONE then
      self:pushvar(class.content)
      funcname = self.symbols:typeof(class.content) .. "."
      args = 1
    else
      funcname = class.content .. "."
    end

    self:expect("symbol", ".")
    subroutine = self:expect("identifier")

    funcname = funcname .. subroutine.content
  else
    local subroutine = self:expect("identifier")
    subroutine.symbol = { category = "subroutine", use = "ref" }
    self.writer:writepush(vmwriter.Segment.POINTER, 0)
    args = 1

    funcname = self.class .. "." .. subroutine.content
  end

  self:expect("symbol", "(")
  numexprs = self:compileexpressionlist()
  self:expect("symbol", ")")

  self.writer:writecall(funcname, numexprs + args)
end

function Compiler:compileterm()
  if self:check("integerConstant") then
    local term = self:next()
    self.writer:writepush(vmwriter.Segment.CONST, term.content)
  elseif self:check("keyword", "true") then
    self:next()
    self.writer:writepush(vmwriter.Segment.CONST, "0")
    self.writer:writearithmetic(vmwriter.Arithmetic.NOT);
  elseif self:check("keyword", "false")
      or self:check("keyword", "null") then
    self:next()
    self.writer:writepush(vmwriter.Segment.CONST, "0")
  elseif self:check("keyword", "this") then
    self:next()
    self.writer:writepush(vmwriter.Segment.POINTER, "0")
  elseif self:check("stringConstant") then
    self:pushstringliteral(self:next().content)
  elseif self:check("identifier") and self:checkahead(1, "symbol", "[") then 
      local identifier = self:next()
      self:next()
      self:compileexpression()
      self:pushvar(identifier.content)
      self.writer:writearithmetic(vmwriter.Arithmetic.ADD)
      self.writer:writepop(vmwriter.Segment.POINTER, 1)
      self.writer:writepush(vmwriter.Segment.THAT, 0)
      self:expect("symbol", "]")
  elseif self:check("identifier") and self:checkahead(1, "symbol", "(") then
    self:compilesubroutinecall()
  elseif self:check("identifier") and self:checkahead(1, "symbol", ".") then
    self:compilesubroutinecall()
  elseif self:check("identifier") then
      local identifier = self:next()
      self:pushvar(identifier.content)
  elseif self:check("symbol", "(") then
    self:next()
    self:compileexpression()
    self:expect("symbol", ")")
  elseif (self:checkunaryop()) then
    local op = self:next().content;
    self:compileterm()
    if op == "-" then
      self.writer:writearithmetic(vmwriter.Arithmetic.NEG)
    elseif op == "~" then
      self.writer:writearithmetic(vmwriter.Arithmetic.NOT)
    end
  else
    self:syntaxerror("expected term") 
  end
end

function Compiler:compileexpressionlist()
  local numexprs = 0
  if not self:check("symbol", ")") then
    self:compileexpression()
    numexprs = numexprs + 1
    while self:check("symbol", ",") do
      self:next()
      self:compileexpression()
      numexprs = numexprs + 1
    end
  end
  return numexprs
end

function Compiler:compileexpression()
  self:compileterm()

  while self:checkop() do
    local op = self:next()
    self:compileterm()

    if op.content == "+" then
      self.writer:writearithmetic(vmwriter.Arithmetic.ADD)
    elseif op.content == "-" then
      self.writer:writearithmetic(vmwriter.Arithmetic.SUB)
    elseif op.content == "=" then
      self.writer:writearithmetic(vmwriter.Arithmetic.EQ)
    elseif op.content == ">" then
      self.writer:writearithmetic(vmwriter.Arithmetic.GT)
    elseif op.content == "<" then
      self.writer:writearithmetic(vmwriter.Arithmetic.LT)
    elseif op.content == "&" then
      self.writer:writearithmetic(vmwriter.Arithmetic.AND)
    elseif op.content == "|" then
      self.writer:writearithmetic(vmwriter.Arithmetic.OR)
    elseif op.content == "*" then
      self.writer:writecall("Math.multiply", 2)
    elseif op.content == "/" then
      self.writer:writecall("Math.divide", 2)
    end
  end
end

function Compiler:compileletstatement()
  local segment, index

  self:expect("keyword", "let")

  local identifier = self:expect("identifier")

  if self:check("symbol", "[") then
    self:next()
    self:compileexpression()
    self:expect("symbol", "]")

    self:pushvar(identifier.content)
    self.writer:writearithmetic(vmwriter.Arithmetic.ADD)

    self:expect("symbol", "=")
    self:compileexpression()
    self:expect("symbol", ";")

    self.writer:writepop(vmwriter.Segment.TEMP, 0)
    self.writer:writepop(vmwriter.Segment.POINTER, 1)
    self.writer:writepush(vmwriter.Segment.TEMP, 0)
    self.writer:writepop(vmwriter.Segment.THAT, 0)
  else
    self:expect("symbol", "=")
    self:compileexpression()
    self:expect("symbol", ";")
    self:popvar(identifier.content)
  end
end

function Compiler:compiledostatement()
  self:expect("keyword", "do")
  self:compilesubroutinecall()
  self.writer:writepop(vmwriter.Segment.TEMP, 0) -- discard return result
  self:expect("symbol", ";")
end

function Compiler:compilereturnstatement()
  self:expect("keyword", "return")
  if self:check("symbol", ";") then
    self.writer:writepush(vmwriter.Segment.CONST, 0)
  else
    self:compileexpression()
  end
  self:expect("symbol", ";")

  self.writer:writereturn();
end

function Compiler:compileifstatement()
  local truelabel = self:label("IF_TRUE")
  local falselabel = self:label("IF_FALSE")

  self:expect("keyword", "if")
  self:expect("symbol", "(")
  self:compileexpression()

  self.writer:writeif(truelabel)
  self.writer:writegoto(falselabel)
  self.writer:writelabel(truelabel)

  self:expect("symbol", ")")
  self:expect("symbol", "{")
  self:compilestatements()
  self:expect("symbol", "}")


  if self:check("keyword", "else") then
    local endlabel = self:label("IF_END")
    self.writer:writegoto(endlabel)
    self.writer:writelabel(falselabel)
    self:next()
    self:expect("symbol", "{")
    self:compilestatements()
    self:expect("symbol", "}")
    self.writer:writelabel(endlabel)
  else
    self.writer:writelabel(falselabel)
  end
end

function Compiler:compilewhilestatement()
  local startlabel = self:label("WHILE_EXP")
  local endlabel = self:label("WHILE_END")

  self:expect("keyword", "while")
  self:expect("symbol", "(")
  self.writer:writelabel(startlabel)
  self:compileexpression()
  self.writer:writearithmetic(vmwriter.Arithmetic.NOT)
  self.writer:writeif(endlabel)
  self:expect("symbol", ")")
  self:expect("symbol", "{")
  self:compilestatements()
  self:expect("symbol", "}")

  self.writer:writegoto(startlabel)
  self.writer:writelabel(endlabel)
end


function Compiler:compilestatements()
  while self:check("keyword", "let")
        or self:check("keyword", "if")
        or self:check("keyword", "while")
        or self:check("keyword", "do")
        or self:check("keyword", "return") do
      local stmnt = self:peek()

      if stmnt.content == "let" then
        self:compileletstatement()
      elseif stmnt.content == "do" then
        self:compiledostatement()
      elseif stmnt.content == "return" then
        self:compilereturnstatement()
      elseif stmnt.content == "if" then
        self:compileifstatement()
      elseif stmnt.content == "while" then
        self:compilewhilestatement()
      end
    end
end

function Compiler:compilesubroutinebody(classname, subroutinename, functype)
  local numlocals

  self:expect("symbol", "{")

  while self:check("keyword", "var") do
    self:compilevardec()
  end

  numlocals = self.symbols:varcount(symbols.Type.VAR) 
  self.writer:writefunction(classname .. "." .. subroutinename, numlocals)

  if functype == "constructor" then
    local numfields = self.symbols:varcount(symbols.Type.FIELD)
    self.writer:writepush(vmwriter.Segment.CONST, numfields)
    self.writer:writecall("Memory.alloc", "1")
    self.writer:writepop(vmwriter.Segment.POINTER, 0)
  elseif functype == "method" then
    self.writer:writepush(vmwriter.Segment.ARG, 0)
    self.writer:writepop(vmwriter.Segment.POINTER, 0)
  end

  self:compilestatements()
  self:expect("symbol", "}")
end

function Compiler:compilesubroutinedec()
  if not (self:check("keyword", "constructor") 
      or self:check("keyword", "function")
      or self:check("keyword", "method")) then
      self:syntaxerror("expected constructor, function, or method")
  end

  local functype
  functype = self:next().content;

  self.nextlabelid = 0 -- scope of labelids is the current function

  if self:check('keyword', 'void') then
    self:next()
    self.rettype = "void"
  else
    local type = self:compiletype()
    self.rettype = type.content
  end

  self.symbols:clearsubroutinesymbols()

  if functype == "method" then
    self.symbols:define("this", self.class, symbols.Type.ARG)
  end

  local identifier = self:expect("identifier")
  identifier.symbol = { category = "subroutine", use = "define" }

  self:expect("symbol", "(")
  self:compileparameterlist()

  self:expect("symbol", ")")
  self:compilesubroutinebody(self.class, identifier.content, functype)

  self.symbols:clearsubroutinesymbols()
end

function Compiler:compileclass()
  self:expect("keyword", "class")
  local class = self:expect("identifier")

  self.class = class.content;

  class.symbol = { category = "class", use = "define" }
  self:expect("symbol", "{")

  while self:check("keyword", "static") or self:check("keyword", "field") do
    self:compileclassvardec()
  end

  while not self:check("symbol", "}") do
    self:compilesubroutinedec()
  end

  self:expect("symbol", "}")
end

function newcompiler(tokens, writer)
  local compiler = setmetatable({}, Compiler)
  compiler.tokens = tokens
  compiler.index = 1
  compiler.symbols = symbols.new()
  compiler.writer = writer
  compiler.nextlabelid = 0
  return compiler
end

function compile(tokens, writer)
  local c = newcompiler(tokens, writer)
  return c:compileclass()
end

return {
  compile = compile
}
