//Title: Test SharedWorker constructor functionality.

import { test, assert_throws_js } from '../../../js/DOM/Events/Testharness';
const SharedWorkerInfo = require('../../../js/MessagePassing/WebWorkers/SharedWorker');
const SharedWorker = SharedWorkerInfo.SharedWorker;
const WorkerInfo = require('../../../js/MessagePassing/WebWorkers/Worker');
const Worker = WorkerInfo.Worker;


test(() => {
  assert_throws_js(Error,
                   function() {
                     new SharedWorker({toString:function(){throw new Error()}}, "name") },
                   "toString exception not propagated");
}, "Test toString exception propagated correctly.");

test(() => {
  assert_throws_js(RangeError,
                   function() {
                     var foo = {toString:function(){new Worker(foo)}}
                     new SharedWorker(foo, "name"); },
                   "Trying to create workers recursively did not result in an exception.");
}, "Test recursive worker creation results in exception.");

test(() => {
  assert_throws_js(TypeError,
                   function() { new SharedWorker(); },
                   "Invoking SharedWorker constructor without arguments did not result in an exception.");
}, "Test SharedWorker creation without arguments results in exception.");

test(() => {
  try {
    var worker = new SharedWorker("support/SharedWorker-common.js");
  } catch (ex) {
    assert_unreached("Constructor failed when no name is passed: (" + ex + ")");
  }
}, "Test SharedWorker constructor without a name does not result in an exception.");

test(() => {
  try {
    var worker = new SharedWorker("support/SharedWorker-common.js", null);
  } catch (ex) {
    assert_unreached("Constructor failed when null name is passed: (" + ex + ")");
  }
}, "Test SharedWorker constructor with null name does not result in an exception.");

test(() => {
  try {
    var worker = new SharedWorker("support/SharedWorker-common.js", undefined);
  } catch (ex) {
    assert_unreached("Constructor failed when undefined name is passed: (" + ex + ")");
  }
}, "Test SharedWorker constructor with undefined name does not result in an exception.");

test(() => {
  try {
    var worker = new SharedWorker("support/SharedWorker-common.js", "name");
  } catch (ex) {
    assert_unreached("Invoking SharedWorker constructor resulted in an exception: (" + ex + ")");
  }
}, "Test SharedWorker constructor suceeds.");