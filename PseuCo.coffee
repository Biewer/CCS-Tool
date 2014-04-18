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
	constructor: (@line, @column, @children...) ->
		@parent = null
		c.parent = this for c in @children
	getType: (env) ->
		if not @_type
			@_type = @_getType(env)
			@_type = true if not @_type		# remember that we already checked type
		if @_type == true then null else @_type
	_collectEnvironment: (env) -> null
	_getType: -> throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "Error", "message" : "Not implemented"})
	insideMonitor: ->
		if @parent
			@parent.insideMonitor()
		else
			false
	insideProcedure: ->
		if @parent
			@parent.insideProcedure()
		else
			false
	usesSendOrReceiveOperator: ->
		for child in @children
			return true if child.usesSendOrReceiveOperator()
		false

# - Program
class PCProgram extends PCNode	# Children: (PCMonitor|PCStruct|PCMainAgent|PCDecl|PCProcedure)+
	collectClasses: (env) -> c.collectClasses(env) for c in @children
	collectEnvironment: (env) -> c.collectEnvironment(env) for c in @children

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> child._collectEnvironment(env) for child in @children

	toString: -> (o.toString("") for o in @children).join("\n")

	# Type checking
	_getType: ->
		env = new PCTEnvironmentController()
		@collectClasses(env)
		@_collectEnvironment(env)
		declaration.getType(env) for declaration in @children
		try
			env.getProcedureWithName("#mainAgent")
		catch
			throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "UndefinedMainAgent", "message" : "You must define a main agent!"})
		cycleChecker = new PCTCycleChecker(env.getAllClasses())
		trace = cycleChecker.cycleTraceForTypes()
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "ClassStructureCycle", "message" : "Monitor/structure cycle detected: #{trace}!"}) if trace
		null

# - MainAgent Decl
class PCMainAgent extends PCNode	# "mainAgent" PCStmtBlock
	collectClasses: (env) -> null
	collectEnvironment: (env) ->
		env.beginMainAgent(@)
		@children[0].collectEnvironment(env)
		env.endMainAgent()

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env._beginMainAgent(@)
		@children[0]._collectEnvironment(env)
		env.endMainAgent()

	toString: -> "mainAgent " + @children[0].toString("")

	# Type checking
	_getType: (env) ->
		env.beginProcedure("#mainAgent")
		@children[0].getType(env)
		env.endProcedure()
		new PCTType(PCTType.MAINAGENT)

	insideProcedure: -> true

# - Procedure Decl
class PCProcedureDecl extends PCNode	# Children: PCFormalParameter objects
	constructor: (line, column, resultType, @name, body, parameters...) ->
		parameters.unshift(line, column, resultType, body)
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

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		args = (parameter.getVariable(env) for parameter in @children[2..])
		env.beginNewProcedure(@, @name, @getResultType().getType(env).type, args)
		@getBody()._collectEnvironment(env)
		env.endProcedure()
	
	toString: (indent) -> "#{indent}#{@getResultType().toString()} #{@name}(#{((@getArgumentAtIndex(i).toString() for i in [0...@getArgumentCount()] by 1).join(", "))}) #{@getBody().toString(indent)}"

	# Type checking
	_getType: (env) ->
		proc = env.beginProcedure(@name)
		child.getType(env) for child in @children
		env.setReturnExhaustive() if @getBody().isReturnExhaustive
		if not (@getResultType().type is PCSimpleType.VOID)
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "ReturnNotExhaustive", "message" : "In your procedure it might be possible that for some conditions no value gets returned."}) if not env.isReturnExhaustive()
		env.endProcedure()
		proc

	insideProcedure: -> true
		

# - Formal Parameter
class PCFormalParameter extends PCNode
	constructor: (line, column, type, @identifier) -> super line, column, type
	
	getVariable: (env) -> new PCTVariable(@, @identifier, @children[0].getType(env).type)
	
	toString: -> @children[0].toString() + " " + @identifier

	# Type checking
	_getType: (env) -> null # already done in `collectEnvironment` of `PCProcedureDecl`

