-- lexit.lua
-- VERSION 1
-- Started:  Feb 2019
-- Updated: 16 Feb 2019
-- by Matthew Hakin


-- *********************************************************************
-- Module Table Initialization
-- *********************************************************************
local lexit = {}  -- Our module; members are added below



-- *********************************************************************
-- Public Constants
-- *********************************************************************


--  Numeric constants representing lexeme categories
lexit.KEY    = 1
lexit.ID     = 2
lexit.NUMLIT = 3
lexit.STRLIT = 4
lexit.OP     = 5
lexit.PUNCT  = 6
lexit.MAL    = 7



-- catnames
-- Array of names of lexeme categories.
-- Human-readable strings. Indices are above numeric constants.
lexit.catnames = {
    "Keyword",
    "Identifier",
    "NumericLiteral",
	"StringLiteral",
    "Operator",
    "Punctuation",
    "Malformed"
}


-- *********************************************************************
-- Kind-of-Character Functions
-- *********************************************************************

-- All functions return false when given a string whose length is not
-- exactly 1.


-- isLetter
-- Returns true if string c is a letter character, false otherwise.
local function isLetter(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "A" and c <= "Z" then
        return true
    elseif c >= "a" and c <= "z" then
        return true
    else
        return false
    end
end


-- isDigit
-- Returns true if string c is a digit character, false otherwise.
local function isDigit(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "0" and c <= "9" then
        return true
    else
        return false
    end
end


-- isWhitespace
-- Returns true if string c is a whitespace character, false otherwise.
local function isWhitespace(c)
    if c:len() ~= 1 then
        return false
    elseif c == " " or c == "\t" or c == "\n" or c == "\r"
      or c == "\f" then
        return true
    else
        return false
    end
end



-- isIllegal
-- Returns true if string c is an illegal character, false otherwise.
local function isIllegal(c)
    if c:len() ~= 1 then
        return false
    elseif isWhitespace(c) then
        return false
    elseif c >= " " and c <= "~" then
        return false
    else
        return true
    end
end




-- *********************************************************************
-- The Lexer
-- *********************************************************************



-- lex
-- Intended for use in a for-in loop:
--     for lexstr, cat in lexit.lex(program) do
-- Here, lexstr is the string form of a lexeme, and cat is a number
-- representing a lexeme category. (See Public Constants.)
function lexit.lex(program)
    -- ***** Variables (like class data members) *****

    local pos       -- Index of next character in program
                    -- INVARIANT: when getLexeme is called, pos is
                    --  EITHER the index of the first character of the
                    --  next lexeme OR program:len()+1
    local state     -- Current state for our state machine
    local ch        -- Current character
    local lexstr    -- The lexeme, so far
    local category  -- Category of lexeme, set when state set to DONE
    local handlers  -- Dispatch table; value created later
    -- ***** States *****

    local DONE   = 0
    local START  = 1
    local LETTER = 2
    local DIGIT  = 3
    local DIGDOT = 4
    local DOT    = 5
    local PLUS   = 6
    local MINUS  = 7
    local STAR   = 8
	local QUOTE  = 9
	local ARROW  = 10
	local ANDIT  = 11
	local ORIT   = 12
	local BEQUAL = 13
	local SQUOTE = 14
	local BRACK  = 15

    -- ***** Character-Related Utility Functions *****

	
    -- currChar
    -- Return the current character, at index pos in program. Return
    -- value is a single-character string, or the empty string if pos is
    -- past the end.
    local function currChar()
        return program:sub(pos, pos)
    end

	
    -- nextChar
    -- Return the next character, at index pos+1 in program. Return
    -- value is a single-character string, or the empty string if pos+1
    -- is past the end.
    local function nextChar()
        return program:sub(pos+1, pos+1)
    end

	-- next2Char
	-- Returns two characters ahead so pos+2
	-- value is a single character string, or the empty string if pos+1
	-- is past the end.
	local function next2Char()
        return program:sub(pos+2, pos+2)
    end

	-- prevChar
    -- Return the previous character, at index pos-1 in program. Return
    -- value is a single-character string, or the empty string if pos-1
    -- is before the beginning.
	local function prevChar()
        return program:sub(pos-1, pos-1)
    end

	-- prevChar
    -- Return the character back 2 from pos, at index pos-2 in program. Return
    -- value is a single-character string, or the empty string if pos-2
    -- is before the beginning.
	local function prev2Char()
        return program:sub(pos-2, pos-2)
    end

	
    -- drop1
    -- Move pos to the next character.
    local function drop1()
        pos = pos+1
    end
	local function isKeyWord(a)
		if a == "Return" then
		return true
		end
	end

	
    -- add1
    -- Add the current character to the lexeme, moving pos to the next
    -- character.
    local function add1()
        lexstr = lexstr .. currChar()
        drop1()
    end

	
	-- skipWhitespace
    -- Skip whitespace and comments, moving pos to the beginning of
    -- the next lexeme, or to program:len()+1.
    local function skipWhitespace()
        while true do      -- In whitespace
            while isWhitespace(currChar()) do
                drop1()
            end

            if currChar() ~= "#" then  -- Comment?
                break
            end
            drop1()

            while true do  -- In comment
                if currChar() == "#" then

                elseif currChar() == "" then  -- End of input?
                   return
				elseif currChar() == "\n" then
				   drop1()
				   break
				elseif currChar() == "\t" then
				   drop1()
				   break
				elseif currChar() == "\r" then
				   drop1()
				   break
				elseif currChar() == "\f" then
				   drop1()
				   break
                end
                drop1()
            end
        end
    end

	
	local function handle_DONE()
        io.write("ERROR: 'DONE' state should not be handled\n")
        assert(0)
    end

	
    local function handle_START()
        if isIllegal(ch) then
            add1()
            state = DONE
            category = lexit.MAL
        elseif isLetter(ch) or ch == "_" then
            add1()
            state = LETTER
        elseif isDigit(ch) then
            add1()
            state = DIGIT
        elseif ch == "." then
            add1()
            state = DOT
        elseif ch == "+" then
            add1()
            state = PLUS
        elseif ch == "-"  then
			add1()
			state = MINUS
        elseif ch == "*" or ch == "%" then
            add1()
            state = STAR
		elseif ch == "\"" then
			add1()
			state = QUOTE
		elseif ch == "'" then
			add1()
			state = SQUOTE
		elseif ch == "<" or ch == ">" then
			add1()
			state = ARROW
		elseif ch == "&" or ch == "!" or ch == "/" then
			add1()
			state = ANDIT
		elseif ch == "[" or ch == "]" then
			add1()
			category = lexit.OP
			state = BRACK
		elseif ch == "|" then
			add1()
			state = ORIT
		elseif ch == "=" then
			add1()
			state = BEQUAL
        else
            add1()
            state = DONE
            category = lexit.PUNCT
        end
    end

	
    local function handle_LETTER()
        if isLetter(ch) or isDigit(ch) or ch == "_" then
            add1()
        else
            state = DONE
            if lexstr == "cr" or lexstr == "end"
			  or lexstr == "elseif" or lexstr == "false"
			  or lexstr == "if" or lexstr == "readnum"
			  or lexstr == "return" or lexstr == "true"
			  or lexstr == "while" or lexstr == "write"
			  or lexstr == "def" or lexstr == "else" then
                category = lexit.KEY
            else
                category = lexit.ID
            end
        end
    end
	
    local function handle_DIGIT()
        if isDigit(ch) then
			add1()
		elseif ((ch == "e" or ch == "E") and nextChar() == "+" and isDigit(next2Char())and (string.find(lexstr, "e") == nil) and (string.find(lexstr, "E") == nil)) then
            add1()
			add1()
		elseif (ch == "e" or ch == "E") and isDigit(nextChar()) and (string.find(lexstr, "e") == nil) and (string.find(lexstr, "E") == nil) then
			add1()

        elseif ch == "." then
		   state = DONE
		   category = lexit.NUMLIT
        else
            state = DONE
            category = lexit.NUMLIT
        end
    end

    
    local function handle_DOT()
            state = DONE
            category = lexit.PUNCT

    end

	
    local function handle_PLUS()


		if prev2Char() == "]" or prev2Char() == ")" then
			state = DONE
			category = lexit.OP

			--
		elseif category == lexit.OP and ch == "(" then
			state = DONE
			category = lexit.OP
			--add1()

		elseif category == lexit.OP and isDigit(ch) then
			state = DIGIT
			category = lexit.NUMLIT
			add1()
			--
		elseif category == lexit.OP and isLetter(ch) then
			--add1()
			state = DONE
			category = lexit.OP
			--
		elseif category == lexit.OP and ch == "+" then
			--add1()
			state = DONE
			category = lexit.OP
			--
		elseif category == lexit.OP and ch == "-" then
			--add1()
			state = DONE
			category = lexit.OP
		--
		elseif category == lexit.OP and ch ~= '' then
			add1()
			state = DIGIT
			category = lexit.OP
		elseif category == lexit.NUMLIT then
			state = DONE
			category = lexit.OP
		elseif category == lexit.KEY then
			if string.sub(program, pos - 5,4) == "true" or string.sub(program, pos - 6,5) == "false"   then
			state = DONE
			category = lexit.OP
			else
			state = DIGIT
			add1()
			category = lexit.DIGIT
			end

		elseif category == lexit.ID then
			if state == PLUS then
			state = DONE
            category = lexit.OP
			else
            state = DONE
			add1()
            category = lexit.OP
			end
		elseif isDigit(ch) then
			state = DIGIT
			add1()
			category = lexit.DIGIT
        else
            state = DONE
            category = lexit.OP
        end
    end

	
    local function handle_MINUS()
		if prev2Char() == "]" or prev2Char() == ")" then
			state = DONE
			category = lexit.OP
		elseif category == lexit.NUMLIT then
			state = DONE
			category = lexit.OP
		elseif category == lexit.ID then
			state = DONE
			category = lexit.OP
		elseif category == lexit.OP and isDigit(ch) then
			state = DIGIT
			add1()
            category = lexit.NUMLIT
		elseif category == lexit.OP and ch == "-"then
			--state = DIGIT
			state = DONE
			print("poop")
			--add1()
            category = lexit.OP
		elseif ch == "-" or ch == "=" or prev2Char() == "e" or prev2Char() == "E" then
            state = DONE
            category = lexit.OP
		elseif isDigit(ch) then
			state = DIGIT
			add1()
			category = lexit.NUMLIT
		elseif category == lexit.KEY then
			if string.sub(program, pos - 5,4) == "true" then
			state = DONE
			category = lexit.OP
			else
			end
        else
            state = DONE
            category = lexit.OP
        end
    end
	
    local function handle_STAR()  -- Handle * or / or =
            state = DONE
            category = lexit.OP
    end

	-- inspired by 
	local function handle_quote()


		if  ch == "\"" then
			add1()
			state = DONE
			category = lexit.STRLIT
		elseif ch == '' then
			--drop1()
			state = DONE
			category = lexit.MAL
		elseif ch == "\n" then
		add1()
		    state = DONE
			category = lexit.MAL
		else
			add1()
			state = QUOTE

		end
	end

	-- inspired by 
	local function handle_singleQuote()
		if ch == "'" then
			add1()
			state = DONE
			category = lexit.STRLIT
		elseif ch == '' then
			--drop1()
			state = DONE
			category = lexit.MAL
		elseif ch == "\n" then
		add1()
		    state = DONE
			category = lexit.MAL
		else
			add1()
			STATE = QUOTE2

		end
	end
	-- inspired by 
	local function handle_arrow()
		if ch == "=" then
			add1()
			state = DONE
			category = lexit.OP
		else
			state = DONE
			category = lexit.OP
		end
	end

	-- inspired by 
	local function handle_and()

		if prevChar() == "!" and ch == "=" then
			   add1()
			   state = DONE
			   category = lexit.OP
		elseif prevChar() == "&" and currChar() == "&" then
			add1()
			   state = DONE
			   category = lexit.OP
		elseif prevChar() == "&" then
		state = DONE
			category = lexit.PUNCT
		elseif prevChar() == "/" then
		 state = DONE
			   category = lexit.OP
		elseif prevChar() == "]" and ch == "+" then
			state = DONE
			category = lexit.OP
		else
			state = DONE
			category = lexit.OP
		end
	end

	-- inspired by 
	local function handle_pipe()
		if ch == "|" then
			add1()
			state = DONE
			category = lexit.OP
		else
			state = DONE
			category = lexit.PUNCT
		end
	end

	-- inspired by 
	local function handle_equal()
		if ch == "=" then
			add1()
			state = DONE
			category = lexit.OP
		else
			state = DONE
			category = lexit.OP
		end
	end

	-- inspired by 
	local function handle_brackets()
	if (category == lexit.OP) and (ch == "+") then
			state = DONE
			category = lexit.OP
	else
	state = DONE
	end
	end



    -- ***** Table of State-Handler Functions *****

	
	handlers = {
        [DONE]=handle_DONE,
        [START]=handle_START,
        [LETTER]=handle_LETTER,
        [DIGIT]=handle_DIGIT,
        [DIGDOT]=handle_DIGDOT,
        [DOT]=handle_DOT,
        [PLUS]=handle_PLUS,
        [MINUS]=handle_MINUS,
        [STAR]=handle_STAR,
		[QUOTE]=handle_quote,
		[ARROW]=handle_arrow,
		[ANDIT]=handle_and,
		[ORIT]=handle_pipe,
		[BEQUAL]=handle_equal,
		[SQUOTE]=handle_singleQuote,
		[BRACK]=handle_brackets,
    }

    -- ***** Iterator Function *****
	
    -- getLexeme
    -- Called each time through the for-in loop.
    -- Returns a pair: lexeme-string (string) and category (int), or
    -- nil, nil if no more lexemes.
    local function getLexeme(dummy1, dummy2)
        if pos > program:len() then
            return nil, nil
        end
        lexstr = ""
        state = START
        while state ~= DONE do
            ch = currChar()
            handlers[state]()

        end
        skipWhitespace()
        return lexstr, category
    end

    -- ***** Body of Function lex *****

    -- Initialize & return the iterator function
    pos = 1
    skipWhitespace()
    return getLexeme, nil, nil
end















-- *********************************************************************
-- Module Table Return
-- *********************************************************************


return lexit
