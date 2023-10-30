(function() {
  Promise.prototype.cb = function(cb) {
    this["catch"]((function(_this) {
      return function(err) {
        return cb(err);
      };
    })(this));
    return this.then((function(_this) {
      return function(res) {
        return cb(null, res);
      };
    })(this));
  };

}).call(this);
