//Title: object with length as transferable

import { assert_throws, test } from '../../../js/DOM/Events/Testharness';
import { MessageChannel } from '../../../js/MessagePassing/PostMessage/MessageChannel';
const Window = require('../../../js/DOM/Events/Window');
var window = Window.getInstance();

test(function() {
   assert_throws(new TypeError(), function() {
      window.postMessage('', '*', {length:1});
   });
   console.log('assert_throws finished execution');
});

