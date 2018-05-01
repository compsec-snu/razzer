function DualGraphView(layout) { 
  var self = this;
  var selectedNode = null;
  var graphTypeIsDirected = true;
  var showingGraph = false;

  // Public data shared with derived class
  this.graphData = null;

  function clickDGNode(label, obj) {
    if (label == selectedNode) {
      selectedNode = null;
      layout.clearNodeInfo();
    } else {
      // Select this node
      selectedNode = label;
      var node = self.graphData.Nodes[obj.id];
      var ftype = obj.getAttribute("functype");
      layout.displayNodeInfo(obj.id, node.lineno, node.dotfile, node.ksyms, ftype);
    }
    _dg.selectedNode = selectedNode;
  }

  function DGNodeAttrFn(label, obj) { 
    var funcType = getFunctionType(label);
    var rect = obj.getElementsByTagName('rect');
    rect[0].style.fill = layout.nodeColor[funcType];
    return funcType;
  }

  var _dg = new DirectedGraph(clickDGNode, "functype", DGNodeAttrFn);

  var width, height;
  var _fg = new ForceGraph(false, false, 1000, 1000);

  // Override ForceGraph Node Click Handler
  _fg.clickNode = function (d, obj, nodes) {
    if (selectedNode == d.index) {
      selectedNode = null;
      layout.clearNodeInfo();
    } else {
      selectedNode = d.index;
      var node = self.graphData.Nodes[obj.id];
      var ftype = obj.getAttribute("functype");
      layout.displayNodeInfo(obj.id, node.lineno, node.dotfile, node.ksyms, ftype);
    }
    nodes.classed("node-selected", function (d) { return (d.index == selectedNode); });
    _fg.updateNodeLinks(selectedNode);
  }

  // Override ForceGraph Node Attribute Handler
  _fg.setNodeAttributes = function() {
    var nodes = d3.selectAll("circle.node");

    nodes
      .attr("id",function(d) { return d.name; })
      .attr("functype", function (d) { return getFunctionType(d.name); })
      .style("fill", function (d) { return layout.nodeColor[getFunctionType(d.name)]; })
      .on("click", function(d){ _fg.clickNode(d, this, nodes); });
  }

  function getFunctionType(label) {
    var funcType;
    if (self.graphData.Nodes[label].isGlobal) {
      if (self.graphData.Nodes[label].isExternal) {
        funcType = "External";
      } else {
        funcType = "Global";
      }
    } else if (self.graphData.Nodes[label].isUnused) {
      funcType = "Local Unused";
    } else if (self.graphData.Nodes[label].isExported) {
      funcType = "Exported";
    } else {
      funcType = "Local";
    }
    return funcType;
  }

  this.setGraphType = function(type) {
    selectedNode = null;
    clearGraph();
    graphTypeIsDirected = (type == "directed");
    layout.updateLayout();
    if (showingGraph)
      this.createGraph();
  }

  this.showLabels = function(show) {
    _fg.showLabels(show);
  }

  this.enableZoom = function(doZoom) {
    _fg.enableZoom(doZoom);
  }

  this.createGraph = function() {
    svg = layout.getD3SvgGraphElement();
    svg.selectAll("g").remove();
    if (graphTypeIsDirected) {
      graph = _dg.createGraph(svg, this.graphData);
      showingGraph = true;
    } else {
      graph = new Object;
      graph.nodes = [];
      graph.links = [];
      var nodes = Object.keys(this.graphData.Nodes);

      nodes.forEach(function(n) { 
        graph.nodes.push({"name": n, "group": 1 });
      });
      Object.keys(this.graphData.Edges).forEach(function(edge) { 
        graph.links.push({ "source": nodes.indexOf(self.graphData.Edges[edge].n1), 
                           "target": nodes.indexOf(self.graphData.Edges[edge].n2)}); 
      });
      _fg.refresh(svg, graph, selectedNode);
      showingGraph = true;
    }
  }

  function clearGraph() {
    // Remove existing svg 
    // Can be used to get rid of zoom
    layout.clearGraphElement();
    layout.resize();
    graph = null;
  }

  this.setActive = function() {
    clearGraph();
    layout.updateLayout();
    if (showingGraph)
      this.createGraph();
  }

  this.resize = function(width, height) {
    if (!graphTypeIsDirected)
      height = width;
    _fg.resize(width, height);
  }

  this.isDirected = function() {
    return graphTypeIsDirected;
  }
}


// -------------------------------------------------------------
// ModuleView - inherits from DualGraphView
// -------------------------------------------------------------
function ModuleView(layout) {
  DualGraphView.prototype.constructor.call(this, layout);

  var self = this;

  getFiles();

  function getFiles() {
    xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET","getfiles", true);
    xmlhttp.onreadystatechange=function(){
      if (xmlhttp.readyState==4 && xmlhttp.status==200){
        var mytext = document.getElementById("mytext");
        var files = JSON.parse(xmlhttp.responseText);
        layout.addModuleSelector(files, selectNewModule);
      }
    }
    xmlhttp.send();
  }

  this.loadModule = function(fname, nodeLabel) {
    _loadModule(fname, nodeLabel);
  }

  function _loadModule(fname, nodeLabel) {
    layout.setModuleSelectorText(fname);
    setTimeout(function() { getModule(fname, nodeLabel); },0);
  }

  function getModule(module, nodeLabel) {
    xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET","getmodule?module="+module, true);
    xmlhttp.onreadystatechange=function() {
      if (xmlhttp.readyState==4 && xmlhttp.status==200){
        self.graphData = JSON.parse(xmlhttp.responseText);
        self.createGraph();
      }
    }
    xmlhttp.send();
  }

  function selectNewModule(module) {
    _loadModule(module, null);
  }
}

// -------------------------------------------------------------
// FunctionView - inherits from DualGraphView
// -------------------------------------------------------------
function FunctionView(layout) {
  DualGraphView.prototype.constructor.call(this, layout);
  layout.createFunctionSelector(selectNewSubGraph);

  var self = this;

  this.loadSubGraph = function(func, depth) {
    _loadSubGraph(func, depth);
  }

  function _loadSubgraph(func, depth) {
    // Validate func
    xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET","funcquery?function="+func, true);
    xmlhttp.onreadystatechange=function() {
      if (xmlhttp.readyState==4 && xmlhttp.status==200){
	var query = JSON.parse(xmlhttp.responseText);
	if (query.found)
	  setTimeout(function() { getSubGraph(func, depth); },0);
	else if (query.err) {
          layout.updateFunctionList(null);
        }
	else {
          layout.updateFunctionList(query.matches);
        }
      }
    }
    xmlhttp.send();
  }

  function getSubGraph(func, depth) {
    xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET","getsubgraph?function="+func+";depth="+depth, true);
    xmlhttp.onreadystatechange=function() {
      if (xmlhttp.readyState==4 && xmlhttp.status==200){
        self.graphData = JSON.parse(xmlhttp.responseText);
        if (Object.keys(self.graphData.Nodes).length > 1500) {
          alert("Too many nodes to graph:\nNodes: "+
                Object.keys(self.graphData.Nodes).length+
                "\nLinks: "+self.graphData.Edges.length);
        } else
          self.createGraph();
      }
    }
    xmlhttp.send();
  }

  function selectNewSubGraph(funcname, depth) {
      _loadSubgraph(funcname, depth);
  }
}

