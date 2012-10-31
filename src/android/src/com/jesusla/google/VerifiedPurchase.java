package com.jesusla.google;

import com.jesusla.google.Consts.PurchaseState;

/**
 * A class to hold the verified purchase information.
 */
public class VerifiedPurchase {
    public PurchaseState purchaseState;
    public String notificationId;
    public String productId;
    public String orderId;
    public long purchaseTime;
    public String developerPayload;

    public VerifiedPurchase(PurchaseState purchaseState, String notificationId,
            String productId, String orderId, long purchaseTime, String developerPayload) {
        this.purchaseState = purchaseState;
        this.notificationId = notificationId;
        this.productId = productId;
        this.orderId = orderId;
        this.purchaseTime = purchaseTime;
        this.developerPayload = developerPayload;
    }
}