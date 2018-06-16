using Toybox.Background;
using Toybox.System as Sys;

// Thanks to JIM MILLER for his Background Service code!
// https://developer.garmin.com/index.php/blog/post/guest-post-creating-a-connect-iq-background-service

// The Service Delegate is the main entry point for background processes
// our onTemporalEvent() method will get run each time our periodic event
// is triggered by the system.
(:background)
class cfServiceDelegate extends Toybox.System.ServiceDelegate {
   var _resultDict = {};

   // @todo see cryptoCurrDict2 in CFView
   var cryptoCurrDict = {
      0 => "BTC",
      1 => "BCH",
      2 => "ETH",
      3 => "LTC"
   };
   
   var quoteCurrDict = {
      0 => "USD",
      1 => "EUR",
      2 => "JPY",
      3 => "GBP",
      4 => "CHF",
      5 => "CAD"
   };
   
   var _responsesRcvd = 0;

   function initialize() {
        Sys.println("BgbgServiceDelegate initialize");
		Sys.ServiceDelegate.initialize();
	}
	
   function onTemporalEvent() {
      Sys.println("BgbgServiceDelegate onTemporalEvent");
      
      /////////////////
      // Cryptocurrency web request
      /////////////////
      var cryptoOptions = {
         :method => Communications.HTTP_REQUEST_METHOD_GET,
         :headers => {"CB-VERSION" => "2017-12-23"},
         :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
       };

      var propertyKey = Application.Properties.getValue("Cryptocurrency");
      var cryptoCurrSym = cryptoCurrDict.get(propertyKey);
      System.println("cryptoCurrVal["+cryptoCurrSym+"]");

      // @todo Probably a better term than QuoteCurrency is FiatCurrency
      propertyKey = Application.Properties.getValue("QuoteCurrency");
      var quoteCurrSym = quoteCurrDict.get(propertyKey);
      System.println("quoteCurrSym["+quoteCurrSym+"]");

      Sys.println("BgbgServiceDelegate making web request...");
      Toybox.Communications.makeWebRequest(
         "https://api.coinbase.com/v2/prices/"+cryptoCurrSym+"-"+quoteCurrSym+"/spot",
         {
         },
         cryptoOptions,
         method(:cryptoOnReceive)
      );

      /////////////////
      // Stock web request
      /////////////////
      var stockOptions = {
         :method => Communications.HTTP_REQUEST_METHOD_GET,
         :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
       };
      // @todo URL encode
      var stockSym = Application.Properties.getValue("StockSymbol");
      System.println("stockSym["+stockSym+"]");
      Sys.println("BgbgServiceDelegate making 2nd web request...");
      Toybox.Communications.makeWebRequest(
         "https://api.iextrading.com/1.0/stock/"+stockSym+"/quote",
         {
         },
         stockOptions,
         method(:stockOnReceive)
      );
   }
    
   /**
    * Crypto - Receive the data from the web request
    */
   function cryptoOnReceive(responseCode, data) {
      if (responseCode == 200) {
          //notify.invoke(data["quotes"]["quote"]["last"]);
          Sys.println("base["+data["data"]["base"]+"]");
          Sys.println("amount["+data["data"]["amount"]+"]");
          //result = data["data"]["amount"];
          _resultDict.put(data["data"]["base"], data["data"]["amount"]);
      } else {
          Sys.println("Failed to load\nError: " + responseCode.toString());
          _resultDict.put("error", responseCode.toString());
      }

      _responsesRcvd++;
      if(_responsesRcvd == 2) {
         _responsesRcvd = 0;
         Background.exit(_resultDict);
      }
   }

   /**
    * Stock - Receive the data from the web request
    */
   function stockOnReceive(responseCode, data) {
      if (responseCode == 200) {
          Sys.println("symbol["+data["symbol"]+"]");
          Sys.println("latestPrice["+data["latestPrice"]+"]");
          _resultDict.put(data["symbol"], data["latestPrice"]);
      } else {
          Sys.println("Failed to load\nError: " + responseCode.toString());
          _resultDict.put("error", responseCode.toString());
      }

      _responsesRcvd++;
      if(_responsesRcvd == 2) {
         _responsesRcvd = 0;
         Background.exit(_resultDict);
      }
   }
}
