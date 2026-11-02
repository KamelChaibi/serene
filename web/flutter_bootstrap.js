{{flutter_js}}
{{flutter_build_config}}

// Serene's web bootstrap.
//
// Flutter 3.41's built-in service worker is a self-unregistering stub, so we
// deliberately do not pass `serviceWorkerSettings` below and register our own
// worker (web/sw.js) instead. The worker caches the app shell so the PWA opens
// offline after the first visit.
(function () {
  function getLoader() {
    return document.getElementById('serene-loader');
  }

  function hideLoader() {
    var loader = getLoader();
    if (!loader) return;
    loader.classList.add('is-hidden');
    window.setTimeout(function () {
      if (loader && loader.parentNode) loader.parentNode.removeChild(loader);
    }, 500);
  }

  function showLoaderError(error) {
    console.error('Serene failed to start:', error);
    var loader = getLoader();
    if (loader) loader.classList.add('has-error');
  }

  _flutter.loader.load({
    onEntrypointLoaded: function (engineInitializer) {
      engineInitializer
        .initializeEngine()
        .then(function (appRunner) {
          return appRunner.runApp();
        })
        .then(function () {
          // Let Flutter paint its first frame before revealing it.
          window.requestAnimationFrame(function () {
            window.requestAnimationFrame(hideLoader);
          });
        })
        .catch(showLoaderError);
    },
  });

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function (error) {
        // The app still works online; only offline support is lost.
        console.warn('Serene service worker registration failed:', error);
      });
    });
  }
})();
