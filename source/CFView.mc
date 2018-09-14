using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.Application;
using Toybox.ActivityMonitor as AMon;

var partialUpdatesAllowed = false;

class CFView extends WatchUi.WatchFace
{
    var isAwake;
    var screenShape;
    var dndIcon;
    var offscreenBuffer;
    var screenWidth;
    var screenHeight;
    var screenCenter;
    
   var _bluetoothBitmap = null;
   var _notificationBitmap = null;
   var _bleNotifYPos;

   var _dateFont;
   var _dateYPos;

   var _timeFont;
   var _timeYPos;

   var _cryptoFont;
   var _cryptoYPos;

   var _stockFont;
   var _stockYPos;

   var _altFont;
   var _altYPos;
 
   var _tempFont;
   var _tempYPos;
 
   var _stepFont;
   var _stepYPos;

   var _hrFont;
   var _hrYPos;

   var fullScreenRefresh;

   var _isRectangle = false;

   // @todo instead of defining this twice (also in cfServiceDelegate), set it as a storage property
   // "the only way to pass data from the main app to the background service is as a property.
   // Your ServiceDelegate can retrieve it with AppBase.getProperty() [deprecated].
   // Make sure to handle the case where the background may not have the data it needs here,
   // as there are things that may not yet have valid values."
   var cryptoCurrDict2 = {
      0 => "BTC",
      1 => "BCH",
      2 => "ETH",
      3 => "LTC"
   };

   /**
    * Initialize variables for this view
    */
   function initialize() {
      WatchFace.initialize();
      
      /* Get the background data from the Object Store b/c...
       * "In the main process, when it first starts, I’ll see if data is in the object store, and if so,
       * then you display that as a “last known value”. If you don’t do something like this with a watch face,
       * each time you leave the watch face and come back, there wouldn’t be any data until the background runs again."*/
      var bgTmp = Application.getApp().getProperty(OSDATA);
      if(bgTmp!=null) {
         System.println("Initializing background data from the object store...");
         bgdata = bgTmp;
      }
      //System.println("bgdata.get(\"BCH\")["+bgdata.get("BCH")+"]");

      screenShape = System.getDeviceSettings().screenShape;
      fullScreenRefresh = true;
      partialUpdatesAllowed = ( Toybox.WatchUi.WatchFace has :onPartialUpdate );
      
      System.println("done initilaizing");

      _isRectangle = System.getDeviceSettings().screenShape != System.SCREEN_SHAPE_ROUND;
      System.println("_isRectangle["+_isRectangle+"]");
   }

   /**
    * Configure the layout of the watchface for this device
    */
   function onLayout(dc) {
      _bluetoothBitmap = WatchUi.loadResource(Rez.Drawables.bluetoothIconB);
      _notificationBitmap = WatchUi.loadResource(Rez.Drawables.notificationIconB);     
      _bleNotifYPos = 2;

      _dateYPos = (_bluetoothBitmap.getHeight() > _notificationBitmap.getHeight()) ? _bluetoothBitmap.getHeight() : _notificationBitmap.getHeight();
      _dateFont = Graphics.FONT_MEDIUM;

      var fudgeFactor = 1;
      _timeYPos = _dateYPos + dc.getFontHeight(_dateFont) - fudgeFactor;
      _timeFont = Graphics.FONT_NUMBER_THAI_HOT;
      
      _stockYPos = _timeYPos + dc.getFontHeight(_timeFont) - fudgeFactor;
      _stockFont = Graphics.FONT_SMALL;
      
      _cryptoYPos = _stockYPos + dc.getFontHeight(_stockFont) - fudgeFactor;
      _cryptoFont = Graphics.FONT_SMALL;
      
      _hrYPos = _cryptoYPos + dc.getFontHeight(_cryptoFont) - fudgeFactor;
      _hrFont = Graphics.FONT_SMALL;
      
      _tempYPos = _hrYPos;
      _tempFont = Graphics.FONT_SMALL;
      
      _stepYPos = _stockYPos;
      _stepFont = Graphics.FONT_SMALL;

      _altYPos = _cryptoYPos;
      _altFont = Graphics.FONT_SMALL;

      // If this device supports the Do Not Disturb feature,
      // load the associated Icon into memory.
      if (System.getDeviceSettings() has :doNotDisturb) {
         dndIcon = WatchUi.loadResource(Rez.Drawables.DoNotDisturbIcon);
      }
      else {
         dndIcon = null;
      }

      screenHeight = dc.getHeight();
      screenWidth = dc.getWidth();
      screenCenter = screenWidth/2;

      // If this device supports BufferedBitmap, allocate the buffers we use for drawing
      if(Toybox.Graphics has :BufferedBitmap && !_isRectangle) {
         offscreenBuffer = new Graphics.BufferedBitmap({
            :width=>screenWidth,
            :height=>screenHeight
         });
      }
      else {
         offscreenBuffer = null;
      }
   }

