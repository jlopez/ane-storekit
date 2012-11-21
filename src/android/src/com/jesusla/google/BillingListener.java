package com.jesusla.google;


public interface BillingListener {
  void verifyTransaction(int startId, String signedData, String signature, VerifiedPurchase purchase);
}
