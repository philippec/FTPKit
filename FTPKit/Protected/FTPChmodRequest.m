#import "FTPKit.h"
#import "FTPChmodRequest.h"
#import "NSError+Additions.h"
#import "FTPKit+Protected.h"

@implementation FTPChmodRequest

@synthesize mode;

- (void)start
{
    if (mode < 0 || mode > 777)
    {
        // Put this an NSError+Additions
        // [NSError FTPKitErrorWithString:code:]
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"File mode value must be between 0 and 0777.", @"")
                                                             forKey:NSLocalizedDescriptionKey];
        NSError *error = [[NSError alloc] initWithDomain:FTPErrorDomain code:0 userInfo:userInfo];
        [self didFailWithError:error];
        return;
    }
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(queue, ^{
        const char *host = [self.credentials.host cStringUsingEncoding:NSUTF8StringEncoding];
        const char *login = [self.credentials.username cStringUsingEncoding:NSUTF8StringEncoding];
        const char *password = [self.credentials.password cStringUsingEncoding:NSUTF8StringEncoding];
        if (ftp_open(host, login, password))
        {
            [self didFailWithError:[NSError FTPKitErrorWithCode:425]];
            return;
        }
        NSString *command = [NSString stringWithFormat:@"SITE CHMOD %i %@", mode, self.handle.path];
        FKLogDebug(@"command: %@", command);
        const char *cmd = [command cStringUsingEncoding:NSUTF8StringEncoding];
        char buffer[256];
        int ret = ftp_sendcommand(cmd, buffer, 256);
        NSString *response = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
        FKLogDebug(@"response: %d %@", ret, response);
        ftp_close();
        if (ret)
        {
            [self didFailWithError:[NSError FTPKitErrorWithCode:550]];
            return;
        }
        FKLogDebug(@"Permissions changed on %@ to %i", self.handle.path, mode);
        [self didUpdateStatus:NSLocalizedString(@"CHMOD Done", @"")];
        if ([self.delegate respondsToSelector:@selector(request:didChmodPath:)])
        {
            [self.delegate request:self didChmodPath:self.handle.path];
        }
    });
}

@end
