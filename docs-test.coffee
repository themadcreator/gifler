types  = require 'ast-types'
recast = require 'recast'
fs     = require 'fs'

ast = recast.parse(fs.readFileSync('./gifler.js'))
types.visit ast, {
  visitComment : (path) ->
    @traverse(path);
    if (types.namedTypes.Block.check(path.value))
      console.log 'BLOCK', path.value.value
}