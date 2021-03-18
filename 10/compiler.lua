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

--
-- appends the given child to the parent node
function append(parent, child)
  assert(parent)
  assert(child)
  -- if child.content then print(parent.tag, child.content) end
  parent[#parent + 1] = child
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

function Compiler:compileclassvardec()
  local node = {tag = "classVarDec"}
  assert(self:check("keyword", "static") or self:check("keyword", "field"))

  append(node, self:next())
  append(node, self:compiletype())
  
  append(node, self:expect("identifier"))
  while self:check("symbol", ",") do
    append(node, self:next())
    append(node, self:expect("identifier"))
  end
  append(node, self:expect("symbol", ";"))

  return node
end


-- @todo use these named funcs over expecting identifiers directly. or not!
function Compiler:compileclassname()
  return self:except("identifier")
end

function Compiler:compilevarname()
  return self:expect("identifier")
end

function Compiler:compilesubroutinename()
  return self:except("identifier")
end

function Compiler:compiletype()
  if self:check("keyword", "int")
      or self:check("keyword", "char")
      or self:check("keyword", "boolean")
      or self:check("identifier") then
      return self:next()
  else
    self:syntaxerror("expected type")
  end
end

function Compiler:compileparameterlist()
  local node = { tag = "parameterList" }

  if not self:check("symbol", ")") then
    append(node, self:compiletype())
    append(node, self:expect("identifier"))

    while self:check("symbol", ",") do
      append(node, self:next())
      append(node, self:compiletype())
      append(node, self:expect("identifier"))
    end
  end

  return node
end

function Compiler:compilevardec()
  local node = { tag = "varDec" }
  append(node, self:expect("keyword", "var"))
  append(node, self:compiletype())
  append(node, self:expect("identifier"))
  while self:check("symbol", ",") do
    append(node, self:next())
    append(node, self:expect("identifier"))
  end
  append(node, self:expect("symbol", ";"))
  return node
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

function Compiler:compilesubroutinecall(node)
  append(node, self:next())
  if self:check("symbol", ".") then
    append(node, self:next())
    append(node, self:expect("identifier"))
  end
  append(node, self:expect("symbol", "("))
  append(node, self:compileexpressionlist())
  append(node, self:expect("symbol", ")"))
end

function Compiler:compileterm()
  local node = { tag = "term" }
  if self:check("integerConstant")
      or self:check("stringConstant")
      or self:check("keyword", "true")
      or self:check("keyword", "false")
      or self:check("keyword", "null")
      or self:check("keyword", "this") then
    append(node, self:next())
  elseif self:check("identifier") and self:checkahead(1, "symbol", "[") then 
      append(node, self:next())
      append(node, self:next())
      append(node, self:compileexpression())
      append(node, self:expect("symbol", "]"))
  elseif self:check("identifier") and self:checkahead(1, "symbol", "(") then
    self:compilesubroutinecall(node)
  elseif self:check("identifier") and self:checkahead(1, "symbol", ".") then
    self:compilesubroutinecall(node)
  elseif self:check("identifier") then
    append(node, self:next())
  elseif self:check("symbol", "(") then
    append(node, self:next())
    append(node, self:compileexpression())
    append(node, self:expect("symbol", ")"))
  elseif (self:checkunaryop()) then
    append(node, self:next())
    append(node, self:compileterm())
  else
    self:syntaxerror("expected term") 
  end

  return node
end

function Compiler:compileexpressionlist()
  local node = { tag = "expressionList" }

  if not self:check("symbol", ")") then
    append(node, self:compileexpression())
    while self:check("symbol", ",") do
      append(node, self:next())
      append(node, self:compileexpression())
    end
  end

  return node
end

function Compiler:compileexpression()
  local node = { tag = "expression" }

  append(node, self:compileterm())

  while self:checkop() do
    append(node, self:next())
    append(node, self:compileterm())
  end

  return node
end

function Compiler:compileletstatement()
  local node = { tag = "letStatement" }

  append(node, self:expect("keyword", "let"))
  append(node, self:compilevarname())

  if self:check("symbol", "[") then
    append(node, self:next())
    append(node, self:compileexpression())
    append(node, self:expect("symbol", "]"))
  end

  append(node, self:expect("symbol", "="))
  append(node, self:compileexpression())
  append(node, self:expect("symbol", ";"))

  return node
end

function Compiler:compiledostatement()
  local node = { tag = "doStatement" }

  append(node, self:expect("keyword", "do"))
  self:compilesubroutinecall(node)
  append(node, self:expect("symbol", ";"))

  return node
end

function Compiler:compilereturnstatement()
  local node = { tag = "returnStatement" }

  append(node, self:expect("keyword", "return"))
  if not self:check("symbol", ";") then
    append(node, self:compileexpression())
  end
  append(node, self:expect("symbol", ";"))

  return node
end

function Compiler:compileifstatement()
  local node = { tag = "ifStatement" }

  append(node, self:expect("keyword", "if"))
  append(node, self:expect("symbol", "("))
  append(node, self:compileexpression());
  append(node, self:expect("symbol", ")"))
  append(node, self:expect("symbol", "{"))
  append(node, self:compilestatements())
  append(node, self:expect("symbol", "}"))

  if self:check("keyword", "else") then
    append(node, self:next())
    append(node, self:expect("symbol", "{"))
    append(node, self:compilestatements())
    append(node, self:expect("symbol", "}"))
  end

  return node
end

function Compiler:compilewhilestatement()
  local node = { tag = "whileStatement" }

  append(node, self:expect("keyword", "while"))
  append(node, self:expect("symbol", "("))
  append(node, self:compileexpression());
  append(node, self:expect("symbol", ")"))
  append(node, self:expect("symbol", "{"))
  append(node, self:compilestatements())
  append(node, self:expect("symbol", "}"))

  return node
end


function Compiler:compilestatements()
  local node  = { tag = "statements" }

  while self:check("keyword", "let")
        or self:check("keyword", "if")
        or self:check("keyword", "while")
        or self:check("keyword", "do")
        or self:check("keyword", "return") do
      local stmnt = self:peek()

      if stmnt.content == "let" then
        append(node, self:compileletstatement())
      elseif stmnt.content == "do" then
        append(node, self:compiledostatement())
      elseif stmnt.content == "return" then
        append(node, self:compilereturnstatement())
      elseif stmnt.content == "if" then
        append(node, self:compileifstatement())
      elseif stmnt.content == "while" then
        append(node, self:compilewhilestatement())
      end
    end

  return node
end

function Compiler:compilesubroutinebody()
  local node = { tag = "subroutineBody" }

  append(node, self:expect("symbol", "{"))

  while self:check("keyword", "var") do
    append(node, self:compilevardec())
  end

  append(node, self:compilestatements())

  append(node, self:expect("symbol", "}"))

  return node
end

function Compiler:compilesubroutinedec()
  if not (self:check("keyword", "constructor") 
      or self:check("keyword", "function")
      or self:check("keyword", "method")) then
      self:syntaxerror("expected constructor, function, or method")
  end

  local node = { tag = "subroutineDec" }

  append(node, self:next())

  if self:check('keyword', 'void') then
    append(node, self:next())
  else
    append(node, self:compiletype())
  end
  
  append(node, self:expect("identifier"))
  append(node, self:expect("symbol", "("))
  append(node, self:compileparameterlist())
  append(node, self:expect("symbol", ")"))
  append(node, self:compilesubroutinebody())

  return node
end

function Compiler:compileclass()
  local node = {tag = "class"}
  append(node, self:expect("keyword", "class"))
  append(node, self:expect("identifier"))
  append(node, self:expect("symbol", "{"))

  while self:check("keyword", "static") or self:check("keyword", "field") do
    append(node, self:compileclassvardec())
  end

  while not self:check("symbol", "}") do
    append(node, self:compilesubroutinedec())
  end

  append(node, self:expect("symbol", "}"))

  return node
end

function newcompiler(tokens)
  local compiler = setmetatable({}, Compiler)
  compiler.tokens = tokens
  compiler.index = 1
  return compiler
end


function compile(tokens)
  local c = newcompiler(tokens)
  return c:compileclass()
end

return {
  compile = compile
}
