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

___
	= (WhiteSpace / LineTerminatorSequence / SingleLineComment)+ {}

EOF
	= !. {}

IntegerLiteral "integer"
	= "0" { return 0; }
	/ head:[1-9] tail:([0-9])* { return parseInt(head + tail.join(""), 10); }

StringLiteral "string"
	= stringLiteral:('"' StringCharacters? '"') { return stringLiteral[1] != null ? stringLiteral[1] : ""; }

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
	= letter:[A-Z_a-z\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u00ff\u0100-\u1fff\u3040-\u318f\u3300-\u337f\u3400-\u3d2d\u4e00-\u9fff\uf900-\ufaff] { return letter; }

Digit
	= digit:[0-9\u0660-\u0669\u06f0-\u06f9\u0966-\u096f\u09e6-\u09ef\u0a66-\u0a6f\u0ae6-\u0aef\u0b66-\u0b6f\u0be7-\u0bef\u0c66-\u0c6f\u0ce6-\u0cef\u0d66-\u0d6f\u0e50-\u0e59\u0ed0-\u0ed9\u1040-\u1049] { return digit; }

Program
	= source:SourceElements	{
								source.unshift(line(), column());
								return construct(PCProgram, source);
							}
	
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
	= "monitor" ___ id:Identifier __ "{" __ code:ClassCode __ "}"	{
																		code.unshift(id, line(), column());
																		return construct(PCMonitor, code);
																	}

Struct
	= "struct" ___ id:Identifier __ "{" __ code:ClassCode "}"	{
																	code.unshift(id, line(), column());
																	return construct(PCStruct, code);
																}

ClassCode
	= code:((Procedure / ConditionDeclarationStatement / DeclarationStatement) __)*	{
																						var declarations = [];
																						for (var i = 0; i < code.length; ++i)
																						{
																							declarations.push(code[i][0]);
																						}
																						return declarations;
																					}

MainAgent
	= "mainAgent" __ stmtBlock:StatementBlock { return new PCMainAgent(line(), column(), stmtBlock); }

Procedure
	= type:ResultType ___ id:Identifier __ fp:FormalParameters __ stmtBlock:StatementBlock	{
																								fp.unshift(line(), column(), type, id, stmtBlock);
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
	= type:Type ___ id:Identifier	{ return new PCFormalParameter(line(), column(), type, id); }

ConditionDeclarationStatement
	= "condition" ___ id:Identifier __ "with" ___ exp:Expression __ ";" { return new PCConditionDecl(line(), column(), id, exp); }

DeclarationStatement
	= decl:Declaration __ ";"	{
									decl.isStatement = true;
									return decl;
								}

Declaration
	= type:Type ___ head:VariableDeclarator tail:(__ "," __ VariableDeclarator)*	{
																						var declarations = [];
																						declarations.push(false, line(), column(), type, head);
																						for (var i = 0; i < tail.length; ++i)
																						{
																							declarations.push(tail[i][3]);
																						}
																						return construct(PCDecl, declarations);
																					}

VariableDeclarator
	= id:Identifier varInit:(__ "=" __ VariableInitializer)? { return varInit != null ? new PCVariableDeclarator(line(), column(), id, varInit[3]) : new PCVariableDeclarator(line(), column(), id); }

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
																													inits.unshift(line(), column(), uncomplete != null)
																													return construct(PCVariableInitializer, inits);
																												}
																												else
																												{
																													return new PCVariableInitializer(line(), column(), uncomplete != null);
																												}
																											}
	/ exp:Expression { return new PCVariableInitializer(line(), column(), false, exp); }

Type
	= type:PrimitiveType ranges:(__ "[" IntegerLiteral "]")*	{
																	var res = type;
																	for (var i = ranges.length - 1; i >= 0; --i)
																	{
																		res = new PCArrayType(line(), column(), res, ranges[i][2]);
																	}
																	return res;
																}

PrimitiveType
	= ch:Chan { return ch; }
	/ "bool" { return new PCSimpleType(line(), column(), PCSimpleType.BOOL); }
	/ "int" { return new PCSimpleType(line(), column(), PCSimpleType.INT); }
	/ "string" { return new PCSimpleType(line(), column(), PCSimpleType.STRING); }
	/ "mutex" { return new PCSimpleType(line(), column(), PCSimpleType.MUTEX); }
	/ "agent" { return new PCSimpleType(line(), column(), PCSimpleType.AGENT); }
	/ id:Identifier { return new PCClassType(line(), column(), id); }

Chan
	= "intchan" int_:(IntegerLiteral)? { return new PCChannelType(line(), column(), PCSimpleType.INT, int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN); }
	/ "boolchan" int_:(IntegerLiteral)? { return new PCChannelType(line(), column(), PCSimpleType.BOOL, int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN); }
	/ "stringchan" int_:(IntegerLiteral)? { return new PCChannelType(line(), column(), PCSimpleType.STRING, int_ != null ? int_ : PCChannelType.CAPACITY_UNKNOWN); }

ResultType
	= "void" { return new PCSimpleType(line(), column(), PCSimpleType.VOID); }
	/ type:Type { return type; }

