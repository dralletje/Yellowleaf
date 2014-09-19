// YellowLeaf FTP by Michiel Dral 
var CustomFile;

exports.File = CustomFile = (function() {
  function CustomFile(stream) {
    this.stream = stream;
  }

  CustomFile.prototype.read = function() {
    return this.stream;
  };

  CustomFile.prototype.isDirectory = false;

  return CustomFile;

})();
