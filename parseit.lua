  -- parseit.lua
-- Matthew D. Hakin
-- 3 March 2019
--
-- Recursive-Descent Parser
-- Requires lexit.lua

-- Grammar
-- Start Symbol: program
--
--		program 	-> 		stmt-list
-- 		stmt_list	->  	{ statement }
--    	statement	->  	�write� �(� write_arg { �,� write_arg } �)�
--		    	 		|  	�def� ID �(� �)� stmt_list �end�
--		    	 		|  	�if� expr stmt_list { �elseif� expr stmt_list } [ �else� stmt_list ] �end�
--				 		|  	�while� expr stmt_list �end�
--			  	 		|  	�return� expr
--		    	 		|  	ID ( �(� �)� | [ �[� expr �]� ] �=� expr )
--    	write_arg	->  	�cr�
--		    	 		|  	STRLIT
--		    	 		|  	expr
--    	expr	  	->  	comp_expr { ( �&&� | �||� ) comp_expr }
--    	comp_expr	->  	�!� comp_expr
--    	 				|  	arith_expr { ( �==� | �!=� | �<� | �<=� | �>� | �>=� ) arith_expr }
--    	arith_expr	->  	term { ( �+� | �-� ) term }
--    	term	  	->  	factor { ( �*� | �/� | �%� ) factor }
--    	factor	  	->  	�(� expr �)�
--						|  	( �+� | �-� ) factor
--			    	 	|  	NUMLIT
--			    	 	|  	( �true� | �false� )
--			    	 	|  	�readnum� �(� �)�
--			    	 	|  	ID [ �(� �)� | �[� expr �]� ]
--
-- All operators (&& || == != < <= > >= binary+ binary- * / %) are left associative.





local parseit = {}  -- Our module

local lexit = require "lexit"


-- Variables

-- For lexer iteration
local iter          -- Iterator returned by lexer.lex
local state         -- State for above iterator (maybe not used)
local lexer_out_s   -- Return value #1 from above iterator
local lexer_out_c   -- Return value #2 from above iterator

-- For current lexeme
local lexstr = ""   -- String form of current lexeme
local lexcat = 0    -- Category of current lexeme:
                    --  one of categories below, or 0 for past the end

-- Symbolic Constants for AST

local STMT_LIST    = 1
local WRITE_STMT   = 2
local FUNC_DEF     = 3
local FUNC_CALL    = 4
local IF_STMT      = 5
local WHILE_STMT   = 6
local RETURN_STMT  = 7
local ASSN_STMT    = 8
local CR_OUT       = 9
local STRLIT_OUT   = 10
local BIN_OP       = 11
local UN_OP        = 12
local NUMLIT_VAL   = 13
local BOOLLIT_VAL  = 14
local READNUM_CALL = 15
local SIMPLE_VAR   = 16
local ARRAY_VAR    = 17


-- Utility Functions

-- advance
-- Go to next lexeme and load it into lexstr, lexcat.
-- Should be called once before any parsing is done.
-- Function init must be called before this function is called.
local function advance()
    -- Advance the iterator
    lexer_out_s, lexer_out_c = iter(state, lexer_out_s)

    -- If we're not past the end, copy current lexeme into vars
    if lexer_out_s ~= nil then
        lexstr, lexcat = lexer_out_s, lexer_out_c
    else
        lexstr, lexcat = "", 0
    end
end


-- init
-- Initial call. Sets input for parsing functions.
local function init(prog)
    iter, state, lexer_out_s = lexit.lex(prog)
    advance()
end


-- atEnd
-- Return true if pos has reached end of input.
-- Function init must be called before this function is called.
local function atEnd()
    return lexcat == 0
end


-- matchString
-- Given string, see if current lexeme string form is equal to it. If
-- so, then advance to next lexeme & return true. If not, then do not
-- advance, return false.
-- Function init must be called before this function is called.
local function matchString(s)
    if lexstr == s then
        advance()
        return true
    else
        return false
    end
end


