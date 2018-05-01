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
var S = require('string');
var dir = require('node-dir');
var dot = require('graphlib-dot');
var keys = Object.keys || require('object-keys');

var Modules = {};
var index = 0;

function parseDotFile(basedir, file) {
  console.error("processing file " + ++index);
  dotfile = file.substring(basedir.length+1);
  var graph = dot.parse(fs.readFileSync(file, 'UTF-8'));
  Modules[dotfile] = { "Nodes": {}, "Edges": {} };
  graph.nodes().forEach(function (node) {
    // Filter out LLVM generated extra nodes and external nodes
    var label = graph.node(node)["label"];
    if (S(label).startsWith("{llvm.")) {
    }
    else if (label[0] == '{' && label != "{external node}") {
      Modules[dotfile].Nodes[label] = { "isGlobal": false, "isExternal": false};
    }
  })
  graph.edges().forEach(function (edge) {
    var incident = graph.incidentNodes(edge), 
    a = graph.node(incident[0])["label"], 
    b = graph.node(incident[1])["label"];

    // Filter out edges for external calls
    if (b[0] != "{") {
      Modules[dotfile].Nodes[a].isExternal = true;
    }
    // Filter out edges for extra LLVM generated nodes
    else if (S(b).startsWith("{llvm.")) {
    }
    else if (a == "{external node}") {
      Modules[dotfile].Nodes[b].isGlobal = true;
    }
    else {
      var edge = [ a, b ];
      if (Modules[dotfile].Edges[edge]) {
        Modules[dotfile].Edges[edge].count += 1;
      } 
      else {
        Modules[dotfile].Edges[edge] = { "n1": a, "n2": b, "count": 1 }
      }
    }
  })
}

function filterDotFiles(basedir, path) {
  if (S(path).endsWith("_.dot")) {
     parseDotFile(basedir, path)
  }
}

// ****************************************************************
// data/Modules.json
// The Dot files are converted into the following data:
//   Dotfile
//     - Nodes
//         - NodeName
//         - isGlobal (clang parses function as global scope)
//         - isExternal (function is defined external to module)
//     - Edges
//         - EdgeName
//         - n1 (source node)
//         - n2 (destination node)
//         - count (cardinality)
// ****************************************************************
function parseDotFiles(basedir) {
  Modules = {};
  console.log("Parsing files");
  dir.files(basedir, function(err, files) {
    if (err) 
      throw err;

    // filter the array of files 
    files.forEach(function (path) {
      filterDotFiles(basedir, path) 
    });
    fs.writeFile("data/Modules.json", JSON.stringify(Modules, null, " "));
  });
}

console.log("Loading data");
if (process.argv.length == 3) {
  var basedir = process.argv[2]; 
  console.log("Reading dot files from "+basedir);
  parseDotFiles(basedir);
}
else
{
  console.log("Usage: nodejs ReadDotFiles.js basedir");
}
