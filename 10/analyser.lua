local tokenizer = require 'tokenizer'
local compiler = require 'compiler'
local lfs = require 'lfs'


function printnode(output, node, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  if node.content then
    output:write(prefix, "<", node.tag, "> ", sanitise(node.content), " </", node.tag, ">\n")
  else
    output:write(prefix, "<", node.tag, ">\n")
    for _, v in ipairs(node) do
      printnode(output, v, indent + 1)
    end
    output:write(prefix, "</", node.tag, ">\n")
  end
end

function sanitise(content)
  return content:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

function analyse(filename)
  local input = assert(io.open(filename, "r"))
  local tokens = tokenizer.tokenize(input)
  local tree = compiler.compile(tokens)
  local output = assert(io.open(filename:gsub(".jack$", "_cpb.xml"), "w"))

  printnode(output, tree)
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
        analyse(path .. file)
      end
  end
else
  analyse(source)
end
