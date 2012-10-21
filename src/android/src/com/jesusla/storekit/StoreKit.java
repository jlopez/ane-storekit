package com.jesusla.storekit;

import java.util.Map;

import com.jesusla.ane.Closure;
import com.jesusla.ane.Context;
import com.jesusla.ane.Extension;

public class StoreKit extends Context {
  private Provider provider;

  public StoreKit() {
    registerFunction("init");
    registerFunction("requestPayment");
    registerFunction("acknowledgeTransaction");
    registerFunction("restoreCompletedTransactions");
  }

  @Override
  protected void initContext() {
    String providerType = getRequiredProperty("SKProvider");
    if (GoogleProvider.TYPE.equalsIgnoreCase(providerType))
      provider = new GoogleProvider(this);
    else if (AmazonProvider.TYPE.equalsIgnoreCase(providerType))
      provider = new AmazonProvider(this);
    else {
      Extension.fail("Unknown provider [%s]. StoreKit will be disabled", providerType);
      provider = new NullProvider(this);
    }
  }

  @Override
  public void dispose() {
    provider.dispose();
  }

  public void init(String[] productIdentifiers, final Closure closure) {
    provider.init(productIdentifiers, closure);
  }

  public void requestPayment(String productIdentifier, final Closure closure) {
    provider.requestPayment(productIdentifier, closure);
  }

  public void acknowledgeTransaction(Map<String, Object> transaction) {
    provider.acknowledgeTransaction(transaction);
  }

  public void restoreCompletedTransactions(final Closure closure) {
    provider.restoreCompletedTransactions(closure);
  }
}
