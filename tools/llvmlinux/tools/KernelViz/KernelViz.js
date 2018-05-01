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
var dot = require('graphlib-dot');
var keys = Object.keys || require('object-keys');

var Modules = new Object;
var TopView = new Object;

var index = 0;

var Nodes = new Object;
var Links = new Object;
var SG;

function SubGraph() {

  this.queryFunc = function(func) {
    var response = new Object;
    response.matches = [];
    response.err = null;
    response.found = false;
    keys(Nodes).some(function (f) {
      if (f == func) {
          response.found = true;
          console.log("Found: "+func);
          return true;
      }
      else if (~f.split("@")[0].indexOf(func)) {
        response.matches.push(f);
        if (response.matches.length > 100) {
          response.matches = [];
          response.err = "Too many matching results";
          console.log(response.err);
          return true;
        } 
        else {
          console.log("------------------------");
          console.log(response.matches);
        }
      }
    });
    return response;
  }

  this.getSubGraph = function(nodeName, n, err) {
    var subGraph = new Object;

    if (Nodes[nodeName] === undefined) {
      console.log(nodeName+" does not exist");
      err = true;
      return null;
    }
    _getSubGraph(nodeName, n, subGraph, err);
    return subGraph;
  }

  function _getSubGraph(nodeName, n, subGraph) {
    if (Links[nodeName] !== undefined && n > 0) {
      if (subGraph.Nodes === undefined) {
        subGraph.Nodes = new Object;
      }
      if (subGraph.Edges === undefined) {
        subGraph.Edges = [];
      }
/*
      if (Links[nodeName].LinksOut !== undefined) {
        Links[nodeName].LinksOut.forEach(function (dest) { 
          _getSubGraph(dest, n-1, subGraph); 
          subGraph.Nodes[dest] = 1;
          if (subGraph.Edges.indexOf(nodeName+","+dest) < 0) {
            subGraph.Edges.push({ "n1": nodeName, "n2": dest });
          }
        });
      }
*/

      if (Links[nodeName].LinksIn !== undefined) {
        console.log(JSON.stringify(Links[nodeName]));
        Links[nodeName].LinksIn.forEach(function (src) {
          _getSubGraph(src, n-1, subGraph); 
          subGraph.Nodes[src] = Nodes[src];
          if (subGraph.Edges.indexOf(src+","+nodeName) < 0) {
            subGraph.Edges.push({ "n1": src, "n2": nodeName });
          }
        });
      }
      subGraph.Nodes[nodeName] = Nodes[nodeName];
    }
  }
}

function runServer() {
  var http = require("http");
  var fs = require("fs");
  var url = require("url");

  // Create whitelists so only a subset of files can be
  // served via nodejs
  var whitelist = [ "/index.html", "/data/TopViewFG.json"];
  var whitelistDir = [ "/external/d3", "/external/dagre", 
                       "/external/completely", "/images",
                       "/scripts" ];

  http.createServer(function(request, response){
    var reqpath = url.parse(request.url).pathname;
    var reqdir = path.normalize(path.dirname(reqpath));

    console.log("request received "+reqpath);
    if(reqpath == "/getfiles"){
      console.log("files request received");
      var string = JSON.stringify(keys(Modules));
      response.writeHead(200, {"Content-Type": "text/plain"});
      response.end(string);
      console.log("string sent");
    }
    else if(reqpath == "/getmodule"){
      console.log("module request received "+url.parse(request.url).query);
      var file = url.parse(request.url).query.substring("module=".length);
      console.log("file:"+file);
      //console.log(JSON.stringify(Modules[file]));
      var string = JSON.stringify(Modules[file]);
      response.writeHead(200, {"Content-Type": "text/plain"});
      response.end(string);
      console.log("string sent");
    }
    else if(reqpath == "/funcquery"){
      console.log("function name query received "+url.parse(request.url).query);
      var args = url.parse(request.url).query.split(";");
      var func = args[0].substring("function=".length);
      console.log("function:"+func);
      var string = JSON.stringify(SG.queryFunc(func));
      response.writeHead(200, {"Content-Type": "text/plain"});
      response.end(string);
      console.log("string sent");
    }
    else if(reqpath == "/getsubgraph"){
      console.log("subgraph request received "+url.parse(request.url).query);
      var args = url.parse(request.url).query.split(";");
      var func = args[0].substring("function=".length);
      var depth = parseInt(args[1].substring("depth=".length));
      console.log("function:"+func+" depth:"+depth);
      var string = JSON.stringify(SG.getSubGraph(func, depth));
      response.writeHead(200, {"Content-Type": "text/plain"});
      response.end(string);
      console.log("string sent");
    }
    else if(reqpath == "/favicon.ico"){
      response.writeHead(200, {'Content-Type': 'image/x-icon'} );
      response.end();
      console.log('favicon requested');
    }
    else if (whitelistDir.indexOf(reqdir) >= 0) {
      console.log("Whitelisted req: "+reqpath);
      var mimetype = "text/plain";
      var req = S(reqpath);
      if (req.endsWith(".js")) {
        mimetype = "text/javascript";
      } else if (reqdir == "/images") {
        mimetype = "image/png";
      }
      fs.readFile('.'+reqpath, function(err, file) {  
        if(err) {  
          showError(response, "Unable to read: "+reqpath);
        } else {  
          response.writeHead(200, { 'Content-Type': mimetype });  
          response.end(file, "utf-8");  
          console.log("string sent");
        }
      });
    }
    else {
      if (reqpath == "/")
        reqpath = "/index.html";
   
      if (whitelist.indexOf(reqpath) >= 0) {
        fs.readFile('.'+reqpath, function(err, file) {  
          if(err) {  
            showError(response, "Unable to read: "+reqpath);
          } else {  
            response.writeHead(200, { 'Content-Type': 'text/html' });  
            response.end(file, "utf-8");  
          }
        });
      }
      else {
        showError(response, "No such file: "+reqpath);
      }
    }
  }).listen(8001);
  console.log("server initialized");
}

function showError(response, text) {
  var Error = '<!DOCTYPE html> <meta charset="utf-8"> <body> <h1>Error</h1>'
              + "<pre>" + text + "</pre></body>";
  response.writeHead(200, { 'Content-Type': 'text/html' });  
  response.end(Error, "utf-8");  
}

// Reload the parsed data
console.log("Loading data");
if (process.argv.length != 2) {
  console.log("Usage: nodejs SWViz.js");
}
else {
  fs.readFile("data/Nodes.json", 'utf8', function (err, data) {
    if (err) {
      console.log(""+err);
      process.exit(1);
    }
    Nodes = JSON.parse(data);
    fs.readFile("data/Links.json", 'utf8', function (err, data) {
      if (err) {
        console.log("" + err);
        process.exit(1);
      }
      Links = JSON.parse(data);
      SG = new SubGraph();
      fs.readFile("data/ModulesResolved.json", 'utf8', function (err, data) {
        if (err) {
          console.log(""+err);
          process.exit(1);
        }
        Modules = JSON.parse(data);
        runServer();
      });
    });
  });
  console.log("Loading cached data");
}

