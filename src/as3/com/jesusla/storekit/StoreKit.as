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

    private static const STATE_PURCHASED:String = "PURCHASED";
    private static const STATE_FAILED:String = "FAILED";
    private static const STATE_REVOKED:String = "REVOKED";
    private static const STATE_VERIFY:String = "VERIFY";

    private static const VENDOR_APPLE:String = "APPLE";
    private static const VENDOR_GOOGLE:String = "GOOGLE";
    private static const VENDOR_AMAZON:String = "AMAZON";

    private static const ERROR_NONE:int = 0;
    private static const ERROR_OTHER:int = 1;
    private static const ERROR_USER_CANCELLED:int = 2;
    private static const ERROR_NOT_AUTHORIZED:int = 3;

    //---------------------------------------------------------------------
    //
    // Private Properties.
    //
    //---------------------------------------------------------------------
    private static var context:ExtensionContext;
    private static var _objectPool:Object = {};
    private static var _objectPoolId:int = 0;
    private static var _productIdentifiers:Array;
    private static var _instance:StoreKit;
    private static var _initialized:Boolean;
    private static var _canMakePayments:Boolean;
    private static var _fakeTransactions:Array = [];
    private static var _restoreCallback:Function;
    private var transactionQueue:Array = [];
    private var queueTransactions:Boolean = true;

    //---------------------------------------------------------------------
    //
    // Public Methods.
    //
    //---------------------------------------------------------------------
    public function StoreKit() {
      if (_instance)
        throw new Error("Singleton");
      _instance = this;
    }

    public static function init(productIdentifiers:Array, callback:Function = null):void {
      // iOS requires product ids (to fetch SKProduct to later request payment)
      // Google Play doesn't require them
      // LCD: require product ids
      _productIdentifiers = productIdentifiers;
      if (context)
        context.call("init", productIdentifiers, onInit);
      else
        setTimeout(onInit, 0, true);

      function onInit(initialized:Boolean, canMakePayments:Boolean):void {
        _initialized = initialized;
        _canMakePayments = initialized && canMakePayments;
        if (callback != null)
          callback(_canMakePayments);
        _instance.flushQueue();
      }
    }

    public static function get initialized():Boolean {
      return _initialized;
    }

    public static function get canMakePayments():Boolean {
      return _canMakePayments;
    }

    public static function get transactions():Array {
      ensureInitialized();
      if (context)
        return context.call("transactions") as Array;
      throw new Error("Unimplemented");
    }

    public static function requestPayment(productIdentifier:String, callback:Function = null):void {
      ensureAvailable();

      if (context)
        context.call("requestPayment", productIdentifier, callback);
      else
        throw new Error("Unimplemented");
    }

    public static function acknowledgeTransaction(transaction:Object):void {
      ensureInitialized();
      if (transaction.transactionState == STATE_VERIFY) {
        transaction.transactionState = STATE_PURCHASED;
        _instance.onTransactionUpdate(transaction);
      }
      else if (context)
        context.call("finishTransaction", transaction);
    }

    public static function rejectTransaction(transaction:Object):void {
    }

    public static function restoreCompletedTransactions(callback:Function = null):void {
      ensureInitialized();
      context.call("restoreCompletedTransactions", callback);
    }

    public static function addEventListener(event:String, listener:Function):void {
      _instance.addEventListener(event, listener);
    }

    public static function removeEventListener(event:String, listener:Function):void {
      _instance.removeEventListener(event, listener);
    }

    public function onTransactionUpdate(transaction:Object):void {
      if (queueTransactions) {
        transactionQueue.push(transaction);
        return;
      }
      var status:String = transaction.transactionState;
      var type:String;
      if (status == STATE_PURCHASED)
        type = TransactionEvent.TRANSACTION_PURCHASED;
      else if (status == STATE_FAILED)
        type = TransactionEvent.TRANSACTION_FAILED;
      else if (status == STATE_REVOKED)
        type = TransactionEvent.TRANSACTION_REVOKED;
      else if (status == STATE_VERIFY)
        type = TransactionEvent.TRANSACTION_VERIFY;
      else
        throw new Error("Unknown transaction update status " + status);

      dispatchEvent(new TransactionEvent(type, transaction));
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
    private function flushQueue():void {
      if (!transactionQueue)
        return;
      queueTransactions = false;
      for each (var transaction:Object in transactionQueue) {
        onTransactionUpdate(transaction);
      }
      transactionQueue = null;
    }

    private static function ensureInitialized():void {
      if (!_initialized)
        throw new Error("Not initialized, must call init() first");
    }

    private static function ensureAvailable():void {
      ensureInitialized();
      if (!_canMakePayments)
        throw new Error("Purchases are not available");
    }

    private static function context_statusEventHandler(event:StatusEvent):void {
      if (event.level == "TICKET")
        context.call("claimTicket", event.code);
      else if (event.level == "RELEASE")
        delete _objectPool[int(event.code)];
    }

    {
      new StoreKit();
      context = ExtensionContext.createExtensionContext(EXTENSION_ID, EXTENSION_ID + ".StoreKit");
      if (context) {
        try {
          context.addEventListener(StatusEvent.STATUS, context_statusEventHandler);
          context.call("setActionScriptThis", _instance);
        } catch (e:ArgumentError) {
          context = null;
        }
      }
    }
  }
}
