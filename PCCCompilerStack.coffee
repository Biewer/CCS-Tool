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



# Has property pseucoNode for the node that created the stack element
class PCCStackElement
	constructor: -> @parent = null
	getResult: -> throw new Error("Abstract and not implemented!")
	getNext: -> throw new Error("Abstract and not implemented!")
	setNext: -> throw new Error("Abstract and not implemented!")
	removeNext: (next) -> throw new Error("Abstract and not implemented!")
	getTopElement: ->
		next = @getNext()
		if next == null then @ else next.getTopElement()
	getCurrentProcessFrame: -> @parent?.getCurrentProcessFrame()
	getCurrentControlElement: -> @parent?.getCurrentControlElement()
	getResults: -> throw new Error("Not implemented")
	removeFromStack: ->
		@getStack().setTopElement(@parent)
		@parent?.removeNext(@)
		@getResults()
	isCompletedProcess: -> false
	createCalculusNode: (cons, args...) ->
		res = new cons(args...)
		res.pseucoNode = @pseucoNode
		@pseucoNode.addCalculusComponent(res) if @pseucoNode
		res
	
	compilerGetVariable: (compiler, identifier) -> @parent?.compilerGetVariable(compiler, identifier)
	compilerGetProcedure: (compiler, identifier) -> @parent?.compilerGetProcedure(compiler, identifier)
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable, callback, context) ->
		@parent?.compilerHandleNewVariableWithDefaultValueCallback(compiler, variable, callback, context)


class PCCUnaryStackElement extends PCCStackElement
	constructor: -> @next = null; super
	#getResult: -> if @next == null then throw new Error("Next element is not set!") else @next.getResult()
	getResults: -> if @next == null then new PCCStackResultContainer() else @next.getResults()
	getNext: -> @next
	setNext: (next) -> 
		throw new Error("Can't set next twice!") if @next != null
		next.parent = @ 
		@next = next
	removeNext: (next) -> 
		throw new Error("Unknown next") if @next != next
		next.parent = null
		@next = null


class PCCBinaryStackElement extends PCCStackElement
	constructor: -> @leftStack = null; @rightStack = null; @topStack = null; @target = 0; super
	getResults: -> throw new Error("Abstract and not implemented!")
	getNext: -> if @target == PCCBinaryTarget.LEFT then @leftStack else if @target == PCCBinaryTarget.RIGHT then @rightStack else @topStack
	setNext: (next) ->
		next.parent = @ if next
		if @target == PCCBinaryTarget.LEFT  
			(throw new Error("Can't set next twice!") if @leftStack)
			@leftStack = next 
		else if @target == PCCBinaryTarget.RIGHT 
			(throw new Error("Can't set next twice!") if @rightStack)
			@rightStack = next 
		else 
			(throw new Error("Can't set next twice!") if @topStack)
			@topStack = next
	removeNext: (next) ->
		throw new Error("Unknown next") if @next != @getNext()
		@setNext(null)
	
	setTarget: (target) ->
		raise new Error("Illegal target!") if target < 0 or target > 2
		if target == PCCBinaryTarget.TOP and @topStack
			raise new Error("Left and right target are not allowed once top was modified!")
		@target = target
		@getStack().setTopElement(@getTopElement())
		@parent.updateBinaryTargets(@)
	setBranchFinished: ->
		if @target == PCCBinaryTarget.TOP
			throw new Error("All branches are already finished!") 
		else if @target == PCCBinaryTarget.RIGHT
			@setTarget(PCCBinaryTarget.TOP)
		else if @target == PCCBinaryTarget.LEFT
			@setTarget(PCCBinaryTarget.RIGHT)
		else
			throw new Error("Unknown target is currently specified!")
		null
	
	updateBinaryTargets: (destination) -> 
		if destination == @leftStack
			@target = PCCBinaryTarget.LEFT
		else if destination == @rightStack
			@target = PCCBinaryTarget.RIGHT
		else if destination == @topStack
			@target = PCCBinaryTarget.TOP
		else
			throw new Error("Unknown destination!")

PCCBinaryTarget = {}
PCCBinaryTarget.LEFT = 0
PCCBinaryTarget.RIGHT = 1
PCCBinaryTarget.TOP = 2

PCCStackElement::updateBinaryTargets = (destination) -> @parent?.updateBinaryTargets(@)



class PCCStopStackElement extends PCCUnaryStackElement
	getResults: ->
		more = if @next then @next.getResults() else new PCCStackResultContainer()
		more.addResult(PCCStackResult.TYPE_CCSPROCESS, @createCalculusNode(CCS.Stop))
		more
	isCompletedProcess: -> true
		

