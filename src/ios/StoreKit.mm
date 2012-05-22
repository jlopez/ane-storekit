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

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, transactions);
  [self executeOnActionScriptThread:^{
    [self callMethodNamed:@"handleTransactions" withArgument:transactions];
  }];
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
  ANELog(@"%s: %@", __PRETTY_FUNCTION__, transactions);
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
  // error & payment are included in the event they're nil
  // if so, they're added as [NSNull null], otherwise, they're
  // replaced below with their dictionary representation.
  NSArray *keys = [NSArray arrayWithObjects:@"transactionIdentifier",
                   @"transactionDate", @"transactionState", @"error",
                   @"payment", nil];
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self dictionaryWithValuesForKeys:keys]];
  if (self.error)
    [dict setObject:[self.error dictionaryRepresentation] forKey:@"error"];
  if (self.payment)
    [dict setObject:[self.payment dictionaryRepresentation] forKey:@"payment"];
  // Missing: transactionReceipt
  return dict;
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
