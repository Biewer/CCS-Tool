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
	The central coordination class for the compile process of PseuCo to CCS.
	You start the compilation process by creating a new PCCCompiler object with the node of your PseuCo tree and call compile() on it. You'll get a CCS tree on success
###

PC = require "PseuCo"
CCS = require "CCS"

PCCFlags = 
	trackGlobalVariables: 1
	trackClassVariables: 2
	trackLocalVariables: 4
	trackVariables: 7
	trackProcedureCalls: 8
	trackAgents: 16

PCCSysAgent = 50
PCCSysEnvironment = 150
PCCSysChannel = 250
PCCSysArray = 450
PCCSysMutexCons = 550
PCCSysWaitRoom = 650
PCCSysInstanceManager = 750
PCCSysUnknownWeight = 5000


PCCVarNameForPseucoVar = (name) -> "$#{name}"
PCCVarNameForInternalVar = (name) -> name

class PCCCompiler 		# ToDo: Allow assigning a recently used program controller (for type checking)
	constructor: (@program, @controller=null, @flags=0) ->
		@stack = null	
		@groupElements = []	
		@controller = new PCCProgramController(@program) if not @controller
		@systemProcesses = {}
		@compilingNodes = []	# stack
		@useReentrantLocks = true

		@needsReturn = false
		@needsMutex = false
		@needsWaitRoom = false
		@needsArrayManager = false
		@needsChannelManager = false
		@needsAgentManager = false
		@needsAgentJoiner = false

	setNeedsReturn: -> @needsReturn = true
	setNeedsMutex: -> @needsMutex = true
	setNeedsWaitRoom: -> @needsWaitRoom = true
	setNeedsArrayManager: -> @needsArrayManager = true
	setNeedsChannelManager: -> @needsChannelManager = true
	setNeedsAgentManager: -> @needsAgentManager = true
	setNeedsAgentJoiner: -> @needsAgentJoiner = true
	
	trackGlobalVars: -> (@flags & PCCFlags.trackGlobalVariables) == PCCFlags.trackGlobalVariables
	trackClassVars: -> (@flags & PCCFlags.trackClassVariables) == PCCFlags.trackClassVariables
	trackLocalVars: -> (@flags & PCCFlags.trackLocalVariables) == PCCFlags.trackLocalVariables
	trackProcCalls: -> (@flags & PCCFlags.trackProcedureCalls) == PCCFlags.trackProcedureCalls
	trackAgents: -> (@flags & PCCFlags.trackAgents) == PCCFlags.trackAgents
	
	compileProgram: -> 
		# @program.collectClasses(@controller)
		# @program.collectEnvironment(@controller)
		@program.getType(@controller)		# Because of type checker improvements, collectEnvironments does not collect variables anymore. getType does however. getType does also collect classes and the environment.
		@program.collectAgents(@controller)
		global = new PCCGlobalStackElement(@controller.getGlobal())
		@stack = new PCCCompilerStack(global)
		usedTypes = @controller.getUsedTypes()
		# @needsChannelManager = false
		((@setNeedsChannelManager() ; break) if c > 0 and v == true) for c,v of usedTypes.channels
		((@setNeedsArrayManager() ; break) if c > 0 and v == true) for c,v of usedTypes.arrays
		@program.compile(@)
		@__assertEmptyGroupStack()
		@compileReturn() if @needsReturn
		@__assertEmptyGroupStack()
		if @needsMutex
			if @useReentrantLocks
				@compileReentrantMutex()
			else
				@compileSimpleMutex()
		@__assertEmptyGroupStack()
		@compileWaitRoom() if @needsWaitRoom
		@__assertEmptyGroupStack()
		@compileArrayManager() if @needsArrayManager
		@__assertEmptyGroupStack()
		@compileArrayWithCapacity(n) for n of usedTypes.arrays
		@__assertEmptyGroupStack()
		@compileChannelManager() if @needsChannelManager
		@__assertEmptyGroupStack()
		@compileChannelWithCapacity(n) for n of usedTypes.channels
		@__assertEmptyGroupStack()
		@compileAgentTools(@needsAgentJoiner) if @needsAgentManager
		@__assertEmptyGroupStack()
		for p in @controller.getAgents()
			p.emitAgentConstructor(@, @needsAgentJoiner)
			@beginSystemProcess(PCCSysAgent)
			@emitProcessApplication(p.getAgentProcessName(), [])
			@endSystemProcess()
		@__assertEmptyGroupStack()
		cls.emitConstructor(@) for cls in @controller.getAllClasses()
		@__assertEmptyGroupStack()
		pdefs = @controller.root.collectPDefs()
		sysDefs = []
		procDefs = []
		mainAgentDefs = []
		for def in pdefs
			if def.compilerFlags?["isProcedure"] == true
				procDefs.push(def)
			else if def.name.substr(0,9) == "MainAgent"
				mainAgentDefs.push(def)
			else
				sysDefs.push(def)
		procDefs[0].insertLinesBefore = 1 if procDefs.length > 0 and sysDefs.length > 0
		mainAgentDefs[0].insertLinesBefore = 1 if mainAgentDefs.length > 0 and (procDefs.length > 0 or sysDefs.length > 0)
		new CCS.CCS(sysDefs.concat(procDefs).concat(mainAgentDefs), @_getSystem())
	
	__assertEmptyGroupStack: -> 
		if @groupElements.length > 0 
			throw new Error("Assertion violation: @groupElements must be empty!")
		null
	
	compile: (node, args...) ->
		@compilingNodes.push(node)
		res = node.compile(@, args...)
		@compilingNodes.pop()
		res
	
	pushStackElement: (element) ->
		element.pseucoNode = @compilingNodes[@compilingNodes.length-1]
		@stack.pushElement(element)
		
	
	_getSystem: ->
		@beginSystemProcess(PCCSysAgent)
		@emitProcessApplication("MainAgent", [new PCCConstantContainer(1)])
		@endSystemProcess()
		weights = []
		for w of @systemProcesses
			i = parseInt w
			weights.push i if not isNaN i
		weights.sort((a,b) -> a-b)
		system = null
		for w in weights
			mainProcesses = @systemProcesses[w]
			for i in [0...mainProcesses.length] by 1
				if system
					system = new CCS.Parallel(system, mainProcesses[i])
				else
					system = mainProcesses[i]
		new CCS.Restriction(system, @_getRestrictedChannels())
	
	_getRestrictedChannels: -> 
		res = ["*", "println", "exception"]
		res.push("sys_var") if @trackGlobalVars() or @trackClassVars() or @trackLocalVars()
		if @trackProcCalls()
			res.push("sys_call") 
			res.push("sys_return") 
		if @trackAgents()
			res.push("sys_start")
			res.push("sys_terminate")
		res
	
	didChangeVariable: (variable, container) ->
		
		
	
	###
		Delegates must implement the following methods:
		 compilerGetVariable(compiler, identifier)
		 compilerGetProcedure(compiler, identifier)
		 compilerHandleNewIdentifierWithDefaultValueCallback(compiler, identifier, callback, context)
		When these methods are called, the receiver may modify the compiler state by emitting CCS processes, pushing processes, ...

		Note - Mar 19, 2015: compilerGetProcedure is not necessary anymore and gets not called anymore, because procedure objects are independent from the compile process. For variables, these calls are still important, because they are managed by process frames, so their internal state may change during compilation.
	###
	
	getVariableWithName: (name) -> @getVariableWithNameOfClass(name, null, false)
	
	getVariableWithNameOfClass: (name, className, isInternal) ->
		name = PCCVariableInfo.getNameForInternalVariableWithName(name) if isInternal
		if className
			return @controller.getClassWithName(className).compilerGetVariable(@, name)
		@stack.compilerGetVariable(@, name)
	
	getProcedureWithName: (name) -> @getProcedureWithNameOfClass(name, null, false)
	
	getProcedureWithNameOfClass: (name, className) ->
		if className
			# return @controller.getClassWithName(className).compilerGetProcedure(@, name)
			return @controller.getClassWithName(className).getProcedureWithName(name)
		# @stack.compilerGetProcedure(@, name)
		@controller.getProcedureWithName(name)
	
	getClassWithName: (name) -> @controller.getClassWithName name
	getCurrentClass: ->
		for e in @groupElements
			return e.classInfo if (e instanceof PCCClassStackElement)
	getCurrentProcedure: ->
		for e in @groupElements
			return e.procedure if (e instanceof PCCProcedureStackElement)
	
	getGlobal: -> @controller.getGlobal()
	
	getFreshContainer: (ccsType, wish) -> 
		res = @getProcessFrame().createContainer(ccsType, wish)
		res.pseucoNode = @compilingNodes[@compilingNodes.length-1] if @compilingNodes.length > 0
		res.pseucoNode.addCalculusComponent(res.pseucoNode) if res.pseucoNode
		res
	
	handleNewVariableWithDefaultValueCallback: (variable, callback, context) ->		# callback returns a container
		@stack.compilerHandleNewVariableWithDefaultValueCallback(@, variable, callback, context)
	
	
	_getControlElement: -> @stack.getCurrentControlElement()
	
	_handleStackResult: (resultContainer, controlElement) ->
		(if result.type == PCCStackResult.TYPE_CCSPROCESS_DEFINITION
			controlElement.compilerPushPDef(result.data)
		) for result in resultContainer.results
	
	beginSystemProcess: (weight) ->
		weight = PCCSysUnknownWeight if not weight
		element = new PCCSystemProcessStackElement(weight)
		@groupElements.push(element)
		@pushStackElement(element)
	
	endSystemProcess: ->
		element = @groupElements.pop()
		weight = element.weight
		throw new Error("Unexpected stack element!") if not (element instanceof PCCSystemProcessStackElement)
		res = element.removeFromStack()
		@systemProcesses[weight] = [] if not @systemProcesses[weight]
		@systemProcesses[weight].push(res.data)
	
	emitSystemProcessApplication: (processName, argumentContainers, weight) ->
		@beginSystemProcess(weight)
		@emitProcessApplication(processName, argumentContainers)
		@endSystemProcess()
	
	beginProcessGroup: (groupable, variables) ->
		frame = new PCCProcessFrame(groupable, variables)
		element = new PCCProcessFrameStackElement(frame)
		@groupElements.push(element)
		@pushStackElement(element)
		frame.emitProcessDefinition(@)
		
	endProcessGroup: ->
		frame = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (frame instanceof PCCProcessFrameStackElement)
		controlElement = @_getControlElement()
		@_handleStackResult(frame.removeFromStack(), controlElement)
		
	getProcessFrame: -> @stack.getCurrentProcessFrame()
	
	addProcessGroupFrame: (nextFrame) ->
		@pushStackElement(new PCCProcessFrameStackElement(nextFrame))
		nextFrame.emitProcessDefinition(@)
		null
	
	emitNewScope: (derivationFrame) ->
		frame = @getProcessFrame()
		derivationFrame = frame if not derivationFrame
		scope = derivationFrame.createScope()
		scope.emitTransitionFromFrame(@, frame)
		@addProcessGroupFrame scope
		scope
	
	emitNextProcessFrame: (derivationFrames) ->
		frame = @getProcessFrame()
		derivationFrames = [frame] if not derivationFrames
		next = PCCProcessFrame.createFollowupFrameForFrames(derivationFrames)
		next.emitTransitionFromFrame(@, frame)
		@addProcessGroupFrame(next)
		next
	
	emitMergeOfProcessFramesOfPlaceholders: (placeholders) ->
		return null if placeholders.length == 0
		frames = (p.frame for p in placeholders)
		followup = PCCProcessFrame.createFollowupFrameForFrames(frames)
		followup.emitCallProcessFromFrame(@, p.frame, p) for p in placeholders
		@addProcessGroupFrame(followup)
		followup
	
	protectContainer: (container) ->
		@getProcessFrame().protectContainer(container)
	
	unprotectContainer: ->
		@getProcessFrame().unprotectContainer()
	
	getProtectedContainer: ->
		@getProcessFrame().getProtectedContainer()
		
	
	
	_silentlyAddProcessDefinition: (processName, argumentContainers) ->
		element = new PCCProcessDefinitionStackElement(processName, argumentContainers)
		@pushStackElement(element)
		element
		
	beginProcessDefinition: (processName, argumentContainers) ->
		element = @_silentlyAddProcessDefinition(processName, argumentContainers)
		@groupElements.push(element)
	
	isCurrentProcessCompleted: ->
		@stack.isCurrentProcessCompleted()
	
	endProcessDefinition: ->
		def = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (def instanceof PCCProcessDefinitionStackElement)
		controlElement = @_getControlElement()
		@_handleStackResult(def.removeFromStack(), controlElement)


	
	beginClass: (className) ->
		@controller.beginClass(className)
		curClass = @controller.getClassWithName(className)
		throw new Error("Tried to begin unknown class!") if not curClass
		element = new PCCClassStackElement(curClass)
		@pushStackElement(element)
		@groupElements.push(element)
		
	endClass: ->
		@controller.endClass()
		cls = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (cls instanceof PCCClassStackElement)
		cls.removeFromStack()
		# ToDo: Ich bin zu müde um zu entscheiden ob ich was handeln oder werfen muss?
	
	
	beginProgram: ->
		###
		throw new Error("Stack already existed before beginning of program!") if @stack != null
		global = new PCCGlobalStackElement(@controller.getGlobal())
		@stack = new PCCCompilerStack(global)
		@groupElements.push(global)
		###
	
	endProgram: ->
	###
		global = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (global instanceof PCCGlobalStackElement)
		global.removeFromStack()
		@stack = null
		###
	
	
	beginMainAgent: ->
		@controller.beginMainAgent()
		@beginProcessGroup(new PCCGroupable("MainAgent"), [new PCCVariableInfo(null, "a", null, true)])
	
	endMainAgent: ->
		@controller.endMainAgent()
		@endProcessGroup()
	
	beginProcedure: (procedureName) ->
		@controller.beginProcedure(procedureName)
		procedure = @getProcedureWithName(procedureName)
		throw new Error("Tried to begin unknown procedure!") if !procedure
		frame = new PCCProcedureFrame(procedure)
		element = new PCCProcedureStackElement(procedure)
		@pushStackElement(element)
		@groupElements.push(element)
		@addProcessGroupFrame(frame)
	
	endProcedure: ->
		@controller.endProcedure()
		proc = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (proc instanceof PCCProcedureStackElement)
		controlElement = @_getControlElement()
		@_handleStackResult(proc.removeFromStack(), controlElement)

	reopenEnvironment: (node) ->
		@controller.reopenEnvironment(node)

	closeEnvironment: -> @controller.closeEnvironment()
	
	
	beginStatement: (statement) ->
	endStatement: ->
	
	beginExpression: (expression) ->
	endExpression: ->


	_usingFrames: -> if @getProcessFrame() then true else false
		#@groupElements.length > 1 or (@groupElements.length > 0 and @groupElements[0] instanceof PCCProcessFrameStackElement)

	emitStop: -> @pushStackElement(new PCCStopStackElement())
	emitExit: -> @pushStackElement(new PCCExitStackElement())
	emitProcessApplication: (processName, argumentContainers=[]) -> 
		@pushStackElement(new PCCApplicationStackElement(processName, argumentContainers))
	emitSimplePrefix: (channel, specificChannel) ->
		@pushStackElement(new PCCPrefixStackElement(channel, specificChannel))
	emitOutput: (channel, specificChannel, valueContainer) ->
		@pushStackElement(new PCCOutputStackElement(channel, specificChannel, valueContainer))
	emitInput: (channel, specificChannel, container) ->
		@pushStackElement(new PCCInputStackElement(channel, specificChannel, container))
	emitMatch: (channel, specificChannel, valueContainer) ->
		@pushStackElement(new PCCMatchStackElement(channel, specificChannel, valueContainer))
	emitCondition: (condition) -> @pushStackElement(new PCCConditionStackElement(condition))
	emitChoice: -> 
		res = new PCCChoiceStackElement()
		@pushStackElement(res)
		@emitNewScope() if @_usingFrames() 
		res
	emitParallel: -> 
		res = new PCCParallelStackElement()
		@pushStackElement(res)
		@emitNewScope() if @_usingFrames()
		res
	emitSequence: -> 
		#@emitNextProcessFrame()	# start new process to avoid loosing input variables in right side of sequence received on left side
		res = new PCCSequenceStackElement()
		@pushStackElement(res)
		res
	emitRestriction: (restrictedChannelNames) -> 
		@pushStackElement(new PCCRestrictionStackElement(restrictedChannelNames))
	
	emitProcessApplicationPlaceholder: ->
		ph = new PCCApplicationPlaceholderStackElement(@getProcessFrame())
		@pushStackElement(ph)
		ph
	
	
	
	
	compileSimpleMutex: ->
		i = new PCCVariableContainer("i", PCCType.INT)
		@beginProcessDefinition("Mutex", [i])
		@emitInput("lock", i, null)
		@emitInput("unlock", i, null)
		@emitProcessApplication("Mutex", [i])
		@endProcessDefinition()
		@compileMutexCons(false)
	
	compileReentrantMutex: ->
		i = new PCCVariableContainer("i", PCCType.INT)
		c = new PCCVariableContainer("c", PCCType.INT)
		a = new PCCVariableContainer("a", PCCType.INT)
		a2 = new PCCVariableContainer("a2", PCCType.INT)
		@beginProcessDefinition("Mutex", [i,c,a])
		control = @emitChoice()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), "=="))
		@emitInput("lock", i, a)
		@emitProcessApplication("Mutex", [i, new PCCConstantContainer(1), a])
		control.setBranchFinished()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), ">"))
		control = @emitChoice()
		@emitMatch("lock", i, a)
		@emitProcessApplication("Mutex", [i, new PCCBinaryContainer(c, new PCCConstantContainer(1), "+"), a])
		control.setBranchFinished()

		control = @emitChoice()
		r = new PCCVariableContainer("r", PCCType.INT)
		@emitInput("multilock", i, r)
		@emitProcessApplication("Mutex", [i, new PCCBinaryContainer(c, r, "+"), a])	# add r reentrances to current counter c
		control.setBranchFinished()
		control = @emitChoice()
		@emitOutput("fullunlock", i, c)
		@emitProcessApplication("Mutex", [i, new PCCConstantContainer(0), a])
		control.setBranchFinished()


		@emitInput("unlock", i, a2)
		control = @emitChoice()
		@emitCondition(new PCCBinaryContainer(a, a2, "=="))
		@emitProcessApplication("Mutex", [i, new PCCBinaryContainer(c, new PCCConstantContainer(1), "-"), a])
		control.setBranchFinished()
		@emitCondition(new PCCBinaryContainer(a, a2, "!="))
		@throwException("Exception: Agent tried to unlock a mutex he did not lock!")
		@endProcessDefinition()
		@compileMutexCons()
		
	compileMutexCons: (reentrantMutex=true) ->
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("Mutex_cons", [i])
		@emitOutput("mutex_create", null, i)
		control = @emitParallel()
		@emitProcessApplication("Mutex_cons", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		control.setBranchFinished()
		if reentrantMutex
			@emitProcessApplication("Mutex", [i, new PCCConstantContainer(0), new PCCConstantContainer(0)])
		else
			@emitProcessApplication("Mutex", [i])
		control.setBranchFinished()
		@endProcessDefinition()
		@emitSystemProcessApplication("Mutex_cons", [new PCCConstantContainer(1)], PCCSysMutexCons)
	
	compileWaitRoom: ->
		i = new PCCVariableContainer("i", PCCType.INT)
		c = new PCCVariableContainer("c", PCCType.INT)
		@beginProcessDefinition("WaitRoom", [i, c])
		control1 = @emitChoice()
		@emitInput("signal", i, null)
		inner = @emitChoice()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), "=="))
		@emitProcessApplication("WaitRoom", [i, c])
		inner.setBranchFinished()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), ">"))
		@emitInput("wait", i, null)
		@emitProcessApplication("WaitRoom", [i, new PCCBinaryContainer(c, new PCCConstantContainer(1), "-")])
		inner.setBranchFinished()
		control1.setBranchFinished()
		control2 = @emitChoice()
		@emitInput("add", i, null)
		@emitProcessApplication("WaitRoom", [i, new PCCBinaryContainer(c, new PCCConstantContainer(1), "+")])
		control2.setBranchFinished()
		control3 = @emitSequence()
		@emitInput("signal_all", i, null)
		@emitProcessApplication("WaitDistributor", [i, c])
		control3.setBranchFinished()
		@emitProcessApplication("WaitRoom", [i, new PCCConstantContainer(0)])
		control3.setBranchFinished()
		control2.setBranchFinished()
		control1.setBranchFinished()
		@endProcessDefinition()
		
		i = new PCCVariableContainer("i", PCCType.INT)
		c = new PCCVariableContainer("c", PCCType.INT)
		@beginProcessDefinition("WaitDistributor", [i, c])
		control = @emitChoice()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), "<="))
		@emitExit()
		control.setBranchFinished()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), ">"))
		@emitInput("wait", i, null)
		@emitProcessApplication("WaitDistributor", [i, new PCCBinaryContainer(c, new PCCConstantContainer(1), "-")])
		control.setBranchFinished()
		@endProcessDefinition()
		
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("WaitRoom_cons", [i])
		@emitOutput("wait_create", null, i)
		control = @emitParallel()
		@emitProcessApplication("WaitRoom_cons", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		control.setBranchFinished()
		@emitProcessApplication("WaitRoom", [i, new PCCConstantContainer(0)])
		control.setBranchFinished()
		@endProcessDefinition()
		@emitSystemProcessApplication("WaitRoom_cons", [new PCCConstantContainer(1)], PCCSysWaitRoom)
		
	throwException: (comps...) ->
		containerFromComp = (comp) ->
			if comp instanceof PCCContainer then comp else new PCCConstantContainer(comp)
		
		container = null
		if comps.length == 0
			container = new PCCConstantContainer("Exception")
		else
			container = containerFromComp(comps.shift())
		
		while comps.length > 0
			container = new PCCBinaryContainer(container, containerFromComp(comps.shift()), "^")
		@emitOutput("exception", null, container)
		@emitStop()
		null
			
	
	compileArrayWithCapacity: (size) ->
		i = new PCCVariableContainer("i", PCCType.INT)
		args = [i]
		args.push(new PCCVariableContainer("v#{j}", PCCType.INT)) for j in [0...size]
		@beginProcessDefinition("Array#{size}", args)
		index = new PCCVariableContainer("index", PCCType.INT)
		@emitInput("array_access", i, index)
		emitAccessors = (compiler, i, size, j, args) ->
			compiler.emitCondition(new PCCBinaryContainer(index, new PCCConstantContainer(j), "=="))
			inner = compiler.emitChoice()
			compiler.emitOutput("array_get", i, args[j+1])
			compiler.emitProcessApplication("Array#{size}", args)
			inner.setBranchFinished()
			compiler.emitInput("array_set", i, args[j+1])
			compiler.emitProcessApplication("Array#{size}", args)
			inner.setBranchFinished()
		for j in [0...size]
			control = @emitChoice()
			emitAccessors(@, i, size, j, args)
			control.setBranchFinished()
		#emitAccessors(@, i, size, size-1, args)
		@emitCondition(new PCCBinaryContainer(new PCCBinaryContainer(index, new PCCConstantContainer(size), ">="), new PCCBinaryContainer(index, new PCCConstantContainer(0), "<"), "||"))  # index >= size || index < 0
		@throwException("Index ", index, " is out of array bounds ([0..#{size-1}])!")
		@endProcessDefinition()
		
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("Array#{size}_cons", [])
		@emitInput("array_new", null, i)
		def = new PCCVariableContainer("d", PCCType.VOID)
		@emitOutput("array#{size}_create", null, i)
		@emitInput("array_setDefault", i, def)
		control = @emitParallel()
		@emitProcessApplication("Array#{size}_cons", [])
		control.setBranchFinished()
		args = [i]
		args.push(def) for j in [0...size]
		@emitProcessApplication("Array#{size}", args)
		control.setBranchFinished()
		@endProcessDefinition()
		@emitSystemProcessApplication("Array#{size}_cons", [], PCCSysArray)
		
	compileArrayManager: ->
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("ArrayManager", [i])
		@emitOutput("array_new", null, i)
		@emitProcessApplication("ArrayManager", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		@endProcessDefinition()
		@emitSystemProcessApplication("ArrayManager", [new PCCConstantContainer(1)], PCCSysInstanceManager)
	
	
	compileChannelWithCapacity: (capacity) ->
		return @compileUnbufferedChannelCons() if capacity <= 0
		i = new PCCVariableContainer("i", PCCType.INT)
		c = new PCCVariableContainer("c", PCCType.INT)
		args = [i, c]
		args.push(new PCCVariableContainer("v#{j}", PCCType.INT)) for j in [0...capacity]
		@beginProcessDefinition("Channel#{capacity}", args)
		args[1] = new PCCBinaryContainer(c, new PCCConstantContainer(1), "+")
		for j in [0...capacity]
			control = @emitChoice()
			@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(j), "=="))
			v = new PCCVariableContainer("v#{j}", PCCType.INT)
			@emitInput("put", i, v)
			@emitProcessApplication("Channel#{capacity}", args)
			control.setBranchFinished()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), ">"))
		@emitOutput("receive", i, new PCCVariableContainer("v0", PCCType.INT))
		args.splice(2, 1)
		args.push(new PCCConstantContainer(0))
		args[1] = new PCCBinaryContainer(c, new PCCConstantContainer(1), "-")
		@emitProcessApplication("Channel#{capacity}", args)
		@endProcessDefinition()
		
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("Channel#{capacity}_cons", [])
		@emitInput("channel_new", null, i)
		#def = new PCCVariableContainer("d", PCCType.VOID)
		@emitOutput("channel#{capacity}_create", null, i)
		#@emitInput("channel_setDefault", i, def)
		control = @emitParallel()
		@emitProcessApplication("Channel#{capacity}_cons", [])
		control.setBranchFinished()
		args = [i, new PCCConstantContainer(0)]
		def = new PCCConstantContainer(0)
		args.push(def) for j in [0...capacity]
		@emitProcessApplication("Channel#{capacity}", args)
		control.setBranchFinished()
		@endProcessDefinition()
		@emitSystemProcessApplication("Channel#{capacity}_cons", [], PCCSysChannel)
	
	compileUnbufferedChannelCons: ->
		i = new PCCVariableContainer("i", PCCType.INT)
		@beginProcessDefinition("Channel_cons", [i])
		@emitOutput("channel_create", null, i)
		@emitProcessApplication("Channel_cons", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "-")])
		@endProcessDefinition()
		@emitSystemProcessApplication("Channel_cons", [new PCCConstantContainer(-1)], PCCSysChannel)
		
	

	compileChannelManager: ->
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("ChannelManager", [i])
		@emitOutput("channel_new", null, i)
		@emitProcessApplication("ChannelManager", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		@endProcessDefinition()
		@emitSystemProcessApplication("ChannelManager", [new PCCConstantContainer(1)], PCCSysInstanceManager)
			
	
	
	compileAgentTools: (addAgentJoiner=true) ->
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("AgentManager", [i])
		@emitOutput("agent_new", null, i)
		@emitProcessApplication("AgentManager", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		@endProcessDefinition()
		@emitSystemProcessApplication("AgentManager", [new PCCConstantContainer(2)], PCCSysInstanceManager)
		
		return if not addAgentJoiner

		a = new PCCVariableContainer("a", PCCType.INT)
		c = new PCCVariableContainer("c", PCCType.INT)
		@beginProcessDefinition("AgentJoiner", [a, c])
		control = @emitChoice()
		@emitInput("join_register", a, null)
		@emitProcessApplication("AgentJoiner", [a, new PCCBinaryContainer(c, new PCCConstantContainer(1), "+")])
		control.setBranchFinished()
		@emitInput("agent_terminate", a, null)
		@emitProcessApplication("JoinDistributor", [a, c])
		control.setBranchFinished()
		@endProcessDefinition()
		
		a = new PCCVariableContainer("a", PCCType.INT)
		c = new PCCVariableContainer("c", PCCType.INT)
		@beginProcessDefinition("JoinDistributor", [a, c])
		control = @emitChoice()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), "<="))
		@emitInput("join_register", a, null)
		@emitInput("join", a, null)
		@emitProcessApplication("JoinDistributor", [a, new PCCConstantContainer(0)])
		control.setBranchFinished()
		@emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), ">"))
		@emitInput("join", a, null)
		@emitProcessApplication("JoinDistributor", [a, new PCCBinaryContainer(c, new PCCConstantContainer(1), "-")])
		control.setBranchFinished()
		@endProcessDefinition()
	
	
	compileReturn: ->
		@beginProcessDefinition("Return", [])
		v = new PCCVariableContainer("v", PCCType.INT)
		@emitInput("return", null, v)
		@emitOutput("rreturn", null, v)
		@emitProcessApplication("Return", [])
		@endProcessDefinition()
		@emitSystemProcessApplication("Return", [])
		
		
		
	
	
		
		
		
		
		
		
		



