`/* ###
PseuCo Compiler  
Copyright (C) 2013  
Saarland University (www.uni-saarland.de)  
Sebastian Biewer (biewer@splodge.com)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
### */`




###

	The following classes represent the PseuCo tree. Its implementation is partly incomplete.
	Method _getType is not implemented everywhere and does not perform type checking anywhere at the moment!
	
	toString returns the string representation of the tree with minimal brackets and correctly indented.

###


PCIndent = "   "

class PCNode
	constructor: (@children...) -> 
		@parent = null
		c.parent = this for c in @children
	getType: (env) -> 
		if not @_type
			@_type = @_getType(env)
			@_type = true if not @_type		# remember that we already checked type
		if @_type == true then null else @_type
	_getType: -> throw new Error("Not implemented")


# - Program
class PCProgram extends PCNode	# Children: (PCMonitor|PCStruct|PCMainAgent|PCDecl|PCProcedure)+
	collectClasses: (env) -> c.collectClasses(env) for c in @children
	collectEnvironment: (env) -> c.collectEnvironment(env) for c in @children
	toString: -> (o.toString("") for o in @children).join("\n")

# - MainAgent Decl
class PCMainAgent extends PCNode	# "mainAgent" PCStmtBlock
	collectClasses: (env) -> null
	collectEnvironment: (env) ->
		env.beginMainAgent(@)
		@children[0].collectEnvironment(env)
		env.endMainAgent()
	toString: -> "mainAgent " + @children[0].toString("")

# - Procedure Decl
class PCProcedureDecl extends PCNode	# Children: PCFormalParameter objects
	constructor: (resultType, @name, body, parameters...) ->
		parameters.unshift(resultType, body)
		super parameters...
	getResultType: -> @children[0]
	getBody: -> @children[1]
	getArgumentCount: -> @children.length-2
	getArgumentAtIndex: (index) -> @children[index+2]
	
	collectClasses: (env) -> null
	collectEnvironment: (env) -> 
		args = (p.getVariable(env) for p in @children[2...@children.length] by 1)
		env.beginNewProcedure(@, @name, @getResultType().getType(env).type, args)
		@getBody().collectEnvironment(env)
		env.endProcedure()
	
	toString: (indent) -> "#{indent}#{@getResultType().toString()} #{@name}(#{((@getArgumentAtIndex(i).toString() for i in [0...@getArgumentCount()] by 1).join(", "))}) #{@getBody().toString(indent)}"
		

# - Formal Parameter
class PCFormalParameter extends PCNode
	constructor: (type, @identifier) -> super type
	
	getVariable: (env) -> new PCVariable(@, @identifier, @children[0].getType(env).type)
	
	toString: -> @children[0].toString() + " " + @identifier

# - Monitor Decl
class PCMonitor extends PCNode	# "monitor" <id> "{" (Procedure decl, condition decl or variable decl)+ "}"
	constructor: (@name, declarations...) -> super declarations...
	
	collectClasses: (env) -> env.processNewClass(@, new PCTClassType(true, @name))
	collectEnvironment: (env) -> 
		env.beginClass(@name)
		c.collectEnvironment(env) for c in @children
		env.endClass()
	
	toString: -> "monitor #{@name} {\n#{ (o.toString(PCIndent) for o in @children).join("\n") }\n}"

# - Struct Decl
class PCStruct extends PCNode	# "struct" <id> "{" (Procedure decl or variable decl)+ "}"
	constructor: (@name, declarations...) -> super declarations...
	
	collectClasses: (env) -> env.processNewClass(@, new PCTClassType(false, @name))
	collectEnvironment: (env) -> 
		env.beginClass(@name)
		c.collectEnvironment(env) for c in @children
		env.endClass()
	
	toString: -> "struct #{@name} {\n#{ (o.toString(PCIndent) for o in @children).join("\n") }\n}"

# - Condition Decl
class PCConditionDecl extends PCNode	# condition <id> with <boolean expression>
	constructor: (@name, expression) -> super expression
	getExpression: -> @children[0]
	
	collectEnvironment: (env) -> 
		env.processNewVariable(new PCVariable(@, @name, new PCTType(PCTType.CONDITION)))
	
	toString: (indent) -> "#{indent}condition #{@name} with #{@children[0].toString()};"

# - Variable Decl
class PCDecl extends PCNode	# Children: Type and variable declarator(s)
	constructor: (@isStatement, children...) -> super children...
	
	getType: -> @children[0]
	getDeclarators: -> @children[1..]
	
	collectClasses: (env) -> null
	collectEnvironment: (env) -> 
		type = @children[0].getType(env).type
		@children[i].collectEnvironment(env, type) for i in [1...@children.length] by 1
	
	toString: (indent) ->
		res = indent + @children[0].toString() + " " + @children[1].toString()	# ToDo: Multiple declarators
		res += ";" if @isStatement
		res

