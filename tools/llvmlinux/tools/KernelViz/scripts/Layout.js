// -------------------------------------------------------------
// Layout
// Requires: d3
// -------------------------------------------------------------
var View = null;
var layout = new Layout;

function Layout() {

  window.addEventListener('resize', this.resize);
  var moduleSelector;
  var functionView;
  var moduleView;
  var topDirView;

  this.nodeColor = { "External": "#f77", "Global": "#177", "Local": "#fff", "Local Unused": "#771", "Exported": "#717" };
  this.funcNodeColor = { "Global": "#177", "Local": "#fff" };
  this.linkColor = { "Call Out": "#d62728", "Call In": "#2ca02c" };

  this.init = function() {
    functionView = new FunctionView(this);
    moduleView = new ModuleView(this);
    topDirView = new TopDirView(this);
  }

  this.updateLayout = function() {
    var self = this;
    var isDirected = (View.isDirected === undefined) ? false : View.isDirected();
    d3.select("div.labelbutton").style("display", isDirected ? "none" : null);
    var keyContainer = d3.select("div.keyContainer").html("");

    var colors = (View == functionView) ? this.funcNodeColor : this.nodeColor;
    createNodeKey(this, keyContainer, colors);

    if (!isDirected) {
      var key = keyContainer
        .append("div")
        .classed("linkKey", true);
      createLinkKey(key, self.linkColor);
    }
  }

  this.displayNodeInfo = function(nodename, lineno, dotfile, ksyms, functype) {
    var splitnodename = nodename.split("@");
    var nodeinfo = d3.select("div.nodeInfoContainer")
      .html("");
      
    var div = nodeinfo.append("div")
      .classed("optionitem", true);

    div.append("span")
      .classed("optionlabel", true)
      .text("Name:");

    div.append("span")
      .text(splitnodename[0]);

    var div2 = nodeinfo.append("div")
      .classed("optionitem", true);

    div2.append("span")
      .classed("optionlabel", true)
      .text("Type:");

    div2.append("span")
      .text(functype);

    if (lineno) {
      var div3 = nodeinfo.append("div")
      .classed("optionitem", true);

      div3.append("div")
        .classed("optionlabel", true)
        .text("Defined in:");

      div3.append("span")
        .classed("wordwrap", true)
        .text(lineno);
    }

    if (splitnodename.length == 2) {
      dotfile = splitnodename[1];
    }
    if (dotfile) {
      var link = "";
      link += "<a href='' onclick='layout.loadModule(\""+dotfile+"\", \""
             +nodename+"\");return false;'>"+dotfile+"</a><section/>";
      var div5 = nodeinfo.append("div")
      .classed("optionitem", true);

      div5.append("div")
        .classed("optionlabel", true)
        .text("Link:");

      div5.append("span")
        .classed("wordwrap", true)
        .html(link);
    }
    if (ksyms) {
      var div6 = nodeinfo.append("div")
      .classed("optionitem", true);

      div6.append("div")
        .classed("optionlabel", true)
        .text("KSymtab:");

      nodeinfo
        .append("span")
        .classed("wordwrap", true)
        .text(ksyms);
    }
  }

  this.clearNodeInfo = function () {
    d3.select("div.nodeInfoContainer").html("");
  }

  this.getD3SvgGraphElement = function () {
    var div = d3.select("div.container");
    return div.select("svg");
  }

  this.clearGraphElement = function() {
    var div = d3.select("div.container");
    div.select("svg").remove();
    div.append("svg");
  }

  this.addModuleSelector = function(files, callback) {
    d3.select("div.selectortxt")
    .append("div")
    .style("border", "1px solid #999")
    .each(function () {
      moduleSelector = completely(this, {
          fontFamily:"sans-serif", fontSize:"14px"
      });

      moduleSelector.options = files.sort();

      moduleSelector.onChange = function (text) {
        moduleSelector.startFrom = text.indexOf(',')+1;
        if (files.indexOf(text) >= 0) {
          callback(text);
        }
        moduleSelector.repaint();
      };
      moduleSelector.repaint();
    });
  }

  this.setModuleSelectorText = function(text) {
    moduleSelector.setText(text);
  }

  this.createFunctionSelector = function(callback) {
    var depth = document.getElementById("funcdepth");
    var textbox = d3.select(".fsearch");
    this.funcCallback = callback;
    
    var searchtext = document.getElementById("funcsearchtext");
    searchtext.oninput = function () { 
      callback(searchtext.value, depth.value); 
    };
    searchtext.onclick = function () { 
      callback(searchtext.value, depth.value); 
    };
    searchtext.onpaste = function () { 
      callback(searchtext.value, depth.value); 
    };
  }

  this.updateFunctionList = function(options) {
    var self = this;
    var functext = document.getElementById("funcname");
    var funcfile = document.getElementById("funcfile");
    var selector = d3.select(".fselector");
    if (options == null || options.length == 0) {
      selector.html("");
    }
    else {
      selector.html("");
      selector
        .append("select")
        .attr("size", options.length > 10 ? 10 : options.length)
        .on("click", function () {
          var depth = document.getElementById("funcdepth");
          var name = this.value.split("@");
          functext.innerHTML = name[0];
          funcfile.innerHTML = (name.length == 2) ? name[1] : "";
          self.funcCallback(this.value, depth.value);
          selector.html("");
        })
        .selectAll("option")
        .data(options)
        .enter()
        .append("option")
        .attr("value", function (d) { 
          return d; 
        })
        .text(function (d) { 
          return d; 
        });
    }
  }

  this.getGraphSize = function(width, height) {
    width = window.innerWidth - 290.0;
    height = 1000;
  }

  this.setView = function(view) {
    if (view == "toplevel") {
      d3.select("div.labelbutton").style("display", null);
      d3.select("div.viewbuttons").style("display", "none");
      d3.select("div.topviewcontrols").style("display", null);
      d3.select("div.selector").style("display", "none");
      d3.selectAll("div.funcoption").style("display", "none");
      View = topDirView;
    } 
    else if (view == "func") {
      View = functionView;
      d3.select("div.labelbutton").style("display", null);
      d3.select("div.viewbuttons").style("display", null);
      d3.select("div.topviewcontrols").style("display", "none");
      d3.select("div.selector").style("display", "none");
      d3.selectAll("div.funcoption").style("display", null);
    }
    else {
      View = moduleView;
      d3.select("div.labelbutton").style("display", null);
      d3.select("div.viewbuttons").style("display", null);
      d3.select("div.topviewcontrols").style("display", "none");
      d3.select("div.selector").style("display", null);
      d3.selectAll("div.funcoption").style("display", "none");
    }

    View.setActive();
    this.resize();
  }

  this.resize = function() {
    var width = window.innerWidth - 290.0;
    var height = 1000;
    d3.select("div.container svg")
      .attr("style", "width:"+ width + "px;height:"+ height + "px;");
    View.resize(width, height);
  };

  this.setGraphType = function(graphtype) {
    View.setGraphType(graphtype);
  }

  this.showLabels = function(show) {
    View.showLabels(show);
  }

  this.showLinks = function(show) {
    topDirView.showLinks(show);
  }

  function createLinkKey(element, linkColor) {
    var table = element
      .append("table");

    var tablehead = table.append("tr");
    var tablebody = table.append("tbody");

    tablehead
      .append("th")
      .text("Link Type");

    tablehead
      .append("th")
      .text("Color");

    row = tablebody
      .selectAll("tr")
      .data(Object.keys(linkColor)) 
      .enter()
      .append("tr");

    row
      .append("td")
      .attr("width", "100px")
      .text(function (d) { return d; });

    row
      .append("td")
      .attr("width", "50px")
      .attr("style", function (d) { return "background-color:"+linkColor[d]+";"; } );
  }

  function createNodeKey(self, viewinfo, colors) {
    if (View != topDirView) {
      var table = viewinfo
        .append("div")
        .classed("nodeKey", true)
        .append("table");

      var tablehead = table.append("tr");
      var tablebody = table.append("tbody");

      tablehead
        .append("th")
        .text("Function Type");

      tablehead
        .append("th")
        .text("Color");

      row = tablebody
        .selectAll("tr")
        .data(Object.keys(colors)) 
        .enter()
        .append("tr");

      row
        .append("td")
        .attr("width", "100px")
        .text(function (d) { return d; });

      row
        .append("td")
        .attr("width", "50px")
        .attr("style", function (d) { return "background-color:"+colors[d]+";"; } );
    }
  }

  this.enableZoom = function(doZoom) {
    if (View.enableZoom !== undefined)
      View.enableZoom(doZoom);
  }

  this.loadModule = function(module, func) {
    moduleView.loadModule(module, func);
  }
}
