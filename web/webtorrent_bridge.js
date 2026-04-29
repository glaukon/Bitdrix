// Bitdrix WebTorrent JS bridge
// Called from Dart via dart:js interop.
(function () {
  'use strict';

  var client = null;
  var serverBaseUrl = null;
  var torrents = {}; // uuid -> WebTorrent torrent object

  // ── init ────────────────────────────────────────────────────────────────────
  // Returns a Promise that resolves with the base streaming URL.
  function init() {
    if (client) return Promise.resolve(serverBaseUrl);

    return new Promise(function (resolve, reject) {
      try {
        client = new WebTorrent();

        client.on('error', function (err) {
          console.error('[Bitdrix] WebTorrent client error:', err);
        });

        var server = client.createServer({ sw: '/webtorrent.sw.min.js' });

        // The server may fire 'listening' or expose .url synchronously in
        // different WebTorrent versions – handle both.
        if (server.url) {
          serverBaseUrl = server.url;
          resolve(serverBaseUrl);
        } else {
          server.on('listening', function () {
            serverBaseUrl = server.url || (window.location.origin);
            resolve(serverBaseUrl);
          });
          server.on('error', function (err) {
            // Fall back to origin-relative paths (SW mode)
            serverBaseUrl = window.location.origin;
            resolve(serverBaseUrl);
          });
          // Give the SW 3 s to register; fall back if it never fires.
          setTimeout(function () {
            if (!serverBaseUrl) {
              serverBaseUrl = window.location.origin;
              resolve(serverBaseUrl);
            }
          }, 3000);
        }
      } catch (e) {
        reject(e.toString());
      }
    });
  }

  // ── addMagnet ───────────────────────────────────────────────────────────────
  // onReady(jsonString)  called once metadata is fetched
  // onError(message)     called on failure
  function addMagnet(magnetLink, id, onReady, onError) {
    if (!client) {
      onError('WebTorrent client not initialised');
      return;
    }
    try {
      client.add(magnetLink, function (torrent) {
        torrents[id] = torrent;

        // Pick the first video file; fall back to file[0].
        var videoFile = null;
        for (var i = 0; i < torrent.files.length; i++) {
          if (/\.(mp4|mkv|avi|mov|webm|m4v)$/i.test(torrent.files[i].name)) {
            videoFile = torrent.files[i];
            break;
          }
        }
        if (!videoFile) videoFile = torrent.files[0];
        var fileIndex = torrent.files.indexOf(videoFile);

        var streamUrl = (serverBaseUrl || window.location.origin) +
          '/' + torrent.infoHash + '/' + fileIndex;

        onReady(JSON.stringify({
          infoHash: torrent.infoHash,
          name: torrent.name,
          length: torrent.length || 0,
          streamUrl: streamUrl,
        }));
      });
    } catch (e) {
      onError(e.toString());
    }
  }

  // ── getStatus ───────────────────────────────────────────────────────────────
  function getStatus(id) {
    var t = torrents[id];
    if (!t) return null;
    return JSON.stringify({
      progress: t.progress || 0,
      downloadSpeed: t.downloadSpeed || 0,
      uploadSpeed: t.uploadSpeed || 0,
      numPeers: t.numPeers || 0,
      downloaded: t.downloaded || 0,
      length: t.length || 0,
      done: t.done || false,
    });
  }

  // ── pause / resume / remove ─────────────────────────────────────────────────
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
    if (t) {
      client.remove(t.infoHash);
      delete torrents[id];
    }
  }

  // ── export ──────────────────────────────────────────────────────────────────
  window.bitdrixBridge = {
    init: init,
    addMagnet: addMagnet,
    getStatus: getStatus,
    pause: pause,
    resume: resume,
    remove: remove,
  };
})();
