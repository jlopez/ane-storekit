package com.jesusla.storekit;

import java.util.Map;

import com.jesusla.ane.Closure;

public interface Provider {
  void dispose();
  void init(String[] productIdentifiers, Closure closure);
  void requestPayment(String productIdentifier, Closure closure);
  void finishTransaction(Map<String, Object> transaction);
  void restoreCompletedTransactions(Closure closure);
  Map<String, Object> getProducts();
}