# class PCDeclStmt extends PCDecl
# 	toString: (indent) -> super + ";"

# - Variable Declarator
class PCVariableDeclarator extends PCNode	# Identifier and optional initializer
	constructor: (@name, initializer) -> (if initializer then super initializer else super []...)
	getInitializer: -> if @children.length > 0 then @children[0] else null
	getTypeNode: -> @parent.getType()
	
	collectEnvironment: (env, type) -> env.processNewVariable(new PCVariable(@, @name, type))
	
	toString: -> 
		res = @name
		res += " = #{@children[0].toString()}" if @children.length > 0
		res

class PCVariableInitializer extends PCNode	# array initialization >= 1 child initializers, otherwise 1 child expression
	constructor: (@isUncompletedArray=false, children...) -> super children...
	isArray: -> !(@children[0] instanceof PCExpression)
	getTypeNode: -> @parent.getTypeNode()
	toString: ->
		if @children[0] instanceof PCExpression
			"#{@children[0].toString()}"
		else
			"{#{ (o.toString() for o in @children).join(", ") }#{ if @isUncompletedArray then "," else "" }}"

# -- TYPES --

class PCArrayType extends PCNode	# array of type baseType
	constructor: (baseType, @size) -> super baseType
	
	_getType: (env) -> new PCTTypeType(new PCTArrayType(@children[0].getType(env).type, @size))
	toString: -> "#{@children[0]}[#{@size}]"

# - Non-Array Type
class PCBaseType extends PCNode	# abstract (?)
	constructor: -> super []...

class PCSimpleType extends PCBaseType
	constructor: (@type) -> 
		throw "Unknown type" if @type < 0 or @type > 5
		super
	
	_getType: -> new PCTTypeType(new PCTType(PCSimpleType.typeToTypeKind(@type)))
	toString: -> PCSimpleType.typeToString(@type)
		

PCSimpleType.VOID = 0
PCSimpleType.BOOL = 1
PCSimpleType.INT = 2
PCSimpleType.STRING = 3
PCSimpleType.MUTEX = 4
PCSimpleType.AGENT = 5
PCSimpleType.typeToString = (type) ->
	switch type
		when PCSimpleType.VOID then "void"
		when PCSimpleType.BOOL then "bool"
		when PCSimpleType.INT then "int"
		when PCSimpleType.STRING then "string"
		when PCSimpleType.MUTEX then "mutex"
		when PCSimpleType.AGENT then "agent"
		else throw new Error("Unknown type!")
PCSimpleType.typeToTypeKind = (type) ->
	switch type
		when PCSimpleType.MUTEX then PCTType.MUTEX
		when PCSimpleType.AGENT then PCTType.AGENT
		when PCSimpleType.VOID then PCTType.VOID
		when PCSimpleType.BOOL then PCTType.BOOL
		when PCSimpleType.INT then PCTType.INT
		when PCSimpleType.STRING then PCTType.STRING
		else throw new Error("Unknown type!")


# - Channel Type
class PCChannelType extends PCNode
	constructor:(@valueType, @capacity) -> super []...
	
	_getType: -> new PCTTypeType(new PCTChannelType(new PCTType(PCSimpleType.typeToTypeKind(@valueType)), @capacity))
	toString: -> "#{PCSimpleType.typeToString(@valueType)}chan#{ if @capacity != PCChannelType.CAPACITY_UNKNOWN then @capacity else "" }"

PCChannelType.CAPACITY_UNKNOWN = -1

# - Encapsulating Type
class PCClassType extends PCBaseType
	constructor: (@className) -> super
	
	_getType: (env) -> new PCTTypeType(env.getClassWithName(@className).type)
	toString: -> @className


# -- EXPRESSIONS --
class PCExpression extends PCNode		# abstract
	childToString: (i=0, diff=0) ->			# diff helps to consider implicit left or right breaks. e.g.: a + b -> diff(a)==0 (implicit left) and diff(b)==1
		res = @children[i].toString()
		res = "(#{res})" if @getPrecedence()+diff > @children[i].getPrecedence()
		res

# - Start Expression
class PCStartExpression extends PCExpression	# One child: procedure or monitor call
	getPrecedence: -> 42
	toString: -> "start #{@childToString(0)}"
	_getType: -> new PCType(PCType.AGENT)

# - Assign Expression
class PCAssignExpression extends PCExpression
	constructor: (destination, @operator, expression) -> super destination, expression
	getDestination: -> @children[0]
	getExpression: -> @children[1]
	
	_getType: (env) -> @children[1].getType(env)
	getPrecedence: -> 39
	toString: -> "#{@getDestination().toString()} #{@operator} #{@childToString(1)}"

