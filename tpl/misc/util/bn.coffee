module = @
buf_pool = require "./buf_pool"

Math.abs_bn = (a)->
  if a < 0 then -a else a

Math.min_bn = (a,b)->
  if a < b then a else b

Math.max_bn = (a,b)->
  if a > b then a else b

# ###################################################################################################
#    legacy API
# ###################################################################################################
@buf2bn = (buf)->
  hex = buf.toString("hex").rjust(2, "0")  # обязательно минимум 1 байт
  hex = "0#{hex}" if hex.length % 2 == 1 # обязательно кратно 2
  BigInt "0x#{hex}"

@bn2buf = (bn)->
  buf = Buffer.alloc 8
  buf.writeBigInt64BE bn
  buf

@bn2buf_pool = (bn)->
  buf = buf_pool.alloc 8
  buf.writeBigInt64BE bn
  buf

# ###################################################################################################
#    new API
# ###################################################################################################
Buffer.prototype.toBn = ()->
  module.buf2bn @

BigInt.prototype.toBuffer = ()->
  module.bn2buf @

BigInt.prototype.toNumber = ()->
  # +@toString()
  Number @
