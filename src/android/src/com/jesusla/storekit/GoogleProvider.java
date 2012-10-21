package com.jesusla.storekit;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import com.jesusla.ane.Closure;
import com.jesusla.ane.Extension;
import com.jesusla.google.BillingListener;
import com.jesusla.google.BillingService;
import com.jesusla.google.BillingSupportedCallback;
import com.jesusla.google.Consts;
import com.jesusla.google.Consts.PurchaseState;
import com.jesusla.google.Consts.ResponseCode;
import com.jesusla.google.RequestPurchaseCallback;
import com.jesusla.google.RestoreTransactionsCallback;
import com.jesusla.google.Security;
import com.jesusla.google.VerificationCallback;

public class GoogleProvider implements Provider {
  public static final String TYPE = "GOOGLE";
  private final StoreKit storeKit;
  private BillingService billing;

  public GoogleProvider(StoreKit storeKit) {
    this.storeKit = storeKit;
    String identity = storeKit.getRequiredProperty("SKIdentity");
    Security.setIdentity(identity);

    billing = new BillingService();
    billing.setActivity(storeKit.getActivity());
    billing.setListener(billingListener);
  }

  @Override
  public void dispose() {
    if (billing != null)
      billing.unbind();
    billing = null;
  }


  @Override
  public void init(String[] productIdentifiers, final Closure closure) {
    boolean success = billing.checkBillingSupported(null, new BillingSupportedCallback() {
      @Override
      public void onBillingSupported(boolean billingSupported, String productType) {
        if (closure != null)
          closure.asyncInvoke(billingSupported);
      }
    });
    if (!success) {
      Extension.warn("Unable to invoke Billing.checkBillingSupported. Returning false");
      if (closure != null)
        closure.invoke(null, false);
    }
  }

  @Override
  public void requestPayment(String productIdentifier, final Closure closure) {
    boolean success = billing.requestPurchase(productIdentifier, Consts.ITEM_TYPE_INAPP, null, new RequestPurchaseCallback() {
      @Override
      public void requestPurchaseResponse(ResponseCode responseCode,
          String productId, String productType, String developerPayload) {
        if (closure != null)
          closure.asyncInvoke(responseCode == ResponseCode.RESULT_OK);
      }
    });
    if (!success) {
      Extension.warn("Unable to invoke Billing.requestPurchase. Returning false");
      if (closure != null)
        closure.invoke(null, false);
    }
  }

  @Override
  public void acknowledgeTransaction(Map<String, Object> transaction) {
    String state = (String)transaction.get("transactionState");
    if (state.equals("VERIFY"))
      acceptTransaction(transaction);
    else
      finishTransaction(transaction);
  }

  private void acceptTransaction(Map<String, Object> transaction) {
    String uuid = (String)transaction.get("_id");
    VerificationCallback callback = callbacks.remove(uuid);
    if (callback != null)
      callback.verificationSucceeded();
  }

  private void finishTransaction(Map<String, Object> transaction) {
    int updateId = (Integer)transaction.get("_id1");
    String notificationId = (String)transaction.get("_id2");
    billing.confirmNotifications(updateId, new String[] { notificationId });
  }

  @Override
  public void restoreCompletedTransactions(final Closure closure) {
    boolean success = billing.restoreTransactions(new RestoreTransactionsCallback() {
      @Override
      public void restoreTransactionsResponse(ResponseCode responseCode) {
        if (closure != null)
          closure.asyncInvoke(responseCode == ResponseCode.RESULT_OK);
      }
    });
    if (!success) {
      Extension.warn("Unable to invoke Billing.restoreTransactions. Returning false");
      if (closure != null)
        closure.invoke(null, false);
    }
  }

  private final BillingListener billingListener = new BillingListener() {
    @Override
    public void onTransactionUpdate(PurchaseState purchaseState,
        String productId, String orderId, long purchaseTime,
        String developerPayload, int updateId, String notificationId) {
      String type = purchaseState.toString();
      if (purchaseState == PurchaseState.CANCELED)
        type = "FAILED";
      else if (purchaseState == PurchaseState.REFUNDED)
        type = "REVOKED";
      Map<String, Object> transaction = new HashMap<String, Object>();
      transaction.put("vendor", TYPE);
      transaction.put("transactionState", type);
      transaction.put("productIdentifier", productId);
      transaction.put("_transactionIdentifier", orderId);
      transaction.put("_transactionDate", new Date(purchaseTime));
      transaction.put("_id1", updateId);
      transaction.put("_id2", notificationId);
      storeKit.asyncFlashCall(null, null, "onTransactionUpdate", type, transaction);
    }

    @Override
    public void verifyTransaction(String signedData, String signature, VerificationCallback callback) {
      String cb = registerCallback(callback);
      Map<String, Object> transaction = new HashMap<String, Object>();
      transaction.put("vendor", TYPE);
      transaction.put("transactionState", "VERIFY");
      transaction.put("_signedData", signedData);
      transaction.put("_signature", signature);
      transaction.put("_id", cb);
      storeKit.asyncFlashCall(null, null, "onTransactionUpdate", "VERIFY", transaction);
    }
  };

  private final Map<String, VerificationCallback> callbacks = new HashMap<String, VerificationCallback>();
  private String registerCallback(VerificationCallback callback) {
    String uuid = UUID.randomUUID().toString();
    callbacks.put(uuid, callback);
    return uuid;
  }
}
