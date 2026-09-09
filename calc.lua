---@diagnostic disable: lowercase-global
---@diagnostic enable: inject-field
---@diagnostic enable: need-check-nil
---@diagnostic enable: undefined-field
---@diagnostic enable: missing-fields

--[[

    expression -> literal | unary | binary | grouping ;
    literal    -> NUMBER ;
    grouping   -> '(' expression ')' ;
    unary      -> ( '-' ) expression ;
    binary     -> expression operator expression ;
    operator   -> '+' | '-' | '*' | '/' ;

]]

--[[
    expression -> term
    term       -> factor ( ( '-' | '+' ) factor )* ;
    factor     -> unary  ( ( '/' | '*' ) unary )*  ;
    unary      -> ('-') unary | primary ;
    primary    -> NUMBER | "(" expression ")" ;

]]

-- ** Token Type ** --
---@enum TokenType
TokenType = {
    EOF = -2,
    EMPTY = -1,
    LITERAL = 0,
    DOT = 1,

    OP_PAREN = 2,
    CL_PAREN = 3,
    
    PLUS = 4,
    MINUS = 5,
    DIVIDE = 6,
    MULTIPLY = 7
}
-- ** Token Type End ** --

-- ** Token ** --
---@class Token
---@field type TokenType
---@field text string
---@field value number | nil
Token = {type = TokenType.EMPTY, text = "", value = nil}

---@param text string
---@param type TokenType
---@param value number | nil
function Token:new(object, type, text, value)
    local object = object or {}
    setmetatable(object, self)
    self.__index = self

    object.type = type
    object.text = text
    object.value = value

    return object
end
-- ** Token End ** --

-- ** Scanner ** --
---@class Scanner
---@field tokens Token[]
Scanner = {}

function Scanner:new(source)
    local object = {
        source = source,
        ---@type Token[]
        tokens = {},
        current = 1,
        start = 1,
        hadError = false,
    }
    setmetatable(object, self)
    self.__index = self
    return object
end

---@return boolean
function Scanner:isAtEnd()
    return self.current > #self.source
end

-- Updates scanner's tokens table, which represents a list of tokens.
---@return nil 
function Scanner:scanTokens()
    while not self:isAtEnd() do
        if self.hadError then return end
        self.start = self.current
        local char = self:advance()
        if char == '(' then
            self:addToken(Token:new(nil, TokenType.OP_PAREN, '('))
        elseif char == ')' then
            self:addToken(Token:new(nil, TokenType.CL_PAREN, ')'))
        elseif char == '.' then
            self:addToken(Token:new(nil, TokenType.DOT, '.'))
        elseif char == '+' then
            self:addToken(Token:new(nil, TokenType.PLUS, '+'))
        elseif char == '*' then
            self:addToken(Token:new(nil, TokenType.MULTIPLY, '*'))
        elseif char == '/' then
            self:addToken(Token:new(nil, TokenType.DIVIDE, '/'))
        elseif char == '-' then
            self:addToken(Token:new(nil, TokenType.MINUS, '-'))
        else
            if self:isDigit(char) then
                self:number()
            elseif not self:isWhitespace(char) then
                self:error("Unknown character.")
            end
        end
    end
    self:addToken(Token:new(nil, TokenType.EOF, '\0'))
end

---@return nil 
function Scanner:number()
    -- So long as we're a number, keep going forward.
    while self:isDigit(self:peek()) do
        self:advance()
    end
    -- If we've hit a '.', then we're a floating point number.
    if self:peek() == "." then
        -- Go past the '.'
        self:advance()

        -- If our peek is not a number, then this is a bad floating point number.
        if not self:isDigit(self:peek()) then
            self:error(
                "Malformed number: "
                .. self.source:sub(self.start, self.current - 1)
                .. " no digits found after the decimal point."
            )
            return nil
        end

        -- Keep consuming numbers to fill out the floating point.
        while self:isDigit(self:peek()) do
            self:advance()
        end
    end

    local text = self.source:sub(self.start, self.current - 1)

    self:addToken(Token:new(
        nil,
        TokenType.LITERAL,
        text,
        tonumber(text)
    ))   
end