   // Handle the update event
   function onUpdate(dc) {
      var clockTime = System.getClockTime();
      var targetDc = null;
      var x = 0; var y = 0;

      // We always want to refresh the full screen when we get a regular onUpdate call.
      fullScreenRefresh = true;

      if(null != offscreenBuffer) {
         dc.clearClip();

         // If we have an offscreen buffer that we are using to draw the background,
         // set the draw context of that buffer as our target.
         targetDc = offscreenBuffer.getDc();
      }
      else {
         targetDc = dc;
      }

      // Fill the entire background with Black.
      targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
      targetDc.fillRectangle(0, 0, screenWidth, screenHeight);

      // Draw the do-not-disturb icon if we support it and the setting is enabled
      if (null != dndIcon && System.getDeviceSettings().doNotDisturb) {
         targetDc.drawBitmap( screenWidth * 0.75, screenHeight / 2 - 15, dndIcon);
      }

      // Bluetooth icon
      x = screenCenter-30;
      if (System.getDeviceSettings().phoneConnected) {
         targetDc.drawBitmap(x, _bleNotifYPos, _bluetoothBitmap);
      }

      // Notification icon
      targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
      var notificationCnt = System.getDeviceSettings().notificationCount;  //notificationCnt = 88;
      if (notificationCnt > 0) {
         x = screenCenter+0;
         targetDc.drawBitmap(x, _bleNotifYPos, _notificationBitmap);
         targetDc.drawText(x+13, _bleNotifYPos-4, Graphics.FONT_TINY, notificationCnt, Graphics.TEXT_JUSTIFY_CENTER);
      }
      
      // DATE
      x = screenCenter;
      var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
      var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);
      targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      targetDc.drawText(x, _dateYPos, _dateFont, dateStr, Graphics.TEXT_JUSTIFY_CENTER);