class PCCExitStackElement extends PCCUnaryStackElement
	getResults: ->
		more = if @next then @next.getResults() else new PCCStackResultContainer()
		more.addResult(PCCStackResult.TYPE_CCSPROCESS, @createCalculusNode(CCS.Exit))
		more
	isCompletedProcess: -> true

class PCCPrefixStackElement extends PCCUnaryStackElement
	constructor: (@channel, @specificChannel) -> super
	_getChannel: -> new CCS.Channel(@channel, if @specificChannel then @specificChannel.ccsTree() else null)
	_getAction: -> throw new Error("Abstract and not implemented!")
	getResults: ->
		container = @next.getResults()
		pRes = container.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		container.replaceResult(PCCStackResult.TYPE_CCSPROCESS, @createCalculusNode(CCS.Prefix, @_getAction(), pRes.data))
		container
	isCompletedProcess: -> if @next then @next.isCompletedProcess() else false

class PCCInputStackElement extends PCCPrefixStackElement
	constructor: (channel, specificChannel, @container) -> super channel, specificChannel	# string x PCCContainer x string
	_getAction: -> 
		variable = if @container then @createCalculusNode(CCS.Variable, @container.identifier) else null
		@createCalculusNode(CCS.Input, @_getChannel(), variable)

class PCCOutputStackElement extends PCCPrefixStackElement
	constructor: (channel, sepcificChannel, @container) -> super channel, sepcificChannel	# string x PCCContainer x PCCContainer
	_getAction: -> @createCalculusNode(CCS.Output, @_getChannel(), if @container then @container.ccsTree() else null)

class PCCConditionStackElement extends PCCUnaryStackElement
	constructor: (@conditionContainer) -> super
	getResults: ->
		container = @next.getResults()
		pRes = container.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		container.replaceResult(PCCStackResult.TYPE_CCSPROCESS, @createCalculusNode(CCS.Condition, @conditionContainer.ccsTree(), pRes.data))
		container
	isCompletedProcess: -> if @next then @next.isCompletedProcess() else false

class PCCRestrictionStackElement extends PCCUnaryStackElement
	constructor: (@restrictedChannels) -> super
	getResults: ->
		container = @next.getResults()
		pRes = container.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		container.replaceResult(PCCStackResult.TYPE_CCSPROCESS, @createCalculusNode(CCS.Restriction, pRes.data, @restrictedChannels))
		container
	isCompletedProcess: -> if @next then @next.isCompletedProcess() else false

class PCCApplicationStackElement extends PCCUnaryStackElement
	constructor: (@processName, argContainers) -> 
		argContainers = [] if argContainers == undefined
		@argContainers = argContainers[..] if argContainers
		super
	getResults: ->
		more = if @next then @next.getResults() else new PCCStackResultContainer()
		values = (c.ccsTree() for c in @argContainers)
		more.addResult(PCCStackResult.TYPE_CCSPROCESS, @createCalculusNode(CCS.ProcessApplication, @processName, values))
		more
	isCompletedProcess: -> true

class PCCApplicationPlaceholderStackElement extends PCCApplicationStackElement
	constructor: (@frame) -> super null, null
	set: (processName, argContainers=[]) ->
		throw new Error("Placeholder values can't be set twice!") if @processName or @argContainers
		@processName = processName
		@argContainers = argContainers[..]
		null
	getResults: ->
		throw new Error("Placeholder without values!") if !@processName or !@argContainers
		super


class PCCBinaryCCSStackElement extends PCCBinaryStackElement
	_createCCSProcess: -> throw new Error("Abstract and not implemented!")
	getResults: ->
		more = if @topStack then @topStack.getResults() else new PCCStackResultContainer()
		leftContainer = @leftStack.getResults()
		left = leftContainer.getResult()
		throw new Error("Unexpected result type!") if left.type != PCCStackResult.TYPE_CCSPROCESS
		rightContainer = @rightStack.getResults()
		right = rightContainer.getResult()
		throw new Error("Unexpected result type!") if right.type != PCCStackResult.TYPE_CCSPROCESS
		rightContainer.removeResult()
		leftContainer.appendContainer(rightContainer)
		leftContainer.appendContainer(more)
		leftContainer.replaceResult(PCCStackResult.TYPE_CCSPROCESS, @_createCCSProcess(left.data, right.data))
		leftContainer
	isCompletedProcess: ->
		if @leftStack and @rightStack then @leftStack.isCompletedProcess() and @rightStack.isCompletedProcess() else false

class PCCChoiceStackElement extends PCCBinaryCCSStackElement
	_createCCSProcess: (left, right) -> @createCalculusNode(CCS.Choice, left, right)
	
class PCCParallelStackElement extends PCCBinaryCCSStackElement
	_createCCSProcess: (left, right) -> @createCalculusNode(CCS.Parallel, left, right)

