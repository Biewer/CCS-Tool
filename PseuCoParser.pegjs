/*
 * PseuCo Compiler
 * Copyright (C) 2015
 * Saarland University (www.uni-saarland.de)
 * Pascal Held (pascal-held@t-online.de)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * @brief This file contains the grammar for the JavaScript parser generator
 * PEG.js.
 *
 * It is divided in the following parts:
 * - Declaration of general source code characters, whitespaces and comments.
 * - Declaration of literals.
 * - Declaration of a pseuCo program.
 * - Declaration of global definitions.
 * - Declaration of statements.
 * - Declaration of types.
 * - Declaration of expressions.
 */

/**
 * @brief Little helper function for constructing the AST. It builds a new AST
 * node object by calling the given constructor with the given arguments.
 *
 * @param constructor The constructor of Object to build.
 * @param args A list of arguments for calling the constructor.
 *
 * @return A new object of type `constructor`.
 */
{
	function construct(constructor, args)
	{
		function F()
		{
			return constructor.apply(this, args);
		}
		F.prototype = constructor.prototype;
		return new F();
	}
}

/*
 * Start rule of the grammar. A pseuCo file must contain a pseuCo program. It
 * can be surrounded with sequences of whitespaces.
 */
start
	= __ program:Program __ EOF { return program; }

/*
 * Every character is a source character.
 */
SourceCharacter
	= .

/*
 * Whitespaces are:
 * - Space
 * - Tabulator
 * - Vertical tabulator
 * - Form feed
 */
WhiteSpace "whitespace"
	= [ \t\v\f] {}

/*
 * A newline or carriage return character indicates the end of a line.
 */
LineTerminator
	= [\n\r] {}

/*
 * Different operation systems use different characters or character sequences,
 * respectively to end a line.
 * - Windows: carriage return + newline
 * - Mac: carriage return
 * - Unix: newline
 */
LineTerminatorSequence "end of line"
	= "\n" {}
	/ "\r\n" {}
	/ "\r" {}

/*
 * A comment can be a multi line, single line or formal comment.
 */
Comment "comment"
	= MultiLineComment {}
	/ FormalComment {}
	/ SingleLineComment {}

/*
 * Multi line comments are started with slash followed by a asterisk. After this
 * sequence any character sequence can follow except for the sequence asterisk
 * slash. The aforementioned sequence terminates the multi line comment.
 */
MultiLineComment
	= "/*" (!"*/" SourceCharacter)* "*/" {}

/*
 * Special form of multi line comment. It is started and finished as the regular
 * one but contains no line break.
 */
MultiLineCommentNoLineTerminator
	= "/*" (!("*/" / LineTerminator) SourceCharacter)* "*/" {}

/*
 * Another special form of multi line comment. It can be started with the
 * character sequence slash asterisk asterisk and terminated as the regular one.
 * It is used for documentation purposes.
 */
FormalComment
	= "/**" (!"*/" SourceCharacter)* "*/" {}

/*
 * A single line comment is started with a slash directly followed by another
 * slash and terminates with the next line break. As well as multi line comments
 * it can contain any character sequence.
 */
SingleLineComment
	= "//" (!LineTerminator SourceCharacter)* {}

/*
 * The next three rules are used to indicate sequences of tokens that do not
 * impact the program behaviour at all.
 */

/*
 * Token sequence that cannot spread more than one line and can be empty.
 */
_
	= (WhiteSpace / MultiLineCommentNoLineTerminator / SingleLineComment)* {}

/*
 * Token sequence that can spread more than one line and can be empty.
 */
__
	= (WhiteSpace / LineTerminatorSequence / Comment)* {}

/*
 * Token sequence that can spread more than one line and cannot be empty.
 */
___
	= (WhiteSpace / LineTerminatorSequence / Comment)+ {}

/*
 * If there is no character at all the end of file is reached.
 */
EOF
	= !. {}

/*
 * pseuCo code can contain three types of literals:
 * - integer literals like 0, 11 or 42
 * - string literals like "Hello World" or "This is a string."
 * - boolean literals like true and false
 */
Literal
	= literal:IntegerLiteral { return literal; }
	/ literal:StringLiteral { return literal; }
	/ literal:BooleanLiteral { return literal; }