      // TIME
      x = screenCenter;
      var hour = clockTime.hour;
      if (!System.getDeviceSettings().is24Hour) {
         hour = hour % 12;
         if (hour == 0) {
            hour = 12;
         }
      }
      targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      if(!_isRectangle){
         targetDc.drawText(x-60, _timeYPos, _timeFont, hour.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
         targetDc.drawText(x+60, _timeYPos, _timeFont, clockTime.min.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
      }
      else {
         targetDc.drawText(x, _timeYPos, _timeFont, hour.format("%02d")+":"+clockTime.min.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
      }

      // STOCK
      x = screenCenter-6;
      var sym = Application.Properties.getValue("StockSymbol");
      System.println("Calling bgdata.get() for sym["+sym+"]...");
      // @todo - sometimes getting "Unexpected Type Error".
      // Probably has something to do with the way bgdata is initialized from the object store
      var assetPrice = bgdata.get(sym);  //assetPrice = 20000.08;
      var rounded = (null != assetPrice) ? Math.round(assetPrice.toNumber()) : "--";
      targetDc.drawText(x, _stockYPos, _stockFont, rounded+" "+sym, Graphics.TEXT_JUSTIFY_RIGHT);
      
      // CRYPTOCURRENCY
      var cryptoCurrKey = Application.Properties.getValue("Cryptocurrency");
      sym = cryptoCurrDict2.get(cryptoCurrKey);
      System.println("CFView - sym["+sym+"]");
      assetPrice = bgdata.get(sym);  //assetPrice = 20000.08;
      rounded = (null != assetPrice) ? Math.round(assetPrice.toNumber()) : "--";
      targetDc.drawText(x, _cryptoYPos, _cryptoFont, rounded+" "+sym, Graphics.TEXT_JUSTIFY_RIGHT);

      // HEART      
      y = _stockYPos;
      var hrIter = AMon.getHeartRateHistory(null, true);
      var hr = hrIter.next();
      var bpm = (hr.heartRate != AMon.INVALID_HR_SAMPLE && hr.heartRate > 0) ? hr.heartRate : 0;
      targetDc.drawText(x, _hrYPos, _hrFont, bpm.toString()+" bpm", Graphics.TEXT_JUSTIFY_RIGHT);

      //******* Start the 2nd column
      x = screenCenter+6;

      // STEPS
      var steps = AMon.getInfo().steps;  //steps = 5154;
      targetDc.drawText(x, _stepYPos, _stepFont, steps.toString()+" stp", Graphics.TEXT_JUSTIFY_LEFT);

      // ALTITUDE
	  y = _cryptoYPos;
      var alt = Toybox.Activity.getActivityInfo().altitude;
      if (alt != null) {
	     if (System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE) {
	        alt = alt * 3.2808399;
	     }
	     if (alt - alt.toNumber() > 0.5) {
            alt += 1;
	     }
	     alt = alt.toNumber();
	  }
      else {
	     alt = "--";
	  }
	  var fieldTxt = alt;  //fieldTxt = 10000;
	  var units = System.getDeviceSettings().elevationUnits == System.UNIT_METRIC ? " m" : " ft"; 
	  targetDc.drawText(x, _altYPos, _altFont, fieldTxt + units, Graphics.TEXT_JUSTIFY_LEFT);

      // TEMPERATURE
      var temperatureHistory = SensorHistory.getTemperatureHistory({});
      var temperature = temperatureHistory.next();
      if(null == temperature) {
         fieldTxt = "-";
      }
      else {
         if(System.getDeviceSettings().elevationUnits == System.UNIT_METRIC) {
            fieldTxt = temperature.data.format("%.0f")+"°C";
         }
         else {
            fieldTxt = (temperature.data.toFloat()*1.8+32).format("%.0f")+"°F";
         }
      }
      targetDc.drawText(x, _tempYPos, _tempFont, fieldTxt, Graphics.TEXT_JUSTIFY_LEFT);
      //fieldTxt = (null == temperature) ? "-" : (temperature.data.toFloat()*1.8+32).format("%.0f");  //fieldTxt = 100;
      //targetDc.drawText(x, _tempYPos, _tempFont, fieldTxt+"°F", Graphics.TEXT_JUSTIFY_LEFT);

   
      // BATTERY
      var totalWidth = 35;
      var nippleWidth = 3;
      x = (dc.getWidth() - totalWidth) / 2;
      var borderWidth = 1;
      
      var totalHeight = 16;
      var nippleHeight = 7;
      y = screenHeight-totalHeight-4;
      
      // Draw base without nipple   
      targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
      targetDc.fillRectangle(x, y, totalWidth-nippleWidth, totalHeight);

      // Draw nipple
      targetDc.fillRectangle(x+totalWidth-nippleWidth, y+((totalHeight-nippleHeight)/2), nippleWidth, nippleHeight);

      // Fill base color
      targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
      targetDc.fillRectangle(x+borderWidth, y+borderWidth, totalWidth-nippleWidth-borderWidth*2, totalHeight-borderWidth*2);
      
      // Draw remaining battery
      var remainingBattery = System.getSystemStats().battery;
      if(remainingBattery >= 25) {
         targetDc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
      }
      else if(remainingBattery >= 10) {
         targetDc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_YELLOW);
      }
      else {
         targetDc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
      }
      
      var innerBorderWidth = 1;
      var statusWidth = (totalWidth-nippleWidth-innerBorderWidth*2-borderWidth*2)*remainingBattery/100;
      var statusWidthInt = Toybox.Math.round(statusWidth).toNumber();
      targetDc.fillRectangle(x+borderWidth+innerBorderWidth, y+borderWidth+innerBorderWidth, statusWidthInt, totalHeight-innerBorderWidth*2-borderWidth*2);

      // Output the offscreen buffers to the main display if required.
      // NOTE: switched dc. to targetDc.
      drawBackground(targetDc);

      if( partialUpdatesAllowed ) {
         // If this device supports partial updates and they are currently
         // allowed run the onPartialUpdate method to draw the seconds.
         onPartialUpdate( targetDc );
      }
      else if ( isAwake ) {
         // Otherwise, if we are out of sleep mode, draw the seconds
         // directly in the full update method.
         drawSeconds(targetDc, false);
      }

      fullScreenRefresh = false;
   }   

   // Handle the partial update event
   function onPartialUpdate( dc ) {
      // If we're not doing a full screen refresh we need to re-draw the background
      // before drawing the updated seconds position. Note this will only re-draw
      // the background in the area specified by the previously computed clipping region.
      if(!fullScreenRefresh) {
         drawBackground(dc);
      }
       
      drawSeconds(dc, true);
   }

   // Draw Seconds
   function drawSeconds(dc, setClipFlg) {
      var secFont = Graphics.FONT_MEDIUM;
      var clipHeight = Graphics.getFontHeight(_timeFont);
      var clipWidth = 40;
      var clipX = (screenWidth-clipWidth)/2;
      if(setClipFlg) {
         dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
         dc.fillRectangle(clipX, _timeYPos, clipWidth, clipHeight);
         dc.setClip(clipX, _timeYPos, clipWidth, clipHeight);
      }
 
      dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);

      var clockTime = System.getClockTime();
      var sec = clockTime.sec.format("%02d");
         dc.drawText(screenCenter, _timeYPos, secFont, sec.substring(0,1), Graphics.TEXT_JUSTIFY_CENTER);
         dc.drawText(screenCenter, _timeYPos+25, secFont, sec.substring(1,2), Graphics.TEXT_JUSTIFY_CENTER);
   }

