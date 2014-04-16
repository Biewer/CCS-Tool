/*
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
*/

start = C:CCS { return C; }

CCS
  = PDefs:(Process)* _ System:Restriction _ !.
		                                { 
		                                	var defs = [];
		                                  	for (var i = 0; i < PDefs.length; i++) {
		                                  		defs.push(PDefs[i]);
		                                  	}
		                                  	return new CCS(defs, System);
		                                }
                                

Process
  = _ n:name _ params:("[" _ v:identifier vs:(_ "," _ v2:identifier { return v2; })* _ "]" _ { vs.unshift(v); return vs; } )? ":=" P:Restriction __ [\n\r]+
		                                { 
		                                  return new CCSProcessDefinition(n.name, P, params ? params : null, line());
		                                }




Restriction
  = _ P:Sequence res:(_ "\\" _ "{" as:(_ a1:(channel / "*") as2:(_ "," _ a2:channel { return a2; })* { as2.unshift(a1); return as2; } )? _ "}" { return  as; })?
  										{
  											res = res ? new CCSRestriction(P, res) : P;
  											res.line = line();
  											return res;
  										}


Sequence
  = _ P:Parallel Ps:(_ ";" Q:Parallel { return Q; })*
		                                {
		                                  Ps.unshift(P);
		                                  while(Ps.length > 1){
		                                    var p = Ps.shift();
		                                    var q = Ps.shift();
		                                    Ps.unshift(new CCSSequence(p,q));
		                                  }
		                                  return Ps[0];
		                                }
	                                
	                                

Parallel
  = _ P:Choice Ps:(_ "|" Q:Choice { return Q; })*
		                                {
		                                  Ps.unshift(P);
		                                  while(Ps.length > 1){
		                                    var p = Ps.shift();
		                                    var q = Ps.shift();
		                                    Ps.unshift(new CCSParallel(p,q));
		                                  }
		                                  return Ps[0];
		                                }




Choice
  = _ P:Prefix Ps:(_ "+" Q:Prefix { return Q; })*
									  {
									    Ps.unshift(P);
									    while(Ps.length > 1){
									      var p = Ps.shift();
									      var q = Ps.shift();
									      Ps.unshift(new CCSChoice(p,q));
									    }
									    return Ps[0];
									  }



Prefix
  = Condition
  	/ _ A:(/*Match
		*/ Input
		/ Output
		/ SimpleAction ) _ "." P:Prefix
									{ 
										return new CCSPrefix(A, P); 
									}
	/ Trivial
	


Condition
  = _ "when" _ "(" _ e:expression _ ")" _ P:Prefix
	  								{
	  									return new CCSCondition(e, P);
	  								}

/*Match
  = a:Action _ "?" _ "=" _ e:expression
									{ 
										return new CCSMatch(a, e ? e : null); 
									}*/
  								

Input
  = a:Action _ "?" v:(_ t:identifier { return t; })?
	  								{ 
	  									return new CCSInput(a, v); 
	  								}


Output
  = a:Action _ "!" e:(_ t:expression { return t; })?
	  								{ 
	  									return new CCSOutput(a, e ? e : null); 
	  								}



SimpleAction
  = a:Action
	                                { 
	                                	return new CCSSimpleAction(a); 
	                                }


Action
  = c:channel e:( "(" e:expression? ")" { return e; } )?
  									{
  										if (!e) e = null;
  										return new CCSChannel(c, e);
  									}
	                                
	                                


                                


Trivial
  = _ "(" P:Restriction _ ")"       { 
  										return P; 
  									}
  / _ "0"                         	{ 
  										return new CCSStop(); 
  									}
  / _ "1"                         	{ 
  										return new CCSExit(); 
  									}
  / _ n:name 
  		args:(_ "[" _ e:expression es:(_ "," _ e1:expression { return e1; })* _ "]" { es.unshift(e); return es; } )?
  			                     	{ 
                                  		return new CCSProcessApplication(n.name, args);
                                	}

name "name"
  = first:[A-Z] rest:[A-Za-z0-9_]* { return {name: first + rest.join(''), line: line, column: column}; }

// The following rules are the same, but they have different names which makes error messages better understandable!
identifier "identifier"
  = first:[a-z] rest:[A-Za-z0-9_]* { return first + rest.join(''); }

channel "channel"
  = first:[a-z] rest:[A-Za-z0-9_]* { return first + rest.join(''); }
  
 int "integer"
  = "0" { return 0; }
  	/ first:[1-9] rest:[0-9]* { return parseInt(first + rest.join('')); }
 
  
