//
//  iTermFileDescriptorMultiClientChild.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 3/15/20.
//

#import "iTermFileDescriptorMultiClientChild.h"

@implementation iTermFileDescriptorMultiClientChild {
    iTermThread *_thread;
}
@synthesize hasTerminated = _hasTerminated;
@synthesize haveWaited = _haveWaited;
@synthesize haveSentPreemptiveWait = _haveSentPreemptiveWait;
@synthesize terminationStatus = _terminationStatus;

- (instancetype)initWithReport:(iTermMultiServerReportChild *)report
                        thread:(iTermThread *)thread {
    self = [super init];
    if (self) {
        _thread = thread;
        _pid = report->pid;
        _executablePath = [[NSString alloc] initWithUTF8String:report->path];
        NSMutableArray<NSString *> *args = [NSMutableArray array];
        for (int i = 0; i < report->argc; i++) {
            NSString *arg = [[NSString alloc] initWithUTF8String:report->argv[i]];
            [args addObject:arg];
        }
        _args = args;

        NSMutableDictionary<NSString *, NSString *> *environment = [NSMutableDictionary dictionary];
        for (int i = 0; i < report->envc; i++) {
            NSString *kvp = [[NSString alloc] initWithUTF8String:report->envp[i]];
            NSInteger equals = [kvp rangeOfString:@"="].location;
            if (equals == NSNotFound) {
                assert(false);
                continue;
            }
            NSString *key = [kvp substringToIndex:equals];
            NSString *value = [kvp substringFromIndex:equals + 1];
            if (environment[key]) {
                continue;
            }
            environment[key] = value;
        }
        _environment = environment;
        _utf8 = report->isUTF8;
        _initialDirectory = [[NSString alloc] initWithUTF8String:report->pwd];
        _hasTerminated = report->terminated;
        _fd = report->fd;
        assert(_fd >= 0);
        fcntl(_fd, F_SETFL, O_NONBLOCK);
        _tty = [NSString stringWithUTF8String:report->tty] ?: @"";
        _haveWaited = NO;
    }
    return self;
}

- (void)willWaitPreemptively {
    [_thread dispatchRecursiveSync:^(id _Nonnull state) {
        assert(!_haveSentPreemptiveWait);
        _haveSentPreemptiveWait = YES;
        [self didTerminate];
    }];
}

- (void)setTerminationStatus:(int)status {
    [_thread dispatchRecursiveSync:^(id _Nonnull state) {
        assert(_hasTerminated);
        _haveWaited = YES;
        _terminationStatus = status;
    }];
}

- (void)didTerminate {
    [_thread dispatchRecursiveSync:^(id _Nonnull state) {
        _hasTerminated = YES;
    }];
}

- (BOOL)hasTerminated {
    __block BOOL result;
    [_thread dispatchRecursiveSync:^(id _Nonnull state) {
        result = _hasTerminated;
    }];
    return result;
}

- (BOOL)haveWaited {
    __block BOOL result;
    [_thread dispatchRecursiveSync:^(id _Nonnull state) {
        result = _haveWaited;
    }];
    return result;
}

- (BOOL)haveSentPreemptiveWait {
    __block BOOL result;
    [_thread dispatchRecursiveSync:^(id _Nonnull state) {
        result = _haveSentPreemptiveWait;
    }];
    return result;
}

- (int)terminationStatus {
    __block BOOL result;
    [_thread dispatchRecursiveSync:^(id _Nonnull state) {
        result = _terminationStatus;
    }];
    return result;
}

@end