Expression
	= exp:StartExpression { return exp; }
	/ exp:AssignmentExpression { return exp; }
	/ exp:SendExpression { return exp; }
	/ exp:ConditionalExpression { return exp; }

StartExpression
	= "start" ___ exp:(MonCall / ProcCall) { return new PCStartExpression(line(), column(), exp); }

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
	= dest:AssignDestination __ op:AssignmentOperator __ exp:Expression { return new PCAssignExpression(line(), column(), dest, op, exp); }

AssignDestination
	= id:Identifier pos:(__ "[" Expression "]")*	{
														var index = [];
														for (var i = pos.length - 1; i >= 0; --i)
														{
															index.push(pos[i][2]);
														}
														index.unshift(id, line(), column());
														return construct(PCAssignDestination, index);
													}

AssignmentOperator
	= "=" { return "="; }
	/ "*=" { return "*="; }
	/ "/=" { return "/="; }
	/ "+=" { return "+="; }
	/ "-=" { return "-="; }

SendExpression
	= callExp:CallExpression __ "<!" __ exp:Expression __ { return new PCSendExpression(line(), column(), callExp, exp); }

ConditionalExpression
	= exp:ConditionalOrExpression rest:(__ "?" __ Expression __ ":" __ ConditionalExpression)? { return rest != null ? new PCConditionalExpression(line(), column(), exp, rest[3], rest[7]) : exp; }

ConditionalOrExpression
	= exp:ConditionalAndExpression rest:(__ "||" __ ConditionalAndExpression)*	{
																					var res = exp;
																					for (var i = 0; i < rest.length; ++i)
																					{
																						res = new PCOrExpression(line(), column(), res, rest[i][3]);
																					}
																					return res;
																				}

ConditionalAndExpression
	= exp:EqualityExpression rest:(__ "&&" __ EqualityExpression)*	{
																		var res = exp;
																		for (var i = 0; i < rest.length; ++i)
																		{
																			res = new PCAndExpression(line(), column(), res, rest[i][3]);
																		}
																		return res;
																	}

EqualityExpression
	= exp:RelationalExpression rest:(__ ("==" / "!=") __ RelationalExpression)*	{
																					var res = exp;
																					for (var i = 0; i < rest.length; ++i)
																					{
																						res = new PCEqualityExpression(line(), column(), res, rest[i][1], rest[i][3]);
																					}
																					return res;
																				}

RelationalExpression
	= exp:AdditiveExpression rest:(__ ("<=" / "<" / ">=" / ">") __ AdditiveExpression)*	{
																							var res = exp;
																							for (var i = 0; i < rest.length; ++i)
																							{
																								res = new PCRelationalExpression(line(), column(), res, rest[i][1], rest[i][3]);
																							}
																							return res;
																						}

AdditiveExpression
	= exp:MultiplicativeExpression rest:(__ ("+" / "-") __ MultiplicativeExpression)*	{
																							var res = exp;
																							for (var i = 0; i < rest.length; ++i)
																							{
																								res = new PCAdditiveExpression(line(), column(), res, rest[i][1], rest[i][3]);
																							}
																							return res;
																						}

MultiplicativeExpression
	= exp:UnaryExpression rest:(__ ("*" / "/" / "%") __ UnaryExpression)*	{
																				var res = exp;
																				for (var i = 0; i < rest.length; ++i)
																				{
																					res = new PCMultiplicativeExpression(line(), column(), res, rest[i][1], rest[i][3]);
																				}
																				return res;
																			}

UnaryExpression
	= op:("+" / "-" / "!") __ exp:UnaryExpression { return new PCUnaryExpression(line(), column(), op, exp); }
	/ exp:ReceiveExpression { return exp; }
	/ exp:PostfixExpression { return exp; }

PostfixExpression
	= dest:AssignDestination _ op:("++" / "--") { return new PCPostfixExpression(line(), column(), dest, op); }

ReceiveExpression
	= op:(__ "<?")* __  exp:CallExpression __	{
													var res = exp;
													for (var i = 0; i < op.length; i++)
													{
														res = new PCReceiveExpression(line(), column(), res)
													}
													return res;
												}

CallExpression
	= call:MonCall { return call; }
	/ call:ProcCall { return call; }
	/ call:ArrayExpression { return call; }

ProcCall
	= id:Identifier __ args:Arguments	{
											args.unshift(id, line(), column());
											return construct(PCProcedureCall, args);
										}

Arguments
	= "(" __ expList:(ExpressionList)? __ ")" { return expList != null ? expList : []; }

MonCall
	= exp:PrimaryExpression call:(_ "." __ ProcCall)+	{
															var res = new PCClassCall(line(), column(), exp, call[0][3]);
															for (var i = 1; i < call.length; ++i)
															{
																res = new PCClassCall(line(), column(), res, call[i][3]);
															}
															return res;
														}

ArrayExpression
	= exp:PrimaryExpression call:(__ "[" Expression "]")*	{
																var res = exp;
																for (var i = call.length - 1; i >= 0; --i)
																{
																	res = new PCArrayExpression(line(), column(), res, call[i][2]);
																}
																return res;
															}

