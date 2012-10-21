package com.jesusla.google;

import com.jesusla.google.Consts.ResponseCode;

public interface RestoreTransactionsCallback {
  /**
   * This is called when we receive a response code from Android Market for a
   * RestoreTransactions request.
   * @param responseCode a response code from Market to indicate the state
   *     of the request
   */
  void restoreTransactionsResponse(ResponseCode responseCode);
}
