package com.jesusla.storekit;

import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import android.content.Context;

import com.amazon.inapp.purchasing.BasePurchasingObserver;
import com.amazon.inapp.purchasing.GetUserIdResponse;
import com.amazon.inapp.purchasing.GetUserIdResponse.GetUserIdRequestStatus;
import com.amazon.inapp.purchasing.Item;
import com.amazon.inapp.purchasing.Item.ItemType;
import com.amazon.inapp.purchasing.ItemDataResponse;
import com.amazon.inapp.purchasing.ItemDataResponse.ItemDataRequestStatus;
import com.amazon.inapp.purchasing.Offset;
import com.amazon.inapp.purchasing.PurchaseResponse;
import com.amazon.inapp.purchasing.PurchaseResponse.PurchaseRequestStatus;
import com.amazon.inapp.purchasing.PurchaseUpdatesResponse;
import com.amazon.inapp.purchasing.PurchaseUpdatesResponse.PurchaseUpdatesRequestStatus;
import com.amazon.inapp.purchasing.PurchasingManager;
import com.amazon.inapp.purchasing.Receipt;
import com.jesusla.ane.Closure;
import com.jesusla.ane.Extension;

public class AmazonProvider implements Provider {
  public static final String TYPE = "AMAZON";
  private final StoreKit storeKit;
  private final Map<String, Closure> callbacks = new HashMap<String, Closure>();
  private Map<String, Item> items;
  private String userId;

  public AmazonProvider(StoreKit storeKit) {
    this.storeKit = storeKit;
    AmazonObserver observer = new AmazonObserver(storeKit.getActivity());
    PurchasingManager.registerObserver(observer);
  }

  @Override
  public void dispose() {
  }

  @Override
  public void init(String[] productIdentifiers, Closure closure) {
    Set<String> skus = new HashSet<String>(Arrays.asList(productIdentifiers));
    String id = PurchasingManager.initiateItemDataRequest(skus);
    registerCallback(id, closure);
  }

  @Override
  public void requestPayment(String productIdentifier, Closure closure) {
    String id = PurchasingManager.initiatePurchaseRequest(productIdentifier);
    registerCallback(id, closure);
  }

  @Override
  public void finishTransaction(Map<String, Object> transaction) {
    // Not with Amazon... (?)
  }

  @Override
  public void restoreCompletedTransactions(Closure closure) {
    String id = PurchasingManager.initiatePurchaseUpdatesRequest(Offset.BEGINNING);
    registerCallback(id, closure);
  }

  private class AmazonObserver extends BasePurchasingObserver {
    public AmazonObserver(Context context) {
      super(context);
    }

    @Override
    public void onGetUserIdResponse(GetUserIdResponse getUserIdResponse) {
      Extension.debug("Amazon: onGetUserIdResponse(%s)", getUserIdResponse);
      userId = getUserIdResponse.getUserId();
      Extension.debug("Received user Id: %s", userId);
      GetUserIdRequestStatus status = getUserIdResponse.getUserIdRequestStatus();
      callback(getUserIdResponse.getRequestId(), status == GetUserIdRequestStatus.SUCCESSFUL);
    }

    @Override
    public void onItemDataResponse(ItemDataResponse itemDataResponse) {
      Extension.debug("Amazon: onItemDataResponse(%s)", itemDataResponse);
      items = itemDataResponse.getItemData();
      Extension.debug("Received items: %s", items);
      ItemDataRequestStatus status = itemDataResponse.getItemDataRequestStatus();
      Closure callback = releaseCallback(itemDataResponse.getRequestId());
      if (status == ItemDataRequestStatus.FAILED)
        callback.asyncInvoke(false);
      else
        requestUserId(callback);
    }

    @Override
    public void onPurchaseResponse(PurchaseResponse purchaseResponse) {
      Extension.debug("Amazon: onPurchaseResponse(%s)", purchaseResponse);
      PurchaseRequestStatus status = purchaseResponse.getPurchaseRequestStatus();
      boolean success = status == PurchaseRequestStatus.SUCCESSFUL;
      String transactionState = success ? "VERIFY" : "FAILED";
      notifyUpdatedTransaction(transactionState, purchaseResponse.getReceipt(), purchaseResponse.getUserId());
    }

