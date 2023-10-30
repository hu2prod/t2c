// Generated by IcedCoffeeScript 108.0.13

/* !pragma coverage-skip-block */

(function() {
  var Websocket_wrap, client_int, request_div, server_int, websocket_list;

  websocket_list = [];

  if (!window.WebSocket) {
    request_div = document.createElement('div');
    document.body.appendChild(request_div);
    client_int = 1000;
    server_int = 15000;
    server_int = 5000;
    window.__ws_cb = function(uid, msg_uid, data) {
      var child, seek, ws, _i, _j, _len, _len1, _ref;
      for (_i = 0, _len = websocket_list.length; _i < _len; _i++) {
        ws = websocket_list[_i];
        if (ws.uid === uid) {
          if (data != null) {
            ws.dispatch("data", data);
          }
          ws.active_script_count--;
          break;
        }
      }
      if ((ws != null ? ws.active_script_count : void 0) < 2) {
        ws.send(null);
      }
      seek = "?u=" + uid + "&mu=" + msg_uid + "&";
      _ref = request_div.children;
      for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
        child = _ref[_j];
        if (-1 !== child.src.indexOf(seek)) {
          request_div.removeChild(child);
          child.onerror = null;
          break;
        }
      }
    };
    setInterval(function() {
      var ws, _i, _len;
      for (_i = 0, _len = websocket_list.length; _i < _len; _i++) {
        ws = websocket_list[_i];
        if (ws.active_script_count < 2) {
          ws.send(null);
        }
      }
    }, client_int);
  }

  Websocket_wrap = (function() {
    Websocket_wrap.uid = 0;

    Websocket_wrap.prototype.uid = 0;

    Websocket_wrap.prototype.msg_uid = 0;

    Websocket_wrap.prototype.websocket = null;

    Websocket_wrap.prototype.timeout_min = 100;

    Websocket_wrap.prototype.timeout_max = 5 * 1000;

    Websocket_wrap.prototype.timeout_mult = 1.5;

    Websocket_wrap.prototype.timeout = 100;

    Websocket_wrap.prototype.url = '';

    Websocket_wrap.prototype.reconnect_timer = null;

    Websocket_wrap.prototype.queue = [];

    Websocket_wrap.prototype.quiet = false;

    Websocket_wrap.prototype.fallback_mode = false;

    Websocket_wrap.prototype.active_script_count = 0;

    event_mixin(Websocket_wrap);

    function Websocket_wrap(url) {
      this.url = url;
      event_mixin_constructor(this);
      this.uid = Websocket_wrap.uid++;
      this.queue = [];
      this.timeout = this.timeout_min;
      this.ws_init();
      websocket_list.push(this);
    }

    Websocket_wrap.prototype["delete"] = function() {
      return this.close();
    };

    Websocket_wrap.prototype.close = function() {
      clearTimeout(this.reconnect_timer);
      this.websocket.onopen = function() {};
      this.websocket.onclose = function() {};
      this.websocket.onclose = function() {};
      this.websocket.close();
      return websocket_list.remove(this);
    };

    Websocket_wrap.prototype.ws_reconnect = function() {
      if (this.reconnect_timer) {
        return;
      }
      this.reconnect_timer = setTimeout((function(_this) {
        return function() {
          _this.ws_init();
        };
      })(this), this.timeout);
    };

    Websocket_wrap.prototype.ws_init = function() {
      if (!window.WebSocket) {
        this.fallback_mode = true;
        this.uid = "" + Math.random();
        this.url = this.url.replace("ws:", "http:");
        this.url = this.url.replace("wss:", "https:");
        this.url += "/ws";
        this.url = this.url.replace(/\/\/ws$/, "/ws");
        return;
      }
      this.reconnect_timer = null;
      this.websocket = new WebSocket(this.url);
      this.timeout = Math.min(this.timeout_max, Math.round(this.timeout * this.timeout_mult));
      this.websocket.onopen = (function(_this) {
        return function() {
          var data, q, _i, _len;
          _this.dispatch("reconnect");
          _this.timeout = _this.timeout_min;
          q = _this.queue.clone();
          _this.queue.clear();
          for (_i = 0, _len = q.length; _i < _len; _i++) {
            data = q[_i];
            _this.send(data);
          }
        };
      })(this);
      this.websocket.onerror = (function(_this) {
        return function(e) {
          if (!_this.quiet) {
            perr("Websocket error.");
            perr(e);
          }
          _this.ws_reconnect();
        };
      })(this);
      this.websocket.onclose = (function(_this) {
        return function() {
          if (!_this.quiet) {
            perr("Websocket disconnect. Restarting in " + _this.timeout);
          }
          _this.ws_reconnect();
        };
      })(this);
      this.websocket.onmessage = (function(_this) {
        return function(message) {
          var data;
          data = JSON.parse(message.data);
          _this.dispatch("data", data);
        };
      })(this);
    };

    Websocket_wrap.prototype.send = function(data) {
      var script;
      if (this.fallback_mode) {
        script = document.createElement('script');
        script.src = "" + this.url + "?u=" + this.uid + "&mu=" + (this.msg_uid++) + "&i=" + server_int + "&d=" + (encodeURIComponent(JSON.stringify(data)));
        script.onerror = (function(_this) {
          return function() {
            request_div.removeChild(script);
            script.onerror = null;
            _this.active_script_count--;
            _this.send(data);
          };
        })(this);
        setTimeout((function(_this) {
          return function() {
            if (script.parentElement) {
              script.onerror();
            }
          };
        })(this), server_int * 3);
        request_div.appendChild(script);
        this.active_script_count++;
        return;
      }
      if (this.websocket.readyState !== this.websocket.OPEN) {
        this.queue.push(data);
      } else {
        this.websocket.send(JSON.stringify(data));
      }
    };

    Websocket_wrap.prototype.write = Websocket_wrap.prototype.send;

    return Websocket_wrap;

  })();

  window.Websocket_wrap = Websocket_wrap;

}).call(this);
