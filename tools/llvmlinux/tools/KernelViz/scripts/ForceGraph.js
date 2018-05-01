// -------------------------------------------------------------
// ForceGraph
//
// Classes used:
//   node
//   node-fg
//   node-selected
//   link
//   link-hidden
//   link-shadow
// -------------------------------------------------------------
function ForceGraph(inShadowlinks, isTopView, width, height) {

  var _force;

  if (isTopView) {
    _force = d3.layout.force()
    .charge(-150)
    .linkStrength(0)
    .size([width, height])
    .on("tick", tick);
  } else {
    _force = d3.layout.force()
    .charge(-500)
    .friction(0.5)
    .gravity(0.1)
    .linkStrength(0.4)
    .linkDistance(60)
    .size([width, height])
    .on("tick", tick);
  }
   
  var minZoom = 0.3;
  var maxZoom = 2;
  var zoom = d3.behavior.zoom().scaleExtent([minZoom,maxZoom]);

  var graph = null;
  var shadowLinks = inShadowlinks;
  var selectedNode = null;
  var hideLinks = false;
  var hideUnselected = true;
  var linkedNodes = {};
  var link;
  var node;
  var label;
  var svg;

  this._showLabels = true;

  function zoomHandler() {
   svg.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")");
  } 

  zoom.on("zoom", function() { zoomHandler() });

  function tick() {
    link.attr("x1", function(d) { return d.source.x; })
        .attr("y1", function(d) { return d.source.y; })
        .attr("x2", function(d) { return d.target.x; })
        .attr("y2", function(d) { return d.target.y; });

    node.attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; });

    label.attr("transform", function(d) {
      return "translate(" + d.x + "," + d.y + ")";
    });
  }

  this.update = function() {
    _force
        .nodes(graph.nodes)
        .links(graph.links)
        .start();

    link = link.data(_force.links());
    link.enter().insert("line", "g")
        .attr("class", "link");
    link.exit().remove();

    this.updateNodeLinks(selectedNode);

    var nodes = d3.selectAll("circle.node");
    node = node.data(_force.nodes());
    node.enter().append("circle")
        .classed("node node-fg", "true")
        .attr("r", 10)
        .attr("id", function(d) { return d.name; })
        .on("click", function(d) { clickNode(d, this, nodes);})
        .call(_force.drag)
        .append("title")
        .text(function(d) { return d.name; });
    node.exit().remove();

    if (this._showLabels) 
      label = label.data(_force.nodes());
    else
      label = label.data([]);
    
    label.enter().append("text")
        .attr("class", "label")
        .attr("x", 0)
        .attr("y", 0)
        .text(function(d) { return d.name; });
    label.exit().remove();

    node.classed("node-selected", function(d) { 
          if (selectedNode == d.index) 
            return true; 
          else
            return false; 
    });
    this.setNodeAttributes();
  }

  // Override this with View specific behavior
  this.clickNode = function(d, obj, nodes) {
  }

  this.setNodeAttributes = function() {
    var fg = this;
    var nodes = d3.selectAll("circle.node");

    nodes
      .on("click", function(d){ 
        fg.clickNode(d, this, nodes); 
    });
  }


  this.updateNodeLinks = function(inSelectedNode) {
    selectedNode = inSelectedNode;
    if (shadowLinks) {
      link
        .classed("link-hidden", false)
        .classed("link-shadow", true)
        .filter(function(k) { 
          return selectedNode != k.source.index && selectedNode != k.target.index; 
        });
    }
    
    linkedNodes = {};

    link
        .classed("link-target", function(k) { 
          if (selectedNode == k.target.index) 
            return true; 
          else
            return false; 
        })
        .classed("link-source", function(k) { 
          if (selectedNode == k.source.index) 
            return true; 
          else
            return false; 
        })
        .classed("link-hidden", function(k) { 
          if (selectedNode == k.source.index || selectedNode == k.target.index) 
            return false; 
          else
            return hideLinks;
        })
        .filter(function(k) { 
          var istgt = (selectedNode == k.source.index || selectedNode == k.target.index); 
          if (istgt) {
            linkedNodes[k.source.index] = true;
            linkedNodes[k.target.index] = true;
          }
          return istgt;
        })
        // Move to the top of displayed links
        .each(function() { 
          if (this != null)
            this.parentNode.appendChild(this); 
        });

    node.classed("node-hidden", function (d) {
          if (hideLinks && selectedNode && hideUnselected) {
            return (!linkedNodes[d.index])
          } else
            return false;
        });

    label.classed("node-hidden", function (d) {
          if (hideLinks && selectedNode && hideUnselected) {
            return (!linkedNodes[d.index])
          } else
            return false;
        });
  }

  this.showLabels = function(show) {
    this._showLabels = show;
    if (graph)
      this.update();
  }

  this.enableZoom = function(doZoom) {
    zoom.on("zoom", doZoom ? function () { zoomHandler(); } : null);
  }

  this.refresh = function (inSvg, inGraph, inSelectedNode) {
    inSvg.selectAll("g").remove();
    svg = inSvg.append("g");

    inSvg.call(zoom);

    graph = inGraph;
    selectedNode = inSelectedNode;

    link = svg.append("g").selectAll(".link");
    node = svg.append("g").selectAll(".node");
    label = svg.append("g").selectAll(".label");
    this.update();
    showingGraph=true;
  }

  this.showLinks = function (show) {
    hideLinks = !show;
    if (graph)
      this.update();
  }

  this.resize = function(width, height) {
    _force.size([width, height]);
  }
}

