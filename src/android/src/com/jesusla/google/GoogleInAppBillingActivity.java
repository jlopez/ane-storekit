/* Copyright (c) 2012 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.jesusla.google;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

import com.jesusla.ane.Extension;
import com.jesusla.storekit.GoogleProvider;

public class GoogleInAppBillingActivity extends Activity {
  // Debug tag, for logging
  static final String TAG = "GoogleInAppBillingActivity";

  // (arbitrary) request code for the purchase flow
  static final int RC_REQUEST = 10001;

  private IabHelper mHelper;
  private String callbackHash = null;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    mHelper = GoogleProvider.getInstance().getHelper();

    Intent intent = getIntent();
    String method = intent.getStringExtra("method");
    if(intent.hasExtra("callback_hash"))
      callbackHash = intent.getStringExtra("callback_hash");

    if (("requestPayment").equalsIgnoreCase(method)) {
      final String sku = intent.getStringExtra("sku");
      final GoogleInAppBillingActivity instance = this;
      runOnUiThread(
          new Runnable() {
            @Override
            public void run() {
              mHelper.launchPurchaseFlow(instance, sku, RC_REQUEST, mPurchaseFinishedListener);
            }
          });
    }
    else if(("consumeItem").equalsIgnoreCase(method)) {
      final String sku = intent.getStringExtra("item_sku");

      runOnUiThread(
          new Runnable() {
            @Override
            public void run() {
              Purchase purchase = GoogleProvider.getInstance().getInventory().getPurchase(sku);
              if(purchase == null) {
                Extension.warn("Consumable item is not on the current inventory %s", sku);
              }
              else {
                mHelper.consumeAsync(purchase, mConsumeFinishedListener);
              }
            }
          });
    }
  }

  @Override
  protected void onActivityResult(int requestCode, int resultCode, Intent data) {
    Extension.debug("onActivityResult(" + requestCode + "," + resultCode + "," + data);
    if (mHelper == null)
      return;

    // Pass on the activity result to the helper for handling
    if (!mHelper.handleActivityResult(requestCode, resultCode, data)) {
      // not handled, so handle it ourselves (here's where you'd
      // perform any handling of activity results not related to in-app
      // billing...
      super.onActivityResult(requestCode, resultCode, data);
    }
    else {
      Extension.debug("onActivityResult handled by IABUtil.");
    }
  }

  // Callback for when a purchase is finished
  IabHelper.OnIabPurchaseFinishedListener mPurchaseFinishedListener = new IabHelper.OnIabPurchaseFinishedListener() {
    @Override
    public void onIabPurchaseFinished(IabResult result, Purchase purchase) {
      // if we were disposed of in the meantime, quit.
      if (mHelper == null) return;

      if (result.isFailure()) {
        GoogleProvider.getInstance().onPurchaseFinished(callbackHash, purchase, result);
        finish();
        return;
      }

      Extension.debug("Purchase successful.");
      GoogleProvider.getInstance().onPurchaseFinished(callbackHash, purchase, result);
      finish();
    }
  };

  // Callback for when an item is consumed
  IabHelper.OnConsumeFinishedListener mConsumeFinishedListener = new IabHelper.OnConsumeFinishedListener() {
    @Override
    public void onConsumeFinished(Purchase purchase, IabResult result) {
      // if we were disposed of in the meantime, quit.
      if (mHelper == null) return;

      GoogleProvider.getInstance().onConsumeFinished(purchase, result);
      finish();
    }
  };

  // We're being destroyed. It's important to dispose of the helper here!
  @Override
  public void onDestroy() {
    super.onDestroy();
    mHelper = null;
  }
}
