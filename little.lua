
parseit = require "parseit"

prog = 'x=++++a'

good, done, ast = parseit.parse(prog)

print(ast)
