//
//  NSObject+Category.h
//  Venus
//
//  Created by houwen.wang on 2016/11/8.
//  Copyright © 2016年 houwen.wang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>

// perform block
#define performBlock(b, ...) if (b) { b(__VA_ARGS__); }

// perform block
#define performReturnValueBlock(b, nilReturnValue, ...) if (b) { return b(__VA_ARGS__); } else { return nilReturnValue; }

//  属性引用类型
typedef NS_ENUM(NSInteger, VSPropertyRefType) {
    VSPropertyRefTypeAssign,    // assign
    VSPropertyRefTypeWeak,      // weak
    VSPropertyRefTypeStrong,    // strong / retain
    VSPropertyRefTypeCopy,      // copy
};

// 属性数据类型
typedef NS_ENUM(NSInteger, VSPropertyDataType) {
    /* unknown */
    VSPropertyDataTypeUnknown,
    /* basic data type */
    VSPropertyDataTypeBool,         // BOOL
    VSPropertyDataTypeChar,         // char
    VSPropertyDataTypeUChar,        // unsigned char
    VSPropertyDataTypeCharPointer,  // char * / unsigned char *
    VSPropertyDataTypeShort,        // short
    VSPropertyDataTypeUShort,       // unsigned short
    VSPropertyDataTypeInt,          // int
    VSPropertyDataTypeUInt,         // unsigned int
    VSPropertyDataTypeFloat,        // float
    VSPropertyDataTypeDouble,       // double
    VSPropertyDataTypeLong,         // long / NSInteger
    VSPropertyDataTypeULong,        // unsigned long / NSUInteger
    VSPropertyDataTypeLongLong,     // long long
    VSPropertyDataTypeULongLong,    // unsigned long long
    VSPropertyDataTypeStruct,       // struct
    VSPropertyDataTypeStructPointer,// struct *
    /* other data type */
    VSPropertyDataTypeVoid,         // void
    VSPropertyDataTypeVoidPointer,  // void *
    VSPropertyDataTypeId,           // id
    VSPropertyDataTypeObject,       // NSObject or subclass
    VSPropertyDataTypeClass,        // Class
    VSPropertyDataTypeSEL,          // SEL
    VSPropertyDataTypeIMP,          // IMP
};

NS_ASSUME_NONNULL_BEGIN

@class VSClassInfo, VSProtocolInfo, VSMethodInfo, VSPropertyInfo, VSIvarInfo;

@interface NSObject (Category)

@property (nonatomic, copy) void (^willDeallocBlock)(__unsafe_unretained id obj);    // 对象将被释放

@end

typedef void(^KeyValueObserverChangedBlock)(NSString *keyPath, id object, NSDictionary<NSKeyValueChangeKey,id> *change, void * _Nullable context);

@interface NSObject (NSKeyValueObserverRegistrationBlock)

// 监听属性变化
- (void)observeValueForKeyPath:(NSString *)keyPath
                       options:(NSKeyValueObservingOptions)options
                       context:(nullable NSString *)context
                   changeBlock:(nonnull KeyValueObserverChangedBlock)block;

// 监听一组属性变化
- (void)observeValueForKeyPaths:(NSArray <NSString *>*)keyPaths
                        options:(NSKeyValueObservingOptions)options
                        context:(nullable NSString *)context
                    changeBlock:(nonnull KeyValueObserverChangedBlock)block;

// block移除监听, 如果block == nil, 所有相同keyPath & 相同context的block将移除监听
- (void)removeObserveValueForBlock:(nullable KeyValueObserverChangedBlock)block
                           keyPath:(NSString *)keyPath
                           context:(nullable NSString *)context;

@end

@interface NSObject (KeyValues)

// key:属性名, value:属性值
@property (nonatomic, assign, readonly) NSDictionary <NSString *, id>*keyValueDictionary;

/**
 * 生成字典时, 需要重新修改属性名的属性
 *
 @return key:原始属性名 value:新属性名
 */
+ (NSDictionary <NSString *, NSString *>*)replacedKeyForGenerateDictionary;

/**
 * 生成字典时, 需要忽略的属性名
 *
 @return 忽略的属性名数组
 */
+ (NSArray <NSString *>*)ignoredPropertiesForGenerateDictionary;

/**
 *  自定义转换
 *  @param oldValue 旧值
 *  @param property 属性名
 *  @return 新值
 */
+ (id)convertedValue:(id)oldValue property:(NSString *)property;

@end

@interface NSObject (ExchangeMethod)

+ (void)exchangeImplementations:(SEL)selfSEL1 otherMethod:(SEL)selfSEL2 isInstance:(BOOL)isInstance;
+ (void)exchangeImplementations:(Method)method otherMethod:(Method)otherMethod;

@end

@interface NSObject (ClassInfo)