// aexp "expression"
//   = f:(int / action) r:(_ o:("+"/"-"/"*"/"/") _ s:(int/action) { return " " + o + " " + s })* { return f + r.join(""); }
// 
// bexp "boolean expression"
//   = f:(int / action) r:(_ o:("=="/"<"/"<="/">"/">="/"!=") _ s:(int/action) { return " " + o + " " + s })* { return f + r.join(""); }


_ "whitespace"
  = [' '\n\r\t] _               {}
  / '#' inlineComment           {}
  / '//' inlineComment			{}
  / '(*' commentA _		{}
  / __             				{}   


__ "inline whitespace"
  = [' '\t] __               {}
  / '#' inlineCommentWhitespace           {}
  / '//' inlineCommentWhitespace             {}
  / '(*' commentA __		{}
  / 			{}
 

/*
inlineComment
  = [^\n\r]* [\n\r]+ _			{}

inlineCommentWhitespace
  = [^\n\r]* [\n\r]+ __			{}
  / [^\n\r]* ![^]				{}
*/

inlineComment
  = [^\n\r]* _			{}

inlineCommentWhitespace
  = [^\n\r]* __			{}
  / [^\n\r]* !.				{}


commentA
	= "*)"		{ }
	/ "*" !")" commentA		{}
	/ "(*" commentA commentA		{}
	/ "(" !"*" commentA		{}
	/ f:[^*(] commentA		{}






// Expressions:

expression
 	= ___ result:equalityExpression ___ { return result; }
 	
 	
 	equalityExpression
 		= left:relationalExpression 
 			equal:( ___ op:( '==' / '!=' ) ___ right:relationalExpression 
 				{ return [op, right]; } )*
 		{ 
 			while (equal.length > 0) {
 				t = equal.shift();
 				left = new CCSEqualityExpression(left, t[1], t[0]);
 			}
 			return left;
 		}
 		
 	
 	relationalExpression
 		= left:concatenatingExpression 
 			relational:( ___ op:( '<''=' / '>''=' / '<' / '>' ) ___ right:concatenatingExpression
 				{ if (op instanceof Array) {op = op.join("");} return [op, right]; } )*
 		{ 
 			while (relational.length > 0) {
 				t = relational.shift();
 				left = new CCSRelationalExpression(left, t[1], t[0]);
 			}
 			return left;
 		}
 	
 	concatenatingExpression
 		= left:additiveExpression 
 			concat:( ___ '^' ___ right:additiveExpression 
 				{ return right; } )*
 		{ 
 			while (concat.length > 0) {
 				t = concat.shift();
 				left = new CCSConcatenatingExpression(left, t);
 			}
 			return left;
 		}
 		
 	
 	additiveExpression
 		= left:multiplicativeExpression 
 			addition:( ___ op:( '+' / '-' ) ___ right:multiplicativeExpression 
 				{ return [op, right]; } )*
 		{
 			while (addition.length > 0) {
 				t = addition.shift();
 				left = new CCSAdditiveExpression(left, t[1], t[0]);
 			}
 			return left;
 		}
 	
 	
 	multiplicativeExpression
 		= left:primaryExpression 
 			multiplication:( ___ op:( '*' / '/' ) ___ right:primaryExpression 
 				{ return [op, right]; } )*
 		{
 			while (multiplication.length > 0) {
 				t = multiplication.shift();
 				left = new CCSMultiplicativeExpression(left, t[1], t[0]);
 			}
 			return left;
 		}
 	
 	
 	primaryExpression
 		= exp_boolean
 		/ exp_integer
 		/ exp_string
 		/ exp_identifier
 		/ "(" ___ equality:equalityExpression ___ ")" 
 			{ return equality; }
 	
 	exp_identifier "identifier"
 	  = first:[a-z] rest:[A-Za-z0-9_]* 
 	  	{ return new CCSVariableExpression(first + rest.join('')); }
 	
 	exp_boolean "boolean literal"
 		= 'true' { return new CCSConstantExpression(true); }
 		/ 'false' { return new CCSConstantExpression(false); }
 	
 	exp_integer "integer literal"
 		= minus:('-')? digits:[0-9]+ { return new CCSConstantExpression(parseInt((minus ? minus : "") + digits.join(""))); }
 		
 	
 	exp_string "string literal"
 	    =	'"' 
 	        s:(   exp_escapeSequence
 	        /   [^"]       
 	        )* 
 	        '"' { return new CCSConstantExpression((s.join ? s.join("") : "")); }
 	
 	exp_escapeSequence 
 	    =   '\\' (
 	                 't'  	{ return '\\t'; }
 	             /   'n'  	{ return '\\n'; }
 	             /   'r'  	{ return '\\r'; }
 	             /   '"'  	{ return '\\"'; }
 	             /   '\\'  	{ return '\\\\'; }
 	             ) 
 	
 	___ "whitespace"
 	  = ' '*               {}
 	  /          
 	
 	