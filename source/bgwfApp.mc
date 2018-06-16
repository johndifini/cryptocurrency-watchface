using Toybox.Application as App;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;

// Thanks to JIM MILLER for his Background Service code!
// https://developer.garmin.com/index.php/blog/post/guest-post-creating-a-connect-iq-background-service


// info about whats happening with the background process
var counter=0;
var bgdata;
var canDoBG=false;

// keys to the object store data
var OSCOUNTER="oscounter";
var OSDATA="osdata";

(:background)
class bgwfApp extends App.AppBase {
   function initialize() {
      AppBase.initialize();
      var now=Sys.getClockTime();
      var ts=now.hour+":"+now.min.format("%02d");
      //you'll see this gets called in both the foreground and background    	          
      Sys.println("App initialize "+ts);
   }

   // onStart() is called on application start up
   function onStart(state) {
      Sys.println("onStart");
   }

   // onStop() is called when your application is exiting
   function onStop(state) {
      Sys.println("onStop");
   }

   // Return the initial view of your application here
   function getInitialView() {
      Sys.println("getInitialView");
      //register for temporal events if they are supported
      if(Toybox.System has :ServiceDelegate) {
         canDoBG=true;
         Background.registerForTemporalEvent(new Time.Duration(5 * 60));
      }
      else {
         Sys.println("****background not available on this device****");
      }
      
      if( Toybox.WatchUi has :WatchFaceDelegate ) {
         return [new CFView(), new CFWatchFaceDelegate()];
      }
      else {
         return [new CFView()];
      }

   }
    
   function onBackgroundData(data) {
      Sys.println("onBackgroundData");
      counter++;
      var now=Sys.getClockTime();
      var ts=now.hour+":"+now.min.format("%02d");
      Sys.println("onBackgroundData="+data+" "+counter+" at "+ts);
      bgdata=data;
      // Store the background data in the Object Store b/c...
      // "In the main process, when it first starts, I’ll see if data is in the object store, and if so,
      // then you display that as a “last known value”. If you don’t do something like this with a watch face,
      // each time you leave the watch face and come back, there wouldn’t be any data until the background runs again."
      App.getApp().setProperty(OSDATA, bgdata);
      Ui.requestUpdate();
   }    

   function getServiceDelegate() {
      Sys.println("getServiceDelegate");
      var now=Sys.getClockTime();
      var ts=now.hour+":"+now.min.format("%02d");    
      Sys.println("getServiceDelegate: "+ts);
      
      return [new cfServiceDelegate()];
    }
}