# - Assign Destination
class PCAssignDestination extends PCNode	# Variable or array element
	constructor: (@identifier, arrayIndexExpressions...) -> super arrayIndexExpressions...
	
	toString: -> "#{@identifier}#{("[#{o.toString()}]" for o in @children).join("")}"

# - Send Expression
class PCSendExpression extends PCExpression	# Children: First: The expression that returns the channel; Second: The expression that returns the value to send
	_getType: (env) -> @children[1].getType(env)
	getPrecedence: -> 39
	toString: -> "#{@childToString(0, 1)} <! #{@childToString(1)}"

# - Conditional Expression
class PCConditionalExpression extends PCExpression	# Three children
	_getType: (env) -> @children[1].getType(env)
	getPrecedence: -> 45
	toString: -> "#{@childToString(0)} ? #{@children[1].toString()} : #{@children[2].toString()}"

# - Or Expression
class PCOrExpression extends PCExpression # 2 children
	_getType: -> new PCTType(PCType.BOOL)
	getPrecedence: -> 48
	toString: -> "#{@childToString(0)} || #{@childToString(1, 1)}"

# - And Expression
class PCAndExpression extends PCExpression # 2 children
	_getType: -> new PCTType(PCType.BOOL)
	getPrecedence: -> 51
	toString: -> "#{@childToString(0)} && #{@childToString(1, 1)}"

# - Equality Expression
class PCEqualityExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right
	_getType: -> new PCTType(PCType.BOOL)
	getPrecedence: -> 54
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

# - Relational Expression
class PCRelationalExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right
	_getType: -> new PCTType(PCType.BOOL)
	getPrecedence: -> 57
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

# - Additive Expression
class PCAdditiveExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right
	_getType: -> new PCTType(PCType.INT)
	getPrecedence: -> 60
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

# - Multiplicative Expression
class PCMultiplicativeExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right
	_getType: -> new PCTType(PCType.INT)
	getPrecedence: -> 63
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

# - Unary Expression
class PCUnaryExpression extends PCExpression
	constructor: (@operator, expression) -> super expression
	_getType: (env) -> @children[0].getType(env)
	getPrecedence: -> 66
	toString: -> "#{@operator}#{@childToString(0)}"

# - Postfix Expression
class PCPostfixExpression extends PCExpression
	constructor: (assignDestination, @operator) -> super assignDestination
	_getType: -> new PCTType(PCType.INT)
	getPrecedence: -> 69
	toString: -> "#{@children[0].toString()}#{@operator}"

# - Receive Expression
class PCReceiveExpression extends PCExpression	# 1 child
	_getType: (env) -> @children[0].getType(env).chanelledType
	getPrecedence: -> 72
	toString: -> "<? #{@childToString(0)}"

# - Procedure Call
class PCProcedureCall extends PCExpression
	constructor: (@procedureName, args...) -> super args...	# arguments are expressions
	getProcedure: (env, className) -> 
		(if className then env.getClassWithName(className) else env).getProcedureWithName(@procedureName)
	getType: (env, className) -> if not className then super else @_getType(env, className)
	_getType: (env, className) -> @getProcedure(env, className).returnType
	getPrecedence: -> 75
	toString: -> "#{@procedureName}(#{(o.toString() for o in @children).join(", ")})"

# - Class Call
class PCClassCall extends PCExpression	# 2 children: expression that returns class and procedure call on that class
	getProcedure: (env) -> @children[1].getProcedure(env, @children[0].getType(env).identifier)
	_getType: (env) ->
		@children[1].getType(env, @children[0].getType(env).identifier)
	getPrecedence: -> 78
	toString: -> "#{@children[0].toString()}.#{@children[1].toString()}"

# - Array Expression
class PCArrayExpression extends PCExpression	# 2 children 
	_getType: (env) -> @children[0].getType(env).elementsType
	getPrecedence: -> 81
	toString: -> "#{@children[0].toString()}[#{@children[1].toString()}]"

# - Literal Expression
class PCLiteralExpression extends PCExpression
	constructor: (@value) -> super []...
	_getType: ->
		switch (typeof @value)
			when "boolean" then new PCTType(PCTType.BOOL)
			when "string" then PCTType(PCTType.STRING)
			else PCTType(PCTType.INT)
	getPrecedence: -> 84
	toString: ->
		switch (typeof @value)
			when "boolean" then (if @value then "true" else "false")
			when "string" then "\"#{@value}\""
			else "#{@value}"

# - Identifier Expression
class PCIdentifierExpression extends PCExpression
	constructor: (@identifier) -> super []...
	_getType: (env) -> env.getVariableWithName(@identifier).type
	getPrecedence: -> 84
	toString: -> @identifier


# -- STATEMENTS --

class PCStatement extends PCNode	# We need this for instanceof check, empty statement and to add semicolon to expression stmt
	collectEnvironment: (env) -> @children.length > 0 and @children[0].collectEnvironment(env)
	toString: (indent, expectsNewBlock) ->
		addIndent = expectsNewBlock == true && (@children.length == 0 || !(@children[0] instanceof PCStmtBlock))
		indent += PCIndent if addIndent
		if @children.length == 0
			res = indent + ";"
		else
			res = @children[0].toString(indent)
			res += ";" if @children[0] instanceof PCStmtExpression
		res = "\n" + res if addIndent
		res

# - Break Statement
class PCBreakStmt extends PCNode
	constructor: -> super []...
	collectEnvironment: (env) -> null
	toString: (indent) -> indent + "break"

# - Continue Statement
class PCContinueStmt extends PCNode
	constructor: -> super []...
	collectEnvironment: (env) -> null
	toString: (indent) -> indent + "continue"

# - Statement Block
class PCStmtBlock extends PCNode
	collectEnvironment: (env) -> c.collectEnvironment(env) for c in @children
	toString: (indent) -> "{\n#{(o.toString(indent+PCIndent) for o in @children).join("\n")}\n#{indent}}"

# - Statement Expression
class PCStmtExpression extends PCNode	# We need this for instanceof check
	collectEnvironment: (env) -> null
	toString: (indent) -> indent + @children[0].toString()

# - Select Statement
class PCSelectStmt extends PCNode	# children are cases
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}select {\n#{(o.toString(indent+PCIndent) for o in @children).join("\n")}\n#{indent}}"

# - Case
class PCCase extends PCNode
	constructor: (execution, condition) -> if condition then super execution, condition else super execution
	getCondition: -> if @children.length == 2 then @children[1] else null
	getExecution: -> @children[0]
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}#{if @children.length == 2 then "case #{@children[1].toString()}" else "default"}: #{@children[0].toString(indent, true)}"

