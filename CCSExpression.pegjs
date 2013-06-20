start
 	= ___ result:equalityExpression ___ { return new Expression(result[0], result[1]); }


equalityExpression
	= left:relationalExpression 
		equal:( ___ op:( '==' / '!=' ) ___ right:relationalExpression 
			{ return [op + '(' + right[0] + ')', op+right[1]]; } )*
	{ 
		if (equal == "") return left;
		equal.unshift(['(' + left[0] + ')', left[1]]);
		return equal.joinChildren("");
	}
	

relationalExpression
	= left:concatenatingExpression 
		relational:( ___ op:( '<''=' / '>''=' / '<' / '>' ) ___ right:concatenatingExpression
			{ return [op + '(' + right[0] + ')', op+right[1]]; } )*
	{ 
		if (relational == "") return left;
		relational.unshift(['(' + left[0] + ')', left[1]]);
		return relational.joinChildren("");
	}

concatenatingExpression
	= left:additiveExpression 
		concat:( ___ '^' ___ right:additiveExpression 
			{ return ['+' + '(' + right[0] + ')', '^' + right[1]]; } )*
	{ 
		if (concat == "") return left;
		concat.unshift(['""+(' + left[0] + ')', left[1]]);
		return concat.joinChildren("");
	}
	

additiveExpression
	= left:multiplicativeExpression 
		addition:( ___ op:( '+' / '-' ) ___ right:multiplicativeExpression 
			{ return [op + 'parseInt(' + right[0] + ')', op+right[1]] } )*
	{
		if (addition == "") return left;
		addition.unshift(['parseInt(' + (left[0]) + ')', left[1]]);
		return addition.joinChildren("");
	}


multiplicativeExpression
	= left:primaryExpression 
		multiplication:( ___ op:( '*' / '/' ) ___ right:primaryExpression 
			{ return [op + 'parseInt(' + right[0] + ')', op+right[1]] } )*
	{
		if (multiplication == "") return left;
		console.log((left));
		multiplication.unshift(['parseInt(' + (left[0]) + ')', left[1]]);
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
  = first:[a-z] rest:[A-Za-z0-9_]* { return '__env("' + first + rest.join('') + '")'; }

exp_boolean "boolean literal"
	= 'true' { return ["1", "1"]; }
	/ 'false' { return ["0", "0"]; }

exp_integer "integer literal"
	= digits:[0-9]+ { var res = digits.join(""); return [res, res]; }
	

exp_string "string literal"
    =	'"' 
        s:(   exp_escapeSequence
        /   [^"]       
        )* 
        '"' { var res = '"' + (s.join ? s.join("") : "") + '"'; return [res, res]; }

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