/*
 * The two boolean literals true and false.
 */
BooleanLiteral
	= "true" { return true; }
	/ "false" { return false; }

/*
 * An integer literal is either "0" or any non-zero digit followed by an
 * arbitrary sequence of digits (including zero).
 */
IntegerLiteral "integer"
	= "0" { return 0; }
	/ head:[1-9] tail:([0-9])* { return parseInt(head + tail.join(""), 10); }

/*
 * A string literal is a possibly empty sequence of string characters (see
 * below) enclosed by double quotes.
 */
StringLiteral "string"
	= stringLiteral:('"' StringCharacters? '"')
		{ return stringLiteral[1] != null ? stringLiteral[1] : ""; }

/*
 * Sequence of string characters (see below).
 */
StringCharacters
	= chars:StringCharacter+ { return chars.join(""); }

/*
 * Any source character except for a double quote, a backslash and a line
 * terminator can be a string character. Escape sequences and line continuations
 * can be string characters as well.
 */
StringCharacter
	= !('"' / "\\" / LineTerminator) char_:SourceCharacter { return char_; }
	/ "\\" seq:EscapeSequence { return seq; }
	/ con:LineContinuation { return con; }

/*
 * A line continuation is a line terminator sequence (\n, \r\n, \r) escaped by
 * a backslash.
 */
LineContinuation
	= "\\" seq:LineTerminatorSequence { return seq; }

/*
 * There are two types of escape sequences:
 * - character escape sequences like \n, \t or \b
 * - octal escape sequences like \000 or \042
 */
EscapeSequence
	= seq:CharacterEscapeSequence { return seq; }
	/ seq:OctalEscapeSequence { return seq; }

/*
 * Possible character escape sequences are:
 * - a single quote
 * - a double quote
 * - a backslash
 * - a backspace
 * - a form feed
 * - a new line
 * - a carriage return
 * - a tabulator
 * - a vertical tabulator
 */
