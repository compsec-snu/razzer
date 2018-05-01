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
var path = require('path');
var keys = Object.keys || require('object-keys');

var Modules = new Object;
var Symbols = new Object;
var Unresolved = [];

var index = 0;

var FunctionMap = new Object;
var LinkMap = new Object;

function AddNode(modName, nodeName) {
  var funcName;
  var mod = Modules[modName];

  if (!mod.Nodes[nodeName].isGlobal)
    funcName = nodeName+"@"+modName;
  else
    funcName = nodeName;
  if (FunctionMap[funcName] === undefined) {
    FunctionMap[funcName] = new Object;
    //FunctionMap[funcName].modName = modName;
    FunctionMap[funcName].isGlobal = mod.Nodes[nodeName].isGlobal;
    if (mod.Nodes[nodeName].lineno)
      FunctionMap[funcName].lineno = mod.Nodes[nodeName].lineno[0];
    if (mod.Nodes[nodeName].ksyms)
      FunctionMap[funcName].ksyms = mod.Nodes[nodeName].ksyms[0][0];
  }
  else {
    if (mod.Nodes[nodeName].isGlobal && (mod.Nodes[nodeName].lineno) &&
      (mod.Nodes[nodeName].lineno[0] != FunctionMap[funcName].lineno)) {
      console.log(mod.Nodes[nodeName].lineno[0].length+" "+FunctionMap[funcName].lineno.length);
      console.log("Global function with different lineno definitions: "+nodeName);
      console.log("  Lineno "+FunctionMap[funcName].lineno);
      console.log("  "+modName+" "+mod.Nodes[nodeName].lineno);
    }
    if (mod.Nodes[nodeName].isGlobal && !mod.Nodes[nodeName].isExternal) {
      FunctionMap[funcName].dotfile = modName;
    }
  }
}

function AddLinks(modName, n1, n2) {
  var mod = Modules[modName];
  var f1, f2;
  if (!mod.Nodes[n1].isGlobal)
    f1 = n1+"@"+modName;
  else
    f1 = n1;
  if (!mod.Nodes[n2].isGlobal)
    f2 = n2+"@"+modName;
  else
    f2 = n2;

  if (LinkMap[f1] === undefined)
    LinkMap[f1] = new Object;
  if (LinkMap[f2] === undefined)
    LinkMap[f2] = new Object;

  if (LinkMap[f1].LinksOut === undefined)
    LinkMap[f1].LinksOut = [];
  LinkMap[f1].LinksOut.push(f2);
  if (LinkMap[f2].LinksIn === undefined)
    LinkMap[f2].LinksIn = [];
  LinkMap[f2].LinksIn.push(f1);
}

function createFunctionIndex() {
  keys(Modules).forEach(function (mod) {
    // For all nodes (functions)
    keys(Modules[mod].Nodes).forEach(function (nodeName) {
      AddNode(mod, nodeName);
    });
    keys(Modules[mod].Edges).forEach(function (edgeName) {
      AddLinks(mod, Modules[mod].Edges[edgeName].n1, Modules[mod].Edges[edgeName].n2);
    });
  });
  fs.writeFile("data/Nodes.json", JSON.stringify(FunctionMap, null, " "));
  fs.writeFile("data/Links.json", JSON.stringify(LinkMap, null, " "));
}