    @Override
    public void onPurchaseUpdatesResponse(PurchaseUpdatesResponse purchaseUpdatesResponse) {
      Extension.debug("Amazon: onPurchaseUpdatesResponse(%s)", purchaseUpdatesResponse);
      boolean success = purchaseUpdatesResponse.getPurchaseUpdatesRequestStatus() == PurchaseUpdatesRequestStatus.SUCCESSFUL;
      Closure callback = releaseCallback(purchaseUpdatesResponse.getRequestId());
      if (!success)
        callback.asyncInvoke(false);
      else {
        String userId = purchaseUpdatesResponse.getUserId();
        for (Receipt receipt : purchaseUpdatesResponse.getReceipts())
          notifyUpdatedTransaction("PURCHASED", receipt, userId);
        for (String sku : purchaseUpdatesResponse.getRevokedSkus())
          notifyRevokedSKU(sku, userId);
        if (purchaseUpdatesResponse.isMore()) {
          String id = PurchasingManager.initiatePurchaseUpdatesRequest(purchaseUpdatesResponse.getOffset());
          registerCallback(id, callback);
        }
        else
          callback.asyncInvoke(true);
      }
    }
  };

  public void notifyUpdatedTransaction(String transactionState, Receipt receipt, String userId) {
    Map<String, Object> transaction = createTransaction(transactionState, userId);
    if (receipt != null) {
      ItemType itemType = receipt.getItemType();
      transaction.put("productIdentifier", receipt.getSku());
      if (itemType == ItemType.SUBSCRIPTION) {
        transaction.put("_subscriptionStartDate", receipt.getSubscriptionPeriod().getStartDate());
        transaction.put("_subscriptionEndDate", receipt.getSubscriptionPeriod().getEndDate());
      }
      transaction.put("_productType", toProductType(itemType));
      transaction.put("_purchaseToken", receipt.getPurchaseToken());
    }
    storeKit.asyncFlashCall(null, null, "onTransactionUpdate", transaction);
  }

  private void notifyRevokedSKU(String sku, String userId) {
    String transactionState = "REVOKED";
    Map<String, Object> transaction = createTransaction(transactionState, userId);
    transaction.put("productIdentifier", sku);
    Item item = items != null ? items.get(sku) : null;
    if (item != null)
      transaction.put("_productType", toProductType(item.getItemType()));
    else
      Extension.warn("Revoked SKU [%s] not found in product list. Omitting productType.", sku);
    storeKit.asyncFlashCall(null, null, "onTransactionUpdate", transaction);
  }

  private Map<String, Object> createTransaction(String transactionState, String userId) {
    Map<String, Object> transaction = new HashMap<String, Object>();
    transaction.put("vendor", TYPE);
    transaction.put("transactionState", transactionState);
    if (userId != null)
      transaction.put("_userId", userId);
    return transaction;
  }

  private String toProductType(ItemType itemType) {
    return itemType == ItemType.CONSUMABLE ? "CONSUMABLE" :
           itemType == ItemType.ENTITLED ? "ENTITLED" :
           itemType == ItemType.SUBSCRIPTION ? "SUBSCRIPTION" : "UNKNOWN";
  }

  private void requestUserId(Closure closure) {
    String id = PurchasingManager.initiateGetUserIdRequest();
    registerCallback(id, closure);
  }

  private void registerCallback(String id, Closure closure) {
    Extension.debug("Amazon: registerCallback(%s, %s)", id, closure);
    callbacks.put(id, closure);
  }

  private Closure releaseCallback(String id) {
    Extension.debug("Amazon: releaseCallback(%s)", id);
    return callbacks.remove(id);
  }

  private void callback(String id, Object... args) {
    Closure callback = releaseCallback(id);
    if (callback != null)
      callback.asyncInvoke(args);
  }
}
