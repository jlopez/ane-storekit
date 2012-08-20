package com.jesusla.storekit {
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.StatusEvent;
  import flash.external.ExtensionContext;
  import flash.utils.ByteArray;
  import flash.utils.getTimer;
  import flash.utils.getQualifiedClassName;
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
    private static var _objectPool:Object = {};
    private static var _objectPoolId:int = 0;
    private static var _isSupported:Boolean;
    private static var _productIds:Array;
    private static var _products:Object;
    private static var _instance:StoreKit;
    private static var _locked:Boolean;
    private static var _initialized:Boolean;
    private static var _fakeTransactions:Array = [];
    private static var _restoreCallback:Function;

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
        return _fakeTransactions;
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
        var receipt:ByteArray = new ByteArray();
        receipt.writeUTFBytes("receipt");
        var transaction:Object = {
          transactionState: SKPaymentTransactionStatePurchased,
          transactionIdentifier: String(getTimer()),
          transactionDate: new Date(),
          transactionReceipt: receipt,
          payment: {
            productIdentifier: productIdentifier,
            quantity: quantity
          },
          error: null
        };
        _fakeTransactions.push(transaction);
        _instance.handleTransaction(transaction);
      }
    }

    public static function finishTransaction(transaction:Object):Boolean {
      if (isSupported && transaction.transactionIdentifier)
        return context.call("finishTransaction", transaction.transactionIdentifier);
      for (var ix:int = 0; ix < _fakeTransactions.length; ++ix) {
        if (_fakeTransactions[ix] != transaction)
          continue;
        _fakeTransactions.splice(ix, 1);
        return true;
      }
      return false;
    }

    public static function restoreCompletedTransactions(callback:Function):void {
      if (!isSupported) {
        if (callback != null)
          callback({ localizedDescription: "Unsupported" });
        return;
      }
      if (_restoreCallback != null)
        _restoreCallback({ localizedDescription: "Aborted" });
      _restoreCallback = callback;
      context.call("restoreCompletedTransactions");
    }

    public function handleRestore(error:Object = null):void {
      if (_restoreCallback == null)
        return;
      _restoreCallback(error);
      _restoreCallback = null;
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

    public function getQualifiedClassName(obj:Object):String {
      return flash.utils.getQualifiedClassName(obj);
    }

    public function enumerateObjectProperties(obj:Object):Array {
      var keys:Array = [];
      for (var key:String in obj)
        keys.push(key);
      return keys;
    }

    public function __retainObject(obj:Object):int {
      _objectPool[++_objectPoolId] = obj;
      return _objectPoolId;
    }

    public function __getObject(id:int):Object {
      return _objectPool[id];
    }

    //---------------------------------------------------------------------
    //
    // Private Methods.
    //
    //---------------------------------------------------------------------
    private static function context_statusEventHandler(event:StatusEvent):void {
      if (event.level == "TICKET")
        context.call("claimTicket", event.code);
      else if (event.level == "RELEASE")
        delete _objectPool[int(event.code)];
    }

    {
      _instance = new StoreKit();
      context = ExtensionContext.createExtensionContext(EXTENSION_ID, "StoreKit");
      if (context) {
        _isSupported = context.actionScriptData;
        context.addEventListener(StatusEvent.STATUS, context_statusEventHandler);
        if (_isSupported)
          context.call("setActionScriptThis", _instance);
      }
    }
  }
}