---@return string
function Scanner:peekNext()
    if (self.current + 1 >= #self.source) then return '\0' end
    return self.source[self.current + 1]
end

---@return nil
function Scanner:error(msg)
    self.hadError = true
    print("Error at characters: " .. self.start .. "/".. self.current-1)
    print(msg)
end

---@param char string
---@return boolean
function Scanner:isDigit(char)
    return char >= '0' and char <= '9'
end

---@return boolean
function Scanner:isWhitespace(char)
    return char == ' '
end

-- Consumes the current token, and advances current.
---@return string
function Scanner:advance()
    local char = self.source:sub(self.current, self.current)
    self.current = self.current + 1
    return char
end

-- Returns the current token, doesn't consume it, doesn't advance current.
---@return string
function Scanner:peek()
    if self:isAtEnd() then return '\0' end
    return self.source:sub(self.current, self.current)
end

---@param token Token
---@return nil
function Scanner:addToken(token)
    table.insert(self.tokens, token)
end

---@return nil
function Scanner:debugPrint(tokens)
    print("DEBUG OUTPUT")
    ---@param value Token 
    for index, value in pairs(tokens) do
        if value.type == TokenType.EOF then
            print("EOF")
        elseif value.type == TokenType.LITERAL then
            print(index, "LITERAL", value.text)
        elseif value.type == TokenType.PLUS then
            print(index, "PLUS", value.text)
        elseif value.type == TokenType.DIVIDE then
            print(index, "DIVIDE", value.text)
        elseif value.type == TokenType.MULTIPLY then
            print(index, "MULTIPLY", value.text)
        elseif value.type == TokenType.MINUS then
            print(index, "MINUS", value.text)
        elseif value.type == TokenType.OP_PAREN then
            print(index, "OP_PAREN", value.text)
        elseif value.type == TokenType.CL_PAREN then
            print(index, "CL_PAREN", value.text)
        end
    end
end

-- ** Scanner End ** --

-- ** Expression Start ** --

---@class Expr
---@field left Expr
---@field operator Token
---@field right Expr
Binary = {}

function Binary:new(left, operator, right)
    local object = {
        left = left,
        operator = operator,
        right = right
    }
    setmetatable(object, self)
    self.__index = self
    return object
end

---@class Literal
---@field value number
Literal = {}

function Literal:new(value)
    local object = {
        value = value
    }
    setmetatable(object, self)
    self.__index = self

    return object
end

---@class Unary
---@field token Token
---@field expr Expr
Unary = {}

function Unary:new(token, expr)
    local object = {
        token = token,
        expr = expr
    }
    setmetatable(object, self)
    self.__index = self

    return object
end

---@class Grouping
---@field expr Expr
Grouping = {}
function Grouping:new(expr)
    local object = {
        expression = expr
    }
    setmetatable(object, self)
    self.__index = self
    return object
end

-- **  Expression End  ** --

-- ** Parser Start ** --
---@class Parser
---@field tokens Token[]
Parser = {}

function Parser:new(tokens)
    local object = {
        ---@type Token[]
        tokens = tokens,
        current = 1,
        hasError = false,
    }
    setmetatable(object, self)
    self.__index = self
    return object
end

function Parser:parse()
    local result = self:expression()
    return result
end

function Parser:expression()
    return self:term()
end

function Parser:term()
    local expr = self:factor()
    while self:match(TokenType.MINUS, TokenType.PLUS) do
        local operator = self:previous()
        local right = self:factor()
        expr = Binary:new(expr, operator, right)
    end
    return expr
end

function Parser:factor()
    local expr = self:unary()
    while self:match(TokenType.DIVIDE, TokenType.MULTIPLY) do
        local operator = self:previous()
        local right = self:unary()
        expr = Binary:new(expr, operator, right)
    end
    return expr
end

function Parser:unary()
    if self:match(TokenType.MINUS) then
        local operator = self:previous()
        local right = self:unary()
        return Unary:new(operator, right)
    end
    return self:primary()
end

function Parser:primary()
    if self:match(TokenType.LITERAL) then
        return Literal:new(self:previous().value)
    end
    if self:match(TokenType.OP_PAREN) then
        local expr = self:expression()
        self:consume(TokenType.CL_PAREN, "Expected ')' after expression.")
        if expr == nil then
            self.hasError = true
        end
        if self.hasError then return nil end
        return Grouping:new(expr)
    end
end

function Parser:consume(type, msg)
    if (self:check(type)) then return self:advance() end
    print("Error occured: " .. msg)
    self.hasError = true
end

function Parser:match(...)
    local types = {...}
    for _, value in ipairs(types) do
        if (self:check(value)) then
            self:advance()
            return true
        end
    end
    return false
end

---@param type TokenType
function Parser:check(type)
    if self:isAtEnd() then return false end
    return self:peek().type == type
end

---@return Token
function Parser:advance()
    if not self:isAtEnd() then self.current = self.current + 1 end
    return self:previous()
end

---@return boolean
function Parser:isAtEnd()
    return self:peek().type == TokenType.EOF
end

---@return Token
function Parser:peek()
    return self.tokens[self.current]
end

---@return Token
function Parser:previous()
    return self.tokens[self.current - 1]
end

-- ** Parser End ** --

---@return string
function paren(str)
    return "(" .. str .. ")"
end

-- ---@param expr Expr
---@return string | nil
function printExpression(expr)
    if getmetatable(expr) == Literal then
        return expr.value
    elseif getmetatable(expr) == Unary then
        return paren(expr.token.text .. " " .. printExpression(expr.expr))
    elseif getmetatable(expr) == Grouping then
        return paren("group " .. printExpression(expr.expression))
    elseif getmetatable(expr) == Token then
        return expr.text
    else
        if getmetatable(expr) == Binary then
            return paren(expr.operator.text ..
                " " .. printExpression(expr.right) .. 
                " " .. printExpression(expr.left))
        end
    end
    return nil
end

-- ---@param expr Expr
---@return number | nil
function evalExpression(expr)
    if getmetatable(expr) == Literal then
        return expr.value
    elseif getmetatable(expr) == Unary then
        return -evalExpression(expr.expr)
    elseif getmetatable(expr) == Grouping then
        return evalExpression(expr.expression)
    elseif getmetatable(expr) == Binary then
        if expr.operator.type == TokenType.MINUS then
            return evalExpression(expr.left) - evalExpression(expr.right)
            -- return left - right
        elseif expr.operator.type == TokenType.PLUS then
            -- return left + right
            return evalExpression(expr.left) + evalExpression(expr.right)
        elseif expr.operator.type == TokenType.DIVIDE then
            -- return left / right
            return evalExpression(expr.left) / evalExpression(expr.right)
        elseif expr.operator.type == TokenType.MULTIPLY then
            -- return left * right
            return evalExpression(expr.left) * evalExpression(expr.right)
        end
    end
    -- We've hit a case that's unknown.
    return nil
end

---@return nil
function what_is_this_table(t)
    local output = "This is a "
    local result = getmetatable(t)
    if result == Literal then output = output .. "Literal"
    elseif result == Binary then output = output .. "Binary"
    elseif result == Unary then output = output .. "Unary" 
    elseif result == Grouping then output = output .. "Grouping"
    end
    if result == nil then 
        print("This is nil.") 
    end
    print(tostring(t) .. " : " .. output)
end

---@return nil
function main()
    print("CTRL+T to leave the REPL.")
    while true do
        ::start::
        local msg = readInput()
        local scanner = Scanner:new(msg)
        scanner:scanTokens()
        if scanner.hadError then
            scanner.hadError = false
            goto start
        end
        local parser = Parser:new(scanner.tokens)
        local expression = parser:parse()
        if expression == nil then 
            print("expression was nil.") 
            goto start
        end
        local result = evalExpression(expression)
        -- printExpression(expression)
        if result == nil then print("we hit an error idk lol") goto start end
        print(result)
    end
end

---@return string
function readInput()
    io.write("calc> ")
    return read()
end

main()

---@return number | nil
function testingFunction(input)
    local scanner = Scanner:new(input)
    scanner:scanTokens()
    local parser = Parser:new(scanner.tokens)
    local expression = parser:parse()
    return evalExpression(expression)
end

---@return boolean
function test(input, expectedValue)
    local result = testingFunction(input)
    if result ~= expectedValue then
        print(
        "Failed to pass test: " .. input .. ", was given value: " .. tostring(expectedValue)
        .. ", expected: " .. result
        )
        return false 
    end
    return true
end

-- these are my sanity checks,
-- if you see no output, then things are good.

test("1", 1)
test("(300 + (3 * 2))", 306)
test("()", nil)
test("(())", nil)
test("(200 + 3) * 4", 812)
test("200 + (3 * 4)", 212)
test("6/2", 3)
test("200 * 4", 800)
test("5 + 5", 10)
test("5 - 3", 2)