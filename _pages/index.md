---
layout: page
title: Home
id: home
permalink: /
---

# Bienvenue Navid Jan !

*Une promesse est une dette, et la plus grande fierté est de l'avoir honorée.*

<div id="graph-wrapper">
  <!-- Conteneur du graphique -->
  <style>
    #graph-wrapper {
      width: 100%;
      height: 600px; /* Ajuste la hauteur selon tes besoins */
      border: 1px solid #ccc; /* Pour visualiser les dimensions du conteneur */
    }
  </style>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/d3/5.16.0/d3.min.js"></script>

  <script>
    window.addEventListener("load", loadGraph);

    function loadGraph() {
      const MINIMAL_NODE_SIZE = 8;
      const MAX_NODE_SIZE = 12;
      const ACTIVE_RADIUS_FACTOR = 1.5;
      const STROKE = 1;
      const FONT_SIZE = 16;
      const TICKS = 200;
      const FONT_BASELINE = 40;
      const MAX_LABEL_LENGTH = 50;

      const graphData = {
        "edges": [
          {"source":"731101021113298111117114115101","target":"67102100"},
          // Autres données d'edges...
        ],
        "nodes": [
          {"id":"731101021113298111117114115101","label":"Node 1"},
          // Autres données de nodes...
        ]
      };

      // Code pour rendre le graphe (à adapter selon ton besoin)
      const svg = d3.select("#graph-wrapper").append("svg")
                    .attr("width", "100%")
                    .attr("height", "100%");

      const simulation = d3.forceSimulation(graphData.nodes)
                           .force("link", d3.forceLink(graphData.edges).id(d => d.id))
                           .force("charge", d3.forceManyBody().strength(-400))
                           .force("center", d3.forceCenter(svg.node().clientWidth / 2, svg.node().clientHeight / 2));

      const link = svg.append("g")
                      .selectAll("line")
                      .data(graphData.edges)
                      .enter().append("line")
                      .attr("stroke-width", STROKE);

      const node = svg.append("g")
                      .selectAll("circle")
                      .data(graphData.nodes)
                      .enter().append("circle")
                      .attr("r", MINIMAL_NODE_SIZE)
                      .attr("fill", "#69b3a2");

      node.append("title").text(d => d.label);

      simulation.on("tick", () => {
        link.attr("x1", d => d.source.x)
            .attr("y1", d => d.source.y)
            .attr("x2", d => d.target.x)
            .attr("y2", d => d.target.y);

        node.attr("cx", d => d.x)
            .attr("cy", d => d.y);
      });
    }
  </script>
</div>