function Node(node, nodeLabel, file, isGlobal, ksymFiles) {

  // this.node will be sent to the client so all client info 
  // must be in this.node
  this.node = node;
  this.nodeLabel = nodeLabel;
  this.symIsGlobal = isGlobal;
  this.ksymFiles = ksymFiles;
  this.file = file;
  this.unresolved = false;
  this.node.isExported = false;

  this.CheckIfUnused = function(edges) {
    var self = this;
    // See if the node is unused
    if (this.node.isExternal === false && this.node.isGlobal === false) {
      this.node.isUnused = true;
      // See if the node has outward edges, if so
      // it must be a locally defined function
      keys(edges).some(function (edgeLabel) {
        if (edges[edgeLabel].n1 === self.nodeLabel ||
           edges[edgeLabel].n2 === self.nodeLabel) {
          self.node.isUnused = false;
          return !self.node.isExternal;
        }
      });
    }
  }

  this.CheckIfKsyms = function(Modules) {
    // If there are kysms for the function
    var self = this;
    if (this.ksymFiles) {
      this.AddKsym(this.ksymFiles.lineno);
      //Modules[file].Nodes[nodeLabel].isExported = true;
      // If no lineno for symbol, use ksym to try to guess dot file
      if (this.node.dotfile === undefined) {
        if (this.ksymFiles.lineno) {
          this.ksymFiles.lineno.forEach(function (lineno) {
            var filename = path.normalize(lineno.split(":")[0]);
            var dotfile = filename.substring(0, filename.length)+"_.dot";
            // Add a dotfile unless it is for a node in current file
            if (Modules[dotfile] !== undefined && dotfile != self.file) {
              if (self.node.dotfile == undefined) {
                self.node.dotfile = [];
              }
              self.node.dotfile.push(dotfile);
            }
          });
        }
      }
    }
  }

  this.CheckIfExported = function(edges) {
    // If the node/function is global but not in obj files, it must be exported
    var self = this;
    if (this.node.isGlobal) {
      if (this.node.isExternal === true) {
        // See if the node has outward edges, if so
        // it must be a locally defined function
        keys(edges).forEach(function (edgeLabel) {
          if (edges[edgeLabel].n1 === self.nodeLabel)
            self.node.isExternal = false;
        });
        // if the function is actually local and is parsed as global and there
        // was no global symbol for it in the obj files then it must be exported
        if (this.symIsGlobal && this.node.isExternal === false) {
          //console.log("Externally referenced: "+this.nodeLabel+" "+this.file);
          this.node.isExported = true;
        } 
        // Local file that is global in vmlinux or .ko file but not exported as ksym
        else if (!this.symIsGlobal && this.node.isExternal === false && this.ksymFiles === undefined) {
          this.unresolved = true;
        }
      } 
    }
  }

  this.AddLineno = function(lineno) {
    if (!this.node.lineno)
      this.node.lineno = [];
    this.node.lineno = this.node.lineno.concat(lineno);
  }

  this.AddDotFile = function(dotfile) {
    if (!this.node.dotfile)
      this.node.dotfile = [];
    this.node.dotfile = this.node.dotfile.concat(dotfile);
  }

  this.AddKsym = function(ksym) {
    if (!this.node.ksyms)
      this.node.ksyms = [];
    this.node.ksyms.push(ksym);
  }
}

function resolve() {
  // For all nodes in all modules
  keys(Modules).forEach(function (file) {
    keys(Modules[file].Nodes).forEach(function (nodeLabel) {
      
      var funcname = nodeLabel.substring(1, nodeLabel.length-1);
      var symbolFiles = Symbols[funcname];
      var ksymFiles = Symbols["__ksymtab_"+funcname];

      var isGlobal = (symbolFiles === undefined) ? false : (symbolFiles.symtype == "T") ? true : false;
      var node = new Node(Modules[file].Nodes[nodeLabel], nodeLabel, file, isGlobal, ksymFiles);

      node.CheckIfUnused(Modules[file].Edges);

      //console.log(nodeLabel + " X " + JSON.stringify(symbolFiles));
      // If there is a global symbol and lineno for the function
      if (symbolFiles && symbolFiles.lineno) {
        // Add global symbol info
        if (isGlobal) {
          symbolFiles.lineno.forEach(function (lineno) { 
            //console.log(nodeLabel + " Y " + lineno);
            if (lineno) {
              var filename = path.normalize(lineno.split(":")[0]);
              var dotfile = filename+"_.dot";
                
              // verify the dot file exists
              //console.log("M "+ Modules[dotfile] + " Z "+dotfile);
              if (Modules[dotfile] !== undefined) {
                node.AddDotFile(dotfile);
              }
              // Add lineno info to local functions
              node.AddLineno(symbolFiles.lineno);
            }
          });
        } 
      } 
      node.CheckIfExported(Modules[file].Edges);
      if (node.unresolved) 
        Unresolved.push([nodeLabel, file, "External"]);
      node.CheckIfKsyms(Modules);
    });
  }); 

  createFunctionIndex();

  fs.writeFile("data/ModulesResolved.json", JSON.stringify(Modules, null, " "));
  fs.writeFile("data/Unresolved.json", JSON.stringify(Unresolved, null, " "));
}

// Reload the parsed data
if (process.argv.length != 2) {
  console.log("Usage: nodejs Resolve.js");
}
else {
  console.log("Loading cached data");
  fs.readFile("data/Modules.json", 'utf8', function (err, data) {
    if (err) {
      console.log(""+err);
      process.exit(1);
    }
    Modules = JSON.parse(data);
    fs.readFile("data/Symbols.json", 'utf8', function (err, data) {
      if (err) {
        console.log("" + err);
        process.exit(1);
      }
      Symbols = JSON.parse(data);
      resolve();
    });
  });
}

