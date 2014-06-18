/*
 * Copyright (C) 2010 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.jesusla.google;

/**
 * This class holds global constants that are used throughout the application
 * to support in-app billing.
 */
public class Consts {
  /** This is the action we use to bind to the MarketBillingService. */
  public static final String MARKET_BILLING_SERVICE_ACTION =
      "com.android.vending.billing.InAppBillingService.BIND";

  // These are the names of the extras that are passed in an intent from
  // Market to this application and cannot be changed.
  //    public static final String NOTIFICATION_ID = "notification_id";
  //    public static final String INAPP_SIGNED_DATA = "inapp_signed_data";
  //    public static final String INAPP_SIGNATURE = "inapp_signature";
  //    public static final String INAPP_REQUEST_ID = "request_id";
  //    public static final String INAPP_RESPONSE_CODE = "response_code";

  public static final boolean DEBUG = true;
}
