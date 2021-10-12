//
//  File.swift
//  
//
//  Created by Romy Cheah on 7/10/21.
//

import Foundation
import GraphQLAST
import GraphQLCodegenConfig

struct EntityGenerator: GraphQLCodeGenerating {
  private let entityNameMap: EntityNameMap

  init(entityNameMap: EntityNameMap) {
    self.entityNameMap = entityNameMap
  }

  func code(schema _: Schema) throws -> String {
    """
    // @generated
    // Do not edit this generated file
    // swiftlint:disable all

    import Foundation

    // MARK: - Interfaces

    protocol \(entityNameMap.requestParameter): Encodable {
      var requestType: \(entityNameMap.requestType) { get }
    }

    protocol \(entityNameMap.selection): RawRepresentable, Hashable, CaseIterable where RawValue == String {}
    protocol \(entityNameMap.selections) {
      func declaration() -> String
      var operationDefinition: String { get }
    }

    // MARK: - Enum

    enum \(entityNameMap.requestType) {
      case query
      case mutation
      case subscription
    }

    // MARK: \(entityNameMap.request)

    struct \(entityNameMap.request)<RequestParameters: \(entityNameMap.requestParameter)>: Encodable {
      let parameters: RequestParameters
      let selections: \(entityNameMap.selections)

      enum CodingKeys: String, CodingKey {
        case parameters = "variables"
        case query
        case mutation
        case subscription
      }

      init(parameters: RequestParameters, selections: \(entityNameMap.selections)) {
        self.parameters = parameters
        self.selections = selections
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(parameters, forKey: .parameters)

        let operationDefinition = selections.operationDefinition

        switch parameters.requestType {
        case .query:
          try container.encode(operationDefinition, forKey: .query)
        case .mutation:
          try container.encode(operationDefinition, forKey: .mutation)
        case .subscription:
          try container.encode(operationDefinition, forKey: .subscription)
        }
      }
    }

    // MARK: - \(entityNameMap.response)

    struct \(entityNameMap.response)<ResponseData: Codable>: Codable {
      let data: ResponseData
    }

    // MARK: - \(entityNameMap.selection)+Declaration

    extension Collection where Element: \(entityNameMap.selection) {
      var declaration: String {
        if count == 0 {
          return Element.allCases.reduce(into: "") { $0 += "\\n  \\($1.rawValue)" }
        } else {
          return reduce(into: "") { $0 += "\\n  \\($1.rawValue)" }
        }
      }
    }

    // MARK: - \(entityNameMap.selections)+Declaration

    extension \(entityNameMap.selections) {
      func declaration(selectionDeclarationMap: [String: String], rootSelectionKey: String) -> String {
        var dictionary = [String: String]()
        dictionary[rootSelectionKey] = selectionDeclarationMap[rootSelectionKey]

        // Initialize queue with root selection
        var queue = Array(dictionary.values)

        // Remove root selection from SelectionDeclarationMap to prevent circular dependency
        var selectionDeclarationMap = selectionDeclarationMap
        selectionDeclarationMap.removeValue(forKey: rootSelectionKey)

        while !queue.isEmpty {
          let currentFragment = queue.removeFirst()

          for childSelectionKey in selectionDeclarationMap.keys {
            if currentFragment.contains("...\\(childSelectionKey)") {
              let value = selectionDeclarationMap[childSelectionKey]!

              queue.append(value)
              dictionary[childSelectionKey] = value
            }
          }
        }

        return dictionary.values.joined(separator: "\\n")
      }
    }
    """
  }
}