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

exports["Compiler"] = PCCCompiler
exports["Constructor"] = PCCConstructor

exports["StackElement"] = PCCStackElement
exports["UnaryStackElement"] = PCCUnaryStackElement
exports["BinaryStackElement"] = PCCBinaryStackElement
#Private: PCCBinaryTarget
exports["StopStackElement"] = PCCStopStackElement
exports["ExitStackElement"] = PCCExitStackElement
exports["PrefixStackElement"] = PCCPrefixStackElement
exports["InputStackElement"] = PCCInputStackElement
exports["OutputStackElement"] = PCCOutputStackElement
exports["MatchStackElement"] = PCCMatchStackElement
exports["ConditionStackElement"] = PCCConditionStackElement
exports["RestrictionStackElement"] = PCCRestrictionStackElement
exports["ApplicationStackElement"] = PCCApplicationStackElement
exports["ApplicationPlaceholderStackElement"] = PCCApplicationPlaceholderStackElement
exports["BinaryCCSStackElement"] = PCCBinaryCCSStackElement
exports["ChoiceStackElement"] = PCCChoiceStackElement
exports["ParallelStackElement"] = PCCParallelStackElement
exports["SequenceStackElement"] = PCCSequenceStackElement
exports["SystemProcessStackElement"] = PCCSystemProcessStackElement
exports["ProcessDefinitionStackElement"] = PCCProcessDefinitionStackElement
exports["ProcessFrameStackElement"] = PCCProcessFrameStackElement
exports["ClassStackElement"] = PCCClassStackElement
exports["GlobalStackElement"] = PCCGlobalStackElement
exports["ProcedureStackElement"] = PCCProcedureStackElement

exports["CompilerStack"] = PCCCompilerStack
exports["StackResult"] = PCCStackResult
exports["StackResultContainer"] = PCCStackResultContainer



exports["Container"] = PCCContainer
exports["ConstantContainer"] = PCCConstantContainer
exports["VariableContainer"] = PCCVariableContainer
exports["ComposedContainer"] = PCCComposedContainer
exports["BinaryContainer"] = PCCBinaryContainer
exports["UnaryContainer"] = PCCUnaryContainer



exports["Executor"] = PCCExecutor




exports["ProcessFrame"] = PCCProcessFrame
exports["ProcedureFrame"] = PCCProcedureFrame
exports["Groupable"] = PCCGroupable




exports["Global"] = PCCGlobal
exports["Class"] = PCCClass
exports["Procedure"] = PCCProcedure
exports["Type"] = PCCType
exports["VariableInfo"] = PCCVariableInfo
exports["Variable"] = PCCVariable
exports["GlobalVariable"] = PCCGlobalVariable
exports["Field"] = PCCField
exports["InternalReadOnlyField"] = PCCInternalReadOnlyField
exports["Condition"] = PCCCondition
exports["LocalVariable"] = PCCLocalVariable
exports["ProgramController"] = PCCProgramController






