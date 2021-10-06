//
//  GraphQLCodegen.swift
//  Grapqhl Codegen
//
//  Created by Romy Cheah on 9/9/21.
//

import Foundation
import GraphQLAST
import GraphQLCodegenConfig
import GraphQLCodegenNameSwift

enum GraphQLCodegenSpecSwiftError: Error, LocalizedError {
  case formatError(context: String)

  var errorDescription: String? {
    switch self {
    case let .formatError(context):
      return "\(Self.self): \(context)"
    }
  }
}

public struct GraphQLCodegenSpecSwift {
  private let scalarMap: ScalarMap
  private let selectionMap: SelectionMap?
  private let entityNameMap: EntityNameMap
  private let entityNameProvider: EntityNameProviding

  private let generators: [GraphQLCodeGenerating]

  public init(
    scalarMap: ScalarMap,
    selectionMap: SelectionMap?,
    entityNameMap: EntityNameMap,
    entityNameProvider: EntityNameProviding
  ) throws {
    self.scalarMap = scalarMap
    self.selectionMap = selectionMap
    self.entityNameMap = entityNameMap
    self.entityNameProvider = entityNameProvider

    self.generators = [
      HeaderCodeGenerator(entityNameMap: self.entityNameMap),
      EnumCodeGenerator(
        scalarMap: self.scalarMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      ),
      ObjectCodeGenerator(
        scalarMap: self.scalarMap,
        selectionMap: self.selectionMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      ),
      InputObjectCodeGenerator(
        scalarMap: self.scalarMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      ),
      InterfaceCodeGenerator(
        scalarMap: self.scalarMap,
        selectionMap: self.selectionMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      ),
      UnionCodeGenerator(
        scalarMap: self.scalarMap,
        selectionMap: self.selectionMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      ),
      RequestParameterGenerator(
        scalarMap: self.scalarMap,
        selectionMap: self.selectionMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      ),
      ResponseCodeGenerator(
        entityNameMap: self.entityNameMap,
        entityNameProvider: entityNameProvider
      ),
      SelectionGenerator(
        scalarMap: self.scalarMap,
        selectionMap: self.selectionMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      ),
      SelectionsGenerator(
        scalarMap: self.scalarMap,
        selectionMap: self.selectionMap,
        entityNameMap: self.entityNameMap,
        entityNameProvider: self.entityNameProvider
      )
    ]
  }

  public func code(schema: Schema) throws -> String {
    let code = try generators.map { try $0.code(schema: schema) }.lines

    let formattedCode: String
    do {
      formattedCode = try code.format()
    } catch {
      throw GraphQLCodegenSpecSwiftError
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

  public static var defaultConfigPath: String? {
    return Bundle.module.path(forResource: "default-config", ofType: "json")
  }
}
