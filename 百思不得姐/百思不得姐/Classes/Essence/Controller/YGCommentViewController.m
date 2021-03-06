//
//  YGCommentViewController.m
//  百思不得姐
//
//  Created by 刘勇刚 on 16/3/3.
//  Copyright © 2016年 liu. All rights reserved.
//

#import "YGCommentViewController.h"
#import "YGTopic.h"
#import "YGTopicCell.h"
#import <MJRefresh.h>
#import <AFNetworking.h>
#import "YGComment.h"
#import <MJExtension.h>
#import "YGCommentHeaderView.h"
#import "YGCommentCell.h"

static NSString * const YGCommentCellID = @"comment"; // cell循环利用的标识

@interface YGCommentViewController () <UITableViewDelegate, UITableViewDataSource>
/**
 *  底部工具条间距
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomLine;
/**
 *  tableView
 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/**
 *  最热评论
 */
@property (strong, nonatomic) NSArray *hotComment;
/**
 *  最新评论
 */
@property (strong, nonatomic) NSMutableArray *latestComment;
/**
 *  保存帖子的数据
 */
@property (strong, nonatomic) NSArray *saved_top_cmt;
/**
 *  当前页码
 */
@property (assign, nonatomic) NSInteger page;
/**
 *  管理者
 */
@property (strong, nonatomic) AFHTTPSessionManager *manager;

@end

@implementation YGCommentViewController

- (AFHTTPSessionManager *)manager
{
    if (!_manager) {
        _manager = [AFHTTPSessionManager manager];
    }
    return _manager;
}

- (NSMutableArray *)latestComment
{
    if (!_latestComment) {
        _latestComment = [NSMutableArray array];
    }
    
    return _latestComment;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupBasic];
    // 设置头部
    [self setupHeader];
    
    // 刷新控件
    [self setupRefresh];
    
}
/**
 *  设置基本数据
 */
- (void)setupBasic
{
    self.title = @"评论";
    self.navigationItem.rightBarButtonItem = [UIBarButtonItem itemWithImage:@"comment_nav_item_share_icon" highImage:@"comment_nav_item_share_icon_click" target:self action:nil];
    
    // 监听键盘的弹出或隐藏
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    
    // cell的高度
    self.tableView.estimatedRowHeight = 44;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    
    //tableView设置全局色
    self.tableView.backgroundColor = YGGlobalBg;
    
    // 注册cell
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([YGCommentCell class]) bundle:nil] forCellReuseIdentifier:YGCommentCellID];
    
    // 去除分割线
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    // 设置内边距
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, YGTopicCellMargin, 0);
}
/**
 *  设置头部cell
 */
- (void)setupHeader
{
    UIView *header = [[UIView alloc] init];
    // 清空top_cmt
    if (self.topic.top_cmt.count) {
        self.saved_top_cmt = self.topic.top_cmt;
        self.topic.top_cmt = nil;
        [self.topic setValue:@0 forKey:@"cellHeight"];
    }
    
    
    
    YGTopicCell *cell = [YGTopicCell viewFromXib];
    cell.topic = self.topic;
    // Cell的高度
    cell.size = CGSizeMake(YGmainScreenW, self.topic.cellHeight);
    [header addSubview:cell];
    
    //header的高度
    header.height = cell.height + YGTopicCellMargin;
    
    self.tableView.tableHeaderView = header;
    
}
- (void)setupRefresh
{
    self.tableView.mj_header = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(loadNewComments)];
    [self.tableView.mj_header beginRefreshing]; // 一进来自动刷新
    
    // footer
    self.tableView.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingTarget:self refreshingAction:@selector(loadMoreComments)];
    self.tableView.mj_footer.hidden = YES;
}
/**
 *  加载最新数据
 */
- (void)loadNewComments
{
    // 结束刷新
    [self.manager.tasks makeObjectsPerformSelector:@selector(cancel)];
    // 参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"a"] = @"dataList";
    params[@"c"] = @"comment";
    params[@"data_id"] = self.topic.ID;
    params[@"hot"] = @"1";
    // 发送请求
    [self.manager GET:@"http://api.budejie.com/api/api_open.php" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            [self.tableView.mj_header endRefreshing]; // 没有数据 头部结束刷新
            return;
        }
        // 最热评论
        self.hotComment = [YGComment mj_objectArrayWithKeyValuesArray:responseObject[@"hot"]];
        // 最新评论
        self.latestComment = [YGComment mj_objectArrayWithKeyValuesArray:responseObject[@"data"]];
        
        // 成功了page回到第一页
        self.page = 1;
        
        // 刷新表格
        [self.tableView reloadData];
        
        [self.tableView.mj_header endRefreshing];
        
        // 控制footer的状态
        NSInteger total = [responseObject[@"total"] integerValue];
        if (self.latestComment.count >= total) {
            self.tableView.mj_footer.hidden = YES;
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [self.tableView.mj_header endRefreshing]; // 结束刷新
        
    }];
}
/**
 *  加载更多数据
 */
