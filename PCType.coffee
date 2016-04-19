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
	This class represents PseuCo's types.
	May be partly incomplete as type checking is not yet completely supported by the PseuCo tree.
###

class PCTType
	constructor: (@kind) ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "InvalidType", "message" : "Unknown kind of type!"}) if @kind < 0 || @kind > 14
	isEqual: (type) ->
		type.kind == @kind
	isAssignableTo: (type) ->
		return false if @kind is PCTType.WILDCARD
		(@isEqual(type) or type.kind is PCTType.WILDCARD)
	getBaseType: -> @
	toString: ->
		switch @kind
			when PCTType.INT then "int"
			when PCTType.BOOL then "bool"
			when PCTType.STRING then "string"
			when PCTType.CHANNEL then "channel"
			when PCTType.ARRAY then "array"
			when PCTType.MONITOR then "monitor"
			when PCTType.STRUCTURE then "struct"
			when PCTType.LOCK then "lock"
			when PCTType.MUTEX then "mutex"
			when PCTType.CONDITION then "condition"
			when PCTType.PROCEDURE then "procedure"
			when PCTType.TYPE then "type"
			when PCTType.MAINAGENT then "mainAgent"
			when PCTType.AGENT then "agent"
			when PCTType.WILDCARD then "wildcard"
			else "void"

PCTType.VOID = 0;
PCTType.BOOL = 1;
PCTType.INT = 2;
PCTType.STRING = 3;

PCTType.CHANNEL = 4;
PCTType.ARRAY = 5;
PCTType.MONITOR = 6;
PCTType.STRUCT = 7;

PCTType.LOCK = 8;
PCTType.MUTEX = 9;
PCTType.CONDITION = 10;

PCTType.PROCEDURE = 11;
PCTType.TYPE = 12;
PCTType.MAINAGENT = 13;

PCTType.AGENT = 14;

PCTType.WILDCARD = 15;



class PCTArrayType extends PCTType
	constructor: (@elementsType, @capacity) ->
		super PCTType.ARRAY
	isEqual: (type) ->
		capacityFulfilled = type.capacity == @capacity || @capacity == 0 || type.capacity == 0
		type.kind == @kind and capacityFulfilled and @elementsType.isEqual(type.elementsType)
	isAssignableTo: (type) ->
		return false if @kind is PCTType.WILDCARD
		(@elementsType.isAssignableTo(type.elementsType) or type.kind is PCTType.WILDCARD)
	getBaseType: -> @elementsType.getBaseType()
	toString: -> "#{@elementsType.toString()}[#{@capacity}]"


class PCTChannelType extends PCTType
	constructor: (@channelledType, @capacity) ->
		super PCTType.CHANNEL
	isEqual: (type) ->
		@kind == type.kind and @capacity == type.capacity and @channelledType.isEqual(type.channelledType)
	isAssignableTo: (type) ->	# is this assignable to type?
		@kind == type.kind and (@capacity == type.capacity or @capacity == PCChannelType.CAPACITY_UNKNOWN) and @channelledType.isEqual(type.channelledType)
	getApplicableCapacity: -> if @capacity == PCChannelType.CAPACITY_UNKNOWN then 0 else @capacity
	getBaseType: -> @channelledType.getBaseType()
	toString: ->
		if @capacity == PCChannelType.CAPACITY_UNKNOWN
			"handshake #{@channelledType.toString()} #{super}"
		else
			"#{@channelledType.toString()} #{super} of capacity #{@capacity}"


class PCTClassType extends PCTType
	constructor: (isMonitor, @identifier) ->
		super (if isMonitor then PCTType.MONITOR else PCTType.STRUCT)
	isMonitor: -> @kind == PCTType.MONITOR
	isEqual: (type) ->
		@kind == type.kind and @identifier == type.identifier
	getBaseType: -> @
	toString: -> "#{super} #{@identifier}"

class PCTProcedureType extends PCTType
	constructor: (@returnType, @argumentTypes) ->
		super PCTType.PROCEDURE
	isEqual: (type) ->
		return false if type.argumentTypes.length != @argumentTypes
		(return false if not type.argumentTypes[i].isEqual(@argumentTypes[i])) for i in [0...@argumentTypes.length] by 1
		type.returnType.isEqual(@returnType)
	getBaseType: -> @returnType.getBaseType()
	toString: ->
		args = (t.toString() for t in @argumentTypes).join(" x ")
		"#{@returnType.toString()} -> (#{args})"
		
		
class PCTTypeType extends PCTType
	constructor: (@type) ->
		super PCTType.TYPE
	getBaseType: -> @type.getBaseType()
	isEqual: (type) ->	@kind == type.kind and @type.isEqual(type.type)
		
		
		
		
	

