{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const config = {
      renderer: "html",
    };
    const appRunner = await engineInitializer.initializeEngine(config);
    await appRunner.runApp();
  }
});