PC.EnvironmentNode::compilerPushPDef = (pdef) ->
	@PCCCompilerPDefs = [] if !@PCCCompilerPDefs
	@PCCCompilerPDefs.push(pdef)
PC.Variable::compilerPushPDef = PC.EnvironmentNode::compilerPushPDef
PC.EnvironmentNode::collectPDefs = ->
	@PCCCompilerPDefs = [] if !@PCCCompilerPDefs
	@PCCCompilerPDefs.concat(SBArrayConcatChildren(c.collectPDefs() for c in @children))
PC.Variable::collectPDefs = -> if @PCCCompilerPDefs then @PCCCompilerPDefs else []


PC.Node::addCalculusComponent = (component) ->
	@calculusComponents = [] if not @calculusComponents
	@calculusComponents.push(component)
PC.Node::getCalculusComponents = ->
	@calculusComponents = [] if not @calculusComponents
	@calculusComponents




###
PCStmtExpression::collectAgents = (env) -> 
	@children[0].collectAgents(env)
PCVariableDeclarator::collectEnvironment = (env, type) ->
	@children.length > 0 and @children[0].collectEnvironment(env)
PCVariableInitializer::collectEnvironment = (env) ->
	!@isArray() and @children[0].collectEnvironment(env)
PCExpression::collectEnvironment = (env) -> c.collectEnvironment(env) for c in @children
PCStartExpression::collectEnvironment = (env) ->
	env instanceof PCCProgramController and env.processProcedureAsAgent(@children[0].getProcedure(env))
	###
	



