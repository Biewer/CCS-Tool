all: Browser

PseuCoTree:
						coffee -c -b -j node_modules/PseuCo/_tree.js  PseuCo.coffee PCType.coffee PCEnvironment.coffee PCExport.coffee

CCSMain:
						coffee -c -b -j node_modules/CCS/_main.js CCS.coffee CCSRules.coffee CCSExecutor.coffee CCSExport.coffee

CCSCompiler: PseuCo CCS
						coffee -c -b -j node_modules/CCSCompiler/Compiler.js PCCCompiler.coffee PCCProcessFrame.coffee PCCProgramController.coffee PCCContainer.coffee PCCCompilerStack.coffee PseuCo+Compiler.coffee PCCExecutor.coffee PCCExport.coffee
					
WebGUI:
						coffee -c -b -j _UI.js UISetup.coffee UITabBar.coffee UIConsole.coffee UICCSHistory.coffee UIEventRecognizer.coffee UIExecutor.coffee UIAppController.coffee UIPseuCoEditor.coffee UICCSEditor.coffee
						


PseuCo:		PseuCoTree
						cat node_modules/PseuCo/_parser.js node_modules/PseuCo/_tree.js > node_modules/PseuCo/PseuCo.js

CCS:		CCSMain
						cat node_modules/CCS/_parser.js node_modules/CCS/_main.js > node_modules/CCS/CCS.js

Browser:	PseuCo CCS CCSCompiler WebGUI
						browserify _UI.js -o htdocs/main.js