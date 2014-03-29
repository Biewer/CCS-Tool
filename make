all: WebGUI

PseuCoTree:
						coffee -c -b -j htdocs/PseuCo.js  PseuCo.coffee PCType.coffee PCEnvironment.coffee

CCSMain:
						coffee -c -b -j htdocs/CCS.js CCS.coffee CCSRules.coffee

PseuCoCompiler: PseuCoTree CCSMain
						coffee -c -b -j htdocs/PCCompiler.js PCCProcessFrame.coffee PCCProgramController.coffee PCCCompiler.coffee PCCContainer.coffee PCCCompilerStack.coffee PseuCo+Compiler.coffee
					
WebGUI: PseuCoCompiler CCSMain PseuCoTree
						coffee -c -b -j htdocs/UI.js UISetup.coffee UITabBar.coffee UIConsole.coffee UICCSHistory.coffee UIEventRecognizer.coffee UIExecutor.coffee UIAppController.coffee UIPseuCoEditor.coffee UICCSEditor.coffee