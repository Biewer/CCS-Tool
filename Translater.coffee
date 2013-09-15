

###
class PCCClass
	constructor: (@name, @fields, @methods) ->
	
	#_getCCSName: -> if @name then "_#{@name}" else ""		# e.g. _M for monitor M or empty string for global environment
	_getCCSProcess: (fields=@fields) -> "Env_#{@name}_[#{@_getCCSArgList(fields)}]"		# e.g. Env_M[i_i, f_x, f_y] for monitor M {int x; int y;}
	_getCCSArgList: (fields) -> ((("f_#{c.name}") for c in fields).unshift("i_i")).join(", ")	# f for field; i_i for internal, instance
	_getCCSFieldAccessors: -> (("get_#{@name}_#{c.name}(i_i)!f_#{c.name}.#{@_getCCSProcess()} + set_#{@name}_#{c.name}(i_i)?t.#{@_getCCSProcess(@fields.replace(i,"t"))}") for i, c in @fields).join(" + ")	# e.g. get_M_x(i_i)!f_x.Env_M[i_i, f_x, f_y] + set_M_x(i_i)?t.Env_M[i_i, t, f_y] + ...
	getCCSString: -> "#{@_getCCSProcess()} := #{@_getCCSFieldAccessors()}"
###




### Usually we want to have one process for one "thing". But because of restrictions of CCS this is not always possible and we have to split one process into multiple processes. These are called a process group.	
class PCCProcessGroup
	constructor: (@prefix, @className, @name) ->
	toString: -> 
		comps = [@prefix]
		comps.push(@className) if @className != null
		comps.push(@name)
		comps.join("_")###


	




###
PCProgram::collectEnvironments = -> ((c.collectEnvironments()) for c in @children).concatChildren()

PCMonitor::collectEnvironments = -> [new PCCClass(@name, @collectClassFields(), @collectMethodFields())]
PCStruct::collectEnvironments = PCMonitor::collectEnvironments
PCMonitor::collectClassFields = -> ((c.collectClassFields()) for c in @children).concatChildren()
PCStruct::collectClassFields = PCMonitor::collectClassFields
PCMonitor::collectMethodFields = -> []	# ToDo
PCStruct::collectMethodFields = PCMonitor::collectMethodFields
###

# - Collecting information about a pseuco program

PCProgram::collectVarsAndProcs = (controller) -> (c.collectVarsAndProcs(controller)) for c in @children)
PCMonitor::collectVarsAndProcs = (controller) ->
	controller.beginClass(@)
	(c.collectVarsAndProcs(controller)) for c in @children)
	controller.endClass(@)
PCStruct::collectVarsAndProcs = PCMonitor::collectVarsAndProcs
PCProcedure::collectVarsAndProcs = (controller) -> controller.processProcedure(@)
PCDecl::collectVarsAndProcs = (controller) -> controller.processDecl(@)
PCConditionDecl::collectVarsAndProcs = (controller) -> controller.processConditionDecl(@)

PCDecl::collectFields = -> 
	new PCCField(@children[0], @children[i].name, @children[i].getDefaultValue()) for i in [1...@children.length] by 1
PCVariableDeclarator::getDefaultValue = -> if @children.length == 0 then null else @children[0].getValue()
PCVariableInitializer::getValue = -> if @children[0] instanceof PCExpression @children[0] else @children
	
	



Array::replace = (i, v) -> 
	res = this.concat([])
	res[i] = v
	res