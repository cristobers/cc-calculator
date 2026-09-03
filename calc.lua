---@diagnostic disable: lowercase-global

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
Token = {type = TokenType.EMPTY, text = "", value = nil}

---@param text string
---@param type TokenType
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

function Scanner:isAtEnd()
    return self.current > #self.source
end

-- Updates scanner's tokens table, which represents a list of tokens.
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
            return
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

function Scanner:peekNext()
    if (self.current + 1 >= #self.source) then return '\0' end
    -- print(self.source, self.current, self.current + 1, #self.source)
    return self.source[self.current + 1]
end

function Scanner:error(msg)
    self.hadError = true
    print("Error at characters: " .. self.start .. "/".. self.current-1)
    print(msg)
end

---@param char string
function Scanner:isDigit(char)
    return char >= '0' and char <= '9'
end

function Scanner:isWhitespace(char)
    return char == ' '
end

-- Consumes the current token, and advances current.
function Scanner:advance()
    local char = self.source:sub(self.current, self.current)
    self.current = self.current + 1
    return char
end

-- Returns the current token, doesn't consume it, doesn't advance current.
function Scanner:peek()
    if self:isAtEnd() then return '\0' end
    return self.source:sub(self.current, self.current)
end

---@param token Token
function Scanner:addToken(token)
    table.insert(self.tokens, token)
end

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
---@field value any
Literal = {}

function Literal:new(object, value)
    local object = object or {}
    setmetatable(object, self)
    self.__index = self
    object.value = value
    return object
end

---@class Unary
---@field token Token
---@field expr Expr
Unary = {}

function Unary:new(object, token, expr)
    local object = object or {}
    setmetatable(object, self)
    self.__index = self
    self.token = token
    self.expr = expr
    return object
end

---@class Grouping
---@field value Expr
Grouping = {}

function Grouping:new(object, expr)
    local object = object or {}
    setmetatable(object, self)
    self.__index = self
    self.value = expr
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
        current = 1
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
        -- print(expr, operator, right)
        expr = Binary:new(expr, operator, right)
    end
    return expr
end

function Parser:unary()
    if self:match(TokenType.MINUS) then
        local operator = self:previous()
        local right = self:unary()
        return Unary:new(nil, operator, right)
    end
    return self:primary()
end

function Parser:primary()
    if self:match(TokenType.LITERAL) then
        -- print(self:previous())
        return Literal:new(nil, self:previous().value)
    end
    if self:match(TokenType.OP_PAREN) then
        local expr = self:expression()
        self:consume(TokenType.CL_PAREN, "Expected ')' after expression.")
        return Grouping:new(nil, expr)
    end
end

function Parser:consume(type, msg)
    if (self:check(type)) then return self:advance() end
    print("we throw an error here......")
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

function Parser:advance()
    if not self:isAtEnd() then self.current = self.current + 1 end
    return self:previous()
end

function Parser:isAtEnd()
    return self:peek().type == TokenType.EOF
end

function Parser:peek()
    return self.tokens[self.current]
end

function Parser:previous()
    return self.tokens[self.current - 1]
end

-- ** Parser End ** --

function paren(str)
    return "(" .. str .. ")"
end

-- ---@param expr Expr
function printExpression(expr)
    if getmetatable(expr) == Literal then
        return expr.value
    elseif getmetatable(expr) == Unary then
        return paren(expr.token.text .. " " .. printExpression(expr.expr))
    elseif getmetatable(expr) == Grouping then
        return paren("group " .. printExpression(expr.value))
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
function evalExpression(expr)
    if getmetatable(expr) == Literal then
        return expr.value
    elseif getmetatable(expr) == Unary then
        if expr.token.type == TokenType.MINUS and getmetatable(expr.expr) == Literal then
            return -expr.expr.value
        end
    elseif getmetatable(expr) == Grouping then
        return evalExpression(expr.value)
    elseif getmetatable(expr) == Binary then
        local left = evalExpression(expr.left)
        local right = evalExpression(expr.right)
        if expr.operator.type == TokenType.MINUS then
            return left - right
        elseif expr.operator.type == TokenType.PLUS then
            return left + right
        elseif expr.operator.type == TokenType.DIVIDE then
            return left / right
        elseif expr.operator.type == TokenType.MULTIPLY then
            return left * right
        end
    end
    return "nil"
end

function what_is_this_table(t)
    local output = "This is a "
    local result = getmetatable(t)
    if result == Literal then output = output .. "Literal"
    elseif result == Binary then output = output .. "Binary"
    elseif result == Unary then output = output .. "Unary" 
    elseif result == Grouping then output = output .. "Grouping"
    end
    if result == nil then print("This is nil.") else 
        print(tostring(t) .. " : " .. output) 
    end
end

function main()
    print("CTRL+T to leave the REPL.")
    while true do
        ::start::
        local msg = readInput()
        local scanner = Scanner:new(msg)
        scanner:scanTokens()
        -- this part is fine
        -- scanner:debugPrint(scanner.tokens)
        if scanner.hadError then
            scanner.hadError = false
            goto start
        end
        local parser = Parser:new(scanner.tokens)
        assert(parser.tokens == scanner.tokens, "wtf")
        local expression = parser:parse()
        if expression == nil then 
            print("expression was nil.") 
            return
        end
        -- print(printExpression(expression))
        print(evalExpression(expression))
    end
end

function readInput()
    io.write("calc> ")
    return read()
end

main()