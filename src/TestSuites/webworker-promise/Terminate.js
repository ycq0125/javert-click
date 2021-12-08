console.log('MAIN: creating worker');

const worker = new WebworkerPromise(new Worker('terminateworker.js'));

var msg = symb_string(msg);

worker.terminate();

console.log('MAIN: posting message to worker');
worker.postMessage(msg)
.then((response) => {
    console.log('MAIN: got success');
    JavertAssert(false)
})
.catch(err => {
    console.log('MAIN: Got error');
    JavertAssert(false)
});

console.log('MAIN: finsihed executing script')