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


programs = 
	"1":
		code:
			"""
			a.b.c.d.0
			"""
		traces:
			["a.b.c.d"]
	"2":
		code:
			"""
			a!.b!.0 + b!.a!.0 | a?.b?.0 + b?.a?.0
			"""
		traces:
			["a!.b!.a?.b?", "a!.b!.b?.a?", "b!.a!.a?.b?", "b!.a!.b?.a?", 
			"a?.b?.a!.b!", "a?.b?.b!.a!", "b?.a?.a!.b!", "b?.a?.b!.a!",
			"a!.a?.b!.b?", "a!.a?.b?.b!", "a!.b?.b!.a?", "a!.b?.a?.b!",
			"b!.a?.a!.b?", "b!.a?.b?.a!", "b!.b?.a!.a?", "b!.b?.a?.a!",
			"a?.a!.b?.b!", "a?.a!.b!.b?", "a?.b!.b?.a!", "a?.b!.a!.b?",
			"b?.a!.a?.b!", "b?.a!.b!.a?", "b?.b!.a?.a!", "b?.b!.a!.a?",
			"\u03c4.\u03c4",
			"\u03c4.b!.b?", "\u03c4.b?.b!", "\u03c4.a!.a?", "\u03c4.a?.a!",
			"a!.\u03c4.a?", "a?.\u03c4.a!", "b!.\u03c4.b?", "b?.\u03c4.b!",
			"b!.b?.\u03c4", "b?.b!.\u03c4", "a!.a?.\u03c4", "a?.a!.\u03c4"]
	"3":
		code:
			"""
			a!.b!.1 + b!.a!.1 | a?.b?.1 + b?.a?.1 ; end!. 0
			"""
		traces:
			["a!.b!.a?.b?.\u03c4.end!", "a!.b!.b?.a?.\u03c4.end!", "b!.a!.a?.b?.\u03c4.end!", "b!.a!.b?.a?.\u03c4.end!", 
			"a?.b?.a!.b!.\u03c4.end!", "a?.b?.b!.a!.\u03c4.end!", "b?.a?.a!.b!.\u03c4.end!", "b?.a?.b!.a!.\u03c4.end!",
			"a!.a?.b!.b?.\u03c4.end!", "a!.a?.b?.b!.\u03c4.end!", "a!.b?.b!.a?.\u03c4.end!", "a!.b?.a?.b!.\u03c4.end!",
			"b!.a?.a!.b?.\u03c4.end!", "b!.a?.b?.a!.\u03c4.end!", "b!.b?.a!.a?.\u03c4.end!", "b!.b?.a?.a!.\u03c4.end!",
			"a?.a!.b?.b!.\u03c4.end!", "a?.a!.b!.b?.\u03c4.end!", "a?.b!.b?.a!.\u03c4.end!", "a?.b!.a!.b?.\u03c4.end!",
			"b?.a!.a?.b!.\u03c4.end!", "b?.a!.b!.a?.\u03c4.end!", "b?.b!.a?.a!.\u03c4.end!", "b?.b!.a!.a?.\u03c4.end!",
			"\u03c4.\u03c4.\u03c4.end!",
			"\u03c4.b!.b?.\u03c4.end!", "\u03c4.b?.b!.\u03c4.end!", "\u03c4.a!.a?.\u03c4.end!", "\u03c4.a?.a!.\u03c4.end!",
			"a!.\u03c4.a?.\u03c4.end!", "a?.\u03c4.a!.\u03c4.end!", "b!.\u03c4.b?.\u03c4.end!", "b?.\u03c4.b!.\u03c4.end!",
			"b!.b?.\u03c4.\u03c4.end!", "b?.b!.\u03c4.\u03c4.end!", "a!.a?.\u03c4.\u03c4.end!", "a?.a!.\u03c4.\u03c4.end!"]
	"4":
		code:
			"""
			a!.b!.1 + b!.a!.1 | a?.b?.1 + b?.a?.1 ; end!. 0 \\ {a, b}
			"""
		traces:
			["\u03c4.\u03c4.\u03c4.end!"]
	"5":
		code:
			"""
			X[a,b] := a.b.X2[b,a]
			X2[a,b] := a.b.0
			X[c,d]
			"""
		traces:
			["c.d.d.c"]
	"6":
		code:
			"""
			X[x] := when (x<3)a.b.X[x+1]
			X[1]
			"""
		traces:
			["a.b.a.b"]
	"7":
		code:
			"""
			Match := strike?. MatchOnFire[off]
			MatchOnFire[ex] := light!. MatchOnFire[ex] + ex.0
			TwoFireCracker := light?. (bang!. 0 | bang!. 0)
			
			(Match | TwoFireCracker) \\ {light}
			"""
		traces:
			["strike?.off", "strike?.\u03c4.off.bang!.bang!", "strike?.\u03c4.bang!.off.bang!", "strike?.\u03c4.bang!.bang!.off"]
	"8":
		code:
			"""
			Counter[c] := when (c>0) rd?x. wr!(x+1+x). Counter[c-1] + when (c==0) done!. 0
			(rd!5.rd!4.rd!3.0 | Counter[4]) \\ {rd}
			"""
		traces:
			["\u03c4.wr!11.\u03c4.wr!9.\u03c4.wr!7"]
	

CCS = require("CCS")

compareTraces = (trace1, trace2) ->
	trace1.sort()
	trace2.sort()
	i1 = 0
	i2 = 0
	missing = []
	additional = []
	len = if trace1.length > trace2.length then trace1.length else trace2.length
	while true
		if i1 >= trace1.length
			if i2 >= trace2.length
				break
			else
				additional.push(trace2[i2++])
				continue
		else if i2 >= trace2.length
			missing.push(trace1[i1++])
			continue
			
		t1 = trace1[i1]
		t2 = trace2[i2]
		if t1 < t2
			missing.push(t1)
			++i1
		else if t1 > t2
			additional.push(t2)
			++i2
		else
			++i1
			++i2
	
	errorText = ""
	if missing.length > 0
		errorText += "Missing traces: \n#{missing.join("\n")}\n\n"
	if additional.length > 0
		errorText += "Additional traces: \n#{additional.join("\n")}\n\n"
	if errorText != ""
		throw new Error(errorText)
		
	true
	
	

describe "CCS parser", ->
	
	testProgram = (i) ->				 # "it" must be wrapped in a function
		it "should parse \"#{i}\"", ->
			tree = null
			try
				tree = CCS.parser.parse(programs[i].code)
			catch e
				e2 = new Error("Line #{e.line}, column #{e.column}: #{e.message}")
				e2.name = e.name
				throw e2
			expect(tree instanceof CCS.CCS).toBe(true)
			
			str = tree.toString()
			try
				tree = CCS.parser.parse(str)
			catch e
				e2 = new Error("Line #{e.line}, column #{e.column}: #{e.message}")
				e2.name = e.name
				throw e2
			expect(tree instanceof CCS.CCS).toBe(true)
			expect(tree.toString() == str)
	
	testTraces = (i) ->
		return if not programs[i].traces
		it "should match traces of program \"#{i}\":\n", ->
			tree = CCS.parser.parse(programs[i].code)
			traces = tree.getTraces()
			expect(compareTraces(programs[i].traces, traces)).toBe(true)
		

	for i of programs
		testProgram(i)
		testTraces(i)
	null
	
	
	
	