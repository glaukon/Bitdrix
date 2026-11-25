{{flutter_js}}
{{flutter_build_config}}

// Load Flutter without its own service worker: the page has to be controlled
// by WebTorrent's worker (webtorrent.sw.min.js) for in-browser streaming, and
// two workers cannot share the same scope.
_flutter.loader.load();
