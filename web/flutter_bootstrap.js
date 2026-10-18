{{flutter_js}}
{{flutter_build_config}}

// Sin serviceWorkerSettings: el service worker de Flutter está deprecado
// (el flutter_service_worker.js que genera solo se desregistra a sí mismo)
// y registramos el nuestro (sw.js) más abajo. No registrar los dos: tienen
// el mismo scope y uno pisaría al otro.
_flutter.loader.load({
  config: {
    // CanvasKit desde el propio sitio y no desde el CDN de Google, para
    // que la app arranque sin conexión.
    canvasKitBaseUrl: "canvaskit/",
  },
});

if ("serviceWorker" in navigator) {
  window.addEventListener("load", async () => {
    try {
      const registration = await navigator.serviceWorker.register("sw.js");
      await navigator.serviceWorker.ready;
      // En la primera visita la página carga antes de que el service worker
      // tome control, así que le pasamos lo que ya se bajó (CanvasKit,
      // main.dart.js, fuentes...) para que lo guarde. Se repite un rato
      // después para atrapar lo que se carga tarde (fuentes de emojis).
      const sendLoadedResources = () => {
        const urls = performance
          .getEntriesByType("resource")
          .map((entry) => entry.name);
        urls.push(location.href);
        registration.active?.postMessage({ type: "cache-urls", urls });
      };
      sendLoadedResources();
      setTimeout(sendLoadedResources, 15000);
    } catch (error) {
      console.warn("No se pudo registrar el service worker:", error);
    }
  });
}
