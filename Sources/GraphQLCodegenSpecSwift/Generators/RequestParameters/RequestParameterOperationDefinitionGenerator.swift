//
//  File.swift
//  
//
//  Created by Romy Cheah on 20/9/21.
//

import Foundation
import GraphQLAST
import GraphQLCodegenConfig

struct RequestParameterOperationDefinitionGenerator {
  private let scalarMap: ScalarMap
  private let variablesGenerator: RequestParameterVariablesGenerator

  init(scalarMap: ScalarMap, variablesGenerator: RequestParameterVariablesGenerator) {
    self.scalarMap = scalarMap
    self.variablesGenerator = variablesGenerator
  }

  func declaration(operation: GraphQLAST.Operation, field: Field) throws -> String {
    let operationName = operation.type.name.lowercased()
    let selection = field.isFragment
      ? " {\n\t\t...\(try field.type.namedType.scalarType(scalarMap: scalarMap))Fragment\n\t}"
      : ""

    let operationVariables = variablesGenerator.operationVariablesDeclaration(with: field)
    let operationVariablesDeclaration = operationVariables.isEmpty
      ? ""
      : "(\n\(operationVariables)\n)"

    let operationArguments = variablesGenerator.operationArgumentsDeclaration(with: field)
    let operationArgumentsDeclaration = operationArguments.isEmpty
      ? ""
      : "(\n\(operationArguments)\n\t)"

    return """
    // MARK: - Operation Definition

    private let operationDefinitionFormat: String = \"\"\"
    \(operationName)\(operationVariablesDeclaration) {
      \(
        """
        \(field.name)\(operationArgumentsDeclaration)\(selection)
        """
      )
    }

    %1$@
    \"\"\"

    var operationDefinition: String {
      String(
        format: operationDefinitionFormat,
        selections.declaration()
      )
    }
    """
  }
}

// MARK: - Field

private extension Field {
  var isFragment: Bool {
    switch self.type.namedType {
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
