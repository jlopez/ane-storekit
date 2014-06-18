package com.jesusla.storekit;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import android.content.Intent;

import com.jesusla.ane.Closure;
import com.jesusla.ane.Extension;
import com.jesusla.google.GoogleInAppBillingActivity;
import com.jesusla.google.IabHelper;
import com.jesusla.google.IabResult;
import com.jesusla.google.Inventory;
import com.jesusla.google.Purchase;
import com.jesusla.google.Security;

public class GoogleProvider implements Provider {
  private static String TAG = "GoogleProvider";
  public static final String VENDOR = "GOOGLE";
  private final StoreKit storeKit;
  private Map<String, String> productIdentifierMap = new HashMap<String, String>();
  private final Map<String, Closure> callbacks = new HashMap<String, Closure>();
  private Inventory inventory;

  // The helper object
  IabHelper helper;

  //Current GoogleProvider instance
  private static GoogleProvider instance = null;
  public static GoogleProvider getInstance() { return instance; }

  public IabHelper getHelper() {return helper; }
  public Inventory getInventory() {return inventory; }

  public GoogleProvider(StoreKit storeKit) {
    instance = this;
    this.storeKit = storeKit;
    String identity = storeKit.getRequiredProperty("SKIdentity");
    Security.setIdentity(identity);

    helper = new IabHelper(storeKit.getActivity());

    // enable debug logging (for a production application, you should set this to false).
    helper.enableDebugLogging(true);
  }

  @Override
  public void dispose() {
    if (helper != null) {
      helper.dispose();
      helper = null;
    }
  }


  @Override
  public void init(String[] productIdentifiers, final Closure closure) {
    productIdentifierMap = buildProductIdentifiers(productIdentifiers);

    helper.startSetup(new IabHelper.OnIabSetupFinishedListener() {
      public void onIabSetupFinished(IabResult result) {
        if (!result.isSuccess()) {
          Extension.warn("Unable to start IabHelper for google provider");
          if (closure != null)
            closure.invoke(null, false);
        }

        OnInventoryUpdatedListener mInventoryFinihsedListener = new OnInventoryUpdatedListener() {
          @Override
          public void onFinsihed() {
            if(inventory.getAllOwnedSkus().size() > 0) {
              for (String sku : inventory.getAllOwnedSkus()) {
                Purchase purchase = inventory.getPurchase(sku);
                verifyTransaction(purchase, purchase.getPurchaseState());
              }
            }
          }
        };

        updateInventory(closure, mInventoryFinihsedListener);
      }
    });
  }

  private interface OnInventoryUpdatedListener {
    public void onFinsihed();
  }

  private void updateInventory(final Closure closure, final OnInventoryUpdatedListener listener) {
    // Listener that's called when we finish querying the items and subscriptions we own
    IabHelper.QueryInventoryFinishedListener mGotInventoryListener = new IabHelper.QueryInventoryFinishedListener() {
      public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
        // Have we been disposed of in the meantime? If so, quit.
        if (helper == null) return;

        if (!result.isSuccess()) {
          Extension.warn("Unable to obtain user inventory from google market");
          if (closure != null)
            closure.invoke(null, false);
        }
        else {
          instance.inventory = inventory;

          listener.onFinsihed();

          if (closure != null)
            closure.asyncInvoke(helper.subscriptionsSupported());
        }
      }
    };

