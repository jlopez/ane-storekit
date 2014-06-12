//
//  StoreKit.mm
//  StoreKit
//
//  Created by Jesus Lopez on 05/14/2012
//  Copyright (c) 2012 JLA. All rights reserved.
//
#import <StoreKit/StoreKit.h>
#import "NativeLibrary.h"

@interface StoreKit : NativeLibrary<SKPaymentTransactionObserver> {
@private
  BOOL observerInitialized;
  NSTimer *transactionReminderTimer;
}

@property (nonatomic, retain) NSMutableDictionary *products;
@property (nonatomic, retain) ASFunction *restoreTransactionsCallback;

- (void)reviewTransactionsAfterDelay:(NSTimeInterval)delay;

@end

@interface SKProduct (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation;

@end

@interface SKPaymentTransaction (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation;

@end

@interface SKPayment (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation;

@end

@interface NSError (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation;

@end

@interface ProductsRequest : NSObject<SKProductsRequestDelegate> {
}

@property (nonatomic, retain) NSArray *productIdentifiers;
@property (nonatomic, retain) ASFunction *callback;
@property (nonatomic, retain) StoreKit *storeKit;

@end

@implementation ProductsRequest

@synthesize productIdentifiers;
@synthesize callback;
@synthesize storeKit;


- (void)dealloc {
  [productIdentifiers release];
  [callback release];
  [storeKit release];
  [super dealloc];
}


- (void)start {
  NSSet *ids = [NSSet setWithArray:productIdentifiers];
  SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:ids];
  productsRequest.delegate = self;
  [productsRequest start];
  // request gets released in delegate - Not a leak
}


- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
  ANELog(@"%s: products[%@] invalidProductIdentifiers[%@]", __PRETTY_FUNCTION__, response.products, response.invalidProductIdentifiers);
  NSMutableDictionary *products = [[[NSMutableDictionary alloc] initWithCapacity:[response.products count]] autorelease];
  for (SKProduct *product in response.products)
    [products setObject:product forKey:product.productIdentifier];
  [storeKit executeOnActionScriptThread:^{
    storeKit.products = products;
    BOOL canMakePayments = [SKPaymentQueue canMakePayments];
    [callback callWithArgument:@(canMakePayments)];
    if (canMakePayments)
      [storeKit reviewTransactionsAfterDelay:60];
  }];
}


- (void)requestDidFinish:(SKRequest *)request {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, request);
  [request release];
  [self release];
}


- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
  ANELog(@"%s: %@, %@", __PRETTY_FUNCTION__, request, error);
  [request release];
  [storeKit executeOnActionScriptThread:^{
    [callback callWithArgument:@(NO)];
    [self release];
  }];
}


@end

@implementation StoreKit

FN_BEGIN(StoreKit)
  FN(init, initWithProductIdentifiers:callback:)
  FN(requestPayment, requestPaymentForProductId:callback:)
  FN(restoreCompletedTransactions, restoreCompletedTransactionsWithCallback:)
  FN(finishTransaction, finishTransaction:)
  FN(transactions, transactions)
  FN(products, products)
FN_END

@synthesize products;
@synthesize restoreTransactionsCallback;

- (id)init {
  if (self = [super init]) {
    observerInitialized = NO;
  }
  return self;
}

- (void)dealloc {
  [restoreTransactionsCallback release];
  [products release];
  if (observerInitialized)
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
  [super dealloc];
}

- (void)initWithProductIdentifiers:(NSArray *)productIdentifiers callback:(ASFunction *)callback {
  ProductsRequest *request = [ProductsRequest new];
  request.storeKit = self;
  request.productIdentifiers = productIdentifiers;
  request.callback = callback;
  [request start];

  if (!observerInitialized)
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
  observerInitialized = YES;
}

- (NSArray *)transactions {
  return [[SKPaymentQueue defaultQueue] transactions];
}

- (NSDictionary *)products {
  return products;
}

- (void)requestPaymentForProductId:(NSString *)productIdentifier callback:(ASFunction *)callback {
  SKPaymentQueue *paymentQueue = [SKPaymentQueue defaultQueue];
  SKProduct *product = [products objectForKey:productIdentifier];
  if (!product) {
    ANELog(@"Product '%@' does not exist. Ignoring request for payment", productIdentifier);
    [callback callWithArgument:@(NO)];
    return;
  }
  SKPayment *payment = [SKPayment paymentWithProduct:product];
  [paymentQueue addPayment:payment];
  [callback callWithArgument:@(YES)];
}

- (void)finishTransaction:(NSDictionary *)transaction {
  NSString *transactionIdentifier = [transaction objectForKey:@"_transactionIdentifier"];
  if (!transactionIdentifier) {
    ANELog(@"%s: Missing transactionIdentifier. Ignoring", __PRETTY_FUNCTION__);
    return;
  }
  SKPaymentQueue *paymentQueue = [SKPaymentQueue defaultQueue];
  NSArray *transactions = paymentQueue.transactions;
  NSUInteger index = [transactions indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
    return [[obj transactionIdentifier] isEqualToString:transactionIdentifier];
  }];
  if (index == NSNotFound) {
    ANELog(@"%s: No transaction found for transactionIdentifier '%@'. Ignoring", __PRETTY_FUNCTION__, transactionIdentifier);
    return;
  }
  SKPaymentTransaction *paymentTransaction = [transactions objectAtIndex:index];
  [paymentQueue finishTransaction:paymentTransaction];
}

