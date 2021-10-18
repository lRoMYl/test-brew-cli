//
//  File.swift
//
//
//  Created by Romy Cheah on 20/9/21.
//

import Foundation
import GraphQLAST
import GraphQLCodegenConfig
import GraphQLCodegenNameSwift

enum SelectionsOperationDefinitionError: Error, LocalizedError {
  case missingFragment(context: String)

  var errorDescription: String? {
    switch self {
    default:
      return "\(Self.self).\(self)"
    }
  }
}

struct SelectionsOperationDefinitionGenerator {
  private let variablesGenerator: RequestVariablesGenerator
  private let entityNameProvider: EntityNameProviding

  init(variablesGenerator: RequestVariablesGenerator, entityNameProvider: EntityNameProviding) {
    self.variablesGenerator = variablesGenerator
    self.entityNameProvider = entityNameProvider
  }

  func declaration(operation: GraphQLAST.Operation, field: Field) throws -> String {
    let operationName = operation.type.name.lowercased()
    let selection: String

    if field.isFragment {
      guard let fragmentName = try entityNameProvider.fragmentName(for: field.type.namedType) else {
        throw SelectionsOperationDefinitionError.missingFragment(
          context: "Expecting fragment name from \(field.type.namedType.name)"
        )
      }

      selection = " {\n     ...\(fragmentName)\n}"
    } else {
      selection = ""
    }

    let operationVariables = variablesGenerator.operationVariablesDeclaration(with: field)
    let operationVariablesDeclaration = operationVariables.isEmpty
      ? ""
      : "(\n\(operationVariables)\n)"

    let operationArguments = variablesGenerator.operationArgumentsDeclaration(with: field)
      .joined(separator: "\n    ")
    let operationArgumentsDeclaration = operationArguments.isEmpty
      ? ""
      : "(\n    \(operationArguments)\n)"

    return try """
    // MARK: - Operation Definition

    func operationDefinition() -> String {
      return \"\"\"
      \("\(field.name)\(operationArgumentsDeclaration)\(selection)")
      \"\"\"
    }
    """.format()
  }
}

// MARK: - Field

private extension Field {
  var isFragment: Bool {
    switch type.namedType {
    case .enum, .scalar:
      return false
    case .object:
      return true
    case .interface:
      return true
    case .union:
      return true
    }
  }
}
