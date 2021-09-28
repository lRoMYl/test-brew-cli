//
//  GraphQLCodegenExampleApp.swift
//  GraphQLCodegenExample
//
//  Created by Romy Cheah on 23/9/21.
//

import ApiClient
import RxSwift
import SwiftUI

@main
struct GraphQLCodegenExampleApp: App {
  private let disposeBag = DisposeBag()
  private let groceriesRepository: GroceriesApiClientImplementing = {
    let restClient = RestClientImpl(
      webService: GroceriesWebService(),
      authProvider: nil
    )

    let repository = GroceriesApiClient(restClient: restClient)

    return repository
  }()

  var body: some Scene {
    WindowGroup {
      ContentView().onAppear() {
        setup()

        try? testGroceriesGraphQL()
      }
    }
  }
}

extension GraphQLCodegenExampleApp {
  func setup() {
    GroceriesResourceParametersDIContainer.shared.implementation
      = GraphQLResourceParametersImplementation()
  }

  func testGroceriesGraphQL() throws {
    let parameters = GroceriesQueries.CampaignsRequestParameter(
      vendorId: "x1yy",
      globalEntityId: "FP_SG",
      locale: "en_SG",
      languageId: "1",
      languageCode: "en",
      apikY: "iQis4oC8Y4DxHiO5",
      discoClientId: "iOS"
    )

    groceriesRepository
      .campaigns(with: parameters)
      .subscribe(
        onSuccess: { response in
          guard let data = response.data else {
            print("Empty Response Data")
            return
          }
          print(data)
        },
        onError: { error in
          print(error)
        }
      )
      .disposed(by: disposeBag)
  }
}