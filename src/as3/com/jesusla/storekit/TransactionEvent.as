package com.jesusla.storekit {
 import flash.events.Event;

 public class TransactionEvent extends Event {
   public static var TRANSACTION_PURCHASED:String = "TRANSACTION_PURCHASED";
   public static var TRANSACTION_FAILED:String = "TRANSACTION_FAILED";
   public static var TRANSACTION_REVOKED:String = "TRANSACTION_REVOKED";
   public static var TRANSACTION_VERIFY:String = "TRANSACTION_VERIFY";

   private var _transaction:Object;

   public function TransactionEvent(name:String, transaction:Object) {
     super(name);
     _transaction = transaction;
   }

   public function get transaction():Object { return _transaction; }
 }
}
