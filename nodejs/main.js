// Generated by CoffeeScript 1.6.3
/* ###
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
### */;
var NJSMain, NJSReadline, NJSSharedMain, NSJReadlineOptions;

NJSReadline = require("readline");

NSJReadlineOptions = {
  input: process.stdin,
  output: process.stdout
};

NJSMain = (function() {
  function NJSMain() {
    var cmd;
    cmd = process.argv[2];
    if (cmd === "-help" || cmd === "-h") {
      this.printHelp();
    } else {
      this.printSummary();
    }
  }

  NJSMain.prototype.printHelp = function() {
    console.log("First line of help");
    return console.log("Second line of help?");
  };

  NJSMain.prototype.printSummary = function() {
    return console.log("ToDo");
  };

  return NJSMain;

})();

NJSSharedMain = new NJSMain();
