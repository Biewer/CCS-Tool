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


class PCCCompiler
	constructor: (@program) ->
		@controller = null
		@stack = null	
		@groupElements = []	
		@controller = new PCCProgramController(@program)
		@systemProcesses = []
	
	compile: -> 
		@program.collectClasses(@controller)
		@program.collectEnvironment(@controller)
		@program.collectAgents(@controller)
		global = new PCCGlobalStackElement(@controller.getGlobal())
		@stack = new PCCCompilerStack(global)
		usedTypes = @controller.getUsedTypes()
		@compileReturn()
		@compileMutex()
		@compileWaitRoom()
		@compileArrayManager()
		@compileArrayWithCapacity(n) for n of usedTypes.arrays
		@compileChannelManager()
		@compileChannelWithCapacity(n) for n of usedTypes.channels
		@compileAgentTools()
		for p in @controller.getAgents()
			p.emitAgentConstructor(@)
			@beginSystemProcess()
			@emitProcessApplication(p.getAgentProcessName(), [])
			@endSystemProcess()
		cls.emitConstructor(@) for cls in @controller.getAllClasses()
		@program.compile(@)
		new CCS(@controller.root.collectPDefs(), @_getSystem())
		# ToDo: return CCS tree
	
	_getSystem: ->
		@beginSystemProcess()
		@emitProcessApplication("MainAgent", [])
		@endSystemProcess()
		system = @systemProcesses[0]
		for i in [1...@systemProcesses.length] by 1
			system = new CCSParallel(system, @systemProcesses[i])
		new CCSRestriction(system, ["*", "println"])
	
	###
		Delegates must implement the following methods:
		 compilerGetVariable(compiler, identifier)
		 compilerGetProcedure(compiler, identifier)
		 compilerHandleNewIdentifierWithDefaultValueCallback(compiler, identifier, callback, context)
		When these methods are called, the receiver may modify the compiler state by emitting CCS processes, pushing processes, ...
	###
	
	
	getVariableWithName: (name, className, isInternal) ->
		name = PCCVariableInfo.getNameForInternalVariableWithName(name) if isInternal
		if className
			return @controller.getClassWithName(className).compilerGetVariable(@, name)
		@stack.compilerGetVariable(@, name)
	
	getProcedureWithName: (name, className) ->
		if className
			return @controller.getClassWithName(className).compilerGetProcedure(@, name)
		@stack.compilerGetProcedure(@, name)
	
	getClassWithName: (name) -> @controller.getClassWithName name
	getCurrentClass: ->
		for e in @groupElements
			return e.classInfo if (e instanceof PCCClassStackElement)
	getCurrentProcedure: ->
		for e in @groupElements
			return e.procedure if (e instanceof PCCProcedureStackElement)
	
	getGlobal: -> @controller.getGlobal()
	
	getFreshContainer: (ccsType, wish) -> @getProcessFrame().createContainer(ccsType, wish)
	
	handleNewVariableWithDefaultValueCallback: (variable, callback, context) ->		# callback returns a container
		@stack.compilerHandleNewVariableWithDefaultValueCallback(@, variable, callback, context)
	
	
	_getControlElement: -> @stack.getCurrentControlElement()
	
	_handleStackResult: (resultContainer, controlElement) ->
		(if result.type == PCCStackResult.TYPE_CCSPROCESS_DEFINITION
			controlElement.compilerPushPDef(result.data)
		) for result in resultContainer.results
	
	beginSystemProcess: ->
		element = new PCCSystemProcessStackElement()
		@groupElements.push(element)
		@stack.pushElement(element)
	
	endSystemProcess: ->
		element = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (element instanceof PCCSystemProcessStackElement)
		res = element.removeFromStack()
		@systemProcesses.push(res.data)
	
	emitSystemProcessApplication: (processName, argumentContainers) ->
		@beginSystemProcess()
		@emitProcessApplication(processName, argumentContainers)
		@endSystemProcess()
	
	beginProcessGroup: (groupable, variables) ->
		frame = new PCCProcessFrame(groupable, variables)
		element = new PCCProcessFrameStackElement(frame)
		@groupElements.push(element)
		@stack.pushElement(element)
		frame.emitProcessDefinition(@)
		
	endProcessGroup: ->
		frame = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (frame instanceof PCCProcessFrameStackElement)
		controlElement = @_getControlElement()
		@_handleStackResult(frame.removeFromStack(), controlElement)
		
	getProcessFrame: -> @stack.getCurrentProcessFrame()
	
	addProcessGroupFrame: (nextFrame) ->
		@stack.pushElement(new PCCProcessFrameStackElement(nextFrame))
		nextFrame.emitProcessDefinition(@)
		null
	
	emitNewScope: ->
		frame = @getProcessFrame()
		scope = frame.createNewScope()
		@stack.pushElement(new PCCScopeStackElement(scope))
		scope
	
	emitNextProcessFrame: (derivationFrames) ->
		frame = @getProcessFrame()
		derivationFrames = [frame] if not derivationFrames
		next = PCCProcessFrame.createFollowupFrameForFrames(derivationFrames)
		next.emitCallProcessFromFrame(@, frame)
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
		@stack.pushElement(element)
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
		@stack.pushElement(element)
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
		@beginProcessGroup(new PCCGroupable("MainAgent"))
	
	endMainAgent: ->
		@controller.endMainAgent()
		@endProcessGroup()
	
	beginProcedure: (procedureName) ->
		@controller.beginProcedure(procedureName)
		procedure = @stack.compilerGetProcedure(@, procedureName)
		throw new Error("Tried to begin unknown procedure!") if !procedure
		frame = new PCCProcedureFrame(procedure)
		element = new PCCProcedureStackElement(procedure)
		@stack.pushElement(element)
		@groupElements.push(element)
		@addProcessGroupFrame(frame)
	
	endProcedure: ->
		@controller.endProcedure()
		proc = @groupElements.pop()
		throw new Error("Unexpected stack element!") if not (proc instanceof PCCProcedureStackElement)
		controlElement = @_getControlElement()
		@_handleStackResult(proc.removeFromStack(), controlElement)
	
	
	beginStatement: (statement) ->
	endStatement: ->
	
	beginExpression: (expression) ->
	endExpression: ->


	_usingFrames: ->
		@groupElements.length > 1 or (@groupElements.length > 0 and @groupElements[0] instanceof PCCProcessFrameStackElement)

	emitStop: -> @stack.pushElement(new PCCStopStackElement())
	emitExit: -> @stack.pushElement(new PCCExitStackElement())
	emitProcessApplication: (processName, argumentContainers=[]) -> 
		@stack.pushElement(new PCCApplicationStackElement(processName, argumentContainers))
	emitOutput: (channel, specificChannel, valueContainer) ->
		@stack.pushElement(new PCCOutputStackElement(channel, specificChannel, valueContainer))
	emitInput: (channel, specificChannel, container) ->
		@stack.pushElement(new PCCInputStackElement(channel, specificChannel, container))
	emitCondition: (condition) -> @stack.pushElement(new PCCConditionStackElement(condition))
	emitChoice: -> 
		res = new PCCChoiceStackElement()
		@stack.pushElement(res)
		@emitNewScope() if @_usingFrames() 
		res
	emitParallel: -> 
		res = new PCCParallelStackElement()
		@stack.pushElement(res)
		@emitNewScope() if @_usingFrames()
		res
	emitSequence: -> 
		#@emitNextProcessFrame()	# start new process to avoid loosing input variables in right side of sequence received on left side
		res = new PCCSequenceStackElement()
		@stack.pushElement(res)
		res
	emitRestriction: (restrictedChannelNames) -> 
		@stack.pushElement(new PCCRestrictionStackElement(restrictedChannelNames))
	
	emitProcessApplicationPlaceholder: ->
		ph = new PCCApplicationPlaceholderStackElement(@getProcessFrame())
		@stack.pushElement(ph)
		ph
	
	
	
	
	compileMutex: ->
		i = new PCCVariableContainer("i", PCCType.INT)
		@beginProcessDefinition("Mutex", [i])
		@emitInput("lock", i, null)
		@emitInput("unlock", i, null)
		@emitProcessApplication("Mutex", [i])
		@endProcessDefinition()
		
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("Mutex_cons", [i])
		@emitOutput("mutex_create", null, i)
		control = @emitParallel()
		@emitProcessApplication("Mutex_cons", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		control.setBranchFinished()
		@emitProcessApplication("Mutex", [i])
		control.setBranchFinished()
		@endProcessDefinition()
		@emitSystemProcessApplication("Mutex_cons", [new PCCConstantContainer(1)])
	
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
		@emitSystemProcessApplication("WaitRoom_cons", [new PCCConstantContainer(1)])
		
	
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
		for j in [0...size-1]
			control = @emitChoice()
			emitAccessors(@, i, size, j, args)
			control.setBranchFinished()
		emitAccessors(@, i, size, size-1, args)
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
		@emitSystemProcessApplication("Array#{size}_cons", [])
		
	compileArrayManager: ->
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("ArrayManager", [i])
		@emitOutput("array_new", null, i)
		@emitProcessApplication("ArrayManager", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		@endProcessDefinition()
		@emitSystemProcessApplication("ArrayManager", [new PCCConstantContainer(1)])
	
	
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
		@emitSystemProcessApplication("Channel#{capacity}_cons", [])
	
	compileUnbufferedChannelCons: ->
		i = new PCCVariableContainer("i", PCCType.INT)
		@beginProcessDefinition("Channel_cons", [i])
		@emitOutput("channel_create", null, i)
		@emitProcessApplication("Channel_cons", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "-")])
		@endProcessDefinition()
		@emitSystemProcessApplication("Channel_cons", [new PCCConstantContainer(-1)])
		
	

	compileChannelManager: ->
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("ChannelManager", [i])
		@emitOutput("channel_new", null, i)
		@emitProcessApplication("ChannelManager", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		@endProcessDefinition()
		@emitSystemProcessApplication("ChannelManager", [new PCCConstantContainer(1)])
			
	
	
	compileAgentTools: ->
		i = new PCCVariableContainer("next_i", PCCType.INT)
		@beginProcessDefinition("AgentManager", [i])
		@emitOutput("agent_new", null, i)
		@emitProcessApplication("AgentManager", [new PCCBinaryContainer(i, new PCCConstantContainer(1), "+")])
		@endProcessDefinition()
		@emitSystemProcessApplication("AgentManager", [new PCCConstantContainer(1)])
		
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
		
		
		
	
	
		
		
		
		
		
		
		



PCEnvironmentNode::compilerPushPDef = (pdef) ->
	@PCCCompilerPDefs = [] if !@PCCCompilerPDefs
	@PCCCompilerPDefs.push(pdef)
PCVariable::compilerPushPDef = PCEnvironmentNode::compilerPushPDef
PCEnvironmentNode::collectPDefs = ->
	@PCCCompilerPDefs = [] if !@PCCCompilerPDefs
	@PCCCompilerPDefs.concat((c.collectPDefs() for c in @children).concatChildren())
PCVariable::collectPDefs = -> if @PCCCompilerPDefs then @PCCCompilerPDefs else []






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
		variables = (@compiler.getVariableWithName(v.getName(), null, v.isInternal) for v in variables)	# local variables
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
	

