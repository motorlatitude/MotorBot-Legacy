var ytdl = require('..');

var stream = ytdl('https://www.youtube.com/watch?v=2UBFIhS1YBk');

console.log('Starting Download');

var size, total = 0;
stream.on('response', function(res) {
  size = ~~res.headers['content-length'];
});

stream.on('data', function(chunk) {
  console.log('downloaded', size, total, chunk.length);
  total += chunk.length;
  if (total >= size / 4) {
    console.log('destroying');
    stream.destroy();
  }
});

stream.on('end', function() {
  console.log('Finished');
});