   // Draw the watch face background 
   // onUpdate uses this method to transfer newly rendered Buffered Bitmaps
   // to the main display.
   // onPartialUpdate uses this to blank the seconds from the previous
   // second before outputing the new one.
   function drawBackground(dc) {
      // If we have an offscreen buffer that has been written to
      // draw it to the screen.
      if( null != offscreenBuffer ) {
         dc.drawBitmap(0, 0, offscreenBuffer);
      }
   }

   // This method is called when the device re-enters sleep mode.
   // Set the isAwake flag to let onUpdate know it should stop rendering the seconds.
   function onEnterSleep() {
      isAwake = false;
      WatchUi.requestUpdate();
   }

   // This method is called when the device exits sleep mode.
   // Set the isAwake flag to let onUpdate know it should render the seconds.
   function onExitSleep() {
      isAwake = true;
   }
}

class CFWatchFaceDelegate extends WatchUi.WatchFaceDelegate {
   // The onPowerBudgetExceeded callback is called by the system if the
   // onPartialUpdate method exceeds the allowed power budget. If this occurs,
   // the system will stop invoking onPartialUpdate each second, so we set the
   // partialUpdatesAllowed flag here to let the rendering methods know they
   // should not be rendering a seconds.
   function onPowerBudgetExceeded(powerInfo) {
      System.println( "Average execution time: " + powerInfo.executionTimeAverage );
      System.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
      partialUpdatesAllowed = false;
   }
}