# - Monitor Decl
class PCMonitor extends PCNode	# "monitor" <id> "{" (Procedure decl, condition decl or variable decl)+ "}"
	constructor: (@name, declarations...) -> super declarations...
	
	collectClasses: (env) -> env.processNewClass(@, new PCTClassType(true, @name))
	collectEnvironment: (env) ->
		env.beginClass(@name)
		c.collectEnvironment(env) for c in @children
		env.endClass()

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.beginClass(@name)
		child._collectEnvironment(env) for child in @children
		env.endClass()
	
	toString: -> "monitor #{@name} {\n#{ (o.toString(PCIndent) for o in @children).join("\n") }\n}"

	# Type checking
	_getType: (env) ->
		env.beginClass(@name)
		child.getType(env) for child in @children
		env.endClass()
		monitor = env.getClassWithName(@name)
		for variable in monitor.children
			monitor.addUseOfClassType(env.getClassWithName(variable.type.identifier)) if variable.type instanceof PCTClassType
		new PCTType(PCTType.VOID)
	insideMonitor: -> true

# - Struct Decl
class PCStruct extends PCNode	# "struct" <id> "{" (Procedure decl or variable decl)+ "}"
	constructor: (@name, declarations...) -> super declarations...
	
	collectClasses: (env) -> env.processNewClass(@, new PCTClassType(false, @name))
	collectEnvironment: (env) ->
		env.beginClass(@name)
		c.collectEnvironment(env) for c in @children
		env.endClass()

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.beginClass(@name)
		child._collectEnvironment(env) for child in @children
		env.endClass()
	
	toString: -> "struct #{@name} {\n#{ (o.toString(PCIndent) for o in @children).join("\n") }\n}"

	# Type checking
	_getType: (env) ->
		env.beginClass(@name)
		child.getType(env) for child in @children
		env.endClass()
		struct = env.getClassWithName(@name)
		for variable in struct.children
			struct.addUseOfClassType(env.getClassWithName(variable.type.identifier)) if variable.type instanceof PCTClassType
		new PCTType(PCTType.VOID)

# - Condition Decl
class PCConditionDecl extends PCNode	# condition <id> with <boolean expression>
	constructor: (line, column, @name, expression) -> super line, column, expression
	getExpression: -> @children[0]
	
	collectEnvironment: (env) ->
		env.processNewVariable(new PCTVariable(@, @name, new PCTType(PCTType.CONDITION)))

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> @collectEnvironment(env)
	
	toString: (indent) -> "#{indent}condition #{@name} with #{@children[0].toString()};"

	# Type checking
	_getType: (env) ->
		type = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidLocation", "message" : "Conditions can only be declared inside monitors!"}) if not @insideMonitor()
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Expressions assigned to condition must be boolean, not #{type}"}) if not type.isEqual(new PCTType(PCTType.BOOL))
		env._processNewVariable(new PCTVariable(@, @name, new PCTType(PCTType.CONDITION)))
		null

# - Variable Decl
class PCDecl extends PCNode	# Children: Type and variable declarator(s)
	constructor: (@isStatement, children...) -> super children...
	
	# getType: -> @children[0] TODO ups, name is already taken
	getDeclarators: -> @children[1..]
	
	collectClasses: (env) -> null
	collectEnvironment: (env) ->
		@type = @children[0].getType(env).type
		@children[i].collectEnvironment(env, @type) for i in [1...@children.length] by 1

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> @collectEnvironment(env)
	
	toString: (indent) ->
		res = indent + @children[0].toString() + " " + @children[1].toString()	# ToDo: Multiple declarators
		res += ";" if @isStatement
		res

	# Type checking
	_getType: (env) ->
		for child in @children[1..]
			type = child._getType(env, @type)
			if type? and not @type.isEqual(type)
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You can't initialize variable of type #{@type} with value of type #{type}"})
		null

