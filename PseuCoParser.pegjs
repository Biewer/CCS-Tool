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

start
	= __ program:Program __ EOF { return program; }

SourceCharacter
	= .

WhiteSpace "whitespace"
	= [ \t\v\f] {}

LineTerminator
	= [\n\r] {}

LineTerminatorSequence "end of line"
	= "\n" {}
	/ "\r\n" {}
	/ "\r" {}

Comment "comment"
	= MultiLineComment {}
	/ FormalComment {}
	/ SingleLineComment {}

MultiLineComment
	= "/*" (!"*/" SourceCharacter)* "*/" {}

MultiLineCommentNoLineTerminator
	= "/*" (!("*/" / LineTerminator) SourceCharacter)* "*/" {}

FormalComment
	= "/**" (!"*/" SourceCharacter)* "*/" {}

SingleLineComment
	= "//" (!LineTerminator SourceCharacter)* {}
_
	= (WhiteSpace / MultiLineCommentNoLineTerminator / SingleLineComment)* {}

__
	= (WhiteSpace / LineTerminatorSequence / Comment)* {}

EOF
	= !. {}

IntegerLiteral "integer"
	= "0" { return "0"; }
	/ head:[1-9] tail:([0-9])* { return head + tail.join(""); }

StringLiteral "string"
	= stringLiteral:('"' StringCharacters? '"') { return stringLiteral.join(""); }

StringCharacters
	= chars:StringCharacter+ { return chars.join(""); }

StringCharacter
	= !('"' / "\\" / LineTerminator) char_:SourceCharacter { return char_; }
	/ "\\" seq:EscapeSequence { return "\\" + seq; }
	/ con:LineContinuation { return con; }

LineContinuation
	= "\\" seq:LineTerminatorSequence { return seq; }

EscapeSequence
	= seq:CharacterEscapeSequence { return seq; }
	/ seq:OctalEscapeSequence { return seq; }

