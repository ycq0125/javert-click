const DedicatedWorkerGlobalScopeAlternative = require('../MessagePassing/WebWorkers/DedicatedWorkerGlobalScopeAlternative');
const MessagePort                           = require('../MessagePassing/PostMessage/MessagePort');
const MPSemantics                           = require('../MessagePassing/Common/MPSemantics');
//const MessageEvent                          = require('../DOM/Events/MessageEvent');

/*
* @JSIL
* @id __setupConf
*/
function __setupConf(workerURL, outsidePortId, isShared, main_fid){
    // First thing to be executed in every worker. Script file needs to import this file. This function needs to be executed before the script.
    var setupInitialHeapName = "setupInitialHeap";
    var global = executeJSILProc(setupInitialHeapName);
    console.log('WORKER: setupInitialHeap executed successfully!');
    //var MP = initMessagePassing();
    //global.__scopeMP = MP.MessagePort.MessagePort.__scopeMP;
    console.log('WORKER: initMessagePassing executed successfully');
    //var workerGlobalObj = isShared ? new MP.SharedWorkerGlobalScope.SharedWorkerGlobalScope(workerURL) : new MP.DedicatedWorkerGlobalScope.DedicatedWorkerGlobalScope(workerURL);
    if(isShared) {
        //MP.SharedWorkerGlobalScope.SharedWorkerGlobalScope(workerURL)
    } else { 
        console.log('WORKER: isShared: false');
        //MP.
        DedicatedWorkerGlobalScopeAlternative.DedicatedWorkerGlobalScopeAlternative(global, workerURL);
    }
    // Create inside port and associate it with global object
    // 16. Let inside port be a new MessagePort object in inside settings's Realm.
    console.log('WORKER: Going to create inside port');
    var insidePort = new MessagePort.MessagePort();
    console.log('WORKER: created inside port with id '+insidePort.__id);
    // 17. Associate inside port with worker global scope.
    global.__port = insidePort;
    //var MPSemantics = MP.MPSemantics;
    // 18. Entangle outside port and inside port.
    MPSemantics.pairPorts(outsidePortId, insidePort.__id);
    console.log('WORKER: just paired ports '+outsidePortId+' and '+insidePort.__id);
    // 23. If script is a classic script, then run the classic script script. Otherwise, it is a module script; run the module script script.
    executeJSILProc(main_fid);
    //console.log('WORKER: going to add handler for process message event');
    //EventsSemantics.addHandler("ProcessMessage", "processMessageSteps");
    //console.log('WORKER: handler for process message event added!');
   //__postScript(workerGlobalObj, EventSemantics, MP);
}

function __postScript(workerGlobalObj, EventsSemantics, MP){
    EventsSemantics.addHandler("ProcessMessage", "processMessageSteps");
    // 26. If is shared is true, then queue a global task on DOM manipulation task source given worker global scope to 
    // fire an event named connect at worker global scope, using MessageEvent, 
    // with the data attribute initialized to the empty string, 
    // the ports attribute initialized to a new frozen array containing inside port, 
    // and the source attribute initialized to inside port.
    if(workerGlobalObj.hasOwnProperty('onconnect')){
        var event = new MP.MessageEvent.MessageEvent();
        event.data = "";
        event.ports = [workerGlobalObj.__port];
        Object.freeze(event.ports);
        workerGlobalObj.dispatchEvent(event);
    }
}