//
//  NSObject+Category.m
//  Venus
//
//  Created by houwen.wang on 2016/11/8.
//  Copyright © 2016年 houwen.wang. All rights reserved.
//

#import "NSObject+Category.h"

static NSMutableSet *swizzledClasses() {
    static dispatch_once_t onceToken;
    static NSMutableSet *swizzledClasses = nil;
    dispatch_once(&onceToken, ^{
        swizzledClasses = [[NSMutableSet alloc] init];
    });
    
    return swizzledClasses;
}

static void swizzleDeallocIfNeeded(Class classToSwizzle) {
    @synchronized (swizzledClasses()) {
        NSString *className = NSStringFromClass(classToSwizzle);
        if ([swizzledClasses() containsObject:className]) return;
        
        SEL deallocSelector = sel_registerName("dealloc");
        __block void (*originalDealloc)(__unsafe_unretained id, SEL) = NULL;
        
        id newDealloc = ^(__unsafe_unretained NSObject *self) {
            
            if (self.willDeallocBlock) {
                self.willDeallocBlock(self);
            }
            
            if (originalDealloc == NULL) {
                struct objc_super superInfo = {
                    .receiver = self,
                    .super_class = class_getSuperclass(classToSwizzle)
                };
                
                void (*msgSend)(struct objc_super *, SEL) = (__typeof__(msgSend))objc_msgSendSuper;
                msgSend(&superInfo, deallocSelector);
            } else {
                originalDealloc(self, deallocSelector);
            }
        };
        
        IMP newDeallocIMP = imp_implementationWithBlock(newDealloc);
        
        if (!class_addMethod(classToSwizzle, deallocSelector, newDeallocIMP, "v@:")) {
            Method deallocMethod = class_getInstanceMethod(classToSwizzle, deallocSelector);
            originalDealloc = (__typeof__(originalDealloc))method_getImplementation(deallocMethod);
            originalDealloc = (__typeof__(originalDealloc))method_setImplementation(deallocMethod, newDeallocIMP);
        }
        
        [swizzledClasses() addObject:className];
    }
}

NS_INLINE VSPropertyDataType propertyType(const char *cType) {
    static NSDictionary <NSString *, NSNumber *>*propertyTypeMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        propertyTypeMap = @{@"" : @(VSPropertyDataTypeUnknown),
                            @"B" : @(VSPropertyDataTypeBool),
                            @"c" : @(VSPropertyDataTypeChar),
                            @"C" : @(VSPropertyDataTypeUChar),
                            @"*" : @(VSPropertyDataTypeCharPointer),
                            @"s" : @(VSPropertyDataTypeShort),
                            @"S" : @(VSPropertyDataTypeUShort),
                            @"i" : @(VSPropertyDataTypeInt),
                            @"I" : @(VSPropertyDataTypeUInt),
                            @"f" : @(VSPropertyDataTypeFloat),
                            @"d" : @(VSPropertyDataTypeDouble),
                            @"l" : @(VSPropertyDataTypeLong),
                            @"L" : @(VSPropertyDataTypeULong),
                            @"q" : @(VSPropertyDataTypeLongLong),
                            @"Q" : @(VSPropertyDataTypeULongLong),
                            @"v" : @(VSPropertyDataTypeVoid),
                            @"@" : @(VSPropertyDataTypeId),
                            @"\"" : @(VSPropertyDataTypeObject),
                            @"#" : @(VSPropertyDataTypeClass),
                            @":" : @(VSPropertyDataTypeSEL),
                            @"?" : @(VSPropertyDataTypeIMP),
                            @"}" : @(VSPropertyDataTypeStruct),
                            };
    });
    
    VSPropertyDataType pType = VSPropertyDataTypeUnknown;
    NSString *type = [NSString stringWithUTF8String:cType];
    
    if (type.length) {
        
        NSString *lastKey = [type substringFromIndex:type.length - 1];
        
        if ([propertyTypeMap.allKeys containsObject:lastKey]) {
            pType = propertyTypeMap[lastKey].integerValue;
        }
        
        if (pType == VSPropertyDataTypeVoid && [type hasPrefix:@"^"]) {
            pType = VSPropertyDataTypeVoidPointer;
        } else if (pType == VSPropertyDataTypeStruct && [type hasPrefix:@"^"]) {
            pType = VSPropertyDataTypeStructPointer;
        }
    }
    
    return pType;
}

@implementation NSObject (Category)

- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"\n \"%@\" class hasn't \"%@\" key!!!\n",self.class,key);
    return [NSNull null];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    NSLog(@"\n \"%@\" class hasn't \"%@\" key!!!\n",self.class,key);
}

- (void)setNilValueForKey:(NSString *)key {
}

// 递归遍历superclass
+ (void)recursionSuperclassUsingBlock:(void(NS_NOESCAPE ^)(Class cls , BOOL *stop))block {
    
    if (block) {
        BOOL stop = NO;
        Class cls_t = [self class];
        do {
            block(cls_t, &stop);
            if (stop) break;
            cls_t = class_getSuperclass(cls_t);
        } while (cls_t);
    }
}

- (void (^)(__unsafe_unretained id))willDeallocBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWillDeallocBlock:(void (^)(__unsafe_unretained id))willDeallocBlock {
    if (self.willDeallocBlock != willDeallocBlock) {
        
        swizzleDeallocIfNeeded(self.class);
        
        objc_setAssociatedObject(self, @selector(willDeallocBlock), willDeallocBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

@end

@class VSKeyValueObserver;

typedef void(^KeyValueChangedHandlerBlock)(VSKeyValueObserver *observer, NSString *keyPath ,id object, NSDictionary<NSKeyValueChangeKey,id> *change, void *context);

@interface VSKeyValueObserver : NSObject

@property (nonatomic, weak) id obj;                                           //
@property (nonatomic, strong) NSMutableSet <NSString *>*observerPaths;        //
@property (nonatomic, copy) KeyValueChangedHandlerBlock changedHandlerBlock;  //

@end

@implementation VSKeyValueObserver

+ (instancetype)keyValueObserverWithChangedHandler:(KeyValueChangedHandlerBlock)handler {
    VSKeyValueObserver *observer = [[[VSKeyValueObserver class] alloc] init];
    observer.changedHandlerBlock = handler;
    return observer;
}

- (void)observeValueForObject:(id)obj
                   forKeyPath:(NSString *)keyPath
                      options:(NSKeyValueObservingOptions)options
                      context:(nullable NSString *)context {
    
    if (obj && keyPath && keyPath.length) {
        NSString *path = [NSString stringWithFormat:@"%@:%@", keyPath, context];
        if (![self.observerPaths containsObject:path]) {
            self.obj = obj;
            [self.observerPaths addObject:[NSString stringWithFormat:@"%@:%@", keyPath, context]];
            [obj addObserver:self forKeyPath:keyPath options:options context:(__bridge void * _Nullable)(context)];
        }
    }
}

- (void)removeObserveValueForKeyPath:(NSString *)keyPath
                             context:(nullable NSString *)context {
    
    NSString *path = [NSString stringWithFormat:@"%@:%@", keyPath, context];
    if ([self.observerPaths containsObject:path]) {
        [self.observerPaths removeObject:path];
        [self.obj removeObserver:self forKeyPath:keyPath context:(__bridge void * _Nullable)(context)];
    }
}

- (NSMutableSet<NSString *> *)observerPaths {
    if (_observerPaths == nil) {
        _observerPaths = [NSMutableSet set];
    }
    return _observerPaths;
}

#pragma mark - KVO callback

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (self.changedHandlerBlock) {
        self.changedHandlerBlock(self, keyPath, object, change, context);
    }
}

- (void)dealloc {
    for (NSString *path in self.observerPaths) {
        NSArray <NSString *>*path_t = [path componentsSeparatedByString:@":"];
        [self.obj removeObserver:self forKeyPath:path_t[0] context:(__bridge void * _Nullable)(path_t[1])];
    }
}

@end

const void * _Nonnull VSKeyValueObserversKey = &VSKeyValueObserversKey;

@implementation NSObject (NSKeyValueObserverRegistrationBlock)

- (void)observeValueForKeyPath:(NSString *)keyPath
                       options:(NSKeyValueObservingOptions)options
                       context:(nullable NSString *)context
                   changeBlock:(nonnull KeyValueObserverChangedBlock)block {
    
    @synchronized (self) {
        
        if (keyPath && keyPath.length && block) {
            
            NSMutableDictionary <KeyValueObserverChangedBlock, VSKeyValueObserver *>*observers = objc_getAssociatedObject(self, VSKeyValueObserversKey);
            
            if (observers == nil) {
                observers = [NSMutableDictionary dictionary];
                objc_setAssociatedObject(self, VSKeyValueObserversKey, observers, OBJC_ASSOCIATION_RETAIN);
            }
            
            VSKeyValueObserver *observer = observers[(id)block];
            if (observer == nil) {
                
                observer = [VSKeyValueObserver keyValueObserverWithChangedHandler:^(VSKeyValueObserver *observer_t, NSString *keyPath, id object, NSDictionary<NSKeyValueChangeKey,id> *change, void *context) {
                    
                    NSDictionary <KeyValueObserverChangedBlock, VSKeyValueObserver *>*observers_t = objc_getAssociatedObject(object, VSKeyValueObserversKey);
                    
                    [observers_t enumerateKeysAndObjectsUsingBlock:^(KeyValueObserverChangedBlock _Nonnull key, VSKeyValueObserver * _Nonnull obj, BOOL * _Nonnull stop) {
                        
                        if ([obj isEqual:observer_t]) {
                            key(keyPath, object, change, context);
                            *stop = YES;
                        }
                    }];
                }];
                observers[(id)block] = observer;
            }
            [observer observeValueForObject:self forKeyPath:keyPath options:options context:context];
        }
    }
}

- (void)observeValueForKeyPaths:(NSArray <NSString *>*)keyPaths
                        options:(NSKeyValueObservingOptions)options
                        context:(nullable NSString *)context
                    changeBlock:(nonnull KeyValueObserverChangedBlock)block {
    
    if (block) {
        for (NSString *keyPath in keyPaths) {
            [self observeValueForKeyPath:keyPath options:options context:context changeBlock:block];
        }
    }
}

// block移除监听, 如果block == nil, 所有相同keyPath & 相同context的block将移除监听
- (void)removeObserveValueForBlock:(nullable KeyValueObserverChangedBlock)block
                           keyPath:(NSString *)keyPath
                           context:(nullable NSString *)context {
    
    @synchronized (self) {
        
        NSMutableDictionary <KeyValueObserverChangedBlock, VSKeyValueObserver *>*observers = objc_getAssociatedObject(self, VSKeyValueObserversKey);
        
        if (observers && observers.count) {
            if (block) {
                VSKeyValueObserver *observer = observers[(id)block];
                if (observer) {
                    [observer removeObserveValueForKeyPath:keyPath context:context];
                }
            } else {
                [observers enumerateKeysAndObjectsUsingBlock:^(KeyValueObserverChangedBlock _Nonnull key, VSKeyValueObserver * _Nonnull obj, BOOL * _Nonnull stop) {
                    [obj removeObserveValueForKeyPath:keyPath context:context];
                }];
            }
            
            // remove none keyPath & context observer
            
            __block NSMutableArray <KeyValueObserverChangedBlock>*shouldRemovedObservers = [NSMutableArray array];
            [observers enumerateKeysAndObjectsUsingBlock:^(KeyValueObserverChangedBlock _Nonnull key, VSKeyValueObserver * _Nonnull obj, BOOL * _Nonnull stop) {
                if (obj.observerPaths.count == 0) {
                    [shouldRemovedObservers addObject:key];
                }
            }];
            [observers removeObjectsForKeys:shouldRemovedObservers];
        }
    }
}

@end

@implementation NSObject (KeyValues)

- (NSDictionary<NSString *,id> *)keyValueDictionary {
    __block NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    __weak typeof(self) ws = self;
    [[self class] recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (cls != [NSObject class]) {
            [[cls propertyList] enumerateObjectsUsingBlock:^(VSPropertyInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                
                // 未被忽略
                if (![[self.class ignoredPropertiesForGenerateDictionary] containsObject:obj.name]) {
                    
                    __strong typeof(ws) ss = ws;
                    
                    id value = [ss valueForKey:obj.name];                    
                    value = [self.class convertedValue:value property:obj.name];
                    
                    NSString *replacedKey = [self.class replacedKeyForGenerateDictionary][obj.name];
                    NSString *key = replacedKey ? replacedKey : obj.name;
                    
                    if (value) {
                        dic[key] = value;
                    } else {
                        if ([[[obj.cls alloc] init] isKindOfClass:[NSString class]]) {
                            dic[key] = @"";
                        } else if ([[[obj.cls alloc] init] isKindOfClass:[NSArray class]]) {
                            dic[key] = @[];
                        } else if ([[[obj.cls alloc] init] isKindOfClass:[NSDictionary class]]) {
                            dic[key] = @{};
                        }
                    }
                }
            }];
        }
    }];
    return [dic copy];
}

//  生成字典时，需要重新修改属性名的属性
+ (NSDictionary <NSString *, NSString *>*)replacedKeyForGenerateDictionary {
    return nil;
}

/**
 * 生成字典时, 需要忽略的属性名
 *
 @return 忽略的属性名数组
 */
+ (NSArray <NSString *>*)ignoredPropertiesForGenerateDictionary {
    return nil;
}

/**
 *  自定义转换
 *  @param oldValue 旧值
 *  @param property 属性名
 *  @return 新值
 */
+ (id)convertedValue:(id)oldValue property:(NSString *)property {
    return oldValue;
}

@end

@implementation NSObject (ExchangeMethod)

+ (void)exchangeImplementations:(SEL)selfSEL1 otherMethod:(SEL)selfSEL2 isInstance:(BOOL)isInstance {
    if (!sel_isEqual(selfSEL1, selfSEL2)) {
        Method method1, method2;
        if (isInstance) {
            method1 = class_getInstanceMethod(self, selfSEL1);
            method2 = class_getInstanceMethod(self, selfSEL2);
        } else {
            method1 = class_getClassMethod(self, selfSEL1);
            method2 = class_getClassMethod(self, selfSEL2);
        }
        [self exchangeImplementations:method1 otherMethod:method2];
    }
}

+ (void)exchangeImplementations:(Method)method otherMethod:(Method)otherMethod {
    method_exchangeImplementations(method, otherMethod);
}

@end

@implementation NSObject (ClassInfo)

#pragma mark - class

+ (NSArray <VSClassInfo *>*)registeredClassList {
    unsigned int count = 0;
    Class *list = objc_copyClassList(&count);
    NSMutableArray <VSClassInfo *>*infos = [NSMutableArray array];
    for (int i=0; i<count; i++) {
        Class s = list[i];
        [infos addObject:[self classInfoWithClass:s]];
    }
    free(list);
    return [infos copy];
}

+ (NSArray <NSString *>*)registeredClassNameList {
    __block NSMutableArray <NSString *>*list = [NSMutableArray array];
    [[self registeredClassList] enumerateObjectsUsingBlock:^(VSClassInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [list addObject:obj.name];
    }];
    return [list copy];
}

#pragma mark - protocol

+ (NSArray <VSProtocolInfo *>*)protocolList {
    unsigned int count = 0;
    Protocol * __unsafe_unretained _Nonnull * _Nullable list = class_copyProtocolList(self, &count);
    NSMutableArray <VSProtocolInfo *>*result = [NSMutableArray array];
    for (int i=0; i<count; i++) {
        Protocol *p = list[i];
        [result addObject:[self protocolInfoWithProtocol:p]];
    }
    free(list);
    return [result copy];
}

+ (NSArray <VSProtocolInfo *>*)allProtocolListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <VSProtocolInfo *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls protocolList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

+ (NSArray <NSString *>*)protocolNameList {
    __block NSMutableArray <NSString *>*list = [NSMutableArray array];
    [[self protocolList] enumerateObjectsUsingBlock:^(VSProtocolInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [list addObject:obj.name];
    }];
    return [list copy];
}

+ (NSArray <NSString *>*)allProtocolNameListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <NSString *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls protocolNameList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

#pragma mark - property

+ (NSArray <VSPropertyInfo *>*)propertyList {
    unsigned int count = 0;
    objc_property_t *list = class_copyPropertyList(self, &count);
    NSMutableArray <VSPropertyInfo *>*result = [NSMutableArray array];
    for (int i=0; i<count; i++) {
        objc_property_t p = list[i];
        [result addObject:[self propertyInfoWithProperty:p]];
    }
    free(list);
    return [result copy];
}

+ (NSArray <VSPropertyInfo *>*)allPropertyListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <VSPropertyInfo *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls propertyList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

+ (NSArray <NSString *>*)propertyNameList {
    __block NSMutableArray <NSString *>*list = [NSMutableArray array];
    [[self propertyList] enumerateObjectsUsingBlock:^(VSPropertyInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [list addObject:obj.name];
    }];
    return [list copy];
}

+ (NSArray <NSString *>*)allPropertyNameListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <NSString *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls propertyNameList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

#pragma mark - ivar

+ (NSArray <VSIvarInfo *>*)ivarList {
    unsigned int count = 0;
    Ivar *list = class_copyIvarList(self, &count);
    NSMutableArray <VSIvarInfo *>*result = [NSMutableArray array];
    for (int i=0; i<count; i++) {
        Ivar v = list[i];
        [result addObject:[self ivarInfoWithIvar:v]];
    }
    free(list);
    return [result copy];
}

+ (NSArray <VSIvarInfo *>*)allIvarListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <VSIvarInfo *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls ivarList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

+ (NSArray <NSString *>*)ivarNameList {
    __block NSMutableArray <NSString *>*list = [NSMutableArray array];
    [[self ivarList] enumerateObjectsUsingBlock:^(VSIvarInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [list addObject:obj.name];
    }];
    return [list copy];
}

+ (NSArray <NSString *>*)allIvarListNameEndOfClass:(Class)endOfClass {
    __block NSMutableArray <NSString *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls ivarNameList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

#pragma mark - method

+ (NSArray <VSMethodInfo *>*)instanceMethodList {
    return [self methodList:self];
}

+ (NSArray <VSMethodInfo *>*)allInstanceMethodListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <VSMethodInfo *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls instanceMethodList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

+ (NSArray <NSString *>*)instanceMethodNameList {
    return [self methodNameList:[self instanceMethodList]];
}

+ (NSArray <NSString *>*)allInstanceMethodNameListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <NSString *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls instanceMethodNameList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

+ (NSArray <VSMethodInfo *>*)classMethodList {
    return [self methodList:object_getClass(self)];
}

+ (NSArray <VSMethodInfo *>*)allClassMethodListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <VSMethodInfo *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls classMethodList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

+ (NSArray <NSString *>*)classMethodNameList {
    return [self methodNameList:[self classMethodList]];
}

+ (NSArray <NSString *>*)allClassMethodNameListEndOfClass:(Class)endOfClass {
    __block NSMutableArray <NSString *>*result = [NSMutableArray array];
    [self recursionSuperclassUsingBlock:^(__unsafe_unretained Class cls, BOOL *stop) {
        if (![cls isEqual:endOfClass]) {
            [result addObjectsFromArray:[cls classMethodNameList]];
        } else {
            *stop = YES;
        }
    }];
    return [result copy];
}

#pragma mark -

+ (NSArray <VSMethodInfo *>*)methodList:(Class)cls {
    unsigned int count = 0;
    Method *list = class_copyMethodList(cls, &count);
    NSMutableArray <VSMethodInfo *>*result = [NSMutableArray array];
    for (int i=0; i<count; i++) {
        Method m = list[i];
        [result addObject:[self methodInfoWithMethod:m]];
    }
    free(list);
    return [result copy];
}

+ (NSArray <NSString *>*)methodNameList:(NSArray <VSMethodInfo *>*)methodList {
    __block NSMutableArray <NSString *>*list = [NSMutableArray array];
    [methodList enumerateObjectsUsingBlock:^(VSMethodInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [list addObject:obj.name];
    }];
    return [list copy];
}

#pragma mark - private methods

+ (VSClassInfo *)classInfoWithClass:(Class)cls {
    if (cls != NULL) {
        VSClassInfo *classInfo  = [[VSClassInfo alloc] init];
        
        classInfo.name          = [NSString stringWithUTF8String:class_getName(cls)];
        classInfo.isMetaClass   = class_isMetaClass(cls);
        classInfo.superCls      = class_getSuperclass(cls);
        classInfo.version       = class_getVersion(cls);
        classInfo.instanceSize  = class_getInstanceSize(cls);
        
        classInfo.ivarList      = [cls ivarList];
        classInfo.propertyList  = [cls propertyList];
        classInfo.protocolList  = [cls protocolList];
        
        classInfo.classMethodList    = [cls classMethodList];
        classInfo.instanceMethodList = [cls instanceMethodList];
        
        return classInfo;
    }
    return nil;
}

+ (VSProtocolInfo *)protocolInfoWithProtocol:(Protocol *)protocol {
    if (protocol != NULL) {
        VSProtocolInfo *info = [[VSProtocolInfo alloc] init];
        info.name = [NSString stringWithUTF8String:protocol_getName(protocol)];
        return info;
    }
    return nil;
}

+ (VSPropertyAttributeInfo *)propertyAttributeInfoWithPropertyAttribute:(objc_property_attribute_t)att {
    VSPropertyAttributeInfo *info = [[VSPropertyAttributeInfo alloc] init];
    info.name = [NSString stringWithUTF8String:att.name];
    info.value = [NSString stringWithUTF8String:att.value];
    return info;
}

+ (VSPropertyInfo *)propertyInfoWithProperty:(objc_property_t)property {
    if (property != NULL) {
        
        __block VSPropertyInfo *info = [[VSPropertyInfo alloc] init];
        info.dataType                = VSPropertyDataTypeUnknown;
        info.refType                 = VSPropertyRefTypeAssign;
        
        /* name */
        info.name = [NSString stringWithUTF8String:property_getName(property)];
        info.getterMethod = [info.name copy];
        info.setterMethod = [info.name copy];
        
        info.attributes = [NSString stringWithUTF8String:property_getAttributes(property)];
        
        unsigned int count;
        objc_property_attribute_t *attList = property_copyAttributeList(property, &count);
        NSMutableArray *attInfoList = [NSMutableArray array];
        for (int i=0; i<count; i++) {
            objc_property_attribute_t att = attList[i];
            [attInfoList addObject:[self propertyAttributeInfoWithPropertyAttribute:att]];
        }
        info.attributeList = [attInfoList copy];
        
        [info.attributeList enumerateObjectsUsingBlock:^(VSPropertyAttributeInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            /* type */
            if ([obj.name isEqualToString:@"T"]) {
                
                info.dataType = propertyType(obj.value.UTF8String);
                
                if (info.dataType == VSPropertyDataTypeObject) {
                    info.cls = NSClassFromString([[obj.value substringToIndex:obj.value.length - 1] substringFromIndex:2]);
                } else if (info.dataType != VSPropertyDataTypeClass &&
                           info.dataType != VSPropertyDataTypeSEL &&
                           info.dataType != VSPropertyDataTypeIMP ) {
                    info.isBasicPointer = ([obj.value hasPrefix:@"^"] || [obj.value hasPrefix:@"*"]);
                }
            }
            /* refType */
            else if ([obj.name isEqualToString:@"&"]) {
                info.refType = VSPropertyRefTypeStrong;
            } else if ([obj.name isEqualToString:@"C"]) {
                info.refType = VSPropertyRefTypeCopy;
            } else if ([obj.name isEqualToString:@"W"]) {
                info.refType = VSPropertyRefTypeWeak;
            }
            /* other */
            else if ([obj.name isEqualToString:@"R"]) {
                info.readonly = YES;
            } else if ([obj.name isEqualToString:@"N"]) {
                info.isNonatomic = YES;
            } else if ([obj.name isEqualToString:@"V"]) {
                info.ivarName = obj.value;
            } else if ([obj.name isEqualToString:@"G"]) {
                info.getterMethod = obj.value;
            } else if ([obj.name isEqualToString:@"S"]) {
                info.setterMethod = obj.value;
            }
        }];
        
        return info;
    }
    return nil;
}

+ (VSMethodInfo *)methodInfoWithMethod:(Method)method {
    if (method != NULL) {
        VSMethodInfo *info = [[VSMethodInfo alloc] init];
        info.name = NSStringFromSelector(method_getName(method));
        info.returnType = [NSString stringWithUTF8String:method_copyReturnType(method)];
        info.numberOfArguments = method_getNumberOfArguments(method);
        info.typeEncoding = [NSString stringWithUTF8String:method_getTypeEncoding(method)];
        info.implementation = method_getImplementation(method);
        
        NSMutableArray *types = [NSMutableArray array];
        for (int i=0; i<info.numberOfArguments; i++) {
            NSString *type = [NSString stringWithUTF8String:method_copyArgumentType(method, i)];
            [types addObject:type];
        }
        info.argumentTypes = types;
        return info;
    }
    return nil;
}

+ (VSIvarInfo *)ivarInfoWithIvar:(Ivar)ivar {
    if (ivar != NULL) {
        VSIvarInfo *info = [[VSIvarInfo alloc] init];
        info.name = [NSString stringWithUTF8String:ivar_getName(ivar)];
        info.typeEncoding = [NSString stringWithUTF8String:ivar_getTypeEncoding(ivar)];
        return info;
    }
    return nil;
}

@end

@implementation VSClassInfo

- (NSString *)description {
    return self.keyValueDictionary.description;
}

@end

@implementation VSProtocolInfo

- (NSString *)description {
    return self.keyValueDictionary.description;
}

@end

@implementation VSPropertyAttributeInfo

- (NSString *)description {
    return self.keyValueDictionary.description;
}

@end

@implementation VSPropertyInfo

- (NSString *)description {
    return self.keyValueDictionary.description;
}

@end

@implementation VSIvarInfo

- (NSString *)description {
    return self.keyValueDictionary.description;
}

@end

@implementation VSMethodInfo

- (NSString *)description {
    return self.keyValueDictionary.description;
}

@end