-- matchCat
-- Given lexeme category (integer), see if current lexeme category is
-- equal to it. If so, then advance to next lexeme & return true. If
-- not, then do not advance, return false.
-- Function init must be called before this function is called.
local function matchCat(c)
    if lexcat == c then
        advance()
        return true
    else
        return false
    end
end





-- "local" statements for parsing functions

local parse_program		-- 1
local parse_stmt_list	-- 2
local parse_statement	-- 3
local parse_write_arg	-- 4
local parse_expr		-- 5
local parse_comp_expr	-- 6
local parse_arith_expr	-- 7
local parse_term		-- 8
local parse_factor		-- 9


-- This function takes a string and returns a boolean
-- indicationg that done is true or false, another bool
-- to indicate done, and a abstract syntax tree
function parseit.parse(prog)
-- Initialise
init(prog)
	-- Get parsing results
	local good, ast = parse_stmt_list()
	local done = atEnd()

	-- Return the results
	return good, done, ast
end


-- Parsing Functions


-- outputs Boolean good and an abstract syntax tree(ast)
function parse_program()	-- 1
	local good, ast

    good, ast = parse_stmt_list()
    return good, ast
end



-- takes no inputs
-- Output a boolean good, and an ast
-- Parses stmt_list
-- 		stmt_list	->  	{ statement }
function parse_stmt_list()	-- 2
    local good, ast, newast

    ast = { STMT_LIST }
    while true do
        if lexstr ~= "write"
          and lexstr ~= "def"
          and lexstr ~= "if"
          and lexstr ~= "while"
          and lexstr ~= "return"
          and lexcat ~= lexit.ID then
            return true, ast
        end

        good, newast = parse_statement()
        if not good then
            return false, nil
        end

        table.insert(ast, newast)
    end
end


-- no input
-- Output a boolean good, and an ast
--    	statement	->  	�write� �(� write_arg { �,� write_arg } �)�
--		    	 		|  	�def� ID �(� �)� stmt_list �end�
--		    	 		|  	�if� expr stmt_list { �elseif� expr stmt_list } [ �else� stmt_list ] �end�
--				 		|  	�while� expr stmt_list �end�
--			  	 		|  	�return� expr
--		    	 		|  	ID ( �(� �)� | [ �[� expr �]� ] �=� expr )
function parse_statement()	-- 3
    local good, ast, ast1, ast2, savelex
	savelex = lexstr

    if matchString("write") then -- Checks to see if a write statement

		-- Fail and return false
        if not matchString("(") then
            return false, nil
        end

        good, ast1 = parse_write_arg()
		-- Fail and return false
        if not good then
            return false, nil
        end

        ast2 = { WRITE_STMT, ast1 }
