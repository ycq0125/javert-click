const JS2JSILList = require('../../Utils/JS2JSILList');

/*
* @id MPSemantics
*/
function MPSemantics(){
}

/*
* @id MPSemanticsNewPort
*/
MPSemantics.prototype.newPort = function(){
    return __MP__wrapper__newPort();
}

/*
* @id MPSemanticsSend
*/
MPSemantics.prototype.send = function(message, plist, orig_port, dest_port){
    console.log('MPSem: send');
    var mplist = JS2JSILList.JS2JSILList([message, dest_port]); 
    var plistJSIL = JS2JSILList.JS2JSILList(plist);
    __MP__wrapper__send(mplist, plistJSIL, orig_port, dest_port);
}

/*
* @id MPSemanticsCreate
*/
MPSemantics.prototype.create = function(url, setup_fid, outsidePortId, isShared){
    console.log('MPSem: create, outsideportid: '+outsidePortId);
    var argslist = JS2JSILList.JS2JSILList([url, outsidePortId, isShared]); 
    return __MP__wrapper__create(url, setup_fid, argslist);
}

/*
* @id MPSemanticsPairPorts
*/
MPSemantics.prototype.pairPorts = function(port1Id, port2Id){
    this.unpairPort(port1Id);
    this.unpairPort(port2Id);
    console.log('MPSem: pair');
    __MP__wrapper__pairPorts(port1Id, port2Id);
}

/*
* @id MPSemanticsUnpairPorts
*/
MPSemantics.prototype.unpairPort = function(portId){
    console.log('MPSem: unpair');
    __MP__wrapper__unpairPort(portId);
}

/*
* @id MPSemanticsGetPaired
*/
MPSemantics.prototype.getPaired = function(portId){
    console.log('MPSem: getPaired');
    return __MP__wrapper__getPaired(portId);
}

/*
* @id MPSemanticsTerminate
*/
MPSemantics.prototype.terminate = function(confId){
    return __MP__wrapper__terminate(confId);
}

/*
* @id MPSemanticsBeginAtomic
*/
MPSemantics.prototype.beginAtomic = function(){
    return __MP__wrapper__beginAtomic();
}  

/*
* @id MPSemanticsEndAtomic
*/
MPSemantics.prototype.endAtomic = function(){
    return __MP__wrapper__endAtomic();
} 

exports.MPSemantics = MPSemantics;