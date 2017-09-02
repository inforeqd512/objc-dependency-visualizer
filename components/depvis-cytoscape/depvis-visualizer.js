function setupCytoscapeLayout(dependencies, container) {
    const nodes = cyNodesFromDependencies(dependencies)

    const edges = dependencies.links.map( (el) => {
        return {
            data: { 
                id: (el.source + "->" + el.dest),
                source: el.source,
                target: el.dest
            }
        }
    })
    console.log(edges)

    const elements = nodes.concat(edges)
    console.log(elements)

    var cy = cytoscape({
      container: container,
      elements: elements,
      style: [
      {
          selector: 'node',
          style: {
            shape: 'hexagon',
            'background-color': 'red',
            label: 'data(id)'
        }
    }],
    layout: {
        name: 'random',
    }
});      

    setTimeout(() => {
        const layout = cy.layout({
            name: 'cose',
        // idealEdgeLength: 200,
        // nodeOverlap: 20,
        animate: false,
        // refresh: 10,
        // fit: true,
        // randomize: true,
        animationThreshold: 10,
        // resizeCy: true
    }, 1000)
        layout.run()
    })
}

function cyNodesFromDependencies(dependencies) {
    var nodesMap = {}
    dependencies.links.forEach( (item) => {
        nodesMap[item.source] = "1"
        nodesMap[item.dest] = "1" 
    })

    const nodes = Object.keys(nodesMap).map((node) => {
        return { data: { id: node }} 
    })
    return nodes
}