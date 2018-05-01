// -------------------------------------------------------------
// DirectedGraph
// -------------------------------------------------------------
function DirectedGraph(clickHandler, nodeattr, nodeattrfunc) {
  var svg;
  var selectedNode = null;
  var showingGraph = false;
  var graph = null;
  var link;
  var node;
  var zoomg;

  function setNodeAttributes() {
    var nodes = d3.selectAll("g.node");

    nodes
    .attr("id",function(label) { return label; })
    .attr(nodeattr, function (label) { 
      return nodeattrfunc(label, this); })
    .on("click", function(label) {
      selectedNode = (label == selectedNode) ? null : label;
      nodes.classed("selected", function (d) { 
        return (d == selectedNode); 
      });
      clickHandler(label, this); 
    });
  }

  function drawDirectedGraph() {
    var d3layout = new dagreD3.layout()
      .nodeSep(20)
      .edgeSep(20)
      .rankDir("LR");
    var renderer = new dagreD3.Renderer();

    renderer.layout(d3layout).run(graph, zoomg);
    setNodeAttributes();
    showingGraph=true;
  }

  this.createGraph = function(inSvg, data) {
    graph = new dagreD3.Digraph();
    Object.keys(data.Nodes).forEach(function(n) { 
      graph.addNode(n, { label: n });
    });
    Object.keys(data.Edges).forEach(function(edge) { 
      graph.addEdge(null, data.Edges[edge].n1, data.Edges[edge].n2); 
    });

    inSvg.selectAll("g").remove();
    svg = inSvg;
    zoomg = svg.append("g");
    var zoom = dagreD3.zoom.panAndZoom(zoomg);
    dagreD3.zoom(svg, zoom);
    link = d3.selectAll("g.link");
    node = d3.selectAll("g.node");

    drawDirectedGraph();
    return graph;
  }
}

