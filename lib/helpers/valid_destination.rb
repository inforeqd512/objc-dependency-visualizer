# noinspection RubyLiteralArrayInspection
class SwiftPrimitives
  @@primitive_swift_types =
    Set.new([
      'alignofValue',
      'anyGenerator',
      'anyGenerator',
      'AnyValue',
      'assert',
      'assertionFailure',
      'autoclosure',
      'Class',
      'debugPrint',
      'debugPrint',
      'dump',
      'escaping',
      'fatalError',
      'getVaList',
      'isUniquelyReferenced',
      'isUniquelyReferencedNonObjC',
      'isUniquelyReferencedNonObjC',
      'max',
      'max',
      'min',
      'abs',
      'alignof',
      'min',
      'numericCast',
      'numericCast',
      'numericCast',
      'numericCast',
      'precondition',
      'preconditionFailure',
      'print',
      'print',
      'readLine',
      'sizeof',
      'sizeofValue',
      'strideof',
      'strideofValue',
      'swap',
      'throws',
      'transcode',
      'unsafeAddressOf',
      'unsafeBitCast',
      'unsafeDowncast',
      'unsafeUnwrap',
      'where',
      'withExtendedLifetime',
      'withExtendedLifetime',
      'withUnsafeMutablePointer',
      'withUnsafeMutablePointers',
      'withUnsafeMutablePointers',
      'withUnsafePointer',
      'withUnsafePointers',
      'withUnsafePointers',
      'withVaList',
      'withVaList',
      'zip',
      'Any',
      'AnyClass',
      'BooleanLiteralType',
      'CBool',
      'CChar',
      'CChar16',
      'CChar32',
      'CDouble',
      'CFloat',
      'CInt',
      'class',
      'CLong',
      'CLongLong',
      'Codable',
      'CShort',
      'CSignedChar',
      'CUnsignedChar',
      'CUnsignedInt',
      'CUnsignedLong',
      'CUnsignedLongLong',
      'CUnsignedShort',
      'CWideChar',
      'Decodable',
      'Encodable',
      'ExtendedGraphemeClusterType',
      'Float32',
      'Float64',
      'FloatLiteralType',
      'Int',
      'IntMax',
      'IntegerLiteralType',
      'StringLiteralType',
      'UIntMax',
      'UnicodeScalarType',
      'Void',
      'Any',
      'AnyHashable',
      'AnyObject',
      'AnyBidirectionalCollection',
      'AnyBidirectionalIndex',
      'AnyForwardCollection',
      'AnyForwardIndex',
      'AnyRandomAccessCollection',
      'AnyRandomAccessIndex',
      'AnySequence',
      'Array',
      'ArraySlice',
      'Array.Index',
      'AutoreleasingUnsafeMutablePointer',
      'Bool',
      'CodingKey',
      'CodingKeys',
      'COpaquePointer',
      'CVaListPointer',
      'Character',
      'ClosedInterval',
      'CollectionOfOne',
      'ContiguousArray',
      'Data',
      'Date',
      'Decimal',
      'Dictionary',
      'DictionaryGenerator',
      'DictionaryIndex',
      'DictionaryLiteral',
      'DispatchQueue',
      'DispatchQueue.main',
      'Double',
      'EmptyGenerator',
      'EnumerateGenerator',
      'EnumerateSequence',
      'Equatable',
      'Error',
      'FlattenBidirectionalCollection',
      'FlattenBidirectionalCollectionIndex',
      'FlattenCollectionIndex',
      'FlattenSequence',
      'Float',
      'GeneratorSequence',
      'HalfOpenInterval',
      'Hashable',
      'IndexingGenerator',
      'IndexingIterator',
      'Int',
      'Int1',
      'Int16',
      'Int32',
      'Int64',
      'Int8',
      'JoinGenerator',
      'JoinSequence',
      'JSONDecoder',
      'JSONEncoder',
      'Key',
      'Keys',
      'LazyCollection',
      'LazyFilterCollection',
      'LazyFilterGenerator',
      'LazyFilterIndex',
      'LazyFilterSequence',
      'LazyMapCollection',
      'LazyMapGenerator',
      'LazyMapSequence',
      'LazySequence',
      'Level',
      'Locale',
      'ManagedBufferPointer',
      'Mirror',
      'MutableSlice',
      'Never',
      'ObjectIdentifier',
      'Optional',
      'OSStatus',
      'PermutationGenerator',
      'Range',
      'RangeGenerator',
      'RawByte',
      'RawRepresentable',
      'Repeat',
      'ReverseCollection',
      'ReverseIndex',
      'ReverseRandomAccessCollection',
      'ReverseRandomAccessIndex',
      'Self',
      'SecItemCopyMatching',
      'SecItemDelete',
      'SecItemAdd',
      'SecItemUpdate',
      'Set',
      'SetGenerator',
      'SetIndex',
      'Slice',
      'StaticString',
      'StrideThrough',
      'StrideThroughGenerator',
      'StrideTo',
      'StrideToGenerator',
      'String',
      'String.CharacterView',
      'String.CharacterView.Index',
      'String.UTF16View',
      'String.UTF16View.Index',
      'String.UTF8View',
      'String.UTF8View.Index',
      'String.UnicodeScalarView',
      'String.UnicodeScalarView.Generator',
      'String.UnicodeScalarView.Index',
      'Swift',
      'Error',
      'TernaryPrecedence',
      'AssignmentPrecedence',
      'CastingPrecedence',
      'Type',
      'UInt',
      'UInt16',
      'UInt32',
      'UInt64',
      'UInt8',
      'UTF16',
      'UTF32',
      'UTF8',
      'URL',
      'URLComponents',
      'URLQueryItem',
      'UnicodeScalar',
      'Unmanaged',
      'UnsafeBufferPointer',
      'UnsafeBufferPointerGenerator',
      'UnsafeMutableBufferPointer',
      'UnsafeMutablePointer',
      'UnsafePointer',
      'UnsafeMutableRawPointer',
      'URLSessionConfiguration',
      'URLWithString',
      'UserDefaults',
      'View',
      'Zip2Generator',
      'Zip2Sequence',
#Operators      
      '&&',
      '!',
      '!=',
      '||',
      '/',
      '*',
      '==',
      '===',
      '?',
      '??',
      '>=',
      '<=',
      '~=',
      '%',
      '<',
      '<',
      '-',
      '+',
      '-=',
      '+=',
      '..<',
      '>',
      '<',
      '/=',
#Globals   
      'floor',
      'sqrt',
      'abs',
      'fabs',
#Foundation
      'Bundle',
      'CharacterSet',
      'Comparable',
      'FileManager',
      'Foundation',
      'HTTPURLResponse',
      'IndexPath',         
      'IndexSet',
      'JSONSerialization',
      'Notification',
      'NotificationCenter',
      'Operation',
      'OperationQueue',
      'TimeInterval',
      'Timer',
      'URLRequest',
      'URLCache',
#objc types
      'id',
      'objc_class',
      'BOOL',
      'ObjCBool',
      'bool',
      'Log',
      'struct',
      'Nonnull',
      'NSStringFromClass',
      'Nullable',
      'UTF8String',
#Project
      'ImplicitlyUnwrappedOptional',
      'NibProviding',
      'OSLog',
      'ANZDebugEnvironmentConfiguration',
      'IPAddress',
      'ObjectFromDictionaryWithClass',
      'SuppressPerformSelectorLeakWarning',
      'SCNetworkReachabilityRef',
      'FromBundle',
      'CrashReporting',
      'ConvertEvent',
      'HTTPConfig',
      'DynamicTypeSupport',
      'Grow',
      'AppID',
      'Decoder',
      'Encoder',
      'Constants',
      'MockServiceProvider',
      'OKAction',
      'Load',
      'More',
      'Transactions',
      'This',
      'The'

    ]).freeze

  def self.primitive_types
    @@primitive_swift_types
  end

end

def is_primitive_swift_type?(dest)
  SwiftPrimitives.primitive_types.include?(dest)
end

def is_filtered_swift_type?(dest)
  /(ClusterType|ScalarType|LiteralType|\.Type)$/.match(dest) != nil || /^Builtin\./.match(dest) != nil
end

def is_filtered_objc_type?(dest)
  /^(dispatch_)|(DISPATCH_)/.match(dest) != nil #or /^([a-z])/.match(dest) != nil
end

def is_valid_dest?(dest, exclusion_prefixes)
  return true if dest.include?("URLSession") #to be able to see graph of how Networking code is implemented through app
  return true if dest.include?("URLConnection")
  return true if dest.include?("CAR") #include CARAccounts etc even if CA is the exclusion prefix
  return false if dest.nil?
  return false if dest.start_with?("_") #ignore __block_literal, _main, 
  return false unless /^(#{exclusion_prefixes})/.match(dest).nil?
  return false if is_primitive_swift_type?(dest)
  return false if is_filtered_swift_type?(dest)
  return false if is_filtered_objc_type?(dest)
  true
end


