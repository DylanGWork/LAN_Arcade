(function(){
  const originalAlert = window.alert;
  window.__lanArcadeAlerts = [];
  window.alert = function(message) {
    window.__lanArcadeAlerts.push(String(message));
    console.info('Life Engine notice:', message);
  };
  window.__lanArcadeRestoreAlert = function() {
    window.alert = originalAlert;
  };
})();