# PCDeclStmt is temporary available for convenience reasons!
class PCDeclStmt extends PCDecl
	constructor: (children...) -> super true, children...
# 	toString: (indent) -> super + ";"

# - Variable Declarator
class PCVariableDeclarator extends PCNode	# Identifier and optional initializer
	constructor: (line, column, @name, initializer) -> (if initializer then super line, column, initializer else super line, column, []...)
	getInitializer: -> if @children.length > 0 then @children[0] else null
	getTypeNode: -> @parent.getType()
	
	collectEnvironment: (env, type) -> env.processNewVariable(new PCTVariable(@, @name, type))

	toString: ->
		res = @name
		res += " = #{@children[0].toString()}" if @children.length > 0
		res

	# Type checking
	_getType: (env, targetType) ->
		if @children.length > 0
			@children[0]._getType(env, targetType)
		else
			null

class PCVariableInitializer extends PCNode	# array initialization >= 1 child initializers, otherwise 1 child expression
	constructor: (line, column, @isUncompletedArray=false, children...) -> super line, column, children...
	isArray: -> !(@children[0] instanceof PCExpression)
	getTypeNode: -> @parent.getTypeNode()
	toString: ->
		if @children[0] instanceof PCExpression
			"#{@children[0].toString()}"
		else
			"{#{ (o.toString() for o in @children).join(", ") }#{ if @isUncompletedArray then "," else "" }}"

	# Type checking
	_getType: (env, targetType) ->
		if @children.length is 0
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "EmptyInitialization", "message" : "Empty array initializations aren't allowed!"})
			type = targetType
		else
			if @isArray()
				type = @children[0]._getType(env, targetType.elementsType)
				for child in @children[1..]
					childType = child._getType(env, targetType.elementsType)
					throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Types of elements of an array must be equal! Found #{type} and #{childType}"}) if not type.isEqual(childType)
				if @isUncompletedArray
					type = new PCTArrayType(type, targetType.capacity)
				else
					type = new PCTArrayType(type, @children.length)
			else
				type = @children[0].getType(env)
		type

# -- TYPES --

class PCArrayType extends PCNode	# array of type baseType or array type
	constructor: (line, column, baseType, @size) -> super line, column, baseType
	
	_getType: (env) -> new PCTTypeType(new PCTArrayType(@children[0].getType(env).type, @size))
	toString: ->
		front = "#{@children[0]}"
		pos = front.indexOf("[")
		if pos is -1
			return "#{front}[#{@size}]"
		else
			end = front.substring(pos)
			front = front.slice(0, pos)
			return "#{front}[#{@size}]#{end}"

# - Non-Array Type
class PCBaseType extends PCNode	# abstract (?)
	constructor: (line, column) -> super line, column, []...

class PCSimpleType extends PCBaseType
	constructor: (line, column, @type) ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "InvalidType", "message" : "Unknown type"}) if @type < 0 or @type > 5
		super line, column, []...
	
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
		else throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "InvalidType", "message" : "Unknown type!"})
PCSimpleType.typeToTypeKind = (type) ->
	switch type
		when PCSimpleType.MUTEX then PCTType.MUTEX
		when PCSimpleType.AGENT then PCTType.AGENT
		when PCSimpleType.VOID then PCTType.VOID
		when PCSimpleType.BOOL then PCTType.BOOL
		when PCSimpleType.INT then PCTType.INT
		when PCSimpleType.STRING then PCTType.STRING
		else throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "InvalidType", "message" : "Unknown type!"})