// 已注册的类列表
+ (NSArray <VSClassInfo *>*)registeredClassList;
+ (NSArray <NSString *>*)registeredClassNameList;

// 协议列表
+ (NSArray <VSProtocolInfo *>*)protocolList;
+ (NSArray <VSProtocolInfo *>*)allProtocolListEndOfClass:(Class)endOfClass;
+ (NSArray <NSString *>*)protocolNameList;
+ (NSArray <NSString *>*)allProtocolNameListEndOfClass:(Class)endOfClass;

// 属性列表
+ (NSArray <VSPropertyInfo *>*)propertyList;
+ (NSArray <VSPropertyInfo *>*)allPropertyListEndOfClass:(Class)endOfClass;
+ (NSArray <NSString *>*)propertyNameList;
+ (NSArray <NSString *>*)allPropertyNameListEndOfClass:(Class)endOfClass;

// 成员变量列表
+ (NSArray <VSIvarInfo *>*)ivarList;
+ (NSArray <VSIvarInfo *>*)allIvarListEndOfClass:(Class)endOfClass;
+ (NSArray <NSString *>*)ivarNameList;
+ (NSArray <NSString *>*)allIvarListNameEndOfClass:(Class)endOfClass;

// 实例方法列表
+ (NSArray <VSMethodInfo *>*)instanceMethodList;
+ (NSArray <VSMethodInfo *>*)allInstanceMethodListEndOfClass:(Class)endOfClass;
+ (NSArray <NSString *>*)instanceMethodNameList;
+ (NSArray <NSString *>*)allInstanceMethodNameListEndOfClass:(Class)endOfClass;

// 类方法列表
+ (NSArray <VSMethodInfo *>*)classMethodList;
+ (NSArray <VSMethodInfo *>*)allClassMethodListEndOfClass:(Class)endOfClass;
+ (NSArray <NSString *>*)classMethodNameList;
+ (NSArray <NSString *>*)allClassMethodNameListEndOfClass:(Class)endOfClass;

@end

@interface VSClassInfo : NSObject

@property (nonatomic, copy) NSString *name;         //
@property (nonatomic, assign) BOOL isMetaClass;     //
@property (nonatomic, assign) int version;          //
@property (nonatomic, strong) Class superCls;       // super class
@property (nonatomic, assign) size_t instanceSize;  //

@property (nonatomic, copy) NSArray <VSMethodInfo *>*instanceMethodList;  //
@property (nonatomic, copy) NSArray <VSMethodInfo *>*classMethodList;     //
@property (nonatomic, copy) NSArray <VSProtocolInfo *>*protocolList;      //
@property (nonatomic, copy) NSArray <VSPropertyInfo *>*propertyList;      //
@property (nonatomic, copy) NSArray <VSIvarInfo *>*ivarList;              //

@end

@interface VSProtocolInfo : NSObject
@property (nonatomic, copy) NSString *name;    //
@end

@interface VSPropertyAttributeInfo :NSObject
@property (nonatomic, copy) NSString *name;    //
@property (nonatomic, copy) NSString *value;   //
@end

@interface VSPropertyInfo : NSObject
@property (nonatomic, copy) NSString *name;                         //
@property (nonatomic, copy) NSString *getterMethod;                 // getter
@property (nonatomic, copy) NSString *setterMethod;                 // setter
@property (nonatomic, copy) NSString *ivarName;                     // 对应的实例变量名字
@property (nonatomic, assign) VSPropertyDataType dataType;          // 数据类型
@property (nonatomic, assign) VSPropertyRefType refType;            // 引用类型

@property (nonatomic, assign) BOOL isNonatomic;                     // 原子属性
@property (nonatomic, assign, getter=isReadonly) BOOL readonly;     // 是否只读

@property (nonatomic, assign) Class cls;                            // 如果是对象有值
@property (nonatomic, assign) BOOL isBasicPointer;                  // 是否是基础数据类型指针 (char * 、BOOL * 、int * 、struct * ...)

@property (nonatomic, copy) NSString *attributes;                   //
@property (nonatomic, copy) NSArray  <VSPropertyAttributeInfo *>*attributeList;    //
@end

@interface VSIvarInfo : NSObject
@property (nonatomic, copy) NSString *name;            //
@property (nonatomic, copy) NSString *typeEncoding;    //
@end

@interface VSMethodInfo : NSObject
@property (nonatomic, copy) NSString *name;                         //
@property (nonatomic, copy) NSString *typeEncoding;                 //
@property (nonatomic, copy) NSString *returnType;                   //
@property (nonatomic, assign) unsigned int numberOfArguments;       //
@property (nonatomic, copy) NSArray <NSString *>*argumentTypes;     //
@property (nonatomic, assign) IMP implementation ;                  //
@end

NS_ASSUME_NONNULL_END

