// YellowLeaf FTP by Michiel Dral 
var AssertEntity;

module.exports = AssertEntity = (function() {
  function AssertEntity(entity) {
    this.entity = entity;
  }

  AssertEntity.prototype.isDirectory = function() {
    if (!this.entity.isDirectory) {
      throw new Error("Cannot apply to a regular file.");
    }
  };

  AssertEntity.prototype.isFile = function() {
    if (this.entity.isDirectory) {
      throw new Error("Cannot apply to a directory.");
    }
  };

  return AssertEntity;

})();
