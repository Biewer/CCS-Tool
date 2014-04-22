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

exports["parser"] = CCSParser

exports["internalChannelName"] = CCSInternalChannel
exports["exitChannelName"] = CCSExitChannel

exports["typeUnknown"] = CCSTypeUnknown
exports["typeChannel"] = CCSTypeChannel
exports["typeValue"] = CCSTypeValue
exports["getMostGeneralType"] = CCSGetMostGeneralType

exports["CCS"] = CCS
exports["ProcessDefinition"] = CCSProcessDefinition
exports["Process"] = CCSProcess
exports["Stop"] = CCSStop
exports["Exit"] = CCSExit
exports["ProcessApplication"] = CCSProcessApplication
exports["Prefix"] = CCSPrefix
exports["Condition"] = CCSCondition
exports["Choice"] = CCSChoice
exports["Parallel"] = CCSParallel
exports["Sequence"] = CCSSequence
exports["Restriction"] = CCSRestriction

exports["Channel"] = CCSChannel
exports["Action"] = CCSAction
exports["SimpleAction"] = CCSSimpleAction
# Private: CCSInternalActionCreate
exports["ValueSet"] = CCSValueSet
exports["Variable"] = CCSVariable
exports["Input"] = CCSInput
exports["Output"] = CCSOutput
exports["CCSExpression"] = CCSExpression
exports["ConstantExpression"] = CCSConstantExpression
exports["VariableExpression"] = CCSVariableExpression
exports["AdditiveExpression"] = CCSAdditiveExpression
exports["MultiplicativeExpression"] = CCSMultiplicativeExpression
exports["ConcatenatingExpression"] = CCSConcatenatingExpression
exports["RelationalExpression"] = CCSRelationalExpression
exports["EqualityExpression"] = CCSEqualityExpression

exports["actionSets"] = ActionSets


exports["Step"] = CCSStep
exports["BaseStep"] = CCSBaseStep
# exports["InputStep"] = CCSInputStep

exports["PrefixRule"] = CCSPrefixRule
exports["OutputRule"] = CCSOutputRule
exports["InputRule"] = CCSInputRule
exports["MatchRule"] = CCSMatchRule
exports["ChoiceLRule"] = CCSChoiceLRule
exports["ChoiceRRule"] = CCSChoiceRRule
exports["ParLRule"] = CCSParLRule
exports["ParRRule"] = CCSParRRule
exports["SyncRule"] = CCSSyncRule
exports["ResRule"] = CCSResRule
exports["CondRule"] = CCSCondRule
exports["ExitRule"] = CCSExitRule
exports["SyncExitRule"] = CCSSyncExitRule
exports["Seq1Rule"] = CCSSeq1Rule
exports["Seq2Rule"] = CCSSeq2Rule
exports["RecRule"] = CCSRecRule


# Private: CCSExecutorCopyOnPerformStepPolicy
# Private: CCSExecutorStepCountPerExecutionUnit
# Private: CCSExecutorDefaultStepPicker
exports["Executor"] = CCSExecutor

@window.CCS = exports if @window




















