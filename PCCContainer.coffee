###
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
###



###
	Manages different kinds of containers. Containers basically wrap CCS Expressions.
###


class PCCContainer
	constructor: (@ccsType) ->
	isReadonly: -> throw new Error("Abstract")
	ccsTree: -> throw new Error("Abstract")
	isEqual: (container) -> throw new Error("Abstract")

class PCCConstantContainer extends PCCContainer
	constructor: (@value) ->
		if typeof @value == "boolean" then super PCCType.BOOL
		else if typeof @value == "number" then super PCCType.INT
		else if typeof @value == "string" then super PCCType.STRING
		else throw new Error("Unknown type")
	isReadonly: -> true
	ccsTree: -> new CCSConstantExpression(@value)
	isEqual: (container) -> container instanceof PCCConstantContainer and container.value == @value

class PCCVariableContainer extends PCCContainer
	constructor: (@identifier, ccsType) -> super ccsType
	isReadonly: -> false
	ccsTree: -> new CCSVariableExpression(@identifier)
	isEqual: (container) -> container instanceof PCCVariableContainer and container.identifier == @identifier

class PCCComposedContainer extends PCCContainer		# abstract
	constructor: (ccsType) -> super ccsType

class PCCBinaryContainer extends PCCComposedContainer
	constructor: (@leftContainer, @rightContainer, @operator) ->
		if @operator == "+" or @operator == "^"
			if @leftContainer.ccsType.isString() or @rightContainer.ccsType.isString() or @operator == "^"
				@exp = new CCSConcatenatingExpression(@leftContainer.ccsTree(), @rightContainer.ccsTree())
				super PCCType.STRING
			else
				@exp = new CCSAdditiveExpression(@leftContainer.ccsTree(), @rightContainer.ccsTree(), @operator)
				super PCCType.INT
		else if @operator == "-"
			@exp = new CCSAdditiveExpression(@leftContainer.ccsTree(), @rightContainer.ccsTree(), @operator)
			super PCCType.INT
		else if @operator == "*" or @operator == "/" or @operator == "%"
			@exp = new CCSMultiplicativeExpression(@leftContainer.ccsTree(), @rightContainer.ccsTree(), @operator)
			super PCCType.INT
		else if @operator == "<" or @operator == "<=" or @operator == ">" or @operator == ">="
			@exp = new CCSRelationalExpression(@leftContainer.ccsTree(), @rightContainer.ccsTree(), @operator)
			super PCCType.BOOL
		else if @operator == "==" or @operator == "!="
			@exp = new CCSEqualityExpression(@leftContainer.ccsTree(), @rightContainer.ccsTree(), @operator)
			super PCCType.BOOL
		else if @operator == "&&"
			throw new Error("Not available in CCS")
		else if @operator == "||"
			throw new Error("Not available in CCS")
		else
			throw new Error("Unknown operator")
	isReadonly: -> true
	ccsTree: -> @exp
	isEqual: (container) -> container instanceof PCCBinaryContainer and container.operator == @operator and container.leftContainer.isEqual(@leftContainer) and container.rightContainer.isEqual(@rightContainer)

class PCCUnaryContainer extends PCCComposedContainer
	constructor: (@operator, @container) ->
		if @operator == "!"
			@exp = new CCSEqualityExpression(@container.ccsTree(), new CCSConstantExpression(false), "==")
			super PCCType.BOOL
		else if @operator == "-"
			@exp = new CCSAdditiveExpression(new CCSConstantExpression(0), @container.ccsTree(), "-")
			super PCCType.INT
		else if @operator != "+"
			throw new Error("Unknown operator")
	isReadonly: -> true
	ccsTree: -> @exp
	isEqual: (container) -> container instanceof PCCConstantContainer and container.operator == @operator and container.container.isEqual(@container) 
		
		
###
PCCContainer.RETURN = -> new PCCVariableContainer("i_r")
PCCContainer.INSTANCE = -> new PCCVariableContainer("i_i")
PCCContainer.GUARD = -> new PCCVariableContainer("i_g")
###