# - Channel Type
class PCChannelType extends PCNode
	constructor:(line, column, @valueType, @capacity) -> super line, column, []...
	
	_getType: -> new PCTTypeType(new PCTChannelType(new PCTType(PCSimpleType.typeToTypeKind(@valueType)), @capacity))
	toString: -> "#{PCSimpleType.typeToString(@valueType)}chan#{ if @capacity != PCChannelType.CAPACITY_UNKNOWN then @capacity else "" }"

PCChannelType.CAPACITY_UNKNOWN = -1

# - Encapsulating Type
class PCClassType extends PCBaseType
	constructor: (line, column, @className) -> super line, column, []...
	
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

	# Type checking
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidLocation", "message" : "Start primitives are only allowed in procedures!"}) if not @insideProcedure()
		@children[0].getType(env)
		new PCTType(PCTType.AGENT)

# - Assign Expression
class PCAssignExpression extends PCExpression
	constructor: (line, column, destination, @operator, expression) -> super line, column, destination, expression
	getDestination: -> @children[0]
	getExpression: -> @children[1]
	
	getPrecedence: -> 39
	toString: -> "#{@getDestination().toString()} #{@operator} #{@childToString(1)}"

	# Type checking
	_getType: (env) ->
		dest = @children[0].getType(env)
		exp = @children[1].getType(env)
		err = ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You tried to assign #{exp} to #{dest}"})
		if @operator is "+="
			if exp.isEqual(new PCTType(PCTType.STRING))
				throw err if not dest.isEqual(new PCTType(PCTType.STRING))
			else if exp.isEqaul(new PCTType(PCTType.INT))
				throw err if not dest.isEqual(new PCTType(PCTType.INT)) and not dest.isEqual(new PCTType(PCTType.STRING))
			else
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operator '+=' is only allowed with integers and strings, but not #{exp}"})
			return dest
		else if @operator is not "="
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operator '#{op}' is only allowed with integers, but not #{dest}"}) if not dest.isEqual(new PCTType(PCTType.INT))
		throw err if not exp.isAssignableTo(dest)
		return dest

