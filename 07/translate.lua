local Parser = require 'parser'

local outputfile = (arg[1]:gsub("%.(.*)", ".asm"))
local parser = Parser.make(outputfile)

parser:parse(arg[1])

