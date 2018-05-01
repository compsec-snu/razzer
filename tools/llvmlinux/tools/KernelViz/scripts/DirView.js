// -------------------------------------------------------------
// TopDirView
// -------------------------------------------------------------
function TopDirView(svgclass, viewinfoclass) {
  var selectedNode = null;

  var _fg = new ForceGraph(true, true, 1, 1);

  // Override ForceGraph Node Click Handler
  _fg.clickNode = function (d, obj, nodes) {
    if (selectedNode == d.index) {
      selectedNode = null;
      layout.clearNodeInfo();
    } else {
      selectedNode = d.index;
    }
    nodes.classed("node-selected", function (d) { return (d.index == selectedNode); });
    _fg.updateNodeLinks(selectedNode);
  }

  this.resize = function(width, height) {
      height = width;
    _fg.resize(width, height);
  }

  function createGraph() {
    svg = d3.selectAll("svg");
    svg.selectAll("g").remove();
    xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET","data/TopViewFG.json", true);
    xmlhttp.onreadystatechange=function() {
      if (xmlhttp.readyState==4 && xmlhttp.status==200){
        graph = JSON.parse(xmlhttp.responseText);
        _fg.refresh(svg, graph, selectedNode);
      }
    }
    xmlhttp.send();
  }

  function clearGraph() {
    // Remove existing svg 
    // Can be used to get rid of zoom
    var div = d3.select("div.container");
    div.selectAll("svg").remove();
    div.append("svg");
    layout.resize();
    graph = null;
  }

  this.setActive = function() {
    clearGraph();
    createGraph();
    layout.updateLayout();
  }

  this.showLabels = function(show) {
    _fg.showLabels(show);
  }

  this.showLinks = function(show) {
    _fg.showLinks(show);
  }

  this.enableZoom = function(doZoom) {
    _fg.enableZoom(doZoom);
  }
}


