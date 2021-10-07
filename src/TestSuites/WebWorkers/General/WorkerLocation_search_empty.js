//Title: WorkerLocation.search with empty &lt;query&gt;

import { async_test, assert_equals } from '../../../js/DOM/Events/Testharness';
const WorkerInfo = require('../../../js/MessagePassing/WebWorkers/Worker');
const Worker = WorkerInfo.Worker;

async_test(function(t) {
  var worker = new Worker("./support/WorkerLocation.js?");
  worker.onmessage = t.step_func_done(function(e) {
    assert_equals(e.data.search, "");
  });
});