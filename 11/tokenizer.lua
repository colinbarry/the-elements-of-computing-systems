--[[
-- a list of token types, the epxressions that match them, and their names.
-- Any token types without a name are considered whitespace and not output
-- as a token
]]

local types = {
  {
    meta = true,
    match = {'%s+', '%/%/[^%\n]*', '%/%*.*%*%/'}
  },
  {
    meta =  true,
    name = 'unterminatedComment',
    match = {'%/%*.*$'}
  },
  {
    name = 'keyword',
    match = {'class%f[%W]', 'constructor%f[%W]', 'function%f[%W]', 
             'method%f[%W]', 'field%f[%W]', 'static%f[%W]', 'var%f[%W]',
             'int%f[%W]', 'char%f[%W]', 'boolean%f[%W]', 'void%f[%W]',
             'true%f[%W]', 'false%f[%W]', 'null%f[%W]', 'this%f[%W]',
             'let%f[%W]', 'do%f[%W]', 'if%f[%W]', 'else%f[%W]', 'while%f[%W]',
             'return%f[%W]'}
  },
  {
    name = 'symbol',
    match = {'%{', '%}', '%(', '%)', '%[', '%]', '%.', '%,', '%;', '%+',
             '%-', '%*', '%/', '%&', '%|', '%<', '%>', '%=', '%~'}
  },
  {
    name = 'identifier',
    match = {'[%a_][%w_]*'}
  },
  {
    name = 'integerConstant',
    match = {'%d+'}
  },
  {
    name = 'stringConstant',
    match  = {'%".-%"'}
  }

}

function match(incomment, text, patterns)
  for _, match in ipairs(patterns) do
    local pattern = '^' .. match
    local lower, upper = text:find(pattern)
    if lower then
      return lower, upper
    end
  end
end

function tokenize(file)
  local tokens = {}
  local content = file:read()
  local linenum = 1
  local incomment = false

  while content do
    if #content == 0 then
      content = file:read()
      linenum = linenum + 1
    else
      local lower, upper, matchtype

      if incomment then
        lower, upper = content:find "%*%/"
        if lower then
          matchtype = types[1] -- comment type
          incomment = false
        end
      else
        for _, type in ipairs(types) do
          lower, upper = match(incomment, content, type.match)
          if lower then
            matchtype = type
            incomment = type.name == "unterminatedComment"
            break;
          end
        end
      end

      if incomment then
        content = ""
      else
        if not lower then
          io.stderr:write("syntax error ", content:match(".-\n"))
          os.exit(1)
        end

        if not matchtype.meta then
          local token = {
            tag = matchtype.name,
            content = content:sub(lower, upper),
            line = linenum
          }

          -- special case for strings: remove the quotes
          if token.tag == "stringConstant" then
            token.content = token.content:sub(2, -2)
          end

          tokens[#tokens + 1] = token
        end

        content = content:sub(upper + 1)
      end
    end
  end

  return tokens
end

return {
  tokenize = tokenize
}
