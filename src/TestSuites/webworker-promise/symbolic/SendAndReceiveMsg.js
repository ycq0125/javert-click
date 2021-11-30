console.log('MAIN: creating worker');

const worker = new WebworkerPromise(new Worker('basicworker.js'));

var msg = symb(msg);
//var msg = null;
var isobj = typeof msg === 'object';
JavertAssume (isobj);

console.log('MAIN: posting message to worker');
worker.postMessage(msg)
.then((response) => {
    console.log('MAIN: Got message: '+response);
    assert_object_equals(response, msg);
})
.catch(err => {
    console.log('MAIN: Got error');
    JavertAssert(false)
});

/*
Failing Model:
	[(#msg: null)]

 STATISTICS 
 ========== 

Executed commands: 363799

real	4m13.077s
user	4m1.442s
sys	0m1.977s
*/

console.log('MAIN: finsihed executing script')