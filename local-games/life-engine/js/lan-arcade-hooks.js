(function(){
  function click(selector) {
    const el = document.querySelector(selector);
    if (!el) return false;
    el.click();
    return true;
  }

  function setSlider(value) {
    const slider = document.querySelector('#slider');
    if (!slider) return false;
    slider.value = String(value);
    slider.dispatchEvent(new Event('input', { bubbles: true }));
    slider.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }

  function snapshot() {
    const text = (document.body && document.body.innerText || '').replace(/\s+/g, ' ').trim();
    const canvas = document.querySelector('#env-canvas');
    return {
      text: text.slice(0, 500),
      alerts: window.__lanArcadeAlerts || [],
      canvas: canvas ? { width: canvas.width, height: canvas.height } : null,
    };
  }

  window.__lanArcadeGame = Object.assign({}, window.__lanArcadeGame, {
    lifeEngineFastForward() {
      const ok = setSlider(180);
      click('.pause-button');
      return ok;
    },
    lifeEngineOpenStats() {
      return click('.tabnav-item#stats');
    },
    lifeEngineOpenWorldControls() {
      return click('.tabnav-item#world-controls');
    },
    lifeEngineSnapshot: snapshot,
  });
})();
