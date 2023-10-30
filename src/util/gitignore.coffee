line_file = require "./line_file"
@push = (item)->
  line_file.push ".gitignore", item
