//
//  File.swift
//  
//
//  Created by Romy Cheah on 18/9/21.
//

import Foundation
import GraphQLAST

private typealias FieldMap = [String: Field]

enum RequestParameterSelectionsError: Error, LocalizedError {
  case missingReturnType(context: String)
  case notImplemented(context: String)

  var errorDescription: String? {
    "\(Self.self).\(self)"
  }
}

struct RequestParameterSelectionsGenerator {
  private let scalarMap: ScalarMap

  init(scalarMap: ScalarMap) {
    self.scalarMap = scalarMap
  }

  func declaration(operationField: Field, objects: [ObjectType]) throws -> String {
    let namedType = operationField.type.namedType

    switch namedType {
    case .object:
      return try objectDeclaration(operationField: operationField, objects: objects)
    case .enum, .scalar:
      return """
      // MARK: - Selections

      let selections: Selections

      struct Selections: GraphQLSelections {
        func declaration() -> String {
          \"\"
        }
      }
      """
    case .interface, .union:
      throw RequestParameterSelectionsError.notImplemented(
        context: "\(namedType) for field \(operationField.name)"
      )
    }
  }
}

private extension RequestParameterSelectionsGenerator {
  func objectDeclaration(operationField: Field, objects: [ObjectType]) throws -> String {
    guard
      let returnObjectType = objects.first(where: { $0.name == operationField.type.namedType.name })
    else {
      throw RequestParameterSelectionsError.missingReturnType(context: "No ObjectType type found for field \(operationField.name)")
    }

    let operationFieldScalarType = try operationField.type.namedType.scalarType(scalarMap: scalarMap)
    var dictionary = [operationFieldScalarType: operationField]
    dictionary.merge(try returnObjectType.allNestedObjectField(objects: objects, scalarMap: scalarMap)) { (_, new) in new }

    let sortedDictionary = Array(dictionary).sorted(by: { $0.key < $1.key })

    let code = """
    // MARK: - Selections

    let selections: Selections

    struct Selections: GraphQLSelections {
    \(try sortedDictionary.map { try $0.value.selectionDeclaration(objects: objects, scalarMap: scalarMap) }.lines )

      func declaration() -> String {
        \"\"\"
        \(
          sortedDictionary.map {
            """
            fragment \($0.key.pascalCase)Fragment on \($0.key.pascalCase) {\\(\($0.key.camelCase)Selections.declaration)
            }\n
            """
          }.lines
        )
        \"\"\"
      }
    }
    """
    let formattedCode = try code.format()

    return formattedCode
  }
}

private extension Field {
  func allNestedObjectField(objects: [ObjectType], scalarMap: ScalarMap) throws -> FieldMap {
    guard
      let returnObjectType = objects.first(where: { $0.name == type.namedType.name })
    else {
      return [:]
    }

    var fieldMap = FieldMap()

    switch returnObjectType.kind {
    case .object:
      let scalarType = try self.type.namedType.scalarType(scalarMap: scalarMap)
      fieldMap[scalarType] = self
    case .enumeration, .inputObject, .interface, .scalar, .union:
      break
    }

    try returnObjectType.allFields(objects: objects).forEach {
      switch $0.type {
      case let .named(outputRef):
        switch outputRef {
        case .object:
          let scalarType = try outputRef.scalarType(scalarMap: scalarMap)
          fieldMap[scalarType] = $0
        case .enum, .interface, .scalar, .union:
          break
        }
      case .list, .nonNull:
        fieldMap.merge(try $0.allNestedObjectField(objects: objects, scalarMap: scalarMap)) { (_, new) in new }
      }
    }

    return fieldMap
  }

  func selectionDeclaration(objects: [ObjectType], scalarMap: ScalarMap) throws -> String {
    let returnName = try type.namedType.scalarType(scalarMap: scalarMap)

    guard
      let returnObjectType = objects.first(where: { $0.name == returnName })
    else {
      return ""
    }

    let allFields = returnObjectType.allFields(objects: objects)
    let fieldsEnum = try allFields.map {
      try $0.enumCaseDeclaration(
        name: $0.name,
        type: $0.type,
        scalarMap: scalarMap
      )
    }.lines

    let selectionVariableName = "\(returnName.camelCase)Selections"
    let selectionEnumName = "\(returnName.pascalCase)Selection"

    let result = """
    let \(selectionVariableName): Set<\(selectionEnumName)>

    enum \(selectionEnumName): String, GraphQLSelection {
      \(fieldsEnum)
    }
    """

    return result
  }

  func enumCaseDeclaration(name: String, type: OutputTypeRef, scalarMap: ScalarMap) throws -> String {
    switch type {
    case let .list(outputRef), let .nonNull(outputRef):
      return try enumCaseDeclaration(name: name, type: outputRef, scalarMap: scalarMap)
    case let .named(objectRef):
      switch objectRef {
      case .scalar, .enum:
        return "case \(name) = \"\(name)\""
      case .object:
        return """
        case \(name) = \"\"\"
        \(name) {
          ...\(try objectRef.scalarType(scalarMap: scalarMap))Fragment
        }
        \"\"\"
        """
      case .union, .interface:
        throw RequestParameterSelectionsError.notImplemented(context: "Union and Interface are not implemented yet")
      }
    }
  }
}

private extension ObjectType {
  func allNestedObjectField(objects: [ObjectType], scalarMap: ScalarMap) throws -> FieldMap {
    let allFields = self.allFields(objects: objects)
    let fieldMaps = try allFields.map { try $0.allNestedObjectField(objects: objects, scalarMap: scalarMap) }
    let result = fieldMaps.reduce(into: FieldMap()) { result, fieldMap in
      result.merge(fieldMap) { (_, new) in new }
    }

    return result
  }
}
