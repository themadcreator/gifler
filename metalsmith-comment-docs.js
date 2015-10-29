types     = require('ast-types');
recast    = require('recast');
fs        = require('fs');
yaml      = require('js-yaml');
yamlRegex = /^(---)/;

function getCommentYamls(contents){
  var yamls = [];
  var ast = recast.parse(contents);

  types.visit(ast, {
    visitComment : function(path){
      this.traverse(path);
      if (types.namedTypes.Block.check(path.value)) {
        content = path.value.value.trim();
        if (yamlRegex.test(content)) {
          obj = yaml.safeLoad(content);
          yamls.push(obj);
        }
      }
    }
  });
  return yamls;
}

module.exports = function(options) {
  return function(files, metalsmith, done) {
    for (key in options) {
      if (options.hasOwnProperty(key)) {
        path = metalsmith.path(options[key]);
        metalsmith.metadata()[key] = getCommentYamls(fs.readFileSync(path, 'utf8'));
      }
    }
    done();
  };
}
