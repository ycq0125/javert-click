console.log('MAIN: Going to initiliaze heap!');
var MP = initMessagePassing();
console.log('MAIN: Heap initialized!');
var Worker = MP.Worker.Worker;

var n = 6;
var worker = new Worker('FibonacciWorker.js');
console.log('MAIN: worker created with id '+worker.__id);
console.log('MAIN: going to send message to worker');
worker.postMessage(n);
console.log('MAIN: message sent to worker');
worker.onmessage = function(e) { console.log('MAIN: got result from worker:'+e.data)};