CharacterEscapeSequence
	= char_:['"\\bfnrtv] { return char_; }

OctalEscapeSequence
	= first:[0-7] second:([0-7])? { return first + (second != null ? second : ""); }
	/ first:[0-3] second:[0-7] third:[0-7] { return first + second + third; }

Identifier "identifier"
	= head:Letter tail:(Letter / Digit)* { return head + tail.join(""); }

Letter
	= letter:[$A-Z_a-z\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u00ff\u0100-\u1fff\u3040-\u318f\u3300-\u337f\u3400-\u3d2d\u4e00-\u9fff\uf900-\ufaff] { return letter; }

Digit
	= digit:[0-9\u0660-\u0669\u06f0-\u06f9\u0966-\u096f\u09e6-\u09ef\u0a66-\u0a6f\u0ae6-\u0aef\u0b66-\u0b6f\u0be7-\u0bef\u0c66-\u0c6f\u0ce6-\u0cef\u0d66-\u0d6f\u0e50-\u0e59\u0ed0-\u0ed9\u1040-\u1049] { return digit; }

Program
	= source:SourceElements { return construct(PCProgram, source); }
	
SourceElements
	= head:SourceElement tail:(__ SourceElement)*	{
														var elements = [];
														elements.push(head);
														for (var i = 0; i < tail.length; ++i)
														{
															elements.push(tail[i][1]);
														}
														return elements;
													}

SourceElement
	= elem:Monitor { return elem; }
	/ elem:Struct { return elem; }
	/ elem:MainAgent { return elem; }
	/ elem:Procedure { return elem; }
	/ elem:DeclarationStatement { return elem; }

Monitor
	= "monitor" _ id:Identifier __ "{" __ code:MonitorCode __ "}"	{
																		code.unshift(id);
																		return construct(PCMonitor, code);
																	}

MonitorCode
	= code:((Procedure / ConditionDeclarationStatement / DeclarationStatement) __)*	{
																						var declarations = [];
																						for (var i = 0; i < code.length; ++i)
																						{
																							declarations.push(code[i][0]);
																						}
																						return declarations;
																					}

MainAgent
	= "mainAgent" __ stmtBlock:StatementBlock { return new PCMainAgent(stmtBlock); }

Procedure
	= type:ResultType _ id:Identifier _ fp:FormalParameters __ stmtBlock:StatementBlock	{
																							fp.unshift(type, id, stmtBlock);
																							return construct(PCProcedureDecl, fp);
																						}

FormalParameters
	= "(" __ test:(FormalParameter (__ "," __ FormalParameter)*)? __ ")"	{
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

FormalParameter
	= type:Type _ id:Identifier { return new PCFormalParameter(type, id); } 

Struct
	= "struct" _ id:Identifier __ "{" __ code:StructCode "}"	{
																	code.unshift(id);
																	return construct(PCStruct, code);
																}

StructCode
	= decls:(Procedure / DeclarationStatement __)*	{
														var declarations = [];
														for (var i = 0; i < decls.length; ++i)
														{
															declarations.push(decls[i][0]);
														}
														return declarations;
													}

ConditionDeclarationStatement
	= "condition" _ id:Identifier _ "with" _ exp:Expression _ ";" { return new PCConditionDecl(id, exp); }

DeclarationStatement
	= decl:Declaration _ ";"	{
									decl.isStatement = true;
									return decl;
								}

Declaration
	= type:Type _ head:VariableDeclarator tail:(__ "," __ VariableDeclarator)*	{
																					var declarations = [];
																					declarations.push(false, type, head);
																					for (var i = 0; i < tail.length; ++i)
																					{
																						declarations.push(tail[i][3]);
																					}
																					return construct(PCDecl, declarations);
																				}

VariableDeclarator
	= id:Identifier varInit:(_ "=" _ VariableInitializer)? { return varInit != null ? new PCVariableDeclarator(id, varInit[3]) : new PCVariableDeclarator(id); }

VariableInitializer
	= "{" __ test:(VariableInitializer (__ ","  __ VariableInitializer)*)? uncomplete:(__ "," __)? __ "}"	{
																												if (test != null)
																												{
																													var inits = [];
																													inits.push(test[0]);
																													for (var i = 0; i < test[1].length; ++i)
																													{
																														inits.push(test[1][i][3]);
																													}
																													return new PCVariableInitializer(uncomplete != null, inits);
																												}
																												else
																												{
																													return new PCVariableInitializer(uncomplete != null);
																												}
																											}
	/ exp:Expression { return new PCVariableInitializer(false, exp); }

Type
	= type:PrimitiveType ranges:("[" IntegerLiteral "]")*	{
																var res = type;
																for (var i = 0; i < ranges.length; ++i)
																{
																	res = new PCArrayType(res, ranges[i][1]);
																}
																return res;
															}

PrimitiveType
	= "bool" { return new PCSimpleType(PCSimpleType.BOOL); }
	/ "int" { return new PCSimpleType(PCSimpleType.INT); }
	/ "string" { return new PCSimpleType(PCSimpleType.INT); }
	/ "mutex" { return new PCSimpleType(PCSimpleType.MUTEX); }
	/ "agent" { return new PCSimpleType(PCSimpleType.AGENT); }
	/ ch:Chan { return ch; }
	/ id:Identifier { return new PCClassType(id); }

Chan
	= "intchan" int_:(IntegerLiteral)? { return new PCChannelType(PCSimpleType.INT, int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN); }
	/ "boolchan" int_:(IntegerLiteral)? { return new PCChannelType(PCSimpleType.BOOL, int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN); }
	/ "stringchan" int_:(IntegerLiteral)? { return new PCChannelType(PCSimpleType.STRING, int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN); }

ResultType
	= "void" { return new PCSimpleType(PCSimpleType.VOID); }
	/ type:Type { return type; }

Expression
	= exp:AssignmentExpression { return exp; }
	/ exp:StartExpression { return exp; }
	/ exp:SendExpression { return exp; }
	/ exp:ConditionalExpression { return exp; }

StartExpression
	= "start" _ exp:(MonCall / ProcCall) { return new PCStartExpression(exp); }

ExpressionList
	= head:Expression tail:(__ "," __ Expression)*	{
														var exps = [];
														exps.push(head);
														for (var i = 0; i < tail.length; ++i)
														{
															exps.push(tail[i][3]);
														}
														return exps;
													}

AssignmentExpression
	= dest:AssignDestination _ op:AssignmentOperator _ exp:Expression { return new PCAssignExpression(dest, op, exp); }

AssignDestination
	= id:Identifier pos:("[" Expression "]")*	{
													var ind = [];
													for (var i = 0; i < pos.length; ++i)
													{
														ind.push(pos[i][1]);
													}
													return new PCAssignDestination(id, ind);
												}

AssignmentOperator
	= "=" { return "="; }
	/ "*=" { return "*="; }
	/ "/=" { return "/="; }
	/ "+=" { return "+="; }
	/ "-=" { return "-="; }

SendExpression
	= callExp:CallExpression _ "<!" _ exp:Expression { return new PCSendExpression(callExp, exp); }

ConditionalExpression
	= exp:ConditionalOrExpression rest:(_ "?" _ Expression _ ":" _ ConditionalExpression)? { return rest != null ? new PCConditionalExpression(exp, rest[3], rest[7]) : exp; }

ConditionalOrExpression
	= exp:ConditionalAndExpression rest:(_ "||" _ ConditionalAndExpression)*	{
																					var res = exp;
																					for (var i = 0; i < rest.length; ++i)
																					{
																						res = new PCOrExpression(res, rest[i][3]);
																					}
																					return res;
																				}

ConditionalAndExpression
	= exp:EqualityExpression rest:(_ "&&" _ EqualityExpression)*	{
																		var res = exp;
																		for (var i = 0; i < rest.length; ++i)
																		{
																			res = new PCAndExpression(res, rest[i][3]);
																		}
																		return res;
																	}

EqualityExpression
	= exp:RelationalExpression rest:(_ ("==" / "!=") _ RelationalExpression)*	{
																					var res = exp;
																					for (var i = 0; i < rest.length; ++i)
																					{
																						res = new PCEqualityExpression(res, rest[i][1], rest[i][3]);
																					}
																					return res;
																				}

RelationalExpression
	= exp:AdditiveExpression rest:(_ ("<=" / "<" / ">=" / ">") _ AdditiveExpression)*	{
																							var res = exp;
																							for (var i = 0; i < rest.length; ++i)
																							{
																								res = new PCRelationalExpression(res, rest[i][1], rest[i][3]);
																							}
																							return res;
																						}

AdditiveExpression
	= exp:MultiplicativeExpression rest:(_ ("+" / "-") _ MultiplicativeExpression)*	{
																						var res = exp;
																						for (var i = 0; i < rest.length; ++i)
																						{
																							res = new PCAdditiveExpression(res, rest[i][1], rest[i][3]);
																						}
																						return res;
																					}

MultiplicativeExpression
	= exp:UnaryExpression rest:(_ ("*" / "/" / "%") _ UnaryExpression)*	{
																			var res = exp;
																			for (var i = 0; i < rest.length; ++i)
																			{
																				res = new PCMultiplicative(res, rest[i][1], rest[i][3]);
																			}
																			return res;
																		}

UnaryExpression
	= op:("+" / "-" / "!") _ exp:UnaryExpression { return new PCUnaryExpression(op, exp); }
	/ exp:ReceiveExpression { return exp; }
	/ exp:PostfixExpression { return exp; }

PostfixExpression
	= dest:AssignDestination op:("++" / "--") { return new PCPostfixExpression(dest, op); }

ReceiveExpression
	= op:(_ "<?")* _  exp:CallExpression { return op.length > 0 ? new PCReceiveExpression(exp) : exp; }

CallExpression
	= call:MonCall { return call; }
	/ call:ProcCall { return call; }
	/ call:ArrayExpression { return call; }

ProcCall
	= id:Identifier _ args:Arguments { return new PCProcedureCall(id, args); }

Arguments
	= "(" _ expList:(ExpressionList)? _ ")" { return expList != null ? expList : []; }

MonCall
	= exp:PrimaryExpression call:("." ProcCall)+	{
														var res = new PCClassCall(exp, call[0][1]);
														for (var i = 1; i < call.length; ++i)
														{
															res = new PCClassCall(res, call[i][1]);
														}
														return res;
													}

ArrayExpression
	= exp:PrimaryExpression call:("[" Expression "]")*	{
															var res = exp;
															for (var i = 0; i < call.length; ++i)
															{
																res = new PCArrayExpression(res, call[i][1]);
															}
															return res;
														}

PrimaryExpression
	= exp:Literal { return new PCLiteralExpression(exp); }
	/ exp:Identifier { return new PCIdentifierExpression(exp); }
	/ "(" exp:Expression ")" { return exp; }

Literal
	= literal:IntegerLiteral { return literal; }
	/ literal:StringLiteral { return literal; }
	/ literal:BooleanLiteral { return literal; }

BooleanLiteral
	= "true" { return true; }
	/ "false" { return false; }

StatementBlock
	= "{" __ blockStmts:(BlockStatement __)* "}"	{
														var stmts = [];
														for (var i = 0; i < blockStmts.length; ++i)
														{
															stmts.push(blockStmts[i][0]);
														}
														return construct(PCStmtBlock, stmts);
													}

BlockStatement
	= stmt:Statement { return stmt; }
	/ stmt:Procedure { return stmt; }
	/ stmt:DeclarationStatement { return new PCStatement(stmt); }
	/ stmt:ConditionDeclarationStatement { return stmt; }

Statement
	= stmt:StatementBlock { return new PCStatement(stmt); }
	/ stmt:StatementExpression ";" { return new PCStatement(stmt); }
	/ stmt:SelectStatement { return new PCStatement(stmt); }
	/ stmt:IfStatement { return new PCStatement(stmt); }
	/ stmt:WhileStatement { return new PCStatement(stmt); }
	/ stmt:DoStatement { return new PCStatement(stmt); }
	/ stmt:ForStatement { return new PCStatement(stmt); }
	/ "break" _ ";" { return new PCStatement(new PCBreakStmt()); }
	/ "continue" _ ";" { return new PCStatement(new PCContinueStmt()); }
	/ stmt:ReturnStatement { return new PCStatement(stmt); }
	/ stmt:PrimitiveStatement { return new PCStatement(stmt); }
	/ stmt:Println { return new PCStatement(stmt); }
	/ _ ";" { return new PCStatement(); }

StatementExpression
	= stmtExp:AssignmentExpression { return new PCStmtExpression(stmtExp); }
	/ stmtExp:SendExpression { return new PCStmtExpression(stmtExp); }
	/ stmtExp:PostfixExpression { return new PCStmtExpression(stmtExp); }
	/ stmtExp:CallExpression { return new PCStmtExpression(stmtExp); }
	/ stmtExp:ReceiveExpression { return new PCStmtExpression(stmtExp); }
	/ stmtExp:StartExpression { return new PCStmtExpression(stmtExp); }

StatementExpressionList
	= head:StatementExpression tail:(__ "," __ StatementExpression)*	{
																			var stmts = [];
																			stmts.push(head);
																			for (var i = 0; i < tail.length; ++i)
																			{
																				stmts.push(tail[i][3]);
																			}
																			return stmts;
																		}

SelectStatement
	= "select" __ "{" __ stmts:(CaseStatement)+ __ "}"	{
															var caseStmts = [];
															for (var i = 0; i < stmts.length; ++i)
															{
																caseStmts.push(stmts[i]);
															}
															return construct(PCSelectStmt, caseStmts);
														}

CaseStatement
	= "case" _ exp:StatementExpression _ ":" __ stmt:Statement { return new PCCase(stmt, exp); }
	/ "default" _ ":" __ stmt:Statement { return new PCCase(stmt); }

IfStatement
	= "if" _ "(" _ exp:Expression _ ")" __ ifStmt:Statement __ test:("else" __ Statement)? { return test != null ? new PCIfStmt(exp, ifStmt, test[2]) : new PCIfStmt(exp, ifStmt); }

WhileStatement
	= "while" _ "(" _ exp:Expression _ ")" __ stmt:Statement { return new PCWhileStmt(exp, stmt); }

DoStatement
	= "do" __ stmt:Statement __ "while" _ "(" _ exp:Expression _ ")" _ ";" { return new PCDoStmt(stmt, exp); }

ForStatement
	= "for" _ "(" _ init:(ForInit)? _ ";" _ exp:(Expression)? _ ";" _ update:(ForUpdate)? _ ")" __ stmt:Statement	{
																														var res = [];
																														if (update != null)
																														{
																															res = res.concat(update);
																														}
																														res.unshift(stmt, init, exp);
																														return construct(PCForStmt, res);
																													}

ForInit
	= head:(Declaration / StatementExpression) tail:(_ "," _ (Declaration / StatementExpression))*	{
																										var inits = [];
																										inits.push(head);
																										for (var i = 0; i < tail.length; ++i)
																										{
																											inits.push(tail[i][3]);
																										}
																										return construct(PCForInit, inits);
																									}

ForUpdate
	= stmtList:StatementExpressionList { return stmtList; }

ReturnStatement
	= "return" _ exp:(Expression)? _ ";" { return exp != null ? new PCReturnStmt(exp) : new PCReturnStatement(); }

PrimitiveStatement
	= "join" _ exp:Expression _ ";" { return new PCPrimitiveStmt(PCPrimitiveStmt.JOIN, exp); }
	/ "lock" _ exp:Expression _ ";" { return new PCPrimitiveStmt(PCPrimitiveStmt.LOCK, exp); }
	/ "unlock" _ exp:Expression _ ";" { return new PCPrimitiveStmt(PCPrimitiveStmt.UNLOCK, exp); }
	/ "waitForCondition" _ exp:Expression _ ";" { return new PCPrimitiveStmt(PCPrimitiveStmt.WAIT, exp); }
	/ "signal" _ exp:Expression _ ";" { return new PCPrimitiveStmt(PCPrimitiveStmt.SIGNAL, exp); }
	/ "signalAll" _ exp:(Expression)? _ ";" { return exp != null ? new PCPrimitiveStmt(PCPrimitiveStmt.SIGNAL_ALL, exp) : new PCPrimitiveStmt(PCPrimitiveStmt.SIGNAL_ALL); }

Println
	= "println" _ "(" _ expList:ExpressionList _ ")" _ ";" { return new PCPrintStmt(expList); }