# - If Statement
class PCIfStmt extends PCNode
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}if (#{@children[0].toString()}) #{@children[1].toString(indent, true)}#{if @children[2] then " #{@children[2].toString(indent, true)}" else ""}"

# - While Statement
class PCWhileStmt extends PCNode
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}while (#{@children[0].toString()}) #{@children[1].toString(indent, true)}"

# - Do Statement
class PCDoStmt extends PCNode
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}do #{@children[0].toString(indent, true)}\n#{indent}while (#{@children[1].toString()})"

# - For Statement
class PCForStmt extends PCNode		# Add PCForUpdate class?
	constructor:(@body, @init, @expression, @update...) ->
		children = @update.concat([@body])
		children.unshift(@expression) if @expression
		children.unshift(@init) if @init
		super children...
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}for (#{if @init then @init.toString() else ""}; #{if @expression then @expression.toString() else ""}; #{(o.toString("") for o in @update).join(", ")}) #{@body.toString(indent, true)}"

# - For loop initialization
class PCForInit extends PCNode
	toString: -> "#{(o.toString("") for o in @children).join(", ")}"

# - Return Statement
class PCReturnStmt extends PCNode
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}return#{if @children.length  == 1 then " #{@children[0].toString()}" else ""};"

# - Primitive Statements
class PCPrimitiveStmt extends PCNode
	constructor: (@kind, expression) -> if expression then super expression else super()
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}#{PCPrimitiveStmt.kindToString(@kind)}#{if @children.length  == 1 then " #{@children[0].toString()}" else ""};"

PCPrimitiveStmt.JOIN = 0
PCPrimitiveStmt.LOCK = 1
PCPrimitiveStmt.UNLOCK = 2
PCPrimitiveStmt.WAIT = 3
PCPrimitiveStmt.SIGNAL = 4
PCPrimitiveStmt.SIGNAL_ALL = 5
PCPrimitiveStmt.kindToString = (kind) ->
	switch kind
		when PCPrimitiveStmt.JOIN then "join"
		when PCPrimitiveStmt.LOCK then "lock"
		when PCPrimitiveStmt.UNLOCK then "unlock"
		when PCPrimitiveStmt.WAIT then "waitForCondition"
		when PCPrimitiveStmt.SIGNAL then "signal"
		when PCPrimitiveStmt.SIGNAL_ALL then "signal all"
		

# - Println Statement
class PCPrintStmt extends PCNode
	collectEnvironment: (env) -> null
	toString: (indent) -> "#{indent}println(#{(o.toString() for o in @children).join(", ")});"
















