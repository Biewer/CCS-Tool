start = C:CCS { return C; }

CCS
  = PDefs:(Process)* _ System:Restriction _
		                                { 
		                                	var defs = {};
		                                  	for (var i = 0; i < PDefs.length; i++) {
		                                  		defs[PDefs[i].name] = PDefs[i];
		                                  	}
		                                  	return new CCS(defs, System);
		                                }
                                

Process
  = _ n:name _ params:("[" _ v:identifier vs:(_ "," _ v2:identifier { return v2; })* _ "]" _ { vs.unshift(v); return vs; } )? ":=" P:Restriction __ "\n"
		                                { 
		                                  return new ProcessDefinition(n.name, P, params == "" ? null : params);
		                                }




Restriction
  = _ P:Sequence res:(_ "\\" _ "{" as:(_ a1:action as2:(_ "," _ a2:action { return new SimpleAction(a2); })* { as2.unshift(new SimpleAction(a1)); return as2; } )? _ "}" { return as; })?
  										{
  											return res == "" ? P : new Restriction(P, res);
  										}


Sequence
  = _ P:Parallel Ps:(_ ";" Q:Parallel { return Q; })*
		                                {
		                                  Ps.unshift(P);
		                                  while(Ps.length > 1){
		                                    var p = Ps.shift();
		                                    var q = Ps.shift();
		                                    Ps.unshift(new Sequence(p,q));
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
		                                    Ps.unshift(new Parallel(p,q));
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
									      Ps.unshift(new Choice(p,q));
									    }
									    return Ps[0];
									  }



Prefix
  = Condition
  	/ _ A:(Match
		/ Input
		/ Output
		/ SimpleAction ) _ "." P:Prefix
									{ 
										return new Prefix(A, P); 
									}
	/ Trivial
	


Condition
  = _ "when" _ "(" _ e:expression _ ")" _ P:Prefix
	  								{
	  									return new Condition(e, P);
	  								}

Match
  = a:action _ "?" _ "=" _ e:expression
									{ 
										return new Match(a, (e == "") ? null : e); 
									}
  								

Input
  = a:action _ "?" v:(_ t:identifier { return t; })?
	  								{ 
	  									return new Input(a, v); 
	  								}


Output
  = a:action _ "!" e:(_ t:expression { return t; })?
	  								{ 
	  									return new Output(a, (e == "") ? null : e); 
	  								}



SimpleAction
  = a:action
	                                { 
	                                	return new SimpleAction(a); 
	                                }
	                                
	                                


                                


Trivial
  = _ "(" P:Restriction _ ")"       { 
  										return P; 
  									}
  / _ "0"                         	{ 
  										return new Stop(); 
  									}
  / _ "1"                         	{ 
  										return new Exit(); 
  									}
  / _ n:name 
  		args:(_ "[" _ e:expression es:(_ "," _ e1:expression { return e1; })* _ "]" { es.unshift(e); return es; } )?
  			                     	{ 
                                  		return new ProcessApplication(n.name, (typeof args == "string" ? null : args));
                                	}

name "name"
  = first:[A-Z] rest:[A-Za-z0-9_]* { return {name: first + rest.join(''), line: line, column: column}; }

// The following rules are the same, but they have different names which makes error messages better understandable!
identifier "identifier"
  = first:[a-z] rest:[A-Za-z0-9_]* { return first + rest.join(''); }

action "action"
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
  / '#' [^\n]* '\n' _           {}
  / __             				{}   


__ "inline whitespace"
  = [' '\t] __               {}
  / '#' [^\n]* '\n' __           {}
  / '#' [^\n]* ![^]             {}
  / 







// Expressions:

expression
 	= ___ result:equalityExpression ___ { return new Expression(result[0], result[1]); }
 	
 	
 	equalityExpression
 		= left:relationalExpression 
 			equal:( ___ op:( '==' / '!=' ) ___ right:relationalExpression 
 				{ return [op + '(' + right[0] + ')', '+"'+op+'"+'+right[1]]; } )*
 		{ 
 			if (equal == "") return left;
 			equal.unshift(['(' + left[0] + ')', '""+'+left[1]]);
 			return equal.joinChildren("");
 		}
 		
 	
 	relationalExpression
 		= left:concatenatingExpression 
 			relational:( ___ op:( '<''=' / '>''=' / '<' / '>' ) ___ right:concatenatingExpression
 				{ return [op + '(' + right[0] + ')', '+"'+op+'"+'+right[1]]; } )*
 		{ 
 			if (relational == "") return left;
 			relational.unshift(['(' + left[0] + ')', '""+'+left[1]]);
 			return relational.joinChildren("");
 		}
 	
 	concatenatingExpression
 		= left:additiveExpression 
 			concat:( ___ '^' ___ right:additiveExpression 
 				{ return ['+' + '(' + right[0] + ')', '+"^"+'+right[1]]; } )*
 		{ 
 			if (concat == "") return left;
 			concat.unshift(['""+(' + left[0] + ')', '""+'+left[1]]);
 			return concat.joinChildren("");
 		}
 		
 	
 	additiveExpression
 		= left:multiplicativeExpression 
 			addition:( ___ op:( '+' / '-' ) ___ right:multiplicativeExpression 
 				{ return [op + 'parseInt(' + right[0] + ')', '+"'+op+'"+'+right[1]] } )*
 		{
 			if (addition == "") return left;
 			addition.unshift(['parseInt(' + (left[0]) + ')', '""+'+left[1]]);
 			return addition.joinChildren("");
 		}
 	
 	
 	multiplicativeExpression
 		= left:primaryExpression 
 			multiplication:( ___ op:( '*' / '/' ) ___ right:primaryExpression 
 				{ return [op + 'parseInt(' + right[0] + ')', '+"'+op+'"+'+right[1]] } )*
 		{
 			if (multiplication == "") return left;
 			console.log((left));
 			multiplication.unshift(['parseInt(' + (left[0]) + ')', '""+'+left[1]]);
 			return multiplication.joinChildren("");
 		}
 	
 	
 	primaryExpression
 		= exp_boolean
 		/ exp_integer
 		/ exp_string
 		/ exp_identifier
 		/ "(" ___ equality:equalityExpression ___ ")" 
 			{ var res = equality; res[1] = "("+res[1]+")"; return res; }
 	
 	exp_identifier "identifier"
 	  = first:[a-z] rest:[A-Za-z0-9_]* 
 	  	{ var res = '__env("' + first + rest.join('') + '")'; return [res, res]; }
 	
 	exp_boolean "boolean literal"
 		= 'true' { return ["1", "true"]; }
 		/ 'false' { return ["0", "false"]; }
 	
 	exp_integer "integer literal"
 		= digits:[0-9]+ { var res = digits.join(""); return [res, res]; }
 		
 	
 	exp_string "string literal"
 	    =	'"' 
 	        s:(   exp_escapeSequence
 	        /   [^"]       
 	        )* 
 	        '"' { var res = '"' + (s.join ? s.join("") : "") + '"'; return [res, "'"+res+"'"]; }
 	
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
 	
 	