# - Assign Destination
class PCAssignDestination extends PCNode	# Variable or array element
	constructor: (@identifier, arrayIndexExpressions...) -> super arrayIndexExpressions...
	
	toString: -> "#{@identifier}#{("[#{o.toString()}]" for o in @children.slice(0).reverse()).join("")}"

	# Type checking
	_getType: (env) ->
		type = env.getVariableWithName(@identifier, @line, @column).type
		for child in @children
			childType = child.getType(env)
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You use array access on a non-array: #{type}"}) if not (type instanceof PCTArrayType)
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Array index must be an integer value, not #{childType}"}) if not childType.isEqual(new PCTType(PCTType.INT))
			type = type.elementsType
		type

# - Send Expression
class PCSendExpression extends PCExpression	# Children: First: The expression that returns the channel; Second: The expression that returns the value to send
	getPrecedence: -> 39
	toString: -> "#{@childToString(0, 1)} <! #{@childToString(1)}"

	# Type checking
	_getType: (env) ->
		left = @children[0].getType(env)
		right = @children[1].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Channel expected but found #{left}"}) if not left instanceof PCTChannelType
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Values of type #{right} can't be sent over channels for #{left.channeledType}"}) if not left.channeledType.isEqual(right)
		right
	
	usesSendOrReceiveOperator: -> true

# - Conditional Expression
class PCConditionalExpression extends PCExpression	# Three children
	getPrecedence: -> 45
	toString: -> "#{@childToString(0)} ? #{@children[1].toString()} : #{@children[2].toString()}"

	# Type checking
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type bool expected instead of #{@children[0].getType(env)} in conditional expression!"}) if not @children[0].getType(env).isEqual(new PCTType(PCTType.BOOL))
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of consequence and alternative must be the same! You have #{@children[1].getType(env)} and #{@children[2].getType(env)} instead."}) if not @children[1].getType(env).isEqual(@children[2].getType(env))
		@children[1].getType(env)

# - Or Expression
class PCOrExpression extends PCExpression # 2 children
	getPrecedence: -> 48
	toString: -> "#{@childToString(0)} || #{@childToString(1, 1)}"

	# Type checking
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type bool expected instead of #{child.getType(env)} in 'or' expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.BOOL))
		new PCTType(PCTType.BOOL)

# - And Expression
class PCAndExpression extends PCExpression # 2 children
	getPrecedence: -> 51
	toString: -> "#{@childToString(0)} && #{@childToString(1, 1)}"

	# Type checking
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type bool expected instead of #{child.getType(env)} in 'and' expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.BOOL))
		new PCTType(PCTType.BOOL)

# - Equality Expression
class PCEqualityExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right
	getPrecedence: -> 54
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	# Type checking
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Types in equality expression must be the same! You have #{@children[0].getType(env)} and #{@children[1].getType(env)} instead."}) if not @children[0].getType(env).isEqual(@children[1].getType(env))
		new PCTType(PCTType.BOOL)

# - Relational Expression
class PCRelationalExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right
	getPrecedence: (env) -> 57
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	# Type checking
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type int expected instead of #{child.getType(env)} in relational expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.BOOL)

# - Additive Expression
class PCAdditiveExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right
	getPrecedence: -> 60
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	# Type checking
	_getType: (env) ->
		isString = false
		for child in @children
			if not child.getType(env).isEqual(new PCTType(PCTType.INT))
				if child.getType(env).isEqual(new PCTType(PCTType.STRING))
					isString = true
				else
					throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Illegal type in additive expression #{child.getType(env)}!"})
		if isString
			new PCTType(PCTType.STRING)
		else
			new PCTType(PCTType.INT)

# - Multiplicative Expression
class PCMultiplicativeExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right
	getPrecedence: -> 63
	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	# Type checking
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type int expected instead of #{child.getType(env)} in multiplicative expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.INT)

# - Unary Expression
class PCUnaryExpression extends PCExpression
	constructor: (line, column, @operator, expression) -> super line, column, expression
	getPrecedence: -> 66
	toString: -> "#{@operator}#{@childToString(0)}"

	# Type checking
	_getType: (env) ->
		type = @children[0].getType(env)
		if @operator is "+" or @operator is "-"
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operators '+' and '-' can only be used with integers, not with #{type}!"}) if not type.isEqual(new PCTType(PCTType.INT))
		else if @operator is "!"
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operator '!' can only be used with booleans, not with #{type}!"}) if not type.isEqual(new PCTType(PCTType.BOOL))
		type

# - Postfix Expression
class PCPostfixExpression extends PCExpression
	constructor: (line, column, assignDestination, @operator) -> super line, column, assignDestination
	getPrecedence: -> 69
	toString: -> "#{@children[0].toString()}#{@operator}"

	# Type checking
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Increment and decrement can only be used with integers, not with #{@children[0].getType(env)}!"}) if not @children[0].getType(env).isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.INT)

# - Receive Expression
class PCReceiveExpression extends PCExpression	# 1 child
	getPrecedence: -> 72
	toString: -> "<? #{@childToString(0)}"

	# Type checking
	_getType: (env) ->
		@children[0].getType(env).chanelledType

	usesSendOrReceiveOperator: -> true

# - Procedure Call
class PCProcedureCall extends PCExpression
	constructor: (@procedureName, args...) -> super args...	# arguments are expressions
	getProcedure: (env, className) ->
		(if className then env.getClassWithName(className) else env).getProcedureWithName(@procedureName, @line, @column)
	getType: (env, className) -> if not className then super else @_getType(env, className)
	getPrecedence: -> 75
	toString: -> "#{@procedureName}(#{(o.toString() for o in @children).join(", ")})"

	# Type checking
	_getType: (env, className) ->
		proc = @getProcedure(env, className)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "No arguments for procedure that requires arguments!"}) if @children.length == 0 and proc.arguments.length > 0
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Arguments were passed to procedure without arguments!"}) if @children.length > 0 and proc.arguments.length == 0
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "More arguments than requiered were passed to procedure!"}) if @children.length > proc.arguments.length
		for arg, i in proc.arguments
			type = arg.type
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Procedure expected argument of type #{type}, but got none!"}) if i >= @children.length
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Argument number #{i + 1} should have type #{type}, but is #{@children[i].getType(env)}"}) if not @children[i].getType(env).isAssignableTo(type)
		proc.returnType