class PCCSequenceStackElement extends PCCBinaryCCSStackElement
	_createCCSProcess: (left, right) -> @createCalculusNode(CCS.Sequence, left, right)




class PCCSystemProcessStackElement extends PCCUnaryStackElement
	constructor: (@weight) -> super()
	getResults: ->
		container = @next.getResults()
		pRes = container.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		pRes
	

class PCCProcessDefinitionStackElement extends PCCUnaryStackElement
	constructor: (@processName, argContainers=[]) -> 
		@argContainers = argContainers[..]
		super
	getResults: ->
		container = @next.getResults()
		pRes = container.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		argNames = ((@createCalculusNode(CCS.Variable, c.identifier)) for c in @argContainers)
		def = @createCalculusNode(CCS.ProcessDefinition, @processName, pRes.data, argNames)
		container.replaceResult(PCCStackResult.TYPE_CCSPROCESS_DEFINITION, def)
		container


class PCCProcessFrameStackElement extends PCCUnaryStackElement
	constructor: (@frame) -> super
	getCurrentProcessFrame: -> @frame
	compilerGetVariable: (compiler, identifier) -> 
		result = @frame.compilerGetVariable(compiler, identifier)
		if result then result else super
	compilerGetProcedure: (compiler, identifier) -> 
		result = @frame.compilerGetProcedure(compiler, identifier)
		if result then result else super
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable, callback, context) ->
		result = @frame.compilerHandleNewVariableWithDefaultValueCallback(compiler, variable, callback, context)
		if result then result else super
	isCompletedProcess: -> if @next then @next.isCompletedProcess() else false

#class PCCScopeStackElement extends PCCProcessFrameStackElement
	

class PCCClassStackElement extends PCCUnaryStackElement
	constructor: (@classInfo) -> super
	getCurrentControlElement: -> @classInfo
	compilerGetVariable: (compiler, identifier) -> 
		result = @classInfo.compilerGetVariable(compiler, identifier)
		if result then result else super
	compilerGetProcedure: (compiler, identifier) -> 
		result = @classInfo.compilerGetProcedure(compiler, identifier)
		if result then result else super
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable, callback, context) ->
		result = @classInfo.compilerHandleNewVariableWithDefaultValueCallback(compiler, variable, callback, context)
		if result then result else super

class PCCGlobalStackElement extends PCCUnaryStackElement
	constructor: (@global) -> super
	getCurrentControlElement: -> @global
	compilerGetVariable: (compiler, identifier) -> 
		result = @global.compilerGetVariable(compiler, identifier)
		if result then result else super
	compilerGetProcedure: (compiler, identifier) -> 
		result = @global.compilerGetProcedure(compiler, identifier)
		if result then result else super
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable, callback, context) ->
		result = @global.compilerHandleNewVariableWithDefaultValueCallback(compiler, variable, callback, context)
		if result then result else super

class PCCProcedureStackElement extends PCCUnaryStackElement
	constructor: (@procedure) -> super
	getCurrentControlElement: -> @procedure
	
	
	
	
	
	
	
	
	
	
	
	
	
	
class PCCCompilerStack
	constructor: (initialElement) -> 
		@topElement = initialElement
		@topElement.__PCCCompilerStack = @
		@topElement.getStack = -> @__PCCCompilerStack
	setTopElement: (e) -> @topElement = e
	getCurrentProcessFrame: -> @topElement.getCurrentProcessFrame()
	getCurrentControlElement: -> @topElement.getCurrentControlElement()
	pushElement: (e) -> 
		@topElement.setNext(e)
		@topElement = e
	isCurrentProcessCompleted: -> @topElement.isCompletedProcess()
	
	compilerGetVariable: (compiler, identifier) -> @topElement?.compilerGetVariable(compiler, identifier)
	compilerGetProcedure: (compiler, identifier) -> @topElement?.compilerGetProcedure(compiler, identifier)
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable, callback, context) ->
		@topElement?.compilerHandleNewVariableWithDefaultValueCallback(compiler, variable, callback, context)

PCCStackElement::getStack = -> @parent.getStack()


class PCCStackResult
	constructor: (@type, @data) ->

class PCCStackResultContainer
	constructor: -> @results = []
	addResult: (type, data) -> @results.unshift(new PCCStackResult(type, data))
	replaceResult: (type, data) -> @results[0] = new PCCStackResult(type, data)
	getResult: -> @results[0]
	removeResult: -> @results.shift()
	appendContainer: (container) -> @results = @results.concat(container.results)

PCCStackResult.TYPE_UNSPECIFIC = 0
PCCStackResult.TYPE_CCSPROCESS = 1
PCCStackResult.TYPE_CCSPROCESS_DEFINITION = 2











