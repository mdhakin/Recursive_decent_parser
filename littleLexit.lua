


lexit = require "lexit"  -- Import lexit module


prog = "x=++++a"


for lexstr, cat in lexit.lex(prog) do

		print(lexstr)
		print(cat)


    end
