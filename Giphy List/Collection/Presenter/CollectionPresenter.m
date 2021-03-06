//
//  CollectionPresenter.m
//  Giphy List
//
//  Created by Nikita Teplyakov on 02.08.2020.
//  Copyright © 2020 Nikita Tepliakov. All rights reserved.
//

#import "CollectionPresenter.h"
#import "NetworkService.h"
#import "ImageLoader.h"

NSInteger const kLimit = 100;

@interface CollectionPresenter ()

@property (nonatomic) BOOL isLoading;
@property (nonatomic, copy) NSString *query;
@property (nonatomic) NSMutableArray<CollectionCellViewModel *> *viewModels;
@property (nonatomic, nullable) PaginationJSONModel *pagination;
@property (nonatomic, nullable) NSBlockOperation *operation;

@property (nonatomic) id<NetworkServiceProtocol> networkService;
@property (nonatomic) ImageLoader *imageLoader;

@end

@implementation CollectionPresenter

- (instancetype)initWithNetworkService:(id<NetworkServiceProtocol>)networkService imageLoader:(ImageLoader *)imageLoader {
	self = [super init];
	if (self) {
		_query = @"";
		_viewModels = @[].mutableCopy;
		_networkService = networkService;
		_imageLoader = imageLoader;
	}
	return self;
}

- (void)loadImagesWithQuery:(NSString *)query {
	if (![self.query isEqualToString:query]) {
		[self.operation cancel];
		self.operation = nil;
		self.pagination = nil;
		self.isLoading = NO;

		self.query = query;
		self.viewModels = @[].mutableCopy;
		[self.delegate updateIsLoading];
		[self.delegate updateList];
	}

	if (query.length < 2) {
		return;
	}

	if (self.isLoading || (self.pagination && self.viewModels.count >= self.pagination.totalCount)) {
		return;
	}

	self.isLoading = YES;
	[self.delegate updateIsLoading];

	__weak typeof(self) wself = self;
	self.operation = [[NSBlockOperation alloc] init];
	NSUInteger hash = self.operation.hash;
	[self.operation addExecutionBlock:^{
		[wself.networkService searchWithQuery:query limit:kLimit offset:wself.viewModels.count success:^(SearchResultJSONModel * _Nonnull result) {
			if (hash == wself.operation.hash) {
				[wself handleResult:result];
			}
		} failure:^(NSError * _Nonnull error) {
			if (hash == wself.operation.hash) {
				[wself handleError];
			}
		}];
	}];

	[self.operation start];
}

- (void)loadMore {
	[self loadImagesWithQuery:self.query];
}

- (void)handleResult:(SearchResultJSONModel *)result {
	if (self.operation.isCancelled) {
		return;
	}

	self.pagination = result.pagination;

	NSMutableArray<CollectionCellViewModel *> *newViewModels = @[].mutableCopy;

	for (GIFJSONModel *model in result.data) {
		NSInteger width = model.images.fixedHeightSmall.width.integerValue;
		NSInteger height = model.images.fixedHeightSmall.height.integerValue;
		NSString *url = model.images.fixedHeightSmall.url;
		CollectionCellViewModel *viewModel = [[CollectionCellViewModel alloc] initWithWidth:width
																					 height:height
																						url:url
																				imageLoader:self.imageLoader];
		[newViewModels addObject:viewModel];
	}

	self.isLoading = NO;
	[self.viewModels addObjectsFromArray:newViewModels];
	[self.delegate updateIsLoading];
	[self.delegate updateList];
}

- (void)handleError {
	if (!self.operation.isCancelled) {
		self.isLoading = NO;
		[self.delegate updateIsLoading];
	}
}

@end
