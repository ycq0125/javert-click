// main.js
console.log('MAIN: creating worker');

var msg = symb_string(msg);
const worker = new WebworkerPromise(new Worker('errorworker.js'));
console.log('Main: worker created');


//var bound = msg.length >= 0 && msg.length <= 20;
//JavertAssume(bound);

var p = worker.postMessage(msg);
p.then(function(msg){
  console.log('Main: Executing then clause')
  JavertAssert(false);
});

p.catch(function (err) {
  console.log('err.message:'+err.message); // 'myException!'
  var errMsgIsCorrect = err.message === 'myException!';
  JavertAssert(errMsgIsCorrect);
  console.log('err.stack:'+err.stack); // stack trace string
});