CharacterEscapeSequence
	= char_:['"\\bfnrtv] { return char_; }

/*
 * Octal escape sequences are sequences of length two or three of digits between
 * zero and seven. In the latter case (three digits) the first digit has to be
 * between zero and three.
 */
OctalEscapeSequence
	= first:[0-7] second:([0-7])?
		{ return first + (second != null ? second : ""); }
	/ first:[0-3] second:[0-7] third:[0-7] { return first + second + third; }

/*
 * Identifiers in pseuCo are sequences of letters and digits where the first
 * character has to be a letter.
 */
Identifier "identifier"
	= head:Letter tail:(Letter / Digit)* { return head + tail.join(""); }

/*
 * Below is a list of possible letter characters.
 */
Letter
	= letter:([A-Z_a-z\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u00ff\u0100-\u1fff] /
		[\u3040-\u318f\u3300-\u337f\u3400-\u3d2d\u4e00-\u9fff\uf900-\ufaff])
		{ return letter; }

/*
 * Below is a list of possible digit characters.
 */
Digit
	= digit:([0-9\u0660-\u0669\u06f0-\u06f9\u0966-\u096f\u09e6-\u09ef] /
		[\u0a66-\u0a6f\u0ae6-\u0aef\u0b66-\u0b6f\u0be7-\u0bef\u0c66-\u0c6f] /
		[\u0ce6-\u0cef\u0d66-\u0d6f\u0e50-\u0e59\u0ed0-\u0ed9\u1040-\u1049])
		{ return digit; }

/*
 * A pseuCo program consists of one or more source elements. The possible source
 * elements are listed below.
 */
Program
	= source:SourceElements
		{
			source.unshift(line(), column());
			return construct(PCProgram, source);
		}

/*
 * Non-empty list of source elements.
 */
SourceElements
	= head:SourceElement tail:(__ SourceElement)*
		{
			var elements = [];
			elements.push(head);
			for (var i = 0; i < tail.length; ++i)
			{
				elements.push(tail[i][1]);
			}
			return elements;
		}

/*
 * Possible source elements:
 * - a monitor (data structure)
 * - a structure (data structure)
 * - the main agent (procedure)
 * - a procedure declaration (procedure)
 * - a global declaration like the declaration of a variable
 */
SourceElement
	= elem:Monitor { return elem; }
	/ elem:Struct { return elem; }
	/ elem:MainAgent { return elem; }
	/ elem:Procedure { return elem; }
	/ elem:DeclarationStatement { return elem; }

/*
 * pseuCo monitors are introduces through the keyword "monitor". This keyword is
 * followed by an identifier and a code block for class code ("{ code }").
 */
Monitor
	= "monitor" ___ id:Identifier __ "{" __ code:ClassCode __ "}"
		{
			code.unshift(id, line(), column());
			return construct(PCMonitor, code);
		}

/*
 * pseuCo structures are introduces through the keyword "struct". This keyword
 * is followed by an identifier and a code block for class code
 * ("{ code }").
 */
Struct
	= "struct" ___ id:Identifier __ "{" __ code:ClassCode "}"
		{
			code.unshift(id, line(), column());
			return construct(PCStruct, code);
		}

/*
 * Code blocks for class code can contain zero or more of the following
 * declarations:
 * - declaration of a procedure
 * - declaration of a condition
 * - declaration of a class global entity e.g. a field (variable).
 */
ClassCode
	= code:((Procedure / ConditionDeclarationStatement /
		DeclarationStatement) __)*
		{
			var declarations = [];
			for (var i = 0; i < code.length; ++i)
			{
				declarations.push(code[i][0]);
			}
			return declarations;
		}

/*
 * The main agent is the entry point of every pseuCo program and is like a
 * special procedure. This procedure has no return type and is named
 * "mainAgent". Beyond that it has no argument list not even an empty pair of
 * parenthesis. Like a normal procedure it has a code block ("{ code }").
 */
MainAgent
	= "mainAgent" __ stmtBlock:StatementBlock
		{ return new PCMainAgent(line(), column(), stmtBlock); }

/*
 * The normal procedure declarations in pseuCo consist of:
 * - specification of the return type
 * - specification of the procedure name
 * - specification of the argument list
 * - specification of the code block
 */
Procedure
	= type:ResultType ___ id:Identifier __ fp:FormalParameters __
		stmtBlock:StatementBlock
		{
			fp.unshift(line(), column(), type, id, stmtBlock);
			return construct(PCProcedureDecl, fp);
		}

/*
 * A argument list is a comma separated list of formal parameters enclosed by a
 * pair of parenthesis.
 */
FormalParameters
	= "(" __ test:(FormalParameter (__ "," __ FormalParameter)*)? __ ")"
		{
			if (test != null)
			{
				var fp = [];
				fp.push(test[0]);
				for (var i = 0; i < test[1].length; ++i)
				{
					fp.push(test[1][i][3]);
				}
				return fp;
			}
			else
			{
				return [];
			}
		}

/*
 * A formal parameter is pair composed of a type and an identifier.
 */
FormalParameter
	= type:Type ___ id:Identifier
		{ return new PCFormalParameter(line(), column(), type, id); }

/*
 * pseuCo supports the following statements:
 * - A block statement ("{ some code }").
 * - A print line statement (prints a line).
 * - A select statement (non-deterministic choice).
 * - An if statements (deterministic choice).
 * - A while statement (loop).
 * - A do-while statement (loop).
 * - A for statement (loop).
 * - A break statement (stop innermost loop).
 * - A continue statement (next iteration of the innermost loop).
 * - A return statement (return to callee of procedure).
 * - A set of primitive statements (see below).
 * - A variety of expression statements (see below).
 * - An empty statement.
 */
Statement
	= stmt:StatementBlock { return new PCStatement(line(), column(), stmt); }
	/ stmt:Println { return new PCStatement(line(), column(), stmt); }
	/ stmt:SelectStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:IfStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:WhileStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:DoStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:ForStatement { return new PCStatement(line(), column(), stmt); }
	/ "break" __ ";"
		{
			return new PCStatement(line(), column(), new PCBreakStmt(line(),
				column()));
		}
	/ "continue" __ ";"
		{
			return new PCStatement(line(), column(), new PCContinueStmt(line(),
				column()));
		}
	/ stmt:ReturnStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:PrimitiveStatement
		{ return new PCStatement(line(), column(), stmt); }
	/ stmt:StatementExpression __ ";"
		{ return new PCStatement(line(), column(), stmt); }
	/ __ ";" { return new PCStatement(line(), column()); }

/*
 * A block statement a block of code enclosed by a pair of braces. Even though
 * the rule is named "StatementBlock" the corresponding object is referenced as
 * block statement. The "BlockStatement" rule is just a container.
 */
StatementBlock
	= "{" __ blockStmts:(BlockStatement __)* "}"
		{
			var stmts = [line(), column()];
			for (var i = 0; i < blockStmts.length; ++i)
			{
				stmts.push(blockStmts[i][0]);
			}
			return construct(PCStmtBlock, stmts);
		}

/*
 * A "block statement" can be a regular statement, a procedure declaration, a
 * declaration statement or a declaration of a condition.
 */
BlockStatement
	= stmt:Statement { return stmt; }
	/ stmt:Procedure { return stmt; }
	/ stmt:DeclarationStatement
		{ return new PCStatement(line(), column(), stmt); }
	/ stmt:ConditionDeclarationStatement { return stmt; }

/*
 * A declaration of a condition is composed of the following token sequence:
 * 1) The keyword "condition".
 * 2) Specification of an identifier.
 * 3) The keyword "with".
 * 4) Specification of an expression.
 */
ConditionDeclarationStatement
	= "condition" ___ id:Identifier __ "with" ___ exp:Expression __ ";"
		{
			return new PCConditionDecl(line(), column(), id, exp);
		}

/*
 * A declaration statement is a declaration followed by a semicolon.
 */
DeclarationStatement
	= decl:Declaration __ ";"
		{
			decl.isStatement = true;
			return decl;
		}

/*
 * A pseuCo declaration is split into the type specification and a non-empty
 * list of variable declarators.
 */
Declaration
	= type:Type ___ head:VariableDeclarator tail:(__ "," __ VariableDeclarator)*
		{
			var declarations = [];
			declarations.push(false, line(), column(), type, head);
			for (var i = 0; i < tail.length; ++i)
			{
				declarations.push(tail[i][3]);
			}
			return construct(PCDecl, declarations);
		}

/*
 * Variable declarators consist of an identifier and may have an initialisation.
 */
VariableDeclarator
	= id:Identifier varInit:(__ "=" __ VariableInitializer)?
		{
			return varInit != null ?
				new PCVariableDeclarator(line(), column(), id, varInit[3]) :
				new PCVariableDeclarator(line(), column(), id);
		}

/*
 * A variable initialiser is a expression or a possibly empty list of variable
 * initialisers surrounded by a pair of braces.
 */
VariableInitializer
	= "{" __ test:(VariableInitializer (__ ","  __ VariableInitializer)*)?
		uncomplete:(__ "," __)? __ "}"
		{
			if (test != null)
			{
				var inits = [];
				inits.push(test[0]);
				for (var i = 0; i < test[1].length; ++i)
				{
					inits.push(test[1][i][3]);
				}
				inits.unshift(line(), column(), uncomplete != null)
				return construct(PCVariableInitializer, inits);
			}
			else
			{
				return new PCVariableInitializer(line(), column(),
					uncomplete != null);
			}
		}
	/ exp:Expression
		{
			return new PCVariableInitializer(line(), column(), false, exp);
		}

/*
 * pseuCo types are primitive types with an optional list of array boundaries
 * ("[number1][number2]...").
 */
Type
	= type:PrimitiveType ranges:(__ "[" IntegerLiteral "]")*
		{
			var res = type;
			for (var i = ranges.length - 1; i >= 0; --i)
			{
				res = new PCArrayType(line(), column(), res, ranges[i][2]);
			}
			return res;
		}

/*
 * A expression statement is one of the following expression:
 * - start expression (start a agent)
 * - assignment (update content of variable)
 * - send expression (send information on channel)
 * - receive expression (receive information on channel)
 * - postfix expression (decrement of increment variable)
 * - call expression (procedure call)
 */
StatementExpression
	= stmtExp:StartExpression
		{ return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:AssignmentExpression
		{ return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:SendExpression
		{ return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:PostfixExpression
		{ return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:CallExpression
		{ return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:ReceiveExpression
		{ return new PCStmtExpression(line(), column(), stmtExp); }

/*
 * A list of expression statements.
 */
StatementExpressionList
	= head:StatementExpression tail:(__ "," __ StatementExpression)*
		{
			var stmts = [];
			stmts.push(head);
			for (var i = 0; i < tail.length; ++i)
			{
				stmts.push(tail[i][3]);
			}
			return stmts;
		}

/*
 * The select statement is build out of:
 * - The keyword "select"
 * - A non-empty list of case statements enclosed by a pair of braces.
 * It embodies the non-deterministic choice.
 */
SelectStatement
	= "select" __ "{" __ stmts:(CaseStatement __ )+ __ "}"
		{
			var caseStmts = [line(), column()];
			for (var i = 0; i < stmts.length; ++i)
			{
				caseStmts.push(stmts[i][0]);
			}
			return construct(PCSelectStmt, caseStmts);
		}

/*
 * There two kinds of case statements:
 * - The actual "case" statement followed by a expression statement a colon and
 *   and a statement.
 * - The default statement followed by a colon and a statement.
 */
CaseStatement
	= "case" ___ exp:StatementExpression __ ":" __ stmt:Statement
		{ return new PCCase(line(), column(), stmt, exp); }
	/ "default" __ ":" __ stmt:Statement
		{ return new PCCase(line(), column(), stmt); }

/*
 * The deterministic choice is represented via the if statement. This statement
 * has the following structure:
 * - The keyword "if".
 * - A condition (expression surrounded by a pair of parenthesis).
 * - A statement (if the condition evaluates to true it is executed).
 * OPTIONAL:
 * - The keyword "else" followed by a statement (executed if the condition
 *   evaluates to false).
 */
IfStatement
	= "if" __ "(" __ exp:Expression __ ")" __ ifStmt:Statement __ test:("else"
		__ Statement)?
		{
			return test != null ?
				new PCIfStmt(line(), column(), exp, ifStmt, test[2]) :
				new PCIfStmt(line(), column(), exp, ifStmt);
		}

/*
 * The while statement is the first kind of loop. It starts with the keyword
 * "while" followed by an expression (enclosed by parenthesis) and a statement.
 * The statement is executed as long as the expression evaluates to true.
 */
WhileStatement
	= "while" __ "(" __ exp:Expression __ ")" __ stmt:Statement
		{ return new PCWhileStmt(line(), column(), exp, stmt); }

/*
 * The do-while statement is the second kind of loop. It starts with the keyword
 * "do" followed by a statement, keyword "while" an expression (enclosed by
 * parenthesis) and a semicolon. The statement is executed as long as the
 * expression evaluates to true but at least once.
 */
DoStatement
	= "do" __ stmt:Statement __ "while" __ "(" __ exp:Expression __ ")" __ ";"
		{ return new PCDoStmt(line(), column(), stmt, exp); }

/*
 * The for statement is the third kind of loop. It starts with the keyword "for"
 * followed by a special kind of expression and a statement. The expression is
 * tripartite. It has a initialisation, a conditional and an update part. The
 * statement is executed as long as the condition evaluates to true and the
 * update part is executed as well. The initialisation part is executed once
 * before the entire loop.
 */
ForStatement
	= "for" __ "(" __ init:(ForInit)? __ ";" __ exp:(Expression)? __ ";" __
		update:(ForUpdate)? __ ")" __ stmt:Statement
		{
			var res = [];
			if (update != null)
			{
				res = res.concat(update);
			}
			res.unshift(line(), column(), stmt, init, exp);
			return construct(PCForStmt, res);
		}

/*
 * The initialisation part of the for loop consist of a non-empty list of
 * declarations.
 */
ForInit
	= head:(Declaration / StatementExpression) tail:(__ "," __ (Declaration /
		StatementExpression))*
		{
			var inits = [line(), column()];
			inits.push(head);
			for (var i = 0; i < tail.length; ++i)
			{
				inits.push(tail[i][3]);
			}
			return construct(PCForInit, inits);
		}

/*
 * The update part of the for loop consist of a expression statement list.
 */
ForUpdate
	= stmtList:StatementExpressionList { return stmtList; }

/*
 * A return statement has to start with the keyword "return" followed by an
 * optional expression and a mandatory semicolon.
 */
ReturnStatement
	= "return" exp:(___ Expression)? __ ";"
		{
			return exp != null ? new PCReturnStmt(line(), column(), exp[1]) :
				new PCReturnStmt(line(), column());
		}

/*
 * Primitive statements are:
 * - The join statement for joining agents.
 * - The lock statement for locking code parts.
 * - The unlock statement for unlocking code parts.
 * - The wait for condition statement for waiting for a signal to occur.
 * - The signal statement for firing a signal for exactly one waiting agent.
 * - The signal all statement for firing signals for all waiting agents.
 */
PrimitiveStatement
	= "join" __ "(" __ exp:Expression __ ")" __ ";"
		{
			return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.JOIN,
				exp);
		}
	/ "lock" __ "(" __ exp:Expression __ ")" __ ";"
		{
			return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.LOCK,
				exp);
		}
	/ "unlock" __ "(" __ exp:Expression __ ")" __ ";"
		{
			return new PCPrimitiveStmt(line(), column(),
				PCPrimitiveStmt.UNLOCK, exp);
		}
	/ "waitForCondition" __ "(" __ exp:Expression __ ")" __ ";"
		{
			return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.WAIT,
				exp);
		}
	/ "signal" __ "(" __ exp:Expression __ ")" __ ";"
		{
			return new PCPrimitiveStmt(line(), column(),
				PCPrimitiveStmt.SIGNAL, exp);
		}
	/ "signalAll" __ "(" exp:(__ Expression)? __ ")" __ ";"
		{
			return exp != null ?
				new PCPrimitiveStmt(line(), column(),
					PCPrimitiveStmt.SIGNAL_ALL, exp[1]) :
				new PCPrimitiveStmt(line(), column(),
					PCPrimitiveStmt.SIGNAL_ALL);
		}

/*
 * The print line statement print a single line and start with the keyword
 * "println" followed by a expression list (with parenthesis) and a semicolon.
 */
Println
	= "println" __ "(" __ expList:ExpressionList __ ")" __ ";"
		{
			expList.unshift(line(), column());
			return construct(PCPrintStmt, expList);
		}

/*
 * pseuCo supports the following primitive types:
 * - Channel types.
 * - Boolean type.
 * - Integer type.
 * - String type.
 * - Mutex type. (In version 0.7 of the PseuCoCo projects the type will be
 *   renamed to lock type)
 * - Agent type.
 * - Class types.
 */
PrimitiveType
	= ch:Chan { return ch; }
	/ "bool" { return new PCSimpleType(line(), column(), PCSimpleType.BOOL); }
	/ "int" { return new PCSimpleType(line(), column(), PCSimpleType.INT); }
	/ "string"
		{ return new PCSimpleType(line(), column(), PCSimpleType.STRING); }
	/ "lock" { return new PCSimpleType(line(), column(), PCSimpleType.MUTEX); }
	/ "agent" { return new PCSimpleType(line(), column(), PCSimpleType.AGENT); }
	/ id:Identifier { return new PCClassType(line(), column(), id); }

/*
 * Channel types can be build from integers, boolean and strings.
 */
Chan
	= "intchan" int_:(IntegerLiteral)?
		{
			return new PCChannelType(line(), column(), PCSimpleType.INT,
				int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN);
		}
	/ "boolchan" int_:(IntegerLiteral)?
		{
			return new PCChannelType(line(), column(), PCSimpleType.BOOL,
				int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN);
		}
	/ "stringchan" int_:(IntegerLiteral)?
		{
			return new PCChannelType(line(), column(), PCSimpleType.STRING,
				int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN);
		}

/*
 * For the return type of a procedure there is a special type called void type
 * for indicating that the procedure does not return anything. Otherwise the
 * normal type are available.
 */
ResultType
	= "void" { return new PCSimpleType(line(), column(), PCSimpleType.VOID); }
	/ type:Type { return type; }

/*
 * Possible expressions are:
 * - Start expressions.
 * - Assignments.
 * - Send expressions.
 * - Conditional expressions (see below).
 */
Expression
	= exp:StartExpression { return exp; }
	/ exp:AssignmentExpression { return exp; }
	/ exp:SendExpression { return exp; }
	/ exp:ConditionalExpression { return exp; }

/*
 * Start an agent. Starts with the keyword "start" followed by a procedure call.
 */
StartExpression
	= "start" __ "(" __ exp:(MonCall / ProcCall) __ ")" __
		{ return new PCStartExpression(line(), column(), exp); }

/*
 * Comma separated list of expression.
 */
ExpressionList
	= head:Expression tail:(__ "," __ Expression)*
		{
			var exps = [];
			exps.push(head);
			for (var i = 0; i < tail.length; ++i)
			{
				exps.push(tail[i][3]);
			}
			return exps;
		}

/*
 * Assignments are build out of a destination an operator and an expression.
 */
AssignmentExpression
	= dest:AssignDestination __ op:AssignmentOperator __ exp:Expression
		{ return new PCAssignExpression(line(), column(), dest, op, exp); }

/*
 * The assignment destination has to be an identifier followed by array accesses
 * ([pos1][pos2]...).
 */
AssignDestination
	= id:Identifier pos:(__ "[" Expression "]")*
		{
			var index = [];
			for (var i = pos.length - 1; i >= 0; --i)
			{
				index.push(pos[i][2]);
			}
			index.unshift(id, line(), column());
			return construct(PCAssignDestination, index);
		}

/*
 * Assignment operators are:
 * - plain assignment
 * - multiply destination with expression and assign
 * - divide destination with expression and assign
 * - add destination with expression and assign
 * - subtract destination with expression and assign
 */
AssignmentOperator
	= "=" { return "="; }
	/ "*=" { return "*="; }
	/ "/=" { return "/="; }
	/ "+=" { return "+="; }
	/ "-=" { return "-="; }

/*
 * Expression for sending data (expression) on a channel (call expression). The
 * special operator "<!" is used for this purpose.
 */
SendExpression
	= callExp:CallExpression __ "<!" __ exp:Expression __
		{ return new PCSendExpression(line(), column(), callExp, exp); }

/*
 * The conditional expression is a expression which evaluates to the expression
 * after the question mark if first expression evaluates to true else to the
 * expression after the colon. For recursion purposes the conditional expression
 * may be a conditional or expression. In this case it evaluates to the
 * conditional or expression. This pattern is repeated in the next rules.
 */
ConditionalExpression
	= exp:ConditionalOrExpression rest:(__ "?" __ Expression __ ":" __
		ConditionalExpression)?
		{
			return rest != null ? new PCConditionalExpression(line(), column(),
				exp, rest[3], rest[7]) : exp;
		}

/*
 * Form: expression1 || expression2
 * Evaluates to true if expression1 or expression2 evaluates to true.
 */
ConditionalOrExpression
	= exp:ConditionalAndExpression rest:(__ "||" __ ConditionalAndExpression)*
		{
			var res = exp;
			for (var i = 0; i < rest.length; ++i)
			{
				res = new PCOrExpression(line(), column(), res, rest[i][3]);
			}
			return res;
		}

/*
 * Form: expression1 && expression2
 * Evaluates to true if expression1 and expression2 evaluates to true.
 */
ConditionalAndExpression
	= exp:EqualityExpression rest:(__ "&&" __ EqualityExpression)*
		{
			var res = exp;
			for (var i = 0; i < rest.length; ++i)
			{
				res = new PCAndExpression(line(), column(), res, rest[i][3]);
			}
			return res;
		}

/*
 * Form: expression1 == expression2 or expression1 != expression2
 * Evaluates to true if expression1 is equal to expression2 (former case) or if
 * expression1 is not equal to expression2 (latter case).
 */
EqualityExpression
	= exp:RelationalExpression rest:(__ ("==" / "!=") __ RelationalExpression)*
		{
			var res = exp;
			for (var i = 0; i < rest.length; ++i)
			{
				res = new PCEqualityExpression(line(), column(), res,
					rest[i][1], rest[i][3]);
			}
			return res;
		}

/*
 * Form:
 * (1) expression1 <= expression2 or
 * (2) expression1 < expression2 or
 * (3) expression1 >= expression2 or
 * (4) expression1 > expression2
 * Evaluates to true if:
 * - expression1 is less than or equal to expression2 (1)
 * - expression1 is less than expression2 (2)
 * - expression1 is greater than or equal to expression2 (3)
 * - expression1 is greater than expression2 (4)
 */
RelationalExpression
	= exp:AdditiveExpression rest:(__ ("<=" / "<" / ">=" / ">") __
		AdditiveExpression)*
		{
			var res = exp;
			for (var i = 0; i < rest.length; ++i)
			{
				res = new PCRelationalExpression(line(), column(), res,
					rest[i][1], rest[i][3]);
			}
			return res;
		}

/*
 * Form:
 * (1) expression1 + expression2 or
 * (2) expression1 - expression2
 * Evaluates to:
 * - sum of expression1 and expression2 (1)
 * - difference of expression1 and expression2 (2)
 */
AdditiveExpression
	= exp:MultiplicativeExpression rest:(__ ("+" / "-") __
		MultiplicativeExpression)*
		{
			var res = exp;
			for (var i = 0; i < rest.length; ++i)
			{
				res = new PCAdditiveExpression(line(), column(), res,
					rest[i][1], rest[i][3]);
			}
			return res;
		}

/*
 * Form:
 * (1) expression1 * expression2 or
 * (2) expression1 / expression2 or
 * (3) expression1 % expression2
 * Evaluates to:
 * - product of expression1 and expression2 (1)
 * - quotient of expression1 and expression2 (2)
 * - remainder of expression1 and expression2 (3)
 */
MultiplicativeExpression
	= exp:UnaryExpression rest:(__ ("*" / "/" / "%") __ UnaryExpression)*
		{
			var res = exp;
			for (var i = 0; i < rest.length; ++i)
			{
				res = new PCMultiplicativeExpression(line(), column(), res,
					rest[i][1], rest[i][3]);
			}
			return res;
		}

/*
 * Form:
 * (1) + expression or
 * (2) - expression or
 * (3) ! expression
 * Evaluates to:
 * - expression (1)
 * - inverse of expression (2)
 * - evaluates to true if expression evaluates to false else to false (3)
 */
UnaryExpression
	= op:("+" / "-" / "!") __ exp:UnaryExpression
		{ return new PCUnaryExpression(line(), column(), op, exp); }
	/ exp:ReceiveExpression { return exp; }
	/ exp:PostfixExpression { return exp; }

/*
 * Increment operation: expression++
 * Decrement operation: expression--
 */
PostfixExpression
	= dest:AssignDestination _ op:("++" / "--")
		{ return new PCPostfixExpression(line(), column(), dest, op); }

/*
 * Receives value from channel (call expression) and evaluates to this value.
 */
ReceiveExpression
	= op:(__ "<?")* __  exp:CallExpression __
		{
			var res = exp;
			for (var i = 0; i < op.length; i++)
			{
				res = new PCReceiveExpression(line(), column(), res)
			}
			return res;
		}

/*
 * A call expression is either a procedure call ("procedureName(argument)") or
 * an array access ("variableName[pos1][pos2]...").
 */
CallExpression
	= call:MonCall { return call; }
	/ call:ProcCall { return call; }
	/ call:ArrayExpression { return call; }

/*
 * Procedure call. Evaluates to the value of the returned expression.
 */
ProcCall
	= id:Identifier __ args:Arguments
		{
			args.unshift(id, line(), column());
			return construct(PCProcedureCall, args);
		}

/*
 * Argument list.
 */
Arguments
	= "(" __ expList:(ExpressionList)? __ ")"
		{ return expList != null ? expList : []; }

/*
 * Call member of class type.
 */
MonCall
	= exp:PrimaryExpression call:(_ "." __ ProcCall)+
		{
			var res = new PCClassCall(line(), column(), exp, call[0][3]);
			for (var i = 1; i < call.length; ++i)
			{
				res = new PCClassCall(line(), column(), res, call[i][3]);
			}
			return res;
		}

/*
 * Access array at specified position.
 */
ArrayExpression
	= exp:PrimaryExpression call:(__ "[" Expression "]")*
		{
			var res = exp;
			for (var i = call.length - 1; i >= 0; --i)
			{
				res = new PCArrayExpression(line(), column(), res, call[i][2]);
			}
			return res;
		}

/*
 * Primary expression are either literals, identifier or a pair of parenthesis
 * containing an expression.
 */
PrimaryExpression
	= exp:Literal { return new PCLiteralExpression(line(), column(), exp); }
	/ exp:Identifier
		{ return new PCIdentifierExpression(line(), column(), exp); }
	/ "(" __ exp:Expression __ ")" { return exp; }
