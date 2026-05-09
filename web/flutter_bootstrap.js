{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const engine = await engineInitializer.initializeEngine();

    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then((reg) => {
        reg.addEventListener('updatefound', () => {
          const newWorker = reg.installing;
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              showUpdatePrompt();
            }
          });
        });
      });
    }

    await engine.runApp();
    
    // Ensure the Flutter app receives focus after initialization to fix keyboard input
    setTimeout(() => {
      const glassPane = document.querySelector('flt-glass-pane');
      if (glassPane) {
        glassPane.focus();
      }
    }, 100);
  }
});

function showUpdatePrompt() {
  const toast = document.createElement('div');
  toast.id = 'update-toast';
  toast.style.cssText = `
    position: fixed;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    background: #323232;
    color: white;
    padding: 12px 24px;
    border-radius: 8px;
    z-index: 10000;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    display: flex;
    align-items: center;
    gap: 16px;
  `;

  toast.innerHTML = `
    <span>A new version is available!</span>
    <button onclick="window.location.reload()" style="
      background: #1565C0;
      color: white;
      border: none;
      padding: 6px 12px;
      border-radius: 4px;
      cursor: pointer;
      font-weight: bold;
    ">Update Now</button>
  `;

  document.body.appendChild(toast);
}
