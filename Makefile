all: CCS PC PCC


pctree:
						coffee -c -b -j node_modules/PseuCo/_tree.js  PseuCo.coffee PCType.coffee PCEnvironment.coffee PCExport.coffee


ccsmain:
						coffee -c -b -j node_modules/CCS/_main.js CCS.coffee CCSRules.coffee CCS+Traces.coffee CCSExecutor.coffee CCSExport.coffee

ccsparser:
						pegjs -e CCSParser CCSParser.pegjs node_modules/CCS/_parser.js

pcparser:
						pegjs -e PseuCoParser PseuCoParser.pegjs node_modules/PseuCo/_parser.js


PCC:
						coffee -c -b -j node_modules/CCSCompiler/CCSCompiler.js PCCCompiler.coffee PCCProcessFrame.coffee PCCProgramController.coffee PCCContainer.coffee PCCCompilerStack.coffee PseuCo+Compiler.coffee PCCExecutor.coffee PCCExport.coffee


PC:		pctree pcparser
						cat node_modules/PseuCo/_parser.js node_modules/PseuCo/_tree.js > node_modules/PseuCo/PseuCo.js


CCS:		ccsmain ccsparser
						cat node_modules/CCS/_parser.js node_modules/CCS/_main.js > node_modules/CCS/CCS.js