- (void)loadMoreComments
{
    // 结束刷新
    [self.manager.tasks makeObjectsPerformSelector:@selector(cancel)];
    
    NSInteger page = self.page + 1;
    // 参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"a"] = @"dataList";
    params[@"c"] = @"comment";
    params[@"data_id"] = self.topic.ID;
    params[@"page"] =@(page);
    YGComment *cmt = [self.latestComment lastObject];
    params[@"lastcid"] = cmt.ID;
    // 发送请求
    [self.manager GET:@"http://api.budejie.com/api/api_open.php" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) return;
        // 最新评论
        NSArray *comments = [YGComment mj_objectArrayWithKeyValuesArray:responseObject[@"data"]];
        [self.latestComment addObjectsFromArray:comments];
        
        // 成功了页码再赋值
        self.page = page;
        
        // 刷新表格
        [self.tableView reloadData];
        
        
        // 控制footer的状态
        NSInteger total = [responseObject[@"total"] integerValue];
        if (self.latestComment.count >= total) {
            self.tableView.mj_footer.hidden = YES;
        } else {
            [self.tableView.mj_footer endRefreshing];
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [self.tableView.mj_footer endRefreshing]; // 结束刷新
        
    }];
    
}
- (void)keyboardWillChangeFrame:(NSNotification *)note
{
    // 键盘最终显示/隐藏完毕后的frame
    CGRect frame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // 修改约束
    self.bottomLine.constant = YGmainScreenH - frame.origin.y;
    
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 恢复帖子的数据
    if (self.saved_top_cmt) {
        self.topic.top_cmt = self.saved_top_cmt;
        [self.topic setValue:@0 forKey:@"cellHeight"];
    }
    // 取消所有任务
    [self.manager invalidateSessionCancelingTasks:YES];
    
}
/**
 *  返回第section组所有评论
 */
- (NSArray *)commentsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.hotComment.count ? self.hotComment : self.latestComment;
    }
    return self.latestComment;
}
- (YGComment *)commentInIndexPath:(NSIndexPath *)indexPath
{
    return [self commentsInSection:indexPath.section][indexPath.row];
}
#pragma mark - UITableViewDelegate方法
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
    
    // 让menuController消失
    [[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIMenuController *menu = [UIMenuController sharedMenuController];
    if (menu.isMenuVisible) {
        [menu setMenuVisible:NO animated:YES];
    } else {
        YGCommentCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        // 出现第一响应者
        [cell becomeFirstResponder];
        
        UIMenuItem *ding = [[UIMenuItem alloc] initWithTitle:@"顶" action:@selector(ding:)];
        UIMenuItem *replay = [[UIMenuItem alloc] initWithTitle:@"回复" action:@selector(replay:)];
        UIMenuItem *report = [[UIMenuItem alloc] initWithTitle:@"举报" action:@selector(report:)];
        menu.menuItems = @[ding, replay, report];
        CGRect rect = CGRectMake(0, cell.height * 0.5, cell.width, cell.height * 0.5);
        [menu setTargetRect:rect inView:cell];
        // 让menu显示出来
        [menu setMenuVisible:YES animated:YES];
    }
    
    
    
}
- (void)ding:(UIMenuController *)menu
{
    NSLog(@"%s  %@",__func__, menu);
}

- (void)replay:(UIMenuController *)menu
{
     NSLog(@"%s  %@",__func__, menu);
}
- (void)report:(UIMenuController *)menu
{
     NSLog(@"%s  %@",__func__, menu);
}

#pragma mark - UITableViewDataSource方法
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger hotCount = self.hotComment.count;
    NSInteger latestCount = self.latestComment.count;
    if (hotCount) return 2;
    if (latestCount) return 1;
    return 0;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger hotCount = self.hotComment.count;
    NSInteger latestCount = self.latestComment.count;
    // 隐藏尾部控件
    tableView.mj_footer.hidden = (latestCount == 0);
    if (section == 0) {
        return hotCount ? hotCount : latestCount;
    }
    return latestCount;
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    YGCommentHeaderView *header = [YGCommentHeaderView headerViewWithTableView:tableView];
    
    // 设置文字
    NSInteger hotCount = self.hotComment.count;
    if (section == 0) {
        header.title = hotCount ? @"最热评论" : @"最新评论";
    } else {
        header.title = @"最新评论";
    }
    
    return header;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    YGCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:YGCommentCellID];
    cell.comment = [self commentInIndexPath:indexPath];
    return cell;
}
@end
