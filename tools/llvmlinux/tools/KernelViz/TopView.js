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

var fs = require('fs');
var path = require('path');
var S = require('string');
var keys = Object.keys || require('object-keys');

var Modules = new Object;
var BucketView = new Object;
var LinkMap = new Object;
var Bucket = new Object;

function addLink(n1, n2) {
  // Prune duplicate links
  if (LinkMap[[n1, n2]] == undefined) {
    BucketView.links.push([n1, n2]);
    LinkMap[[n1, n2]] = 1;
  }
}

function processNode(file, nodeLabel) {
  var node = Modules[file].Nodes[nodeLabel];
  var defnFile = null;
  if (node.dotfile !== undefined && node.dotfile[0] != null ) {
    if (node.dotfile != file) {
      defnFile = node.dotfile[0];
    }
  } else if (node.lineno != undefined && node.lineno[0]) {
    if (!S(node.lineno[0]).startsWith(file.split("_.dot")[0])) {
      defnFile = path.normalize(node.lineno[0].split(":")[0]);
    }
  }
  if (defnFile == null) 
    return;

  // Known that Bucket[file] exists
  var n1 = Bucket[file];

  // If func is defined in a non-dot file then create new node
  if (Bucket[defnFile] === undefined) {
    Bucket[defnFile] = path.dirname(defnFile);
  }
  var n2 = Bucket[defnFile];

  addLink(n1, n2);
}

function createTopLevelView() {
  var NodeMap = new Object;
  BucketView.nodes = [];
  BucketView.links = [];

  // Create a bucketed view of the modules
  keys(Modules).forEach(function (mod) { 
    Bucket[mod] = path.dirname(mod);

    // Prune duplicate nodes
    if (NodeMap[path.dirname(mod)] === undefined) {
      NodeMap[path.dirname(mod)] = 0;
      //BucketView.nodes.push({"name":Bucket[mod],"group":1});
      BucketView.nodes.push(Bucket[mod]);
    }
    NodeMap[path.dirname(mod)] += 1;

    // For all nodes (functions)
    keys(Modules[mod].Nodes).forEach(function (nodeLabel) {
      processNode(mod, nodeLabel);
    });
  });
  fs.writeFile("data/TopViewDG.json", JSON.stringify(BucketView, null, " "));
  var ForceView = new Object;
  ForceView.nodes = [];
  ForceView.links = [];
  BucketView.nodes.forEach(function (n) {
    ForceView.nodes.push({"name":n,"group":1}); 
  });
  BucketView.links.forEach(function (link) {
    // FIXME - why is the node not found??
    if(BucketView.nodes.indexOf(link[1]) >= 0) { 
      ForceView.links.push({"source":BucketView.nodes.indexOf(link[0]),
                            "target":BucketView.nodes.indexOf(link[1]),"value":1}); 
    }
  });
  fs.writeFile("data/TopViewFG.json", JSON.stringify(ForceView, null, " "));
}

// Reload the parsed data
if (process.argv.length != 2) {
  console.log("Usage: nodejs TopView.js");
}
else {
  console.log("Loading cached data");
  fs.readFile("data/ModulesResolved.json", 'utf8', function (err, data) {
    if (err) {
      console.log(""+err);
      process.exit(1);
    }
    Modules = JSON.parse(data);
    createTopLevelView();
  });
}

