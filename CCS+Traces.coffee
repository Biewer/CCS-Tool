

CCS::getTraces = (weak) ->
	@system.getTraces(weak)

CCSProcess::_getTraces = (prefix, set, weak) -> 
	steps = @getPossibleSteps(true)
	if steps and steps.length > 0
# 		prefix = prefix + "." if prefix.length > 0
		for s in steps
			p = s.perform()
			prefix2 = prefix
			if not weak or not s.action.isInternalAction() 
				prefix2 = prefix2 + "." if prefix2.length > 0
				prefix2 = prefix2 + s.action.toString(true)
			p._getTraces(prefix2, set, weak)
	else
		set[prefix] = true

CCSProcess::getTraces = (weak) ->
	set = {}
	@_getTraces("", set, weak)
	res = []
	for trace, b of set
		res.push(trace) if b == true
	res

