/**
 * Copyright (c) 2014 Mark Charlebois
 *
 * All rights reserved. 
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted (subject to the limitations in the disclaimer
 * below) provided that the following conditions are met:
 * 
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *  
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * 
 * - Neither the name KernelViz nor the names of its contributors may be used
 *   to endorse or promote products derived from this software without 
 *   specific prior written permission.
 * 
 * NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
 * THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

var fs = require('fs')
var path = require('path')
var S = require('string');
var sys = require('sys')
var exec = require('child_process').exec;

function createRawSymbolFile(basedir, srcdir, fname) {
  console.log(fname+" doesn't exist, parsing files...");
  // If defined symbols file doesn't exist, then create it
  // Handle case where vmlinux is the only file
  var cmd = "(echo "+basedir+"/vmlinux && find "+basedir+" -name '*.ko') | " 
        + "xargs nm -l -p --defined-only > "+fname+" &&"
        + "(head -n 2 "+fname+" | grep -v 'vmlinux:' && "
        + "(echo '' > "+fname+"_1 && echo '"+basedir+"/vmlinux:' >> "+fname+"_1 &&"
        + "cat "+fname+" >> "+fname+"_1  && "
        + "mv "+fname+"_1 "+fname+"))";
    //console.log(cmd);
    exec(cmd , function(err, stdout, stderr) {
    if( err ) {
      console.log("" + err+"\n"+stderr);
      process.exit(1);
    }
    else {
      parseKernelFiles(basedir, srcdir, fname, false);
    }
  });
}

function parseKernelFiles(basedir, srcdir, fname, create) {
  // Read the defined symbols file
  console.log("File:"+fname);
  fs.readFile(fname, 'utf8', function (err, data) {
    if (err) {
      if (create == false) {
        console.log("" + err);
        process.exit(1);
      }
      createRawSymbolFile(basedir, srcdir, fname);
    } else {
      if (S(data).startsWith("\n"+basedir+"/vmlinux:\n")) {
        console.log(fname+" exists, parsing symbols");
        parseDefinedSymbols(basedir, srcdir, data);	
      } else {
        console.log("New basedir ("+basedir+"), parsing symbols");
        createRawSymbolFile(basedir, srcdir, fname);
      }
    }
  });
}

function parseDefinedSymbols(basedir, srcdir, data) {
  var SymbolMap = new Object;
  // If vmlinux was the only file, then the file name will be omitted
  if (data[0] != '\n') {
    data = "\n"+basedir+"/vmlinux:\n"+data;
  }
  var files = data.substring(1).split("\n\n");
  files.forEach(function (f) {
    var symbols = f.split("\n");
    var line = symbols[0];
    var fname = line.substring(basedir.length+1,line.length-1);
    var skip = false;

    symbols.slice(1).forEach(function(line) {
      // Handle last newline in last file
      if (line == "") {
        line = "1 X X\tX";
      }
      var tokens = line.split(" ");
      var symtype = tokens[1];

      // Functions only (text segment and ksyms)
      if (symtype == "t" || symtype == "T" || symtype == "R") {
        //console.log("Line: "+line);
        var tmp = tokens[2].split("\t");
        var sym = tmp[0];
        var lineno = null;
        if (tmp.length == 2) {
          lineno = tmp[1].substring(srcdir.length+1,line.length-1);
        }
        if (SymbolMap[sym] === undefined) {
          SymbolMap[sym] = new Object;
          SymbolMap[sym].symtype = symtype;
          SymbolMap[sym].file = [ fname ];
          if (lineno) {
            SymbolMap[sym].lineno = [ lineno ];
          } 
        } else if (SymbolMap[sym].symtype != "R") {
          SymbolMap[sym].file.push(fname);
          if (lineno) {
            if (SymbolMap[sym].lineno === undefined)
              SymbolMap[sym].lineno = [];
            SymbolMap[sym].lineno.push(lineno);
          } 
        }
      }
    });
  });
  fs.writeFile("data/Symbols.json", JSON.stringify(SymbolMap, null, " "));
}

if (process.argv.length == 4) {
  var objbasedir = path.resolve(process.argv[2]); 
  var srcbasedir = path.resolve(process.argv[3]); 
  console.log("Reading object files from "+objbasedir);
  parseKernelFiles(objbasedir, srcbasedir, "tmp/defined_symbols", true);
}
else {
  console.log("Usage: nodejs ReadSymbols.js dir_tree");
  return 0;
}
