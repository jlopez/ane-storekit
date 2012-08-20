Storekit iOS ANE
================
Download the latest binary from [here](ane-storekit/wiki/storekit.ane)

Usage
-----
    import com.jesusla.storekit.*;

    // StoreKit listeners should be setup as soon as app starts
    // The first three event listeners are These events are described later on.
    StoreKit.addEventListener(StoreKit.STOREKIT_INITIALIZED_EVENT, storeKit_initializedHandler);
    StoreKit.addEventListener(TransactionEvent.TRANSACTION_PURCHASED, storeKit_paymentSucceededHandler);
    StoreKit.addEventListener(TransactionEvent.TRANSACTION_FAILED, storeKit_paymentFailedHandler);
    StoreKit.addEventListener(TransactionEvent.TRANSACTION_UPDATED, storeKit_paymentUpdatedHandler);

    // Now that listeners are ready StoreKit may be initialized.
    // PRODUCTS should be an array of Product IDs, which need to be previously configured in
    // iTunesConnect.
    const PRODUCTS:Array = [
      'com.company.sku1', 'com.company.sku2', 'com.company.sku3',
      'com.company.sku4', 'com.company.sku5', 'com.company.sku6'
    ];
    StoreKit.init(PRODUCTS);

    // STOREKIT_INITIALIZED_EVENT will fire as soon as StoreKit obtains product
    // information. The app can then obtain product price, description, etc.
    var product:Object = StoreKit.products['com.company.sku1'];
    product['localizedTitle']; // "invisibility"
    product['localizedDescription']; "Invisibility Power-Up"
    product['localizedPrice']; // "$4.99"
    product['price']; // 4.99
    product['productIdentifier']; // "com.company.sku1"

    // Additionally, TRANSACTION_PURCHASED / TRANSACTION_FAILED
    // will be fired for each pending transaction (i.e. transactions
    // that haven't been finalized yet, e.g. if the application crashes
    // before fulfilling a purchase)

    // Once initialized, the app may determine whether the user has enabled/disabled
    // in-app purchases:
    var enabled:Boolean = StoreKit.canMakePayments();

    // Call .requestPayment when the user wishes to buy a product.
    // This method returns true if the method posts the request
    // successfully. This does not mean, though, that the user did
    // indeed complete the purchase. For that, the app must wait to get
    // the TRANSACTION_PURCHASED event.
    StoreKit.requestPayment("com.company.sku1");

    // Once the purchase is successful, the event TransactionEvent.TRANSACTION_PURCHASED
    // will fire. The event has a transaction property with detailed information.
    // The code must acknowledge receipt of the transaction by invoking finishTransaction
    // _after_ fulfilling the purchase.
    var transaction:Object = event.transaction;
    transaction.payment.transactionIdentier; // "com.company.sku1"
    transaction.payment.quantity; // 1
    transaction.transactionState; // SKPaymentTransactionStatePurchased
    transaction.transactionDate; // Purchase date as a String
        // to convert to a Date: "new Date(transaction.transactionDate)"
    transaction.transactionIdentifier; // Unique transaction ID
    transaction.paymentReceipt; // Apple generated payment receipt

    // Purchase is fulfilled and if successful transaction is finalized:
    if (Backend.awardPowerUp("com.company.sku1"))
      StoreKit.finishTransaction(transaction); // Returns true if successful
    // Failure to acknowledge receipt will cause the transaction to remain
    // in the system (even if the app restarts). This allows the app to retry
    // in the future.

    // On the other hand, if the purchase fails (user canceled, network down, etc.)
    // the event TransactionEvent.TRANSACTION_FAILED will fire.
    // The transaction property contains information on the failed transaction.
    var transaction:Object = event.transaction;
    transaction.payment.transactionIdentier; // "com.company.sku1"
    transaction.payment.quantity; // 1
    transaction.transactionState; // SKPaymentTransactionStateFailed
    transaction.error.code; // Error code (Apple-specific)
    transaction.error.domain; // Error domain (Apple-specific)
    transaction.error.localizedDescription; // e.g. "Cannot connect to iTunes Store"
    transaction.transactionIdentifier; // Unique transaction ID

    // Just as with a successful transaction, the app should finalize the transaction
    // so that it is removed from the system:
    StoreKit.finishTransaction(transaction); // true if successful

    // Unlike TRANSACTION_PURCHASED & TRANSACTION_FAILED, the event TRANSACTION_UPDATED
    // is fired whenever a transaction changes state, whether successful or failed.
    // The app may choose to rely on this state instead of the other two and
    // distinguish between both cases by inspecting the transactionState property.

    // At any point in time the app may obtain a list of all pending
    // (i.e. unfinalized) transactions.
    var transactions:Array = StoreKit.transactions;

    // Request restoring completed transactions
    StoreKit.restoreCompletedTransactions(restoreCallback);

    // The callback takes a single argument, which will contain an error object
    // or null if the restore operation was successful.
    function restoreCallback(error:Object):void {
      // error is null if restore was successful,
      // otherwise, it contains the following properties
      error.code; // Error code (Apple-specific)
      error.domain; // Error domain (Apple-specific)
      error.localizedDescription; // e.g. "Cannot connect to iTunes Store"
      error.localizedFailureReason; // may be null
      error.localizedRecoverySuggestion; // may be null
    }

Coming soon
===========
* Downloadable content