class PCCConstructor
	constructor: (@compiler, @delegate, @context) ->
	emit: ->
		envName = @delegate.constructorGetName(@, @context)
		variables = @delegate.constructorGetArguments(@, @compiler, @context)
		@compiler.beginProcessGroup(new PCCGroupable(envName+"_cons"), variables)
		entry = @compiler.getProcessFrame()
		variables = (@compiler.getVariableWithNameOfClass(v.getName(), null, v.isInternal) for v in variables)	# local variables
		envArgCount = @delegate.constructorProtectEnvironmentArguments(@, @compiler, variables, @context)
		vars = []
		vars.unshift(@compiler.unprotectContainer()) for i in [0...envArgCount]
		recursion = @delegate.constructorShouldCallRecursively?(@, @context)
		control = null
		control = @compiler.emitParallel() if recursion
		@compiler.emitProcessApplication(envName, vars)
		if recursion
			control.setBranchFinished()
			@delegate.constructorUpdateVariablesForRecursiveCall(@, @compiler, entry, variables, @context)
			entry.emitCallProcessFromFrame(@compiler, @compiler.getProcessFrame())
			control.setBranchFinished()
		@compiler.endProcessGroup()
PCCConstructor.emitConstructor = (compiler, delegate, context) -> (new PCCConstructor(compiler, delegate, context)).emit()









SBArrayConcatChildren = (array) ->
	return [] if array.length == 0
	target = array[..]
	result = target.shift()[..]	# Result should always be a copy
	while target.length > 0
		result = result.concat(target.shift())
	result
	