PrimaryExpression
	= exp:Literal { return new PCLiteralExpression(line(), column(), exp); }
	/ exp:Identifier { return new PCIdentifierExpression(line(), column(), exp); }
	/ "(" __ exp:Expression __ ")" { return exp; }

Literal
	= literal:IntegerLiteral { return literal; }
	/ literal:StringLiteral { return literal; }
	/ literal:BooleanLiteral { return literal; }

BooleanLiteral
	= "true" { return true; }
	/ "false" { return false; }

StatementBlock
	= "{" __ blockStmts:(BlockStatement __)* "}"	{
														var stmts = [line(), column()];
														for (var i = 0; i < blockStmts.length; ++i)
														{
															stmts.push(blockStmts[i][0]);
														}
														return construct(PCStmtBlock, stmts);
													}

BlockStatement
	= stmt:Statement { return stmt; }
	/ stmt:Procedure { return stmt; }
	/ stmt:DeclarationStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:ConditionDeclarationStatement { return stmt; }

Statement
	= stmt:StatementBlock { return new PCStatement(line(), column(), stmt); }
	/ stmt:Println { return new PCStatement(line(), column(), stmt); }
	/ stmt:SelectStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:IfStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:WhileStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:DoStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:ForStatement { return new PCStatement(line(), column(), stmt); }
	/ "break" __ ";" { return new PCStatement(line(), column(), new PCBreakStmt(line(), column())); }
	/ "continue" __ ";" { return new PCStatement(line(), column(), new PCContinueStmt(line(), column())); }
	/ stmt:ReturnStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:PrimitiveStatement { return new PCStatement(line(), column(), stmt); }
	/ stmt:StatementExpression __ ";" { return new PCStatement(line(), column(), stmt); }
	/ __ ";" { return new PCStatement(line(), column()); }

StatementExpression
	= stmtExp:StartExpression { return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:AssignmentExpression { return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:SendExpression { return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:PostfixExpression { return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:CallExpression { return new PCStmtExpression(line(), column(), stmtExp); }
	/ stmtExp:ReceiveExpression { return new PCStmtExpression(line(), column(), stmtExp); }

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
	= "select" __ "{" __ stmts:(CaseStatement __ )+ __ "}"	{
																var caseStmts = [line(), column()];
																for (var i = 0; i < stmts.length; ++i)
																{
																	caseStmts.push(stmts[i][0]);
																}
																return construct(PCSelectStmt, caseStmts);
															}

CaseStatement
	= "case" ___ exp:StatementExpression __ ":" __ stmt:Statement { return new PCCase(line(), column(), stmt, exp); }
	/ "default" __ ":" __ stmt:Statement { return new PCCase(line(), column(), stmt); }

IfStatement
	= "if" __ "(" __ exp:Expression __ ")" __ ifStmt:Statement __ test:("else" __ Statement)? { return test != null ? new PCIfStmt(line(), column(), exp, ifStmt, test[2]) : new PCIfStmt(line(), column(), exp, ifStmt); }

WhileStatement
	= "while" __ "(" __ exp:Expression __ ")" __ stmt:Statement { return new PCWhileStmt(line(), column(), exp, stmt); }

DoStatement
	= "do" __ stmt:Statement __ "while" __ "(" __ exp:Expression __ ")" __ ";" { return new PCDoStmt(line(), column(), stmt, exp); }

ForStatement
	= "for" __ "(" __ init:(ForInit)? __ ";" __ exp:(Expression)? __ ";" __ update:(ForUpdate)? __ ")" __ stmt:Statement	{
																																var res = [];
																																if (update != null)
																																{
																																	res = res.concat(update);
																																}
																																res.unshift(line(), column(), stmt, init, exp);
																																return construct(PCForStmt, res);
																															}

ForInit
	= head:(Declaration / StatementExpression) tail:(__ "," __ (Declaration / StatementExpression))*	{
																											var inits = [line(), column()];
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
	= "return" exp:(___ Expression)? __ ";" { return exp != null ? new PCReturnStmt(line(), column(), exp[1]) : new PCReturnStmt(line(), column()); }

PrimitiveStatement
	= "join" ___ exp:Expression __ ";" { return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.JOIN, exp); }
	/ "lock" ___ exp:Expression __ ";" { return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.LOCK, exp); }
	/ "unlock" ___ exp:Expression __ ";" { return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.UNLOCK, exp); }
	/ "waitForCondition" ___ exp:Expression __ ";" { return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.WAIT, exp); }
	/ "signal" ___ exp:Expression __ ";" { return new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.SIGNAL, exp); }
	/ "signalAll" exp:(___ Expression)? __ ";" { return exp != null ? new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.SIGNAL_ALL, exp[1]) : new PCPrimitiveStmt(line(), column(), PCPrimitiveStmt.SIGNAL_ALL); }

Println
	= "println" __ "(" __ expList:ExpressionList __ ")" __ ";"	{
																	expList.unshift(line(), column());
																	return construct(PCPrintStmt, expList);
																}