# - Class Call
class PCClassCall extends PCExpression	# 2 children: expression that returns class and procedure call on that class
	getProcedure: (env) -> @children[1].getProcedure(env, @children[0].getType(env).identifier)
	getPrecedence: -> 78
	toString: -> "#{@children[0].toString()}.#{@children[1].toString()}"

	# Type checking
	_getType: (env) ->
		type = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Incorrect type left to '.' (point). Expected a monitor or struct object, but found #{type}"}) if not (type instanceof PCTClassType)
		@children[1].getType(env, @children[0].getType(env).identifier)

# - Array Expression
class PCArrayExpression extends PCExpression	# 2 children 
	getPrecedence: -> 81
	toString: ->
		front = "#{@children[0]}"
		pos = front.indexOf("[")
		if pos is -1
			return "#{front}[#{@children[1]}]"
		else
			end = front.substring(pos)
			front = front.slice(0, pos)
			return "#{front}[#{@children[1]}]#{end}"

	# Type checking
	_getType: (env) ->
		type = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You use array access on a non-array: #{type}"}) if not (type instanceof PCTArrayType)
		childType = @children[1].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Array index must be an integer value, not #{childType}"}) if not childType.isEqual(new PCTType(PCTType.INT))
		type = type.elementsType
		type

# - Literal Expression
class PCLiteralExpression extends PCExpression
	constructor: (line, column, @value) -> super line, column, []...
	getPrecedence: -> 84
	toString: ->
		switch (typeof @value)
			when "boolean" then (if @value then "true" else "false")
			when "string" then "\"#{@value}\""
			else "#{@value}"

	# Type checking
	_getType: (env) ->
		switch (typeof @value)
			when "boolean" then new PCTType(PCTType.BOOL)
			when "string" then new PCTType(PCTType.STRING)
			else new PCTType(PCTType.INT)

# - Identifier Expression
class PCIdentifierExpression extends PCExpression
	constructor: (line, column, @identifier) -> super line, column, []...
	getPrecedence: -> 84
	toString: -> @identifier

	# Type checking
	_getType: (env) ->
		env.getVariableWithName(@identifier, @line, @column).type


# -- STATEMENTS --

class PCStatement extends PCNode	# We need this for instanceof check, empty statement and to add semicolon to expression stmt
	collectEnvironment: (env) -> @children.length > 0 and @children[0].collectEnvironment(env)

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> @children.length > 0 and @children[0]._collectEnvironment(env)

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

	# Type checking
	_getType: (env) ->
		@children[0].getType(env) if @children.length > 0
		new PCTType(PCTType.VOID)

# - Break Statement
class PCBreakStmt extends PCNode
	constructor: (line, column) -> super line, column, []...
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> indent + "break"

	# Type checking
	_getType: (env) ->
		# TODO is within loop?
		new PCTType(PCTType.VOID)

# - Continue Statement
class PCContinueStmt extends PCNode
	constructor: (line, column) -> super line, column, []...
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> indent + "continue"

	# Type checking
	_getType: (env) ->
		# TODO is within loop?
		new PCTType(PCTType.VOID)

