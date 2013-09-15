###
	Manages different kinds of containers. Containers basically wrap CCS Expressions.
###


class PCCContainer
	isReadonly: -> throw new Error("Abstract")
	ccsTree: -> throw new Error("Abstract")

class PCCConstantContainer extends PCCContainer
	constructor: (@value) ->
	isReadonly: -> true
	ccsTree: -> new CCSConstantExpression(@value)

class PCCVariableContainer extends PCCContainer
	constructor: (@identifier) ->
	isReadonly: -> false
	ccsTree: -> new CCSVariableExpression(@identifier)

class PCCComposedContainer extends PCCContainer		# ToDo

PCCContainer.RETURN = -> new PCCVariableContainer("i_r")
PCCContainer.INSTANCE = -> new PCCVariableContainer("i_i")
PCCContainer.GUARD = -> new PCCVariableContainer("i_g")