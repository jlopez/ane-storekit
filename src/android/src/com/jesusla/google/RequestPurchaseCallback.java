package com.jesusla.google;

import com.jesusla.google.Consts.ResponseCode;

public interface RequestPurchaseCallback {
  /**
   * This is called when we receive a response code from Android Market for a
   * RequestPurchase request that we made.  This is used for reporting various
   * errors and also for acknowledging that an order was sent successfully to
   * the server. This is NOT used for any purchase state changes. All
   * purchase state changes are received in the {@link BillingListener} and
   * are handled in @link Security#verifyPurchase(String, String).
   * @param context the context
   * @param request the RequestPurchase request for which we received a
   *     response code
   * @param responseCode a response code from Market to indicate the state
   * of the request
   */
  void requestPurchaseResponse(ResponseCode responseCode, String productId, String productType, String developerPayload);
}
