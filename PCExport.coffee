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

exports = if module and module.exports then module.exports else {}

exports["parser"] = PseuCoParser

exports["EnvironmentController"] = PCTEnvironmentController
exports["EnvironmentNode"] = PCTEnvironmentNode
exports["Class"] = PCTClass
exports["Procedure"] = PCTProcedure
exports["Variable"] = PCTVariable

exports["Type"] = PCTType
exports["ArrayType"] = PCTArrayType
exports["ChannelType"] = PCTChannelType
exports["ClassType"] = PCTClassType
exports["ProcedureType"] = PCTProcedureType
exports["TypeType"] = PCTTypeType

exports["Node"] = PCNode
exports["Program"] = PCProgram
exports["MainAgent"] = PCMainAgent
exports["ProcedureDecl"] = PCProcedureDecl
exports["FormalParameter"] = PCFormalParameter
exports["Monitor"] = PCMonitor
exports["Struct"] = PCStruct
exports["ConditionDecl"] = PCConditionDecl
exports["Decl"] = PCDecl
exports["DeclStmt"] = PCDeclStmt
exports["VariableDeclarator"] = PCVariableDeclarator
exports["VariableInitializer"] = PCVariableInitializer
exports["ArrayTypeNode"] = PCArrayType
exports["BaseTypeNode"] = PCBaseType
exports["SimpleTypeNode"] = PCSimpleType
exports["ChannelTypeNode"] = PCChannelType
exports["ClassTypeNode"] = PCClassType
exports["Expression"] = PCExpression
exports["StartExpression"] = PCStartExpression
exports["AssignExpression"] = PCAssignExpression
exports["AssignDestination"] = PCAssignDestination
exports["SendExpression"] = PCSendExpression
exports["ConditionalExpression"] = PCConditionalExpression
exports["OrExpression"] = PCOrExpression
exports["AndExpression"] = PCAndExpression
exports["EqualityExpression"] = PCEqualityExpression
exports["RelationalExpression"] = PCRelationalExpression
exports["AdditiveExpression"] = PCAdditiveExpression
exports["MultiplicativeExpression"] = PCMultiplicativeExpression
exports["UnaryExpression"] = PCUnaryExpression
exports["PostfixExpression"] = PCPostfixExpression
exports["ReceiveExpression"] = PCReceiveExpression
exports["ProcedureCall"] = PCProcedureCall
exports["ClassCall"] = PCClassCall
exports["ArrayExpression"] = PCArrayExpression
exports["LiteralExpression"] = PCLiteralExpression
exports["IdentifierExpression"] = PCIdentifierExpression
exports["Statement"] = PCStatement
exports["BreakStmt"] = PCBreakStmt
exports["ContinueStmt"] = PCContinueStmt
exports["StmtBlock"] = PCStmtBlock
exports["StmtExpression"] = PCStmtExpression
exports["SelectStmt"] = PCSelectStmt
exports["Case"] = PCCase
exports["IfStmt"] = PCIfStmt
exports["WhileStmt"] = PCWhileStmt
exports["DoStmt"] = PCDoStmt
exports["ForStmt"] = PCForStmt
exports["ForInit"] = PCForInit
exports["ReturnStmt"] = PCReturnStmt
exports["PrimitiveStmt"] = PCPrimitiveStmt
exports["PrintStmt"] = PCPrintStmt



@window.PC = exports if @window


