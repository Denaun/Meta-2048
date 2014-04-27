var eventObj = document.createEventObject ? document.createEventObject() : document.createEvent("Events");

if(eventObj.initEvent)
  eventObj.initEvent("keydown", true, true);

eventObj.keyCode = arguments[0];
eventObj.which = arguments[0];

var el = document.body
el.dispatchEvent ? el.dispatchEvent(eventObj) : el.fireEvent("onkeydown", eventObj); 
