(function() {
  var C, Deferrals, Pipeliner, Rendezvous, exceptionHandler, exports, findDeferral, make_defer_return, stackWalk, tick_counter, trampoline, warn, __active_trace, __c, __iced_k, __iced_k_noop, _iand, _ior, _timeout, _trace_to_string,
    __slice = [].slice;

  __iced_k = __iced_k_noop = function() {};

  window.iced = exports = {};

  C = {
    k: "__iced_k",
    k_noop: "__iced_k_noop",
    param: "__iced_p_",
    ns: "iced",
    runtime: "runtime",
    Deferrals: "Deferrals",
    deferrals: "__iced_deferrals",
    fulfill: "_fulfill",
    b_while: "_break",
    t_while: "_while",
    c_while: "_continue",
    n_while: "_next",
    n_arg: "__iced_next_arg",
    defer_method: "defer",
    slot: "__slot",
    assign_fn: "assign_fn",
    autocb: "autocb",
    retslot: "ret",
    trace: "__iced_trace",
    passed_deferral: "__iced_passed_deferral",
    findDeferral: "findDeferral",
    lineno: "lineno",
    parent: "parent",
    filename: "filename",
    funcname: "funcname",
    catchExceptions: 'catchExceptions',
    runtime_modes: ["node", "inline", "window", "none", "browserify", "interp"],
    trampoline: "trampoline",
    context: "context",
    defer_arg: "__iced_defer_"
  };

  make_defer_return = function(obj, defer_args, id, trace_template, multi) {
    var k, ret, trace, v;
    trace = {};
    for (k in trace_template) {
      v = trace_template[k];
      trace[k] = v;
    }
    trace[C.lineno] = defer_args != null ? defer_args[C.lineno] : void 0;
    ret = function() {
      var inner_args, o, _ref;
      inner_args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (defer_args != null) {
        if ((_ref = defer_args.assign_fn) != null) {
          _ref.apply(null, inner_args);
        }
      }
      if (obj) {
        o = obj;
        if (!multi) {
          obj = null;
        }
        return o._fulfill(id, trace);
      } else {
        return warn("overused deferral at " + (_trace_to_string(trace)));
      }
    };
    ret[C.trace] = trace;
    return ret;
  };

  __c = 0;

  tick_counter = function(mod) {
    __c++;
    if ((__c % mod) === 0) {
      __c = 0;
      return true;
    } else {
      return false;
    }
  };

  __active_trace = null;

  _trace_to_string = function(tr) {
    var fn;
    fn = tr[C.funcname] || "<anonymous>";
    return "" + fn + " (" + tr[C.filename] + ":" + (tr[C.lineno] + 1) + ")";
  };

  warn = function(m) {
    return typeof console !== "undefined" && console !== null ? console.error("ICED warning: " + m) : void 0;
  };

  exports.trampoline = trampoline = function(fn) {
    if (!tick_counter(500)) {
      return fn();
    } else if ((typeof process !== "undefined" && process !== null ? process.nextTick : void 0) != null) {
      return process.nextTick(fn);
    } else {
      return setTimeout(fn);
    }
  };

  exports.Deferrals = Deferrals = (function() {
    function Deferrals(k, trace) {
      this.trace = trace;
      this.continuation = k;
      this.count = 1;
      this.ret = null;
    }

    Deferrals.prototype._call = function(trace) {
      var c;
      if (this.continuation) {
        __active_trace = trace;
        c = this.continuation;
        this.continuation = null;
        return c(this.ret);
      } else {
        return warn("Entered dead await at " + (_trace_to_string(trace)));
      }
    };

    Deferrals.prototype._fulfill = function(id, trace) {
      if (--this.count > 0) {

      } else {
        return trampoline(((function(_this) {
          return function() {
            return _this._call(trace);
          };
        })(this)));
      }
    };

    Deferrals.prototype.defer = function(args) {
      var self;
      this.count++;
      self = this;
      return make_defer_return(self, args, null, this.trace);
    };

    return Deferrals;

  })();

  exports.findDeferral = findDeferral = function(args) {
    var a, _i, _len;
    for (_i = 0, _len = args.length; _i < _len; _i++) {
      a = args[_i];
      if (a != null ? a[C.trace] : void 0) {
        return a;
      }
    }
    return null;
  };

  exports.Rendezvous = Rendezvous = (function() {
    var RvId;

    function Rendezvous() {
      this.completed = [];
      this.waiters = [];
      this.defer_id = 0;
    }

    RvId = (function() {
      function RvId(rv, id, multi) {
        this.rv = rv;
        this.id = id;
        this.multi = multi;
      }

      RvId.prototype.defer = function(defer_args) {
        return this.rv._defer_with_id(this.id, defer_args, this.multi);
      };

      return RvId;

    })();

    Rendezvous.prototype.wait = function(cb) {
      var x;
      if (this.completed.length) {
        x = this.completed.shift();
        return cb(x);
      } else {
        return this.waiters.push(cb);
      }
    };

    Rendezvous.prototype.defer = function(defer_args) {
      var id;
      id = this.defer_id++;
      return this._defer_with_id(id, defer_args);
    };

    Rendezvous.prototype.id = function(i, multi) {
      multi = !!multi;
      return new RvId(this, i, multi);
    };

    Rendezvous.prototype._fulfill = function(id, trace) {
      var cb;
      if (this.waiters.length) {
        cb = this.waiters.shift();
        return cb(id);
      } else {
        return this.completed.push(id);
      }
    };

    Rendezvous.prototype._defer_with_id = function(id, defer_args, multi) {
      this.count++;
      return make_defer_return(this, defer_args, id, {}, multi);
    };

    return Rendezvous;

  })();

  exports.stackWalk = stackWalk = function(cb) {
    var line, ret, tr, _ref;
    ret = [];
    tr = cb ? cb[C.trace] : __active_trace;
    while (tr) {
      line = "   at " + (_trace_to_string(tr));
      ret.push(line);
      tr = tr != null ? (_ref = tr[C.parent]) != null ? _ref[C.trace] : void 0 : void 0;
    }
    return ret;
  };

  exports.exceptionHandler = exceptionHandler = function(err, logger) {
    var stack;
    if (!logger) {
      logger = console.error;
    }
    logger(err.stack);
    stack = stackWalk();
    if (stack.length) {
      logger("Iced 'stack' trace (w/ real line numbers):");
      return logger(stack.join("\n"));
    }
  };

  exports.catchExceptions = function(logger) {
    return typeof process !== "undefined" && process !== null ? process.on('uncaughtException', function(err) {
      exceptionHandler(err, logger);
      return process.exit(1);
    }) : void 0;
  };

  _timeout = function(cb, t, res, tmp) {
    var arr, rv, which, ___iced_passed_deferral, __iced_deferrals, __iced_k;
    __iced_k = __iced_k_noop;
    ___iced_passed_deferral = iced.findDeferral(arguments);
    rv = new iced.Rendezvous;
    tmp[0] = rv.id(true).defer({
      assign_fn: (function(_this) {
        return function() {
          return function() {
            return arr = __slice.call(arguments, 0);
          };
        };
      })(this)(),
      lineno: 273,
      context: __iced_deferrals
    });
    setTimeout(rv.id(false).defer({
      lineno: 274,
      context: __iced_deferrals
    }), t);
    (function(_this) {
      return (function(__iced_k) {
        __iced_deferrals = new iced.Deferrals(__iced_k, {
          parent: ___iced_passed_deferral
        });
        rv.wait(__iced_deferrals.defer({
          assign_fn: (function() {
            return function() {
              return which = arguments[0];
            };
          })(),
          lineno: 275
        }));
        __iced_deferrals._fulfill();
      });
    })(this)((function(_this) {
      return function() {
        if (res) {
          res[0] = which;
        }
        return cb.apply(null, arr);
      };
    })(this));
  };

  exports.timeout = function(cb, t, res) {
    var tmp;
    tmp = [];
    _timeout(cb, t, res, tmp);
    return tmp[0];
  };

  _iand = function(cb, res, tmp) {
    var ok, ___iced_passed_deferral, __iced_deferrals, __iced_k;
    __iced_k = __iced_k_noop;
    ___iced_passed_deferral = iced.findDeferral(arguments);
    (function(_this) {
      return (function(__iced_k) {
        __iced_deferrals = new iced.Deferrals(__iced_k, {
          parent: ___iced_passed_deferral
        });
        tmp[0] = __iced_deferrals.defer({
          assign_fn: (function() {
            return function() {
              return ok = arguments[0];
            };
          })(),
          lineno: 292
        });
        __iced_deferrals._fulfill();
      });
    })(this)((function(_this) {
      return function() {
        if (!ok) {
          res[0] = false;
        }
        return cb();
      };
    })(this));
  };

  exports.iand = function(cb, res) {
    var tmp;
    tmp = [];
    _iand(cb, res, tmp);
    return tmp[0];
  };

  _ior = function(cb, res, tmp) {
    var ok, ___iced_passed_deferral, __iced_deferrals, __iced_k;
    __iced_k = __iced_k_noop;
    ___iced_passed_deferral = iced.findDeferral(arguments);
    (function(_this) {
      return (function(__iced_k) {
        __iced_deferrals = new iced.Deferrals(__iced_k, {
          parent: ___iced_passed_deferral
        });
        tmp[0] = __iced_deferrals.defer({
          assign_fn: (function() {
            return function() {
              return ok = arguments[0];
            };
          })(),
          lineno: 311
        });
        __iced_deferrals._fulfill();
      });
    })(this)((function(_this) {
      return function() {
        if (ok) {
          res[0] = true;
        }
        return cb();
      };
    })(this));
  };

  exports.ior = function(cb, res) {
    var tmp;
    tmp = [];
    _ior(cb, res, tmp);
    return tmp[0];
  };

  exports.Pipeliner = Pipeliner = (function() {
    function Pipeliner(window, delay) {
      this.window = window || 1;
      this.delay = delay || 0;
      this.queue = [];
      this.n_out = 0;
      this.cb = null;
      this[C.deferrals] = this;
      this["defer"] = this._defer;
    }

    Pipeliner.prototype.waitInQueue = function(cb) {
      var ___iced_passed_deferral, __iced_deferrals, __iced_k;
      __iced_k = __iced_k_noop;
      ___iced_passed_deferral = iced.findDeferral(arguments);
      (function(_this) {
        return (function(__iced_k) {
          var _while;
          _while = function(__iced_k) {
            var _break, _continue, _next;
            _break = __iced_k;
            _continue = function() {
              return iced.trampoline(function() {
                return _while(__iced_k);
              });
            };
            _next = _continue;
            if (!(_this.n_out >= _this.window)) {
              return _break();
            } else {
              (function(__iced_k) {
                __iced_deferrals = new iced.Deferrals(__iced_k, {
                  parent: ___iced_passed_deferral,
                  funcname: "Pipeliner.waitInQueue"
                });
                _this.cb = __iced_deferrals.defer({
                  lineno: 353
                });
                __iced_deferrals._fulfill();
              })(_next);
            }
          };
          _while(__iced_k);
        });
      })(this)((function(_this) {
        return function() {
          _this.n_out++;
          (function(__iced_k) {
            if (_this.delay) {
              (function(__iced_k) {
                __iced_deferrals = new iced.Deferrals(__iced_k, {
                  parent: ___iced_passed_deferral,
                  funcname: "Pipeliner.waitInQueue"
                });
                setTimeout(__iced_deferrals.defer({
                  lineno: 361
                }), _this.delay);
                __iced_deferrals._fulfill();
              })(__iced_k);
            } else {
              return __iced_k();
            }
          })(function() {
            return cb();
          });
        };
      })(this));
    };

    Pipeliner.prototype.__defer = function(out, deferArgs) {
      var tmp, voidCb, ___iced_passed_deferral, __iced_deferrals, __iced_k;
      __iced_k = __iced_k_noop;
      ___iced_passed_deferral = iced.findDeferral(arguments);
      (function(_this) {
        return (function(__iced_k) {
          __iced_deferrals = new iced.Deferrals(__iced_k, {
            parent: ___iced_passed_deferral,
            funcname: "Pipeliner.__defer"
          });
          voidCb = __iced_deferrals.defer({
            lineno: 375
          });
          out[0] = function() {
            var args, _ref;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            if ((_ref = deferArgs.assign_fn) != null) {
              _ref.apply(null, args);
            }
            return voidCb();
          };
          __iced_deferrals._fulfill();
        });
      })(this)((function(_this) {
        return function() {
          _this.n_out--;
          if (_this.cb) {
            tmp = _this.cb;
            _this.cb = null;
            return tmp();
          }
        };
      })(this));
    };

    Pipeliner.prototype._defer = function(deferArgs) {
      var tmp;
      tmp = [];
      this.__defer(tmp, deferArgs);
      return tmp[0];
    };

    Pipeliner.prototype.flush = function(autocb) {
      var ___iced_passed_deferral, __iced_k, _while;
      __iced_k = autocb;
      ___iced_passed_deferral = iced.findDeferral(arguments);
      _while = (function(_this) {
        var __iced_deferrals;
        return function(__iced_k) {
          var _break, _continue, _next;
          _break = __iced_k;
          _continue = function() {
            return iced.trampoline(function() {
              return _while(__iced_k);
            });
          };
          _next = _continue;
          if (!_this.n_out) {
            return _break();
          } else {
            (function(__iced_k) {
              __iced_deferrals = new iced.Deferrals(__iced_k, {
                parent: ___iced_passed_deferral,
                funcname: "Pipeliner.flush"
              });
              _this.cb = __iced_deferrals.defer({
                lineno: 404
              });
              __iced_deferrals._fulfill();
            })(_next);
          }
        };
      })(this);
      _while(__iced_k);
    };

    return Pipeliner;

  })();

}).call(this);
