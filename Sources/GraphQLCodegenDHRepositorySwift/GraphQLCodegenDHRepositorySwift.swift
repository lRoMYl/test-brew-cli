//
//  File.swift
//  
//
//  Created by Romy Cheah on 24/9/21.
//

import Foundation
import GraphQLAST
import GraphQLCodegenConfig
import SwiftFormat

enum GraphQLCodegenDHRepositorySwiftError: Error, LocalizedError {
  case formatError(context: String)

  var errorDescription: String? {
    switch self {
    case let .formatError(context):
      return "\(Self.self).formatError: \(context)"
    }
  }
}

public struct GraphQLCodegenDHRepositorySwift {
  private let namespace: String
  private let entityNameMap: EntityNameMap

  /// Generators
  private let generators: [Generating]

  public init(namespace: String?, entityNameMap: EntityNameMap?) throws {
    self.namespace = namespace ?? ""
    self.entityNameMap = entityNameMap ?? .default

    self.generators = [
      HeaderGenerator(),
      RepositoryGenerator(namespace: self.namespace, entityNameMap: self.entityNameMap),
      ResourceParametersGenerator(namespace: self.namespace, entityNameMap: self.entityNameMap),
      GraphQLResponseWrappedValueGenerator(namespace: self.namespace, entityNameMap: self.entityNameMap)
    ]
  }

  public func code(schema: Schema) throws -> String {
    let code = try generators.map { try $0.code(schema: schema) }.lines

    let formattedCode: String

    do {
      formattedCode = try code.format()
    } catch {
      throw GraphQLCodegenDHRepositorySwiftError
        .formatError(
          context: """
            \(error)
            Raw text:
            \(code)
            """
        )
    }

    return formattedCode
  }
}