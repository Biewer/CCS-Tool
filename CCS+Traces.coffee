

CCS::getTraces = (weak, maxSteps) ->
	maxSteps = 0 if not maxSteps
	@system.getTraces(weak, maxSteps)

CCSProcess::_getTraces = (prefix, set, weak, maxSteps) ->
	return if maxSteps.i-- < 0 
	#console.log maxSteps.i
	steps = @getPossibleSteps(true)
	if steps and steps.length > 0
# 		prefix = prefix + "." if prefix.length > 0
		for s in steps
			p = s.perform()
			prefix2 = prefix
			if not weak or not s.action.isInternalAction() 
				prefix2 = prefix2 + "." if prefix2.length > 0
				prefix2 = prefix2 + s.toString()
			p._getTraces(prefix2, set, weak, maxSteps)
	else
		set[prefix] = true

CCSProcess::getTraces = (weak, maxSteps) ->
	maxSteps = 0 if not maxSteps
	set = {}
	@_getTraces("", set, weak, {"i": maxSteps})
	res = []
	for trace, b of set
		res.push(trace) if b == true
	res



CCSProcess::getFinalProcesses = ->
	steps = @getPossibleSteps(true)
	if steps and steps.length > 0
		for s in steps
			p = s.perform()
