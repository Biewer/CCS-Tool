all: CCS PC PCC


pctree:
						coffee -c -b -j node_modules/PseuCo/_tree.js  PseuCo.coffee PCType.coffee PCEnvironment.coffee PCExport.coffee


ccsmain:
						coffee -c -b -j node_modules/CCS/_main.js CCS.coffee CCSRules.coffee CCSExecutor.coffee CCSExport.coffee


PCC:
						coffee -c -b -j node_modules/CCSCompiler/CCSCompiler.js PCCCompiler.coffee PCCProcessFrame.coffee PCCProgramController.coffee PCCContainer.coffee PCCCompilerStack.coffee PseuCo+Compiler.coffee PCCExecutor.coffee PCCExport.coffee


PC:		pctree
						cat node_modules/PseuCo/_parser.js node_modules/PseuCo/_tree.js > node_modules/PseuCo/PseuCo.js


CCS:		ccsmain
						cat node_modules/CCS/_parser.js node_modules/CCS/_main.js > node_modules/CCS/CCS.js
