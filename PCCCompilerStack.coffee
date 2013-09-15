



class PCCStackElement
	constructor: (@parent) ->
	getResult: -> throw new Error("Abstract and not implemented!")
	getNext: -> throw new Error("Abstract and not implemented!")
	setNext: -> throw new Error("Abstract and not implemented!")
	getTopElement: ->
		next = @getNext()
		if next == null the @ else next.getTopElement()
	
	compilerGetVariable: (compiler, identifier, instanceContainer) -> @parent?.compilerGetVariable()
	compilerGetProcedure: (compiler, identifier, instanceContainer) -> @parent?.compilerGetProcedure()
	compilerHandleNewIdentifierWithDefaultValueCallback: (compiler, identifier, callback, context) ->
		@parent?.compilerHandleNewIdentifierWithDefaultValueCallback()


class PCCUnaryStackElement extends PCCStackElement
	constructor: -> @next = null; super
	getResult: -> if @next == null then throw new Error("Next element is not set!") else @next.getResult()
	getNext: -> @next
	setNext: (next) -> 
		throw new Error("Can't set next twice!") if @next != null
		next.parent = @ 
		@next = next


class PCCBinaryStackElement extends PCCStackElement
	constructor: -> @leftStack = null; @rightStack = null; @topStack = null; @target = 0; super
	getResult: -> throw new Error("Abstract and not implemented!")
	getNext: -> if @target == PCCBinaryStackElement.TARGET_LEFT then @leftStack else if @target == PCCBinaryStackElement.TARGET_RIGHT then @rightStack else @topStack
	setNext: (next) ->
		next.parent = @
		if @target == PCCBinaryStackElement.TARGET_LEFT  
			throw new Error("Can't set next twice!") if @leftStack != null
			@leftStack = next 
		else if @target == PCCBinaryStackElement.TARGET_RIGHT 
			throw new Error("Can't set next twice!") if @rightStack != null
		 	@rightStack = next 
		 else 
		 	throw new Error("Can't set next twice!") if @topStack != null
		 	@topStack = next
	setTarget: (target) ->
		raise new Error("Illegal target!") if target < 0 or target > 2
		if target == PCCBinaryStackElement.TARGET_TOP and @topStack != null
			raise new Error("Left and right target are not allowed once top was modified!")
		@target = target
		@getStack().setTopElement(@getTopElement())
		@parent.updateBinaryTargets(@)
	updateBinaryTargets: (destination) -> 
		if destination == @leftStack
			@target = PCCBinaryStackElement.TARGET_LEFT
		else if destination == @rightStack
			@target = PCCBinaryStackElement.TARGET_RIGHT
		else if destination == @topStack
			@target = PCCBinaryStackElement.TARGET_TOP
		else
			throw new Error("Unknown destination!")

PCCBinaryStackElement.TARGET_LEFT = 0
PCCBinaryStackElement.TARGET_RIGHT = 1
PCCBinaryStackElement.TARGET_TOP = 2

PCCStackElement::updateBinaryTargets = (destination) -> @parent.updateBinaryTargets(@)



class PCCStopStackElement extends PCCUnaryStackElement
	getResult: ->
		more = if @next then @next.getResult() else null
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS, new CCSStop(), more)
		

class PCCExitStackElement extends PCCUnaryStackElement
	getResult: ->
		more = if @next then @next.getResult() else null
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS, new CCSExit(), more)

class PCCPrefixStackElement extends PCCUnaryStackElement
	constructor: (@channel, @sepcificChannel) ->
	_getChannel: -> new CCSChannel(@channel, if @specificChannel then @specificChannel.ccsTree() else null)
	_getAction: -> throw new Error("Abstract and not implemented!")
	getResult: ->
		pRes = @next.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS, new CCSPrefix(@_getAction(), pRes.data), pRes.moreResults)

class PCCInputStackElement extends PCCPrefixStackElement
	constructor: (channel, sepcificChannel, @variable) -> super channel, sepcificChannel	# string x PCCContainer x string
	_getAction: -> new CCSInput(@_getChannel(), @variable)

class PCCOutputStackElement extends PCCPrefixStackElement
	constructor: (channel, sepcificChannel, @container) -> super channel, sepcificChannel	# string x PCCContainer x PCCContainer
	_getAction: -> new CCSOutput(@_getChannel(), if @container then @container.ccsTree() else null)

class PCCConditionStackElement extends PCCUnaryStackElement
	constructor: (@conditionContainer) ->
	getResult: ->
		pRes = @next.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS, new CCSCondition(@conditionContainer.ccsTree(), pRes.data), pRes.moreResults)

class PCCRestrictionStackElement extends PCCUnaryStackElement
	constructor: (@restrictedChannels) ->
	getResult: ->
		pRes = @next.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS, new CCSRestriction(pRes.data, @restrictedChannels), pRes.moreResults)

