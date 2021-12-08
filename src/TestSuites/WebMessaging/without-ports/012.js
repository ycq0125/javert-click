//Title: loop in array in structured clone</title>

import { MessageChannel } from '../../../js/MessagePassing/WebMessaging/MessageChannel';
import { assert_equals, async_test } from '../../../js/DOM/Events/Testharness';
const Window = require('../../../js/DOM/Events/Window');
var window = Window.getInstance();

async_test(function() {
  var x = [];
  x[0] = x;
  window.postMessage(x, '*');
  window.onmessage = this.step_func(function(e) {
    assert_equals(e.data, e.data[0]);
    this.done();
  });
});