--
        while matchString(",") do -- Check for multiple arguments
            good, ast1 = parse_write_arg()
            if not good then
                return false, nil
            end

            table.insert(ast2, ast1) -- add this to the table
        end
		-- if the write doesn't have a ')' then return false
        if not matchString(")") then
            return false, nil
        end

        return true, ast2

		--		    	 		|  	�def� ID �(� �)� stmt_list �end�
    elseif matchString("def") then -- define a function
    	savelex = lexstr
		-- after a 'def' it needs to be an ID
    	if not matchCat(lexit.ID) then
    		return false, nil
    	end
		--
    	if not matchString("(") then -- In this sequence there must be a '(' and then a ')'
    		return false, nil
    	end
		--
    	if not matchString(")") then -- In this sequence there must be a '(' and then a ')'
    		return false, nil
    	end
		--
    	good, ast1 = parse_stmt_list() -- now start parsing inside the fuction
    	if not good then
    		return false, nil
    	end
		--
    	if not matchString("end") then -- then there must be an end to the function
			return false, nil
		end
		--
    	return true, { FUNC_DEF, savelex, ast1 } -- return the fuction and its contents

		-- If a return statement is encountered, pase the expression following it
		--			  	 		|  	�return� expr
    elseif matchString("return") then
    	good, ast1 = parse_expr()
    	if not good then
    		return false, nil
    	end
		--
    	ast2 = { RETURN_STMT, ast1 } -- return the return statement expression
    	return true, ast2


		--		    	 		|  	�if� expr stmt_list { �elseif� expr stmt_list } [ �else� stmt_list ] �end�
		-- entering an if statement
    elseif matchString("if") then
    	good, ast1 = parse_expr()  -- Parse and return the expression for the if statement
    	if not good then
    		return false, nil
    	end
		--
    	good, ast = parse_stmt_list()
    	if not good then
    		return false, nil
    	end
		--
    	ast2 = { IF_STMT, ast1, ast } -- the first part of the if statement
		-- Else part
    	while matchString("elseif") do
	    	good, ast1 = parse_expr() -- repeat the same from the above if statement
	    	if not good then
	    		return false, nil
	    	end

	    	table.insert(ast2, ast1)
	    	good, ast1 = parse_stmt_list()
	    	if not good then
	    		return false, nil
	    	end

	    	table.insert(ast2, ast1)
    	end
		--
		-- The fianl else
    	if matchString("else") then
    		good, ast1 = parse_stmt_list() -- repeat above for if statements
	    	if not good then
	    		return false, nil
	    	end
	    	table.insert(ast2, ast1)
    	end

    	if not matchString("end") then -- if statement must have end
    		return false, nil
    	end

    	return true, ast2 -- return the if statement

		-- Enter a while loop
		--				 		|  	�while� expr stmt_list �end�
    elseif matchString("while") then
    	good, ast1 = parse_expr() -- Parse the expression for the while loop
    	if not good then
    		return false, nil
    	end

		-- now parse the inner part of the while loop
    	good, ast = parse_stmt_list()
    	if not good then
    		return false, nil
    	end
		--
		-- hold the while loop in ast2
    	ast2 = { WHILE_STMT, ast1, ast }
    	if not matchString("end") then
    		return false, nil
    	end

    	return true, ast2

		-- function calls and arrays
		--		    	 		|  	ID ( �(� �)� | [ �[� expr �]� ] �=� expr )
    elseif matchCat(lexit.ID) then
    	if matchString("(") then
    		if not matchString(")") then
    			return false, nil
    		end

    		return true, { FUNC_CALL, savelex }
    	elseif matchString("[") then
    		good, ast1 = parse_expr() -- expression in brackets
    		if not good then
    			return false, nil

    		end
    		if not matchString("]") then
    			return false, nil
    		end
    		ast2 = { ARRAY_VAR, savelex, ast1 }

			-- assignment for array element
    		if matchString("=") then
    			good, ast1 = parse_expr()
    			if not good then
    				return false, nil
    			end
    			return true, { ASSN_STMT, ast2, ast1 }
    		end
			-- assign a value to an ID
       	elseif matchString("=") then
    		good, ast1 = parse_expr()
    		if not good then
    			return false, nil
    		end
    		return true, { ASSN_STMT, { SIMPLE_VAR, savelex }, ast1 }
    	end
    end
    return false, nil
end


-- ouputd bool and an ast
-- Parses the terminal write argument
--    	write_arg	->  	�cr�
--		    	 		|  	STRLIT
--		    	 		|  	expr
function parse_write_arg()	-- 4
	local savelex, good, ast
	savelex = lexstr
	--
	if matchCat(lexit.STRLIT) then
		return true, { STRLIT_OUT, savelex }
		--
	elseif matchString("cr") then
		return true, { CR_OUT }
		-- cr?
	else
		good, ast = parse_expr()
		if not good then
			return false, nil
		end
		--
		return true, ast
	end
end


-- Output bool, and ast
-- for comparison operations
--    	comp_expr	->  	�!� comp_expr
--    	 				|  	arith_expr { ( �==� | �!=� | �<� | �<=� | �>� | �>=� ) arith_expr }
function parse_comp_expr()	-- 6
	local saveop, good, ast, newast
	saveop = lexstr
	if matchString("!") then
	--
		good, ast = parse_comp_expr()
		if not good then
			return false, nil
			--
		end
		return good, { { UN_OP, saveop } , ast }
	end
	-- If a '!' what is not?
	good, ast = parse_arith_expr()
	if not good then
		return false, nil
	end
	while true do
		saveop = lexstr
		if not matchString("!=") and not matchString("==") and not matchString("<")
			and not matchString(">") and not matchString("<=") and not matchString(">=") then
			break
		end

		good, newast = parse_arith_expr()
		if not good then
			return false, nil
		end
