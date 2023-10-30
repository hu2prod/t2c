// https://gist.github.com/josephrocca/44e4c0b63828cfc6d6155097b2efc113
class BigMap {
  constructor(iterable) {
    if(iterable) throw new Error("haven't implemented construction with iterable yet");
    this._maps = [new Map()];
    this._perMapSizeLimit = 14000000;
    this.size = 0;
  }
  has(key) {
    for(let map of this._maps) {
      if(map.has(key)) return true;
    }
    return false;
  }
  get(key) {
    for(let map of this._maps) {
      if(map.has(key)) return map.get(key);
    }
    return undefined;
  }
  set(key, value) {
    for(let map of this._maps) {
      if(map.has(key)) {
        map.set(key, value);
        return this;
      }
    }
    let map = this._maps[this._maps.length-1];
    if(map.size > this._perMapSizeLimit) {
      map = new Map();
      this._maps.push(map);
    }
    map.set(key, value);
    this.size++;
    return this;
  }
  entries() {
    let mapIndex = 0;
    let entries = this._maps[mapIndex].entries();
    return {
      next: () => {
        let n = entries.next();
        if(n.done) {
          if(this._maps[++mapIndex]) {
            entries = this._maps[mapIndex].entries();
            return entries.next();
          } else {
            return {done:true};
          }
        } else {
          return n;
        }
      }
    };
  }
  [Symbol.iterator]() {
    return this.entries();
  }
  delete(key) {
    var athis = _this;
    this._maps.forEach(function(map) {
      if (map.delete(key)) {
        athis.size--;
      }
    });
  }
  keys() {
    var list = [];
    this._maps.forEach(function(map) {
      var loc_list = map.keys();
      for(var i=0,len=loc_list.length;i<len;i++) {
        list.push(loc_list[i]);
      }
    })
    return list;
  }
  values() {
    var list = [];
    this._maps.forEach(function(map) {
      var loc_list = map.values();
      for(var i=0,len=loc_list.length;i<len;i++) {
        list.push(loc_list[i]);
      }
    })
    return list;
  }
  forEach(fn) {
    this._maps.forEach(function(map) {
      map.forEach(fn);
    })
  }
  clear() {
    this._maps = [new Map()];
    this.size = 0;
  }
}

module.exports = BigMap;