# - Statement Block
class PCStmtBlock extends PCNode
	collectEnvironment: (env) -> c.collectEnvironment(env) for c in @children

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}{\n#{(o.toString(indent+PCIndent) for o in @children).join("\n")}\n#{indent}}"

	# Type checking
	_getType: (env) ->
		env.getEnvironment(@, @__id)
		for child in @children
			child.getType(env)
			if child instanceof PCStatement and child.children[0]? and child.children[0] instanceof PCStmtBlock
				env.setReturnExhaustive() if child.children[0].isReturnExhaustive
		env.closeEnvironment()
		new PCTType(PCTType.VOID)

# - Statement Expression
class PCStmtExpression extends PCNode	# We need this for instanceof check
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> indent + @children[0].toString()

	# Type checking
	_getType: (env) ->
		@children[0].getType(env)

# - Select Statement
class PCSelectStmt extends PCNode	# children are cases
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}select {\n#{(o.toString(indent+PCIndent) for o in @children).join("\n")}\n#{indent}}"

	# Type checking
	_getType: (env) ->
		env.getEnvironment(@, @__id)
		retExhaust = true
		for child in @children
			child.getType(env)
			retExhaut &= child.isReturnExhaustive
		env.setReturnExhaustive() if retExhaust
		env.closeEnvironment()
		env.setReturnExhaustive() if retExhaust
		new PCTType(PCTType.VOID)

# - Case
class PCCase extends PCNode
	constructor: (line, column, execution, condition) -> if condition then super line, column, execution, condition else super line, column, execution
	getCondition: -> if @children.length == 2 then @children[1] else null
	getExecution: -> @children[0]
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		child._collectEnvironment(env) for child in @children

	toString: (indent) -> "#{indent}#{if @children.length == 2 then "case #{@children[1].toString()}" else "default"}: #{@children[0].toString(indent, true)}"

	# Type checking
	_getType: (env) ->
		child.getType(env) for child in @children
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "case condition requires at least one send or receive operation."}) if @children.length > 1 and not @children[0].usesSendOrReceiveOperator()
		if @children[0] instanceof PCStatement and @children[0].children[0]? and @children[0].children[0] instanceof PCStmtBlock
			@isReturnExhaustive = @children[0].children[0].isReturnExhaustive
		new PCTType(PCTType.VOID)

# - If Statement
class PCIfStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}if (#{@children[0].toString()}) #{@children[1].toString(indent, true)}#{if @children[2] then "\n#{indent}else #{@children[2].toString(indent, true)}" else ""}"

	# Type checking
	_getType: (env) ->
		expType = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if not expType.isEqual(new PCTType(PCTType.BOOL))
		env.getEnvironment(@, @.__id)
		@children[1].getType(env)
		@children[2].getType(env) if @children.length > 2
		if @children[1] instanceof PCStatement and @children[1].children[0]? and @children[1].children[0] instanceof PCStmtBlock
			if @children[2]?
				if @children[2] instanceof PCStatement and @children[2].children[0]? and @children[2].children[0] instanceof PCStmtBlock
					env.setReturnExhaustive() if @children[1].children[0].isReturnExhaustive and @children[2].children[0].isReturnExhaustive
			else
				env.setReturnExhaustive() if @children[1].children[0].isReturnExhaustive
		env.closeEnvironment()
		env.setReturnExhaustive() if @isReturnExhaustive
		new PCTType(PCTType.VOID)

# - While Statement
class PCWhileStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}while (#{@children[0].toString()}) #{@children[1].toString(indent, true)}"

	# Type checking
	_getType: (env) ->
		expType = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if not expType.isEqual(new PCTType(PCTType.BOOL))
		env.getEnvironment(@, @.__id)
		@children[1].getType(env)
		env.closeEnvironment()
		new PCTType(PCTType.VOID)

# - Do Statement
class PCDoStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}do #{@children[0].toString(indent, true)}\n#{indent}while (#{@children[1].toString()})"

	# Type checking
	_getType: (env) ->
		env.getEnvironment(@, @.__id)
		@children[0].getType(env)
		env.closeEnvironment()
		expType = @children[1].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if not expType.isEqual(new PCTType(PCTType.BOOL))
		new PCTType(PCTType.VOID)

