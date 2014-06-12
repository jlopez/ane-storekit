package com.jesusla.storekit;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

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
import com.jesusla.google.VerifiedPurchase;

public class GoogleProvider implements Provider {
  public static final String VENDOR = "GOOGLE";
  private final StoreKit storeKit;
  private BillingService billing;
  private Map<String, String> productIdentifierMap = new HashMap<String, String>();

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
    productIdentifierMap = buildProductIdentifiers(productIdentifiers);
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
    boolean success = billing.requestPurchase(cleanId, Consts.ITEM_TYPE_INAPP, null, new RequestPurchaseCallback() {
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
  public void finishTransaction(Map<String, Object> transaction) {
    int updateId = (Integer)transaction.get("_updateId");
    String notificationId = (String)transaction.get("_notificationId");
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
    public void verifyTransaction(int updateId, String signedData, String signature, VerifiedPurchase purchase) {
      Map<String, Object> transaction = buildTransaction(updateId, purchase);
      if (purchase.purchaseState == PurchaseState.PURCHASED) {
        transaction.put("_signedData", signedData);
        transaction.put("_signature", signature);
        notifyTransactionUpdate(transaction, "VERIFY");
      }
      else {
        String type = convertStateToType(purchase.purchaseState);
        notifyTransactionUpdate(transaction, type);
      }
    }
  };

  private Map<String, Object> buildTransaction(int updateId, VerifiedPurchase purchase) {
    String originalProductId = productIdentifierMap.get(purchase.productId);
    Map<String, Object> transaction = new HashMap<String, Object>();
    transaction.put("vendor", VENDOR);
    transaction.put("productIdentifier", originalProductId);
    transaction.put("_transactionIdentifier", purchase.orderId);
    transaction.put("_transactionDate", new Date(purchase.purchaseTime));
    transaction.put("_updateId", updateId);
    transaction.put("_notificationId", purchase.notificationId);
    return transaction;
  }

  protected String convertStateToType(PurchaseState purchaseState) {
    if (purchaseState == PurchaseState.CANCELED)
      return "FAILED";
    else if (purchaseState == PurchaseState.REFUNDED)
      return "REVOKED";
    else if (purchaseState == PurchaseState.PURCHASED)
      return "PURCHASED";
    Extension.warn("Unknown purchaseState %s", purchaseState);
    return null;
  }

  private void notifyTransactionUpdate(Map<String, Object> transaction, String type) {
    transaction.put("transactionState", type);
    storeKit.asyncFlashCall(null, null, "onTransactionUpdate", transaction);
  }
}