    //Initialize user inventory
    helper.queryInventoryAsync(mGotInventoryListener);
  }

  private Map<String, String> buildProductIdentifiers(String[] productIdentifiers) {
    // Creates a mapping between product ids and clean (lowercase) ids.
    // This is so that we can later return the original camelcase ids
    // given the lowercased one.
    Map<String, String> map = new HashMap<String, String>();
    for (String id : productIdentifiers) {
      String cleanId = cleanProductIdentifier(id);
      String existingProductId = map.get(cleanId);
      if (existingProductId != null && !existingProductId.equals(id))
        Extension.fail("GooglePlay: ProductId clash between %s and %s", existingProductId, id);
      map.put(cleanId, id);
    }
    return map;
  }

  private String cleanProductIdentifier(String productIdentifier) {
    return productIdentifier.toLowerCase();
  }

  @Override
  public void requestPayment(String productIdentifier, final Closure closure) {
    String cleanId = cleanProductIdentifier(productIdentifier);

    if(helper != null && helper.subscriptionsSupported()) {
      Intent intent = new Intent(storeKit.getActivity(), GoogleInAppBillingActivity.class);
      intent.putExtra("method", "requestPayment");
      intent.putExtra("sku", cleanId);
      String callbackHash = Long.toString(System.currentTimeMillis());
      callbacks.put(callbackHash, closure);
      intent.putExtra("callback_hash", callbackHash);

      storeKit.getActivity().startActivityForResult(intent, 2);
    }
  }

  public void onPurchaseFinished(String callbackHash, Purchase purchase, IabResult result) {
    verifyTransaction(purchase, result.getResponse());
    Closure callback = callbacks.remove(callbackHash);
    if (callback != null) {
      if(result.getResponse() == IabHelper.BILLING_RESPONSE_RESULT_OK) {
        //Add purchase to inventory, to then it's easy to get the object for consuming
        inventory.addPurchase(purchase);
      }
      callback.asyncInvoke(result.getResponse() == IabHelper.BILLING_RESPONSE_RESULT_OK);
    }
  }

  public void onConsumeFinished(Purchase purchase, IabResult result) {
    //Nothing to do here, there's no callback
    inventory.erasePurchase(purchase.getSku());
  }

  @Override
  public void finishTransaction(Map<String, Object> transaction) {
    Intent intent = new Intent(storeKit.getActivity(), GoogleInAppBillingActivity.class);
    if(transaction == null || !transaction.containsKey("productIdentifier")) {
      //can't finish this transactions, it's a transaction with error
      return;
    }
    intent.putExtra("method", "consumeItem");
    intent.putExtra("item_sku", transaction.get("productIdentifier").toString());
    storeKit.getActivity().startActivityForResult(intent, 2);
  }

  @Override
  public void restoreCompletedTransactions(final Closure closure) {
    //There's no need to restore transactions with billing v3
    //User subscriptions or no consumed items can be asked using mHelper
    closure.asyncInvoke(true);
  }

  private void verifyTransaction(Purchase purchase, int response) {
    Map<String, Object> transaction = null;
    if (purchase != null && purchase.getPurchaseState() == IabHelper.BILLING_RESPONSE_RESULT_OK) {
      transaction = buildTransaction(purchase);
      transaction.put("_signedData", purchase.getOriginalJson());
      transaction.put("_signature", purchase.getSignature());
      notifyTransactionUpdate(transaction, "VERIFY");
    }
    else {
      transaction = new HashMap<String, Object>();
      final String type = convertStateToType(response);

      if(response == IabHelper.BILLING_RESPONSE_RESULT_ITEM_ALREADY_OWNED) {
        //At this point we know that an item was owned but no consumed,
        //so we update the inventory and send verify notification to take the proper action in game
        final Map<String, Object> transactionForCallback = transaction;

        OnInventoryUpdatedListener mInventoryFinihsedListener = new OnInventoryUpdatedListener() {
          @Override
          public void onFinsihed() {
            if(inventory.getAllOwnedSkus().size() > 0) {
              for (String sku : inventory.getAllOwnedSkus()) {
                Purchase purchase = inventory.getPurchase(sku);
                //notify about no consumed items for this case when item was previously owned but no consumed
                verifyTransaction(purchase, purchase.getPurchaseState());
              }
            }else {
              //send error notification (no transaction data going with the event, so there's no way to accomplish the finishTransaction call)
              notifyTransactionUpdate(transactionForCallback, type);
            }
          }
        };

        //Bringing no consumed items
        updateInventory(null, mInventoryFinihsedListener);
      }
      else {
        //send error notification (no transaction data going with the event, so there's no way to accomplish the finishTransaction call)
        notifyTransactionUpdate(transaction, type);
      }
    }
  }

  private Map<String, Object> buildTransaction(Purchase purchase) {
    String originalProductId = productIdentifierMap.get(purchase.getSku());
    Map<String, Object> transaction = new HashMap<String, Object>();
    transaction.put("vendor", VENDOR);
    transaction.put("productIdentifier", originalProductId);
    transaction.put("_transactionIdentifier", purchase.getOrderId());
    transaction.put("_transactionDate", new Date(purchase.getPurchaseTime()));
    transaction.put("_updateId", 0);
    //TODO: there's no notificationID, so Im using the token instead
    transaction.put("_notificationId", purchase.getToken());
    return transaction;
  }

  protected String convertStateToType(int purchaseState) {
    if (purchaseState == IabHelper.BILLING_RESPONSE_RESULT_USER_CANCELED ||
        purchaseState == IabHelper.BILLING_RESPONSE_RESULT_ITEM_ALREADY_OWNED ||
        purchaseState == IabHelper.BILLING_RESPONSE_RESULT_ERROR)
      return "FAILED";
    else if (purchaseState == IabHelper.BILLING_RESPONSE_RESULT_ITEM_UNAVAILABLE ||
        purchaseState == IabHelper.BILLING_RESPONSE_RESULT_ITEM_NOT_OWNED)
      return "REVOKED";
    else if (purchaseState == IabHelper.BILLING_RESPONSE_RESULT_OK)
      return "PURCHASED";
    Extension.warn("Unknown purchaseState %s", purchaseState);
    return null;
  }

  private void notifyTransactionUpdate(Map<String, Object> transaction, String type) {
    transaction.put("transactionState", type);
    storeKit.asyncFlashCall(null, null, "onTransactionUpdate", transaction);
  }
}