class PCCApplicationStackElement extends PCCUnaryStackElement
	constructor: (@processName, @argContainers) ->
	getResult: ->
		more = if @next then @next.getResult() else null
		values = c.ccsTree() for c in @argContainers
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS, new CCSProcessApplication(@processName, values), more)


class PCCBinaryCCSStackElement extends PCCBinaryStackElement
	_createCCSProcess: -> throw new Error("Abstract and not implemented!")
	getResult: ->
		more = if @topStack then @topStack.getResult() else null
		left = @leftStack.getResult()
		throw new Error("Unexpected result type!") if left.type != PCCStackResult.TYPE_CCSPROCESS
		right = @rightStack.getResult()
		throw new Error("Unexpected result type!") if right.type != PCCStackResult.TYPE_CCSPROCESS
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS, @_createCCSProcess(left.data, right.data), more)

class PCCChoiceStackElement extends PCCBinaryCCSStackElement
	_createCCSProcess: (left, right) -> new CCSChoice(left, right)
	
class PCCParallelStackElement extends PCCBinaryCCSStackElement
	_createCCSProcess: (left, right) -> new CCSParallel(left, right)

class PCCSequenceStackElement extends PCCBinaryCCSStackElement
	_createCCSProcess: (left, right) -> new CCSRestriction(left, right)




class PCCProcessDefinitionStackElement extends PCCUnaryStackElement
	constructor: (@processName, @argNames) ->
	getResult: ->
		pRes = @next.getResult()
		throw new Error("Unexpected result type!") if pRes.type != PCCStackResult.TYPE_CCSPROCESS
		def = new CCSProcessDefinition(@processName, pRes.data, @argNames)
		new PCCStackResult(PCCStackResult.TYPE_CCSPROCESS_DEFINITION, def, pRes.moreResults)


class PCCProcessFrameStackElement extends PCCUnaryStackElement
	constructor: (@frame) ->
	compilerGetVariable: (compiler, identifier, instanceContainer) -> 
		result = @frame.compilerGetVariable(compiler, identifier, instanceContainer)
		if result then result else super
	compilerGetProcedure: (compiler, identifier, instanceContainer) -> 
		result = @frame.compilerGetProcedure(compiler, identifier, instanceContainer)
		if result then result else super
	compilerHandleNewIdentifierWithDefaultValueCallback: (compiler, identifier, callback, context) ->
		result = @frame.compilerHandleNewIdentifierWithDefaultValueCallback(compiler, identifier, callback, context)
		if result then result else super

class PCCClassStackElement extends PCCUnaryStackElement
	constructor: (@classInfo) ->
	compilerGetVariable: (compiler, identifier, instanceContainer) -> 
		result = @classInfo.compilerGetVariable(compiler, identifier, instanceContainer)
		if result then result else super
	compilerGetProcedure: (compiler, identifier, instanceContainer) -> 
		result = @classInfo.compilerGetProcedure(compiler, identifier, instanceContainer)
		if result then result else super
	compilerHandleNewIdentifierWithDefaultValueCallback: (compiler, identifier, callback, context) ->
		result = @classInfo.compilerHandleNewIdentifierWithDefaultValueCallback(compiler, identifier, callback, context)
		if result then result else super

class PCCGlobalStackElement extends PCCUnaryStackElement
	constructor: (@global) ->
	compilerGetVariable: (compiler, identifier, instanceContainer) -> 
		result = @global.compilerGetVariable(compiler, identifier, instanceContainer)
		if result then result else super
	compilerGetProcedure: (compiler, identifier, instanceContainer) -> 
		result = @global.compilerGetProcedure(compiler, identifier, instanceContainer)
		if result then result else super
	compilerHandleNewIdentifierWithDefaultValueCallback: (compiler, identifier, callback, context) ->
		result = @global.compilerHandleNewIdentifierWithDefaultValueCallback(compiler, identifier, callback, context)
		if result then result else super

class PCCProcedureStackElement extends PCCUnaryStackElement
	constructor: (@procedure) ->
	
	
	
	
	
	
	
	
	
	
	
	
	
	
class PCCCompilerStack
	constructor: (initialElement) -> 
		@topElement = initialElement
		@topElement.__PCCCompilerStack = @
		@topElement.getStack = -> @__PCCCompilerStack
	setTopElement: (e) -> @topElement = e

PCCStackElement::getStack = -> @parent.getStack()


class PCCStackResult
	constructor: (@type, @data, @moreResults) ->

PCCStackResult.TYPE_UNSPECIFIC = 0
PCCStackResult.TYPE_CCSPROCESS = 1
PCCStackResult.TYPE_CCSPROCESS_DEFINITION = 2











