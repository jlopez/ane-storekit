Storekit iOS ANE
================
Download the latest binary from [here](ane-storekit/wiki/storekit.ane)

Android Setup
-------------
The following must be merged into the application descriptor in the
manifestAdditions section:

    <uses-permission android:name="com.android.vending.BILLING"/>
    <application android:enabled="true" @ANDROID_DEBUGGABLE@>
      <activity android:name="com.jesusla.ane.CustomActivity"/>
      <service android:name="com.jesusla.google.BillingService"/>
      <receiver android:name="com.jesusla.google.BillingReceiver">
        <intent-filter>
          <action android:name="com.android.vending.billing.IN_APP_NOTIFY"/>
          <action android:name="com.android.vending.billing.RESPONSE_CODE"/>
          <action android:name="com.android.vending.billing.PURCHASE_STATE_CHANGED"/>
        </intent-filter>
      </receiver>
      <receiver android:name="com.amazon.inapp.purchasing.ResponseReceiver">
        <intent-filter>
          <action android:name="com.amazon.inapp.purchasing.NOTIFY"
                  android:permission="com.amazon.inapp.purchasing.Permission.NOTIFY"/>
        </intent-filter>
      </receiver>
    </application>

For Google Play In-App Billing:

    <meta-data android:name="SKProvider" android:value="Google"/>
    <meta-data android:name="SKIdentity" android:value="BASE64_ENCODED_PUBLIC_KEY"/>

For Amazon In-App Purchases:

    <meta-data android:name="SKProvider" android:value="Amazon"/>

Usage
-----
    import com.jesusla.storekit.*;

    // StoreKit listeners should be setup as soon as app starts
    StoreKit.addEventListener(TransactionEvent.TRANSACTION_PURCHASED, storeKit_purchaseHandler);
    StoreKit.addEventListener(TransactionEvent.TRANSACTION_FAILED, storeKit_failureHandler);
    StoreKit.addEventListener(TransactionEvent.TRANSACTION_REVOKED, storeKit_revokeHandler);
    StoreKit.addEventListener(TransactionEvent.TRANSACTION_VERIFY, storeKit_verifyHandler);

    // Once listeners are setup, StoreKit should be initialized
    // PRODUCTS should be an array of Product IDs, which need to be previously configured in
    // iTunesConnect / GooglePlay / Amazon Market.
    const PRODUCTS:Array = [
      'sku1', 'sku2', 'sku3', 'sku4', 'sku5', 'sku6'
    ];
    StoreKit.init(PRODUCTS, initCallback);

    function initCallback(success:Boolean):void

    // initCallback is called with a flag indicating the initialization status
    // If true, the system is ready to process orders. This flag can be
    // obtained at any time with the canMakePayments property. The caller
    // should adjust the UI appropriately in those cases when this flag is false.
    StoreKit.canMakePayments;

    // To request a purchase:
    StoreKit.requestPayment('sku1', requestCallback);

    // The success/failure of the purchase is reported in the optional
    // request callback. A true value does not mean that the purchase
    // went through. It simply means that the request was successful.
    function requestCallback(success:Boolean):void

    // As the transaction is processed, several events are fired.
    // If there's a problem with the transaction (e.g. user cancels
    // the transaction, the payment was declined, etc.) the event
    // TRANSACTION_FAILED is fired. The failure must be acknowledged
    // by finishing the transaction with acknowledgeTransaction()
    function storeKit_failureHandler(event:TransactionEvent):void {
      // Acknowledge the failure. Omitting this step will
      // cause the event to be constantly fired for this
      // transaction until acknowledged.
      StoreKit.acknowledgeTransaction(event.transaction);
    }

    // If the transaction succeeds, the TRANSACTION_VERIFY event
    // is fired. The client must now verify the transaction in an
    // implementation-specific manner (e.g. verifying its cryptographic
    // signature via a server-side request, etc.). The transaction
    // should be acknowledged if verification passes. Otherwise,
    // the transaction should be rejected.
    function storeKit_verifyHandler(event:TransactionEvent):void {
      if (serverSideVerification(event.transaction))
        StoreKit.acknowledgeTransaction(event.transaction);
      else
        StoreKit.rejectTransaction(event.transaction);
    }

    // After being successfully verified, the TRANSACTION_PURCHASED
    // event is fired. The transaction is now complete and should
    // be fulfilled. It is important not to acknowledge the transaction
    // before it is fulfilled.
    function storeKit_purchaseHandler(event:TransactionEvent):void {
      if (fulfillTransaction(event.transaction))
        StoreKit.acknowledgeTransaction(event.transaction);
    }

    // Finally, the TRANSACTION_REVOKED event may be fired for
    // transactions that are revoked/refunded server-side. The client must
    // revoke the goods (e.g. deduct coins, etc) and acknowledge the
    // transaction.
    function storeKit_revokeHandler(event:TransactionEvent):void {
      if (revokeTransaction(event.transaction))
        StoreKit.acknowledgeTransaction(event.transaction);
    }

    // Transactions are plain objects with the following properties:
    var transaction:Object = event.transaction;
    transaction.vendor; // One of VENDOR_APPLE, VENDOR_GOOGLE, VENDOR_AMAZON
    transaction.transactionState; // One of STATE_FAILED, STATE_VERIFY,
                                  // STATE_PURCHASED, STATE_REVOKED
    transaction.productIdentifier; // e.g. 'sku1' (String)

    // Note that during a VERIFY, only the first two fields are guaranteed
    // to be present. The rest of the fields will be vendor-specific.

    // Finally, the app may request restoring completed transactions.
    // This will cause all non-consumable historic transactions to be
    // resent to the client with a STATE_PURCHASED state. The optional callback
    // is notified with a flag indicating success/failure
    StoreKit.restoreCompletedTransactions(restoreCallback);

    function restoreCallback(success:Boolean):void
