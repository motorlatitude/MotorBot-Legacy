//var Buffer = require('buffer/').Buffer

var header = Buffer.alloc(72);
header.fill(0);
var lastRowOffset = "cake"; // file header + row header
header.write(lastRowOffset, 0, 4);
console.log(header);
console.log(header.constructor.name.toString());
