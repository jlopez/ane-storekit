package com.jesusla.storekit {
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.StatusEvent;
  import flash.external.ExtensionContext;
  import flash.utils.setTimeout;

  /**
   * Chartboost extension
   */
  public class StoreKit extends EventDispatcher {
    //---------------------------------------------------------------------
    //
    // Constants
    //
    //---------------------------------------------------------------------
    private static const EXTENSION_ID:String = "com.jesusla.storekit";

    public static const STOREKIT_INITIALIZED_EVENT:String = "STOREKIT_INITIALIZED_EVENT";

    public static const SKPaymentTransactionStatePurchasing:uint = 0;
    public static const SKPaymentTransactionStatePurchased:uint = 1;
    public static const SKPaymentTransactionStateFailed:uint = 2;
    public static const SKPaymentTransactionStateRestored:uint = 3;

    //---------------------------------------------------------------------
    //
    // Private Properties.
    //
    //---------------------------------------------------------------------
    private static var context:ExtensionContext;
    private static var _isSupported:Boolean;
    private static var _productIds:Array;
    private static var _products:Object;
    private static var _instance:StoreKit;
    private static var _locked:Boolean;
    private static var _initialized:Boolean;

    //---------------------------------------------------------------------
    //
    // Public Methods.
    //
    //---------------------------------------------------------------------
    public function StoreKit() {
      if (_locked)
        throw new Error("Singleton");
      _locked = true;
    }

    public static function get isSupported():Boolean {
      return _isSupported;
    }

    public static function init(productIdentifiers:Array):void {
      if (_initialized)
        throw new Error("Already initialized");
      _initialized = true;
      if (isSupported)
        context.call("init", productIdentifiers);
      else
        setTimeout(fakeInit, 1000);

      function fakeInit():void {
        var products:Object = {}
        for (var ix:uint = 0; ix < productIdentifiers.length; ++ix) {
          var productIdentifier:String = productIdentifiers[ix];
          products[productIdentifier] = {
            localizedTitle: "Title for " + productIdentifier,
            localizedDescription: "Description for " + productIdentifier,
            localizedPrice: "$100.00",
            price: 100,
            productIdentifier: productIdentifier
          };
        }
        _instance.handleInitialization(products);
      }
    }

    public static function get products():Object {
      return _products;
    }

    public static function get canMakePayments():Boolean {
      return isSupported && context.call("canMakePayments");
    }

    public static function get transactions():Array {
      if (!isSupported)
        return [];
      return context.call("transactions") as Array;
    }

    public static function requestPayment(productIdentifier:String, quantity:uint = 1):Boolean {
      if (!_products)
        throw new Error("StoreKit not initialized");
      if (!_products[productIdentifier])
        throw new Error("Invalid product Id '" + productIdentifier + "'");
      if (quantity < 1)
        throw new Error("Invalid quantity " + quantity);

      if (isSupported)
        return context.call("requestPayment", productIdentifier, quantity);

      setTimeout(fakeTransaction, 1000);
      return true;

      function fakeTransaction():void {
        var transaction:Object = {
          transactionState: true,
          transactionIdentifier: "n/a",
          transactionDate: new Date(),
          payment: {
            productIdentifier: productIdentifier,
            quantity: quantity
          },
          error: null
        };
        _instance.handleTransaction(transaction);
      }
    }

    public static function finishTransaction(transaction:Object):Boolean {
      if (isSupported && transaction.transactionIdentifier)
        return context.call("finishTransaction", transaction.transactionIdentifier);
      return false;
    }

    public static function addEventListener(event:String, listener:Function):void {
      _instance.addEventListener(event, listener);
    }

    public static function removeEventListener(event:String, listener:Function):void {
      _instance.removeEventListener(event, listener);
    }

    public function handleInitialization(products:Object):void {
      _products = products;
      dispatchEvent(new Event(STOREKIT_INITIALIZED_EVENT));
    }

    public function handleTransactions(transactions:Array):void {
      for (var ix:uint = 0; ix < transactions.length; ++ix)
        handleTransaction(transactions[ix]);
    }

    private function handleTransaction(transaction:Object):void {
      dispatchEvent(new TransactionEvent(TransactionEvent.TRANSACTION_UPDATED, transaction));
      if (transaction.transactionState == SKPaymentTransactionStatePurchased)
        dispatchEvent(new TransactionEvent(TransactionEvent.TRANSACTION_PURCHASED, transaction));
      else if (transaction.transactionState == SKPaymentTransactionStateFailed)
        dispatchEvent(new TransactionEvent(TransactionEvent.TRANSACTION_FAILED, transaction));
    }

    //---------------------------------------------------------------------
    //
    // Private Methods.
    //
    //---------------------------------------------------------------------
    private static function context_statusEventHandler(event:StatusEvent):void {
      if (event.level == "TICKET")
        context.call("claimTicket", event.code);
    }

    {
      _instance = new StoreKit();
      context = ExtensionContext.createExtensionContext(EXTENSION_ID, "StoreKit");
      if (context) {
        _isSupported = context.actionScriptData;
        context.addEventListener(StatusEvent.STATUS, context_statusEventHandler);
        context.actionScriptData = _instance;
      }
    }
  }
}
