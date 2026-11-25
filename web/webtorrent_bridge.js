// Bitdrix ⇄ WebTorrent bridge (called from Dart via dart:js_interop).
//
// WebTorrent is loaded as an ES module in index.html and exposed as
// window.WebTorrent. Files are streamed through WebTorrent's service worker
// (webtorrent.sw.min.js), which serves /webtorrent/<infoHash>/<path> URLs with
// Range support and fetches the pieces each request needs.
(function () {
  'use strict';

  var client = null;
  var initPromise = null;
  var torrents = {}; // Dart id -> WebTorrent torrent

  function waitForWebTorrent() {
    if (window.WebTorrent) return Promise.resolve(window.WebTorrent);
    return new Promise(function (resolve, reject) {
      var timer = setTimeout(function () {
        reject(new Error('WebTorrent library failed to load'));
      }, 15000);
      window.addEventListener('webtorrent-ready', function () {
        clearTimeout(timer);
        resolve(window.WebTorrent);
      }, { once: true });
    });
  }

  function init() {
    if (initPromise) return initPromise;
    initPromise = waitForWebTorrent().then(function (WebTorrent) {
      client = new WebTorrent();
      client.on('error', function (err) {
        console.error('[Bitdrix] WebTorrent error:', err);
      });
      if (!('serviceWorker' in navigator)) {
        console.warn('[Bitdrix] Service workers unavailable: streaming disabled');
        return false;
      }
      return navigator.serviceWorker
        .register('./webtorrent.sw.min.js', { scope: './' })
        .then(function () { return navigator.serviceWorker.ready; })
        .then(function (registration) {
          // On the first visit the worker claims the page asynchronously;
          // stream URLs only work once the page is controlled.
          if (navigator.serviceWorker.controller) return registration;
          return new Promise(function (resolve) {
            var done = function () { resolve(registration); };
            navigator.serviceWorker.addEventListener('controllerchange', done, { once: true });
            setTimeout(done, 5000);
          });
        })
        .then(function (registration) {
          client.createServer({ controller: registration });
          return !!navigator.serviceWorker.controller;
        })
        .catch(function (err) {
          console.warn('[Bitdrix] Could not start the streaming worker:', err);
          return false;
        });
    });
    return initPromise;
  }

  function describe(torrent) {
    return JSON.stringify({
      infoHash: torrent.infoHash,
      name: torrent.name || '',
      length: torrent.length || 0,
      files: torrent.files.map(function (f) {
        return { name: f.name, path: f.path, length: f.length };
      }),
    });
  }

  function decodeDataUri(uri) {
    var base64 = uri.substring(uri.indexOf('base64,') + 7);
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }

  // source: magnet link, info hash or a data: URI holding a .torrent file.
  function add(source, id, onReady, onError) {
    init().then(function () {
      var input = source.indexOf('data:') === 0 ? decodeDataUri(source) : source;
      var existing = null;
      try { existing = client.get(input); } catch (e) { existing = null; }
      Promise.resolve(existing).then(function (found) {
        if (found) {
          torrents[id] = found;
          if (found.ready) onReady(describe(found));
          else found.once('ready', function () { onReady(describe(found)); });
          return;
        }
        var torrent = client.add(input, function (t) {
          onReady(describe(t));
        });
        torrents[id] = torrent;
        torrent.on('error', function (err) {
          onError(String(err && err.message ? err.message : err));
        });
      });
    }).catch(function (err) {
      onError(String(err && err.message ? err.message : err));
    });
  }

  function getStatus(id) {
    var t = torrents[id];
    if (!t) return null;
    return JSON.stringify({
      ready: !!t.ready,
      paused: !!t.paused,
      progress: t.progress || 0,
      downloadSpeed: t.downloadSpeed || 0,
      uploadSpeed: t.uploadSpeed || 0,
      numPeers: t.numPeers || 0,
      downloaded: t.downloaded || 0,
      uploaded: t.uploaded || 0,
      length: t.length || 0,
      done: !!t.done,
      files: t.ready ? t.files.map(function (f) { return f.downloaded || 0; }) : [],
    });
  }

  // Returns the service-worker URL used to stream file `index`.
  function streamUrl(id, index) {
    var t = torrents[id];
    if (!t || !t.ready) return null;
    var file = t.files[index];
    if (!file) return null;
    // Prioritise the file being played.
    t.files.forEach(function (f, i) {
      if (i !== index && typeof f.deselect === 'function') f.deselect(1);
    });
    file.select(1);
    try {
      return file.streamURL;
    } catch (e) {
      console.warn('[Bitdrix] streamURL unavailable:', e);
      return null;
    }
  }

  function pause(id) {
    var t = torrents[id];
    if (t) t.pause();
  }

  function resume(id) {
    var t = torrents[id];
    if (t) t.resume();
  }

  function remove(id) {
    var t = torrents[id];
    delete torrents[id];
    if (t && client) client.remove(t, { destroyStore: true });
  }

  window.bitdrixBridge = {
    init: init,
    add: add,
    getStatus: getStatus,
    streamUrl: streamUrl,
    pause: pause,
    resume: resume,
    remove: remove,
  };
})();
