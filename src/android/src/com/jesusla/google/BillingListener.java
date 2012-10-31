package com.jesusla.google;


public interface BillingListener {
  /**
   * Notifies the application of purchase state changes. The application
   * can offer an item for sale to the user via
   * {@link BillingService#requestPurchase(String)}. The BillingService
   * calls this method after it gets the response. Another way this method
   * can be called is if the user bought something on another device running
   * this same app. Then Android Market notifies the other devices that
   * the user has purchased an item, in which case the BillingService will
   * also call this method. Finally, this method can be called if the item
   * was refunded.
   * @param startId
   * @param purchaseState the state of the purchase request (PURCHASED,
   *     CANCELED, or REFUNDED)
   * @param productId a string identifying a product for sale
   * @param orderId a string identifying the order
   * @param purchaseTime the time the product was purchased, in milliseconds
   *     since the epoch (Jan 1, 1970)
   * @param developerPayload the developer provided "payload" associated with
   *     the order
   */
  void onTransactionUpdate(int startId, VerifiedPurchase purchase);

  void verifyTransaction(int startId, String signedData, String signature, VerifiedPurchase purchase);
}
