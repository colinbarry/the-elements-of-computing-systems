local tokenizer = require 'tokenizer'
local compilerengine = require 'engine'
local vmwriter = require 'vmwriter'
local lfs = require 'lfs'

function compile(filename)
  local input = assert(io.open(filename, "r"))
  local output = assert(io.open(filename:gsub(".jack$", ".vm"), "w"))
  local tokens = tokenizer.tokenize(input)
  local writer = vmwriter.new(output)

  compilerengine.compile(tokens, writer)
end

local source = arg[1]
if not source then
  io.stderr:write("no filename or directory specified\n")
  os.exit()
end

local mode = lfs.attributes(source, 'mode')
if not mode then
  io.stdout:write(source, ' could not be opened')
  os.exit(1)
end

if mode == 'directory' then
  -- compile all .jack files in the directory
  
  -- remove trailing / or \
  if source:sub(-1) == '\\' or source:sub(-1) == '/' then 
    source = source:sub(1, -2)
  end

  -- the name of the .jack file will be the name of the bottom-most
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
  for file in lfs.dir(source) do
      if file:match(".jack$") then
        compile(path .. file)
      end
  end
else
  compile(source)
end
