(function(){
  class LiteChart {
    constructor(containerId, options) {
      this.containerId = containerId;
      this.container = document.getElementById(containerId);
      this.options = options || {};
      this.options.data = this.options.data || [];
    }
    render() {
      this.container = this.container || document.getElementById(this.containerId);
      if (!this.container) return;
      const title = this.options.title && this.options.title.text ? this.options.title.text : 'Chart';
      const points = [];
      for (const series of this.options.data || []) {
        for (const point of series.dataPoints || []) {
          if (typeof point.y === 'number' && Number.isFinite(point.y)) points.push(point.y);
        }
      }
      const latest = points.slice(-40);
      const max = Math.max(1, ...latest);
      const bars = latest.map((value) => '<span class="canvasjs-lite-bar" style="height:' + Math.max(2, Math.round((value / max) * 100)) + '%"></span>').join('');
      this.container.innerHTML = '<div class="canvasjs-lite"><div class="canvasjs-lite-title"></div><div class="canvasjs-lite-bars">' + bars + '</div><div class="canvasjs-lite-note"></div></div>';
      this.container.querySelector('.canvasjs-lite-title').textContent = title;
      this.container.querySelector('.canvasjs-lite-note').textContent = latest.length ? ('Latest: ' + latest[latest.length - 1] + ' | Samples: ' + latest.length) : 'Waiting for simulation data';
    }
  }
  window.CanvasJS = window.CanvasJS || {};
  window.CanvasJS.Chart = window.CanvasJS.Chart || LiteChart;
})();
