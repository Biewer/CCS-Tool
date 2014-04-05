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
		"""
		a.b.c.d.0
		"""
	"2":
		"""
		a!.b!.0 + b!.a!.0 | a?.b?.0 + b?.a?.0
		"""
	"3":
		"""
		a!.b!.1 + b!.a!.1 | a?.b?.1 + b?.a?.1 ; end!. 0
		"""
	"4":
		"""
		a!.b!.1 + b!.a!.1 | a?.b?.1 + b?.a?.1 ; end!. 0 \\ {a, b}
		"""
	"5":
		"""
		X[a,b] := a.b.X[b,a]
		X[c,d]
		"""
	"6":
		"""
		X[x] := when (x<3)a.b.X[x+1]
		X[1]
		"""
	

CCS = require("CCS")


describe "CCS parser", ->
	
	testProgram = (i) ->				 # "it" must be wrapped in a function
		it "should parse \"#{i}\"", ->
			tree = null
			try
				tree = CCS.parser.parse(programs[i])
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

	for i of programs
		testProgram(i)
	null
	
	
	
	