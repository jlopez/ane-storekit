//
//  StoreKit.mm
//  StoreKit
//
//  Created by Jesus Lopez on 05/14/2012
//  Copyright (c) 2012 JLA. All rights reserved.
//
#import <StoreKit/StoreKit.h>
#import "NativeLibrary.h"

@interface StoreKit : NativeLibrary<SKProductsRequestDelegate, SKPaymentTransactionObserver> {
@private
  NSMutableDictionary *products;
  BOOL observerInitialized;
}

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

@implementation StoreKit

FN_BEGIN(StoreKit)
  FN(init, setupWithProductIds:)
  FN(canMakePayments, canMakePayments)
  FN(transactions, transactions)
  FN(requestPayment, requestPaymentForProductId:quantity:)
  FN(finishTransaction, finishTransactionWithIdentifier:)
  FN(restoreCompletedTransactions, restoreCompletedTransactions)
FN_END

- (id)init {
  if (self = [super init]) {
    products = [NSMutableDictionary new];
    observerInitialized = NO;
  }
  return self;
}

- (void)dealloc {
  [products release];
  if (observerInitialized)
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
  [super dealloc];
}

- (void)setupWithProductIds:(NSArray *)productIds {
  NSSet *ids = [NSSet setWithArray:productIds];
  SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:ids];
  productsRequest.delegate = self;
  [productsRequest start];

  if (!observerInitialized)
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
  observerInitialized = YES;
}

- (BOOL)canMakePayments {
  return [SKPaymentQueue canMakePayments];
}

- (NSArray *)transactions {
  return [[SKPaymentQueue defaultQueue] transactions];
}

- (BOOL)requestPaymentForProductId:(NSString *)productIdentifier quantity:(NSUInteger)quantity {
  SKPaymentQueue *paymentQueue = [SKPaymentQueue defaultQueue];
  SKProduct *product = [products objectForKey:productIdentifier];
  if (!product) {
    ANELog(@"Product '%@' does not exist. Ignoring request for payment", productIdentifier);
    return NO;
  }
  SKPayment *payment = [SKPayment paymentWithProduct:product];
  [paymentQueue addPayment:payment];
  return YES;
}

- (BOOL)finishTransactionWithIdentifier:(NSString *)transactionIdentifier {
  SKPaymentQueue *paymentQueue = [SKPaymentQueue defaultQueue];
  NSArray *transactions = paymentQueue.transactions;
  NSUInteger index = [transactions indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
    return [[obj transactionIdentifier] isEqualToString:transactionIdentifier];
  }];
  if (index == NSNotFound) {
    ANELog(@"%s: No transaction found for transactionIdentifier '%@'. Ignoring", __PRETTY_FUNCTION__, transactionIdentifier);
    return NO;
  }
  SKPaymentTransaction *paymentTransaction = [transactions objectAtIndex:index];
  [paymentQueue finishTransaction:paymentTransaction];
  return YES;
}

- (void)restoreCompletedTransactions {
  [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
  ANELog(@"%s: products[%@] invalidProductIdentifiers[%@]", __PRETTY_FUNCTION__, response.products, response.invalidProductIdentifiers);
  for (SKProduct *product in response.products)
    [products setObject:product forKey:product.productIdentifier];
  [self executeOnActionScriptThread:^{
    [self callMethodNamed:@"handleInitialization" withArgument:products];
  }];
}

- (void)requestDidFinish:(SKRequest *)request {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, request);
  [request release];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
  ANELog(@"%s: %@, %@", __PRETTY_FUNCTION__, request, error);
  [request release];
}

// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, transactions);
  [self executeOnActionScriptThread:^{
    [self callMethodNamed:@"handleTransactions" withArgument:transactions];
  }];
}

// Sent when transactions are removed from the queue (via finishTransaction:).
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, transactions);
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
  [self executeOnActionScriptThread:^{
    [self callMethodNamed:@"handleRestore" withArgument:error];
  }];
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
  [self executeOnActionScriptThread:^{
    [self callMethodNamed:@"handleRestore"];
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