# - For Statement
class PCForStmt extends PCNode		# Add PCForUpdate class?
	constructor:(line, column, @body, @init, @expression, @update...) ->
		children = @update.concat([@body])
		children.unshift(@expression) if @expression
		children.unshift(@init) if @init
		super line, column, children...
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		@init._collectEnvironment(env)
		@body._collectEnvironment(env)
		env.closeEnvironment()

	toString: (indent) -> "#{indent}for (#{if @init then @init.toString() else ""}; #{if @expression then @expression.toString() else ""}; #{(o.toString("") for o in @update).join(", ")}) #{@body.toString(indent, true)}"

	# Type checking
	_getType: (env) ->
		env.getEnvironment(@, @__id)
		@init.getType(env) if @init
		expType = @expression.getType(env) if @expression?
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if expType? and not expType.isEqual(new PCTType(PCTType.BOOL))
		update.getType(env) for update in @update
		@body.getType(env)
		env.closeEnvironment()
		new PCTType(PCTType.VOID)

# - For loop initialization
class PCForInit extends PCNode
	toString: -> "#{(o.toString("") for o in @children).join(", ")}"

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		child._collectEnvironment(env) for child in @children

	# Type checking
	_getType: (env) ->
		child.getType(env) for child in @children
		new PCTType(PCTType.VOID)

# - Return Statement
class PCReturnStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> "#{indent}return#{if @children.length  == 1 then " #{@children[0].toString()}" else ""};"

	# Type checking
	_getType: (env) ->
		type = @children[0].getType(env) if @children.length > 0
		type = new PCTType(PCTType.VOID) if not type?
		expectedType = env.getExpectedReturnValue()
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Expression of type #{type} doesn't match expected return type #{expectedType} for procedure."}) if not type.isEqual(expectedType)
		env.setReturnExhaustive()

# - Primitive Statements
class PCPrimitiveStmt extends PCNode
	constructor: (line, column, @kind, expression) -> if expression then super line, column, expression else super line, column, []...
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> "#{indent}#{PCPrimitiveStmt.kindToString(@kind)}#{if @children.length  == 1 then " #{@children[0].toString()}" else ""};"

	# Type checking
	_getType: (env) ->
		@_type = @children[0].getType(env) if @children.length > 0
		switch @kind
			when PCPrimitiveStmt.JOIN
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "join must be applied on agents, not #{@_type}!"}) if not @_type.isEqual(new PCTType(PCTType.AGENT))
			when PCPrimitiveStmt.LOCK, PCPrimitiveStmt.UNLOCK
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "lock and unlock must be applied on mutex objects, not #{@_type}!"}) if not @_type.isEqual(new PCTType(PCTType.MUTEX))
			when PCPrimitiveStmt.WAIT
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "waitForCondition can only be used in monitors!"}) if not @insideMonitor()
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "waitForCondition must be applied on condition or boolean objects, not #{@_type}!"}) if not @_type.isEqual(new PCTType(PCTType.Bool)) and not @_type.isEqual(new PCTType(PCTType.CONDITION))
			when PCPrimitiveStmt.SIGNAL, PCPrimitiveStmt.SIGNAL_ALL
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "signal and signalAll can only be used in monitors!"}) if not @insideMonitor()
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "signal and signalAll must be applied on condition objects, not #{@_type}!"}) if @children.length > 0 and not @_type.isEqual(new PCTType(PCTType.CONDITION))
		new PCTType(PCTType.VOID)

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

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> "#{indent}println(#{(o.toString() for o in @children).join(", ")});"

	# Type checking
	_getType: (env) ->
		for child in @children
			type = child.getType(env)
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "println can only process strings and integers, but no #{type}!"}) if not type.isEqual(new PCTType(PCTType.STRING)) and not type.isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.VOID)

