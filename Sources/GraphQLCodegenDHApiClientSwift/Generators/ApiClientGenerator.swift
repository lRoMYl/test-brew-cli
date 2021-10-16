//
//  File.swift
//
//
//  Created by Romy Cheah on 24/9/21.
//

import Foundation
import GraphQLAST
import GraphQLCodegenConfig
import GraphQLCodegenNameSwift
import GraphQLCodegenUtil

enum ApiClientGeneratorError: Error, LocalizedError {
  case notImplemented(context: String)

  var errorDescription: String? {
    "\(Self.self).\(self)"
  }
}

struct ApiClientGenerator: Generating {
  private let apiClientPrefix: String

  private let apiClientName: String
  private let apiClientProtocolName: String

  private let entityNameMap: EntityNameMap
  private let scalarMap: ScalarMap
  private let entityNameProvider: EntityNameProviding

  init(entityNameMap: EntityNameMap, scalarMap: ScalarMap, entityNameProvider: EntityNameProviding) {
    self.apiClientPrefix = entityNameMap.apiClientPrefix
    self.apiClientName = entityNameMap.apiClientName(apiClientPrefix: apiClientPrefix)
    self.apiClientProtocolName = entityNameMap.apiClientProtocolName(apiClientPrefix: apiClientPrefix)
    self.entityNameMap = entityNameMap
    self.scalarMap = scalarMap
    self.entityNameProvider = entityNameProvider
  }

  func code(schema: Schema) throws -> String {
    let resourceParametersConfigurating = entityNameMap.resourceParametersConfiguratingName(apiClientPrefix: apiClientPrefix)
    let resourceParametersConfiguratorVariable = entityNameMap.resourceParametersConfiguratorVariableName()

    return """
    \(try protocolCode(with: schema.operations))

    // MARK: - \(apiClientProtocolName)

    final class \(apiClientName): \(apiClientProtocolName) {
      private let restClient: RestClient
      private let scheduler: SchedulerType
      private let \(resourceParametersConfiguratorVariable): \(resourceParametersConfigurating)?

      init(
        restClient: RestClient,
        scheduler: SchedulerType = ConcurrentDispatchQueueScheduler(qos: .background),
        \(resourceParametersConfiguratorVariable): \(resourceParametersConfigurating)? = nil
      ) {
        self.restClient = restClient
        self.scheduler = scheduler
        self.\(resourceParametersConfiguratorVariable) = \(resourceParametersConfiguratorVariable)
      }

      \(try schema.operations.map { try funcCode(with: $0).lines }.lines)
    }

    private extension \(apiClientName) {
      \(try schema.operations.map { try executeCode(with: $0) }.lines)
    }
    """
  }
}

extension ApiClientGenerator {
  func protocolCode(with operation: GraphQLAST.Operation) throws -> String {
    let funcDeclarations: [String] = try operation.type.fields.map {
      try funcSignatureCode(field: $0, operation: operation)
    }

    return funcDeclarations.lines
  }

  func protocolCode(with operations: [GraphQLAST.Operation]) throws -> String {
    return """
    protocol \(apiClientProtocolName) {
      \(
        try operations.map {
          try protocolCode(with: $0)
        }.lines
      )
    }
    """
  }

  func funcCode(with operation: GraphQLAST.Operation) throws -> [String] {
    let operationName = operation.type.name.pascalCase
    let resourceParameterName = entityNameMap.resourceParametersName(apiClientPrefix: apiClientPrefix)
    let resourceParametersConfiguratorVariable = entityNameMap.resourceParametersConfiguratorVariableName()

    var codes: [String] = try operation.type.fields.map {
      let funcSignature = try funcSignatureCode(field: $0, operation: operation)
      let enumName = $0.enumName(with: operation)

      return """
      \(funcSignature) {
        let resource = \(resourceParameterName)(
          \(resourceParametersConfiguratorVariable): \(resourceParametersConfiguratorVariable),
          resourceBodyParameters: .\(enumName)(request: request, selections: selections)
        )

        return executeGraphQL\(operationName)(
          resource: resource
        )
      }
      """
    }

    codes.append("""
    func \(operation.enumNamePrefix) (
      request: \(try entityNameProvider.requestParameterName(with: operation)),
      selections: \(try entityNameProvider.selectionsName(with: operation))
    ) -> \(responseGenericCode(text: try entityNameProvider.name(for: operation.type))) {
      let resource = \(resourceParameterName)(
        \(resourceParametersConfiguratorVariable): \(resourceParametersConfiguratorVariable),
        resourceBodyParameters: .\(operation.enumNamePrefix)(request: request, selections: selections)
      )

      return executeGraphQLQuery(
        resource: resource
      )
    }
    """)

    return codes
  }

  func funcSignatureCode(field: Field, operation: GraphQLAST.Operation) throws -> String {
    let responseDataText = try entityNameProvider.responseDataName(for: field, with: operation)

    let parametersName = try entityNameProvider.requestParameterName(for: field, with: operation)
    let selectionsName = try entityNameProvider.selectionsName(for: field, operation: operation)

    return """
    func \(field.funcName())(
      with request: \(parametersName),
      selections: \(selectionsName)
    ) -> \(responseGenericCode(text: responseDataText))
    """
  }

  /// Executation for operation type is generated only if its defined in the schema
  /// E.g. If the schema have no mutation, no mutation object will be present in the schema, thus executeGraphQL cannot be generated respectively
  func executeCode(with operation: GraphQLAST.Operation) throws -> String {
    let operationName = operation.type.name.pascalCase
    let genericResponse = "Response"
    let responseDataText = "\(entityNameMap.response)<\(genericResponse)>"
    let responseGenericCode = self.responseGenericCode(text: genericResponse)
    let responseDataGenericCode = self.responseGenericCode(text: responseDataText)

    return """
    func executeGraphQL\(operationName)<\(genericResponse)>(
      resource: ResourceParameters
    ) -> \(responseGenericCode) where \(genericResponse): Codable {
      let request: \(responseDataGenericCode) = restClient
        .executeRequest(resource: resource)

      return request
        .map { apiResponse in
          return ApiResponse(
            data: apiResponse.data?.data,
            httpURLResponse: apiResponse.httpURLResponse,
            metaData: apiResponse.metaData
          )
        }
        .subscribe(on: scheduler)
    }
    """
  }

  func responseGenericCode(text: String) -> String {
    "Single<ApiResponse<\(text)>>"
  }
}