- (void)restoreCompletedTransactionsWithCallback:(ASFunction *)callback {
  self.restoreTransactionsCallback = callback;
  [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)reviewTransactionsAfterDelay:(NSTimeInterval)delay {
  [self performSelector:@selector(transactionReview) withObject:nil afterDelay:delay];
}

- (void)cancelTransactionReview {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(transactionReview) object:nil];
}

- (void)transactionReview {
  SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
  NSArray *transactions = [queue transactions];
  NSUInteger transactionCount = [transactions count];
  ANELog(@"%s: %d transactions to review", __PRETTY_FUNCTION__, transactionCount);
  if (transactionCount)
    [self paymentQueue:queue updatedTransactions:transactions];
  // else, there's nothing to review and no reason to keep reviewing them
  // (transactions can't be added to the queue out of the blue)
  // transaction reviews are restarted as soon as new transactions are
  // added to the queue in the paymentQueue:updatedTransactions: delegate method
}

id wrapNil(id obj) {
  return obj ? obj : [NSNull null];
}

// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
  [self cancelTransactionReview];
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, transactions);
  [self executeOnActionScriptThread:^{
    for (SKPaymentTransaction *transaction in transactions) {
      NSString *type;
      SKPaymentTransactionState state = transaction.transactionState;
      if (state == SKPaymentTransactionStatePurchasing)
        continue;
      if (state == SKPaymentTransactionStatePurchased)
        type = @"VERIFY";
      else if (state == SKPaymentTransactionStateFailed)
        type = @"FAILED";
      else if (state == SKPaymentTransactionStateRestored)
        type = @"PURCHASED";
      else
        continue;
      NSDictionary *tx = @{
        @"vendor": @"APPLE",
        @"transactionState": wrapNil(type),
        @"productIdentifier": wrapNil(transaction.payment.productIdentifier),
        @"_transactionIdentifier": wrapNil(transaction.transactionIdentifier),
        @"_transactionDate": wrapNil(transaction.transactionDate),
        @"_transactionReceipt": wrapNil(transaction.transactionReceipt),
        @"_error": wrapNil([transaction.error dictionaryRepresentation]),
        @"error": translateError(transaction.error),
      };
      [self callMethodNamed:@"onTransactionUpdate" withArgument:tx];
    }
    [self reviewTransactionsAfterDelay:60];
  }];
}

NSNumber *translateError(NSError *error) {
  if (![SKErrorDomain isEqual:error.domain])
    return @0;
  if (error.code == SKErrorPaymentCancelled)
    return @2;
  if (error.code == SKErrorPaymentNotAllowed)
    return @3;
  return @1;
}

// Sent when transactions are removed from the queue (via finishTransaction:).
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, transactions);
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, error);
  [self executeOnActionScriptThread:^{
    [restoreTransactionsCallback callWithArgument:@(NO)];
    self.restoreTransactionsCallback = nil;
  }];
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
  [self executeOnActionScriptThread:^{
    [restoreTransactionsCallback callWithArgument:@(YES)];
    self.restoreTransactionsCallback = nil;
  }];
}

@end

@implementation SKProduct (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation {
  NSArray *keys = [NSArray arrayWithObjects:@"localizedTitle",
                   @"localizedDescription", @"price", @"productIdentifier", nil];
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self dictionaryWithValuesForKeys:keys]];

  NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
  [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
  [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
  [numberFormatter setLocale:self.priceLocale];
  NSString *formattedString = [numberFormatter stringFromNumber:self.price];
  [dict setObject:formattedString forKey:@"localizedPrice"];
  [numberFormatter release];

  return dict;
}

@end

@implementation SKPaymentTransaction (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation {
  NSArray *keys = [NSArray arrayWithObjects:@"transactionIdentifier",
                   @"transactionDate", @"transactionState", @"error",
                   @"payment", @"transactionReceipt", nil];
  return [NSMutableDictionary dictionaryWithDictionary:[self dictionaryWithValuesForKeys:keys]];
}

@end

@implementation SKPayment (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation {
  NSArray *keys = [NSArray arrayWithObjects:@"productIdentifier",
                   @"quantity", nil];
  return [self dictionaryWithValuesForKeys:keys];
}

@end

@implementation NSError (JLDictionaryRepresentation)

- (NSDictionary *)dictionaryRepresentation {
  NSArray *keys = [NSArray arrayWithObjects:@"domain", @"code",
                   @"localizedDescription", @"localizedFailureReason",
                   @"localizedRecoverySuggestion", nil];
  return [self dictionaryWithValuesForKeys:keys];
}

@end
