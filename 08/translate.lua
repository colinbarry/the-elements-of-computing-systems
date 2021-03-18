local Parser = require 'parser'
local lfs = require 'lfs'

local source = arg[1]
if not source then
  io.stdout:write('usage: translate source\n')
  os.exit(1)
end

local mode = lfs.attributes(source, 'mode')
if not mode then
  io.stdout:write(source, ' could not be opened')
  os.exit(1)
end

if mode == 'directory' then
  -- compile all .vm files in the directory
  
  -- remove trailing / or \
  if source:sub(-1) == '\\' or source:sub(-1) == '/' then 
    source = source:sub(1, -2)
  end

  -- the name of the .vm file will be the name of the bottom-most
  -- directory.
  local dirname
  if source:find('/') then 
    dirname = source:match('%/([^/]*)$')
  elseif source:find('\\') then 
    dirname = source:match('%\\([^/]*)$')
  else
    dirname = source
  end

  local path = source .. '/'
  local parser = Parser.make(path .. dirname .. '.asm', true)
  for file in lfs.dir(source) do
      if file:match(".vm$") then
        parser:parse(path .. file)
      end
  end
else
  -- single .vm file
  local outputfile = source:gsub('%.(.*)', '.asm')
  local parser = Parser.make(outputfile, false)
  parser:parse(source)
end