--
		ast = { { BIN_OP, saveop }, ast, newast }
	end
	return true, ast
end

-- outputs bool and an ast
-- parses expressions from many different places
-- terminal expr
--    	expr	  	->  	comp_expr { ( �&&� | �||� ) comp_expr }
function parse_expr()		-- 5
	local savelex, saveop, good, ast, newast
	savelex = lexstr
	--
	good, ast = parse_comp_expr()
	if not good then
		return false, nil
	end
	while true do
	--
		saveop = lexstr
		if not matchString("&&") and not matchString("||") then -- and , or
			break
		end

		good, newast = parse_comp_expr()
		if not good then
			return false, nil
		end

		ast = { { BIN_OP, saveop}, ast, newast }
	end
	return true, ast
end







-- output bool and ast
-- Parse term terminal
--    	term	  	->  	factor { ( �*� | �/� | �%� ) factor }
function parse_term()		-- 8
	local saveop, good, ast, newast
	good, ast = parse_factor()
	if not good then
		return false, nil
	end

	while true do
		saveop = lexstr
		if not matchString("/") and not matchString("%") and not matchString("*") then
			break
		end
		--
		good, newast = parse_factor()
		if not good then
			return false, nil
		end
		ast = { { BIN_OP, saveop }, ast, newast }
	end
	return true, ast
end





-- outputs bool and ast
-- Parses arithmatic expressions
--    	arith_expr	->  	term { ( �+� | �-� ) term }
function parse_arith_expr()	-- 7
	local saveop, good, ast, newast
	good, ast = parse_term()
	if not good then
		return false, nil
	end
--
	while true do
		saveop = lexstr
		if not matchString("-") and not matchString("+") then
			break
		end
		--
		good, newast = parse_term()
		if not good then
			return false, nil
		end
		ast = { { BIN_OP, saveop }, ast, newast }
		--
	end
	return true, ast
end







-- output boolean and ast
-- parses the teminal factor
--    	factor	  	->  	�(� expr �)�
--						|  	( �+� | �-� ) factor
--			    	 	|  	NUMLIT
--			    	 	|  	( �true� | �false� )
--			    	 	|  	�readnum� �(� �)�
--			    	 	|  	ID [ �(� �)� | �[� expr �]� ]
function parse_factor()		-- 9
	local savelex, saveop, good, ast, ast1
	savelex = lexstr

	if matchString("(") then
		good, ast = parse_expr() -- parseing sub expressions
		if not good then
			return false, nil
		end
		--
		if not matchString(")") then
			return false, nil
		end
		--
		return good, ast
	elseif matchCat(lexit.NUMLIT) then -- If num litteral
		return true, { NUMLIT_VAL, savelex }
	elseif matchString("-") or matchString("+") then
		saveop = savelex

		good, ast = parse_factor()
		if not good then
			return false, nil
		end
		--
		return true, { { UN_OP, saveop }, ast }
	elseif matchString("true") or matchString("false") then
		return true, { BOOLLIT_VAL, savelex }
	elseif matchString("readnum") then

		if not matchString("(") then
			return false, nil
		end
		--
		if not matchString(")") then
			return false, nil
		end
		return true, { READNUM_CALL } -- maybe an input call?
	elseif matchCat(lexit.ID) then
		if matchString("(") then
    		if not matchString(")") then
    			return false, nil
    		end
			--
    		return true, { FUNC_CALL, savelex } -- function call
    	elseif matchString("[") then
    		good, ast1 = parse_expr()
    		if not good then
    			return false, nil
    		end
			--
    		if not matchString("]") then
    			return false, nil
    		end

    		return true, { ARRAY_VAR, savelex, ast1 } -- array
    	end
		--
    	return true, { SIMPLE_VAR, savelex }
	end

end




return parseit
