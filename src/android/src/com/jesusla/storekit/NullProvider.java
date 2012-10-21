package com.jesusla.storekit;

import java.util.Map;

import com.jesusla.ane.Closure;

public class NullProvider implements Provider {
  public NullProvider(StoreKit storeKit) {
  }

  @Override
  public void dispose() {
  }

  @Override
  public void init(String[] productIdentifiers, Closure closure) {
    closure.invoke(null, false);
  }

  @Override
  public void requestPayment(String productIdentifier, Closure closure) {
    closure.invoke(null, false);
  }

  @Override
  public void acknowledgeTransaction(Map<String, Object> transaction) {
  }

  @Override
  public void restoreCompletedTransactions(Closure closure) {
    closure.invoke(null, false);
  }
}
