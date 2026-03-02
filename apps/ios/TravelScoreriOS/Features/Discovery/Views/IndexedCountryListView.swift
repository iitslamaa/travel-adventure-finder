//
//  IndexedCountryListView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/1/26.
//

import SwiftUI
import UIKit

struct IndexedCountryListView: UIViewControllerRepresentable {

    let countries: [Country]

    func makeUIViewController(context: Context) -> IndexedCountryListController {
        let listController = IndexedCountryListController(countries: countries)
        return listController
    }

    func updateUIViewController(_ uiViewController: IndexedCountryListController,
                                context: Context) {
        uiViewController.update(countries: countries)
